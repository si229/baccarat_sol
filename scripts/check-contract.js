const hre = require("hardhat");

async function main() {
  const address = process.env.CHECK_ADDRESS;

  if (!address) {
    throw new Error("Usage: $env:CHECK_ADDRESS='<contract-address>'; npx hardhat run scripts/check-contract.js --network localhost");
  }

  const code = await hre.ethers.provider.getCode(address);
  console.log("Address:", address);
  console.log("Has code:", code !== "0x");

  if (code === "0x") {
    return;
  }

  const baccarat = await hre.ethers.getContractAt("Baccarat", address);

  try {
    console.log("Baccarat.owner():", await baccarat.owner());
    console.log("Baccarat.getToken(0):", await baccarat.getToken(0));
    console.log("Baccarat.getToken(1):", await baccarat.getToken(1));
    console.log("Baccarat.getToken(2):", await baccarat.getToken(2));
  } catch (error) {
    console.log("Baccarat check failed:", error.shortMessage || error.message);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
