require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.16",
      },
      {
        version: "0.5.12",
      },
      {
        version: "0.4.17",
        settings: {},
      },
    ],
  },
};
