require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks:{
    hardhat:{},
    localhost:{
      url:"http://127.0.0.1:8545",
      accounts:["0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"]

    }
  }
};
