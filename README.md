# ERC721ExampleDeed

`ExampleDeed.sol` is an attempt to implement the latest draft of the ERC721 standard.

Its inheriting contract `ERC721Deed.sol` is based on the `ERC721Token` from OpenZeppelin (https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/ERC721/ERC721Token.sol). The term NFT (non-fungible token) was dropped in favour of the more fitting term deed.

*Warning:* The standard is still open for discussion, so this project should be considered work in progress. Follow the discussion here: https://github.com/ethereum/EIPs/pull/841

## About this example

For this example, each deed is associated with a name and a beneficiary, and the concept of "appropriation" is introduced: Deeds are permanently up for sale.
Whoever is willing to pay more than the last price that was paid for a given deed, can take ownership of that deed.

The previous owner is reimbursed with the amount he paid earlier, and additionally receives half of the amount that the price was increased by. The other half goes to the deed's beneficiary address.

The contract supports PullPayments. Anyone can send ether to a deed, and the deed's beneficiary can withdraw such received amounts.

## Tests and mocks

The tests and mocks of this repository are based on OpenZeppelin work. The directory structure is a result of the decision to install their contracts through EthPM instead of NPM.

## TODO

Thanks to the efforts of OpenZeppelin, tests for `ERC721Deed.sol` were derived from their `ERC721TokenTest.test.js`. Further tests are required, especially for `ExampleDeed.sol`.
