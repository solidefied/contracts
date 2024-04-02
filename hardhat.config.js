const KEYS = require("./scriptKey.json");
require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    polygonMumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${KEYS.POLYGONMUMBAI.Key}`,
      accounts: KEYS.ACC_PRIVATE_KEY,
      timeout: 3600000,
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${KEYS.GOERLI.Key}`,
      accounts: KEYS.ACC_PRIVATE_KEY,
      timeout: 3600000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.25",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.8",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.4.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      polygonMumbai: KEYS.ETHERSCAN.polygonMumbai,
      goerli: KEYS.ETHERSCAN.goerli,
    },
  },
};
