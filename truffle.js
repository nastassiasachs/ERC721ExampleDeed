require("babel-register");
require("babel-polyfill");
// var HDWalletProvider = require("truffle-hdwallet-provider");
// var infura_apikey = "<key>";
// var mnemonic = "<bla bla bla>";

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "4447",
    },
    // ropsten: {
    //   provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/"),
    //   network_id: "3",
    //   gas: 6700000
    // },
  }
};
