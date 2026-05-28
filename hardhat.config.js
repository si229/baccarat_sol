require("@nomicfoundation/hardhat-toolbox");

const localhostPrivateKey = process.env.LOCALHOST_PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks:{
    hardhat:{},
    localhost:{
      url:"http://127.0.0.1:8545",
      ...(localhostPrivateKey ? { accounts:[localhostPrivateKey] } : {})
    }
  }
};
