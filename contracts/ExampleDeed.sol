pragma solidity ^0.4.18;

import "zeppelin/contracts/math/SafeMath.sol";
import "zeppelin/contracts/lifecycle/Pausable.sol";
import "zeppelin/contracts/payment/PullPayment.sol";
import "zeppelin/contracts/ReentrancyGuard.sol";
import "./ERC721Deed.sol";
import "./ERC721Metadata.sol";

/*
  Notes on this example implementation:

  For this example, each deed is associated with a name and a beneficiary, and the concept of "appropriation" is introduced: Deeds are permanently up for sale.
  Whoever is willing to pay more than the last price that was paid for a given deed, can take ownership of that deed.
  The previous owner is reimbursed with the amount he paid earlier, and additionally receives half of the amount that the price was increased by. The other half goes to the deed's beneficiary address.
 */

contract ExampleDeed is ERC721Deed, Pausable, PullPayment, ReentrancyGuard {

  using SafeMath for uint256;


  /* Events */

  // When a dead is created by the contract owner.
  event Creation(uint256 indexed id, bytes32 indexed name, address beneficiary);

  // When a deed is appropriated, the ownership of the deed is transferred to the new owner. The old owner is reimbursed, and he and the deed's beneficiary share the profit of the sale.
  event Appropriation(uint256 indexed id, address indexed oldOwner, uint256 oldPrice, address indexed newOwner, uint256 newPrice);

  // Payments to the deed's beneficiary address via PullPayment are also supported by this contract.
  event Payment(uint256 indexed id, address indexed sender, address indexed beneficiary, uint256 amount);

  // When a deed needs to be removed. Payments to benefeciaries are kept available for withdrawal. The contract owner needs to own the deed in order to be able to destroy it. So, deed owners are protected from involuntary loss of the potential reimbursement.
  event Destruction(uint256 indexed id);


  /* The actual deeds */

  // The data structure of the example deed
  struct Example {
    bytes32 name;
    address beneficiary;
    uint256 price;
    uint256 created;
    uint256 deleted;
  }

  // Mapping from _deedId to Example
  mapping (uint256 => Example) private deeds;

  // Mapping from deed name to boolean indicating if the name is already taken
  mapping (bytes32 => bool) private deedNameExists;

  // Needed to make all deeds discoverable. The length of this array also serves as our deed ID.
  uint256[] private deedIds;


  /* Variables in control of owner */

  // The contract owner can change the initial price of deeds at Creation.
  uint256 private creationPrice = 0.01 ether;

  // The contract owner can change the base URL, in case it becomes necessary. It is needed for Metadata.
  string public url = "http://example.com/";

  // ERC-165 Metadata
  bytes4 internal constant INTERFACE_SIGNATURE_ERC165 = // 0x01ffc9a7
      bytes4(keccak256('supportsInterface(bytes4)'));

  bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = // 0xda671b9b
      bytes4(keccak256('ownerOf(uint256)')) ^
      bytes4(keccak256('countOfDeeds()')) ^
      bytes4(keccak256('countOfDeedsByOwner(address)')) ^
      bytes4(keccak256('deedOfOwnerByIndex(address,uint256)')) ^
      bytes4(keccak256('approve(address,uint256)')) ^
      bytes4(keccak256('takeOwnership(uint256)'));

  bytes4 internal constant INTERFACE_SIGNATURE_ERC721Metadata = // 0x2a786f11
      bytes4(keccak256('name()')) ^
      bytes4(keccak256('symbol()')) ^
      bytes4(keccak256('deedUri(uint256)'));


  function ExampleDeed() public {}

  // The contract owner can withdraw funds that were received this way.
  function() public payable {}

  modifier onlyExistingNames(uint256 _deedId) {
    require(deedNameExists[deeds[_deedId].name]);
    _;
  }

  modifier noExistingNames(bytes32 _name) {
    require(!deedNameExists[_name]);
    _;
  }

  modifier notDeleted(uint256 _deedId) {
    require(deeds[_deedId].deleted == 0);
    _;
  }


   /* ERC721Metadata */

  function name()
  external pure returns (string) {
    return "ExampleDeed";
  }

  function symbol()
  external pure returns (string) {
    return "ED";
  }

  function supportsInterface(bytes4 _interfaceID)
  external pure returns (bool) {
    return (
      _interfaceID == INTERFACE_SIGNATURE_ERC165
      || _interfaceID == INTERFACE_SIGNATURE_ERC721
      || _interfaceID == INTERFACE_SIGNATURE_ERC721Metadata
    );
  }

  function deedUri(uint256 _deedId)
  external view onlyExistingNames(_deedId) returns (string _uri) {
    _uri = _strConcat(url, _bytes32ToString(deeds[_deedId].name));
  }

  function deedName(uint256 _deedId)
  external view onlyExistingNames(_deedId) returns (string _name) {
    _name = _bytes32ToString(deeds[_deedId].name);
  }


  /* Enable listing of all deeds (alternative to ERC721Enumerable to avoid having to work with arrays). */
  function ids()
  external view returns (uint256[]) {
    return deedIds;
  }

  function deed(uint256 _deedId)
  external view returns (Example) {
    return deeds[_deedId];
  }


  /* Core features of the example: Appropriation and Payment */

  // Forces the transfer of the deed to a new owner, if a higher price was paid. This functionality can be paused by the owner.
  function appropriate(uint256 _deedId)
  external whenNotPaused nonReentrant payable {
    // The new price must be greater than the old price.
    uint256 oldPrice = priceOf(_deedId);
    uint256 newPrice = msg.value;
    require(newPrice > oldPrice);

    // The current owner is forbidden to appropriate himself.
    address oldOwner = this.ownerOf(_deedId);
    address newOwner = msg.sender;
    require(oldOwner != newOwner);

    // Set new price of the deed.
    deeds[_deedId].price = newPrice;

    // The profit is split between the previous deed owner and the deed beneficiary in equal parts.
    uint256 profitShare = newPrice.sub(oldPrice).div(2);

    // The deed beneficiary gets his share.
    asyncSend(beneficiaryOf(_deedId), profitShare);

    // Reimburse previous owner with his share and the price he paid.
    asyncSend(oldOwner, profitShare.add(oldPrice));

    // Clear any outstanding approvals and transfer the deed.
    clearApprovalAndTransfer(oldOwner, newOwner, _deedId);
    Appropriation(_deedId, oldOwner, oldPrice, newOwner, newPrice);
  }

  // Send a PullPayment.
  function pay(uint256 _deedId)
  external nonReentrant payable {
    address beneficiary = beneficiaryOf(_deedId);
    asyncSend(beneficiary, msg.value);
    Payment(_deedId, msg.sender, beneficiary, msg.value);
  }

  // The owner can only withdraw what has not been assigned to beneficiaries as PullPayments.
  function withdraw()
  external nonReentrant {
    withdrawPayments();
    if (msg.sender == owner) {
      // The contract's balance MUST stay backing the outstanding withdrawals. Only the surplus not needed for any backing can be withdrawn by the owner.
      uint256 surplus = this.balance.sub(totalPayments);
      if (surplus > 0) {
        owner.transfer(surplus);
      }
    }
  }


  /* Owner Functions */

  // The contract owner creates deeds. Newly created deeds are initialised with a name and a beneficiary.
  function create(bytes32 _name, address _beneficiary)
  public onlyOwner noExistingNames(_name) {
    deedNameExists[_name] = true;
    uint256 deedId = deedIds.length;
    deedIds.push(deedId);
    super._mint(owner, deedId);
    deeds[deedId] = Example({
      name: _name,
      beneficiary: _beneficiary,
      price: creationPrice,
      created: now,
      deleted: 0
    });
    Creation(deedId, _name, owner);
  }

  // Deeds can only be burned if the contract owner is also the deed owner. This ensures that the deed owner is reimbursed when the contract owner needs to remove a deed from the contract.
  function destroy(uint256 _deedId)
  public onlyOwner notDeleted(_deedId) {
    // We deliberately let the name stay in use, so that each name remains a unique identifier forever.

    // We deliberately let any payments stored for the beneficiary. The contract owner cannot withdraw such deposits.

    // Iterating over an array of IDs is too expensive, so we mark the deed as deleted instead.
    deeds[_deedId].deleted = now;

    super._burn(_deedId);
    Destruction(_deedId);
  }

  function setCreationPrice(uint256 _price)
  public onlyOwner {
    creationPrice = _price;
  }

  function setUrl(string _url)
  public onlyOwner {
    url = _url;
  }

  /* Other publicly available functions */

  // Returns the last paid price for this deed.
  function priceOf(uint256 _deedId)
  public view notDeleted(_deedId) returns (uint256 _price) {
    _price = deeds[_deedId].price;
  }

  // Returns the current beneficiary of the deed.
  function beneficiaryOf(uint256 _deedId)
  public view notDeleted(_deedId) returns (address _beneficiary) {
    _beneficiary = deeds[_deedId].beneficiary;
  }


  /* Private helper functions */

  function _bytes32ToString(bytes32 _bytes32)
  private pure returns (string) {
    bytes memory bytesString = new bytes(32);
    uint charCount = 0;
    for (uint j = 0; j < 32; j++) {
      byte char = byte(bytes32(uint(_bytes32) * 2 ** (8 * j)));
      if (char != 0) {
        bytesString[charCount] = char;
        charCount++;
      }
    }
    bytes memory bytesStringTrimmed = new bytes(charCount);
    for (j = 0; j < charCount; j++) {
      bytesStringTrimmed[j] = bytesString[j];
    }

    return string(bytesStringTrimmed);
  }

  function _strConcat(string _a, string _b)
  private pure returns (string) {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    string memory ab = new string(_ba.length + _bb.length);
    bytes memory bab = bytes(ab);
    uint k = 0;
    for (uint i = 0; i < _ba.length; i++) bab[k++] = _ba[i];
    for (i = 0; i < _bb.length; i++) bab[k++] = _bb[i];
    return string(bab);
  }

}
