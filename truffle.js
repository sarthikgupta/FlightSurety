// var HDWalletProvider = require("truffle-hdwallet-provider");
// var mnemonic = "rack dream head onion major scheme short rapid spare team tobacco ghost";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost
      port: 8545,            // Standard Ganache UI port
      network_id: "*", 
      gas: 6700000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};