# Baccarat Contracts

## Directory

- `contracts/baccarat/Baccarat.sol` - main Baccarat escrow, bet, settlement, and prize pool contract.
- `contracts/interfaces/IBaccarat.sol` - public API, events, enums, and shared structs.
- `contracts/mocks/MockPEPE.sol` - mock PEPE token for local testing.
- `contracts/mocks/MockUSDT.sol` - mock 6-decimal USDT token for local testing.
- `scripts/deploy.js` - deploys mock tokens and the Baccarat contract.
- `test/Baccarat.js` - Hardhat tests for player balance, prize pool, bet, and settlement flows.

## Fresh Environment Startup

Use these steps after cloning the contract project into a new local environment.

### One-command Windows startup

From PowerShell:

```powershell
cd E:\contract\baccarat_sol
.\scripts\init-local.ps1 all
```

Or through npm:

```powershell
cd E:\contract\baccarat_sol
npm run init:windows
```

The script installs contract dependencies, compiles, starts a local Hardhat node in a new PowerShell window, deploys the local contracts, verifies the deployment, starts `web3-api`, and starts `gameServer`.

You can also run one step at a time:

```powershell
.\scripts\init-local.ps1 setup
.\scripts\init-local.ps1 node
.\scripts\init-local.ps1 deploy
.\scripts\init-local.ps1 doctor
.\scripts\init-local.ps1 web3
.\scripts\init-local.ps1 game
```

### About `npx hardhat --init`

Do not run `npx hardhat --init` in this existing repository. That command is for creating a new Hardhat project in an empty directory and will prompt for a project template. This repository already has its Hardhat config, contracts, scripts, tests, and lock file, so new environments should use `npm ci`.

This project currently stays on Hardhat 2 because Hardhat 3 migration requires Node.js `v22.10.0` or newer and an ESM/plugin migration. Upgrade only after the team standardizes on Node 22+ and can validate the full contract, web3-api, and gameServer flow.

### 1. Install dependencies and compile

```powershell
cd E:\contract\baccarat_sol
npm ci
npm run compile
```

### 2. Start the local Hardhat chain

Keep this PowerShell window running:

```powershell
cd E:\contract\baccarat_sol
npx hardhat node --hostname 0.0.0.0 --port 8545
```

### 3. Deploy local contracts

Open a second PowerShell window:

```powershell
cd E:\contract\baccarat_sol
npm run deploy:localhost
```

The deploy script deploys `MockUSDT`, `MockPEPE`, and `Baccarat`. It also updates:

- `../gameServer/config/sys.config`
- `../web3-api/.env`

Run the doctor command to verify the deployed Baccarat contract:

```powershell
cd E:\contract\baccarat_sol
npm run doctor:localhost
```

### 4. Start web3-api

If `../web3-api/.env` does not exist, create it with values matching the local chain and the deployed Baccarat address:

```env
ETH_HTTP_URL=http://127.0.0.1:8545
ETH_WS_URL=ws://127.0.0.1:8545
BACCARAT_CONTRACT_ADDRESS=<deployed Baccarat address>
CONTRACT_OWNER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
WEB3_API_ADDR=:9090
WEB3_INTERNAL_TOKEN=baccarat-local-internal-20260529
GAME_SERVER_BALANCE_URL=http://127.0.0.1:7000/api/balance/update
```

Then start the service:

```powershell
cd E:\contract\web3-api
go mod download
go run .\cmd\web3-api
```

### 5. Start gameServer

```powershell
cd E:\contract\gameServer
rebar3 compile
rebar3 shell
```

The local web page is usually available at:

```text
http://127.0.0.1:7000/
```

If `hardhat node` is stopped and restarted, the local chain state is reset. Run `npm run deploy:localhost` again to redeploy and refresh the dependent configs.

## Commands

```shell
npm run compile
npm test
npm run deploy:localhost
npm run doctor:localhost
```

## Troubleshooting

If Hardhat prints `Baccarat#<unrecognized-selector>`, check that your app is using the latest Baccarat address, not a mock token address:

```shell
$env:CHECK_ADDRESS="<address>"
npx hardhat run scripts/check-contract.js --network localhost
```
