const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

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

  updateGameServerConfig({
    baccarat: baccarat.target,
    pepe: pepe.target,
    usdt: usdt.target
  });
  updateWeb3ApiEnv({ baccarat: baccarat.target });
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

function updateGameServerConfig(addresses) {
  const configPath = path.resolve(__dirname, "../../gameServer/config/sys.config");
  if (!fs.existsSync(configPath)) {
    console.log("gameServer sys.config not found, skipped:", configPath);
    return;
  }

  let content = fs.readFileSync(configPath, "utf8");
  content = content.replace(
    /\{contract_address,\s*<<"0x[a-fA-F0-9]{40}">>\}/,
    `{contract_address, <<"${addresses.baccarat}">>}`
  );

  const tokenConfig = `{token_addresses, #{\n            <<"PEPE">> => <<"${addresses.pepe}">>,\n            <<"USDT">> => <<"${addresses.usdt}">>\n        }}`;
  if (/\{token_addresses,\s*#\{[\s\S]*?\}\s*\}/.test(content)) {
    content = content.replace(/\{token_addresses,\s*#\{[\s\S]*?\}\s*\}/, tokenConfig);
  } else {
    content = content.replace(
      /(\{contract_address,\s*<<"0x[a-fA-F0-9]{40}">>\},)/,
      `$1\n        ${tokenConfig},`
    );
  }

  fs.writeFileSync(configPath, content, "utf8");
  console.log("gameServer config updated:", configPath);
}

function updateWeb3ApiEnv(addresses) {
  const envPath = path.resolve(__dirname, "../../web3-api/.env");
  if (!fs.existsSync(envPath)) {
    console.log("web3-api .env not found, skipped:", envPath);
    return;
  }

  let content = fs.readFileSync(envPath, "utf8");
  if (/^BACCARAT_CONTRACT_ADDRESS=.*$/m.test(content)) {
    content = content.replace(/^BACCARAT_CONTRACT_ADDRESS=.*$/m, `BACCARAT_CONTRACT_ADDRESS=${addresses.baccarat}`);
  } else {
    content = `${content.replace(/\s*$/, "")}\nBACCARAT_CONTRACT_ADDRESS=${addresses.baccarat}\n`;
  }

  fs.writeFileSync(envPath, content, "utf8");
  console.log("web3-api .env updated:", envPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
