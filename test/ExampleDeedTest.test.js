import assertRevert from './helpers/assertRevert';
const BigNumber = web3.BigNumber;
const ExampleDeed = artifacts.require('ExampleDeed.sol');

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract('ExampleDeed', accounts => {
  let deed = null;
  const _firstDeedName = 'one';
  const _secondDeedName = 'two';
  const _deletedDeedName = 'del';
  const _unknownDeedId = 999;
  const _creator = accounts[0];
  const _firstBeneficiary = accounts[1];
  const _secondBeneficiary = accounts[2];
  const _unrelatedAddr = accounts[3];
  const _appropriator = accounts[4];
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

  beforeEach(async function () {
    deed = await ExampleDeed.new({ from: _creator });
    await deed.create(_firstDeedName, _firstBeneficiary, { from: _creator });
    await deed.create(_secondDeedName, _secondBeneficiary, { from: _creator });
    await deed.create(_deletedDeedName, _secondBeneficiary, { from: _creator });
  });

  describe('destroy', function () {
    describe('when the given id exists', function () {
      it('marks the deed as deleted', async function () {
        let countOfDeeds = await deed.countOfDeeds();
        countOfDeeds.should.be.bignumber.equal(3);
        let count = await  deed.countOfDeedsByOwner(_creator);
        let deedId = await deed.deedOfOwnerByIndex(_creator, --count);
        await deed.destroy(deedId);
        countOfDeeds = await deed.countOfDeeds();
        countOfDeeds.should.be.bignumber.equal(2);
      });
    });

    describe('when the given id does not exist', function () {
      it('reverts', async function () {
        await assertRevert(deed.destroy(_unknownDeedId));
      });
    });
  });


  describe('appropriate', function () {
    describe('when the given id does not exist', function () {
      it('reverts', async function () {
        await assertRevert(deed.appropriate(_unknownDeedId));
      });
    });

    // FIXME: Error "AssertionError: Expected "revert", got AssertionError: assert.fail() instead"
    // describe('when the given id exists', function () {
    //   it('reverts', async function () {
    //
    //     describe('when not enough ether was sent', function () {
    //       it('to a valid id', async function () {
    //         await assertRevert(deed.appropriate(0, {from: _appropriator, value: web3.toWei(0.0001, 'ether')}));
    //       });
    //     });
    //
    //     describe('when enough ether was sent', function () {
    //       it('reverts when id is unknown', async function () {
    //         await assertRevert(deed.appropriate(_unknownDeedId, {from: _appropriator, value: web3.toWei(1, 'ether')}));
    //       });
    //     });
    //   });
    // });

  });

});
