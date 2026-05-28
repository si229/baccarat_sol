# Baccarat Contracts

## Directory

- `contracts/baccarat/Baccarat.sol` - main Baccarat escrow, bet, settlement, and prize pool contract.
- `contracts/interfaces/IBaccarat.sol` - public API, events, enums, and shared structs.
- `contracts/mocks/MockPEPE.sol` - mock PEPE token for local testing.
- `contracts/mocks/MockUSDT.sol` - mock 6-decimal USDT token for local testing.
- `scripts/deploy.js` - deploys mock tokens and the Baccarat contract.
- `test/Baccarat.js` - Hardhat tests for player balance, prize pool, bet, and settlement flows.

## Commands

```shell
npx hardhat compile
npx hardhat test
npx hardhat node --hostname 0.0.0.0 --port 8545
npx hardhat run scripts/deploy.js --network localhost
```

## Troubleshooting

If Hardhat prints `Baccarat#<unrecognized-selector>`, check that your app is using the latest Baccarat address, not a mock token address:

```shell
$env:CHECK_ADDRESS="<address>"
npx hardhat run scripts/check-contract.js --network localhost
```
