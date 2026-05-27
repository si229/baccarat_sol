const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("BaccaratModule", (m) => {
  const usdt = m.contract("MockUSDT");
  const pepe = m.contract("MockPEPE");
  const baccarat = m.contract("Baccarat", [pepe, usdt]);

  return { baccarat, pepe, usdt };
});
