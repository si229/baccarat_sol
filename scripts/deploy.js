const hre = require("hardhat");

async function main() {
  const MockUSDT = await hre.ethers.getContractFactory("MockUSDT");
  const usdt = await MockUSDT.deploy();
  await usdt.waitForDeployment();
  console.log("USDT deployed to:", usdt.target);

  const PEPE = await hre.ethers.getContractFactory("MockPEPE");
  const pepe = await PEPE.deploy();
  await pepe.waitForDeployment();
  console.log("PEPE deployed to:", pepe.target);

  const Baccarat = await hre.ethers.getContractFactory("Baccarat");
  const baccarat = await Baccarat.deploy(pepe.target, usdt.target);
  await baccarat.waitForDeployment();
  console.log("Baccarat deployed to:", baccarat.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
