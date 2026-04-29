const hre = require("hardhat");

async function main() {
  const Baccarat = await hre.ethers.getContractFactory("Baccarat");
  const baccarat = await Baccarat.deploy();
  await baccarat.waitForDeployment();
  console.log("Baccarat deployed to:", baccarat.target);
}

// 错误处理
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});