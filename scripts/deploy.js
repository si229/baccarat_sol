const hre = require("hardhat");

async function main() {
  const [deployer, ...testAccounts] = await hre.ethers.getSigners();

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

  await distributeHalfToTestAccounts(usdt, "USDT", testAccounts);
  await distributeHalfToTestAccounts(pepe, "PEPE", testAccounts);
}

async function distributeHalfToTestAccounts(token, symbol, accounts) {
  if (!accounts.length) {
    console.log(`${symbol} distribution skipped: no test accounts`);
    return;
  }

  const totalSupply = await token.totalSupply();
  const totalDistribution = totalSupply / 2n;
  const share = totalDistribution / BigInt(accounts.length);
  const decimals = await token.decimals();

  for (const account of accounts) {
    const tx = await token.transfer(account.address, share);
    await tx.wait();
  }

  console.log(`${symbol} distributed: ${hre.ethers.formatUnits(totalDistribution, decimals)} total, ${hre.ethers.formatUnits(share, decimals)} each to ${accounts.length} test accounts`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
