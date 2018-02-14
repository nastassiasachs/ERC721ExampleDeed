var ExampleDeed = artifacts.require("./ExampleDeed.sol");

module.exports = function(deployer) {
  deployer.deploy(ExampleDeed);
};
