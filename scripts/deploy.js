const hre = require("hardhat");

async function main() {
  const Baccarat = await hre.ethers.getContractFactory("Baccarat");
  const baccarat = await Baccarat.deploy();
  await baccarat.waitForDeployment();
  console.log("baccarat deployed to:", baccarat.target);

  const USDT = await hre.ethers.getContractFactory("MockUSDT");
  const Usdt = await USDT.deploy();
  await Usdt.waitForDeployment();
  console.log("USDT deployed to:", Usdt.target);

  const PEPE = await hre.ethers.getContractFactory("PEPE");
  const Pepe = await PEPE.deploy();
  await Pepe.waitForDeployment();
  console.log("PEPE deployed to:", Pepe.target);
}

// 错误处理
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});