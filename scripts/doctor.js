const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

const ENTRYPOINTS = [
  "deposit(uint8,uint256)",
  "depositPlayerBalance(uint8,uint256)",
  "withdraw(uint8,uint256)",
  "withdrawPlayerBalance(uint8,uint256)",
  "settlePlayerBalances(address,uint8[],int256[])",
  "contractVersion()"
];

async function main() {
  const address = process.env.CHECK_ADDRESS || readWeb3ApiContractAddress();
  if (!address) {
    throw new Error("Set CHECK_ADDRESS or BACCARAT_CONTRACT_ADDRESS in web3-api/.env");
  }

  const network = await hre.ethers.provider.getNetwork();
  const code = await hre.ethers.provider.getCode(address);
  const artifact = await hre.artifacts.readArtifact("Baccarat");

  console.log("Network:", hre.network.name);
  console.log("Chain ID:", network.chainId.toString());
  console.log("Contract:", address);
  console.log("Has code:", code !== "0x");
  console.log("Artifact bytecode bytes:", byteLength(artifact.deployedBytecode));
  console.log("On-chain bytecode bytes:", byteLength(code));
  console.log("Entrypoints:");
  for (const signature of ENTRYPOINTS) {
    const selector = hre.ethers.id(signature).slice(0, 10);
    console.log(`  ${selector} ${signature} ${code.toLowerCase().includes(selector.slice(2)) ? "OK" : "MISSING"}`);
  }

  if (code === "0x") return;

  const baccarat = await hre.ethers.getContractAt("Baccarat", address);
  console.log("contractVersion:", await optionalCall(() => baccarat.contractVersion()));
  console.log("owner:", await optionalCall(() => baccarat.owner()));
  console.log("getToken(0):", await optionalCall(() => baccarat.getToken(0)));
  console.log("getToken(1):", await optionalCall(() => baccarat.getToken(1)));
  console.log("getToken(2):", await optionalCall(() => baccarat.getToken(2)));
}

function byteLength(hex) {
  return hex && hex !== "0x" ? (hex.length - 2) / 2 : 0;
}

async function optionalCall(fn) {
  try {
    return await fn();
  } catch (error) {
    return `ERROR: ${error.shortMessage || error.message}`;
  }
}

function readWeb3ApiContractAddress() {
  const envPath = path.resolve(__dirname, "../../web3-api/.env");
  if (!fs.existsSync(envPath)) return "";

  const content = fs.readFileSync(envPath, "utf8");
  const match = content.match(/^BACCARAT_CONTRACT_ADDRESS=(0x[a-fA-F0-9]{40})$/m);
  return match ? match[1] : "";
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
