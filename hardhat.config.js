require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  paths: {
    artifacts: './src/artifacts',
  },
  networks: {
    fuji: {
      url: process.env.FUJI_URL,
      accounts: process.env.PRIVATE_KEY,
      chainID: 43113,
    },
  },
};
