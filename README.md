# GameFi Economy Capstone

Full-stack decentralized protocol for **Option B - GameFi Economy**. It includes ERC-1155 items, crafting, a fungible resource AMM, NFT rental vault, Chainlink VRF-style loot drops, Chainlink price-feed staleness checks, ERC-4626 treasury vault, OpenZeppelin Governor + Timelock governance, The Graph subgraph, frontend dApp, Foundry tests, CI, and deployment scripts.

## Ownership split

| Area                                                                         | Owner    |
| ---------------------------------------------------------------------------- | -------- |
| Game mechanics: ERC-1155 items, crafting, loot drops, rentals                | Person 1 |
| Economy and governance: AMM, ERC-20 votes token, ERC-4626 vault, oracle, DAO | Person 2 |
| Integration: frontend, subgraph, CI, deployment, docs, final demo            | Person 3 |

Every team member should still understand the complete architecture and be ready for Q&A.

## Repository layout

```text
contracts/              Solidity production contracts
contracts/mocks/        Test mocks for Chainlink price feed and VRF coordinator
contracts/math/         AMM math plus Yul benchmark harness
script/                 Foundry deployment and post-deployment verification scripts
test/                   Unit, fuzz, invariant, fork, and vulnerability case-study tests
frontend/               React + Wagmi + Viem dApp
subgraph/               The Graph schema, mappings, ABI fragments, documented queries
docs/                   Architecture, audit, gas, coverage, criteria matrix, slides
.github/workflows/      CI pipeline
scripts/                Setup and local verification helpers
```

## Key contracts

| Contract                                        | Purpose                                                              |
| ----------------------------------------------- | -------------------------------------------------------------------- |
| `GameToken.sol`                                 | ERC20Votes + ERC20Permit governance token                            |
| `GameItems1155.sol`                             | ERC-1155 in-game items and loot boxes                                |
| `GameParametersV1.sol` / `GameParametersV2.sol` | UUPS-upgradeable DAO-governed recipe and loot table parameters       |
| `CraftingManager.sol`                           | Burns resource tokens and mints ERC-1155 crafted items               |
| `LootDrop.sol`                                  | Chainlink VRF-compatible loot box flow                               |
| `RentalVault.sol`                               | Pull-payment rental vault for ERC-1155 items                         |
| `AMMPool.sol`                                   | From-scratch x\*y=k AMM with 0.3% fee, slippage protection, LP token |
| `AMMPoolFactory.sol`                            | Factory using CREATE and CREATE2                                     |
| `GameVault4626.sol`                             | ERC-4626 treasury vault controlled by the Timelock                   |
| `PriceFeedAdapter.sol`                          | Chainlink price feed adapter with stale-price revert                 |
| `GameGovernor.sol`                              | Governor + Timelock lifecycle configuration                          |

## Mandatory criteria coverage

| Requirement                           | Implementation                                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------------------------------- |
| UUPS upgrade path                     | `GameParametersV1` to `GameParametersV2`, tested in `testUupsUpgradeToV2`                      |
| Factory with CREATE and CREATE2       | `AMMPoolFactory.createPool` and `createPoolDeterministic`                                      |
| Inline Yul and benchmark path         | `AMMMath.quoteOutYul` vs `quoteOutSolidity`                                                    |
| ERC-20 votes/permit governance token  | `GameToken`                                                                                    |
| ERC-1155                              | `GameItems1155`                                                                                |
| ERC-4626 vault                        | `GameVault4626`                                                                                |
| DeFi primitive                        | `AMMPool`, built from scratch                                                                  |
| Chainlink price feed with stale check | `PriceFeedAdapter`, `MockV3Aggregator` tests                                                   |
| Chainlink VRF loot drops              | `LootDrop`, `MockVRFCoordinatorV2` tests                                                       |
| OpenZeppelin Governor + Timelock      | `GameGovernor`, `TimelockController`, lifecycle test                                           |
| Subgraph                              | `subgraph/schema.graphql`, `subgraph/src/mapping.ts`, `subgraph/queries.md`                    |
| Frontend                              | `frontend/src/App.tsx` with wallet, reads, writes, proposal voting, subgraph data              |
| Security requirements                 | AccessControl, ReentrancyGuard, CEI, SafeERC20, pull payments, case-study tests                |
| Testing requirements                  | 88 test functions plus 6 invariant functions across unit/fuzz/invariant/fork/case-study tests  |
| CI                                    | `.github/workflows/ci.yml` runs build, tests, coverage, Slither, fmt, lint, frontend, subgraph |
| L2 deployment                         | `script/Deploy.s.sol` and `script/VerifyPostDeploy.s.sol`                                      |

## Setup

### 1. Install prerequisites

- Git
- Node.js 20+
- Foundry (`forge`, `cast`, `anvil`)
- Python 3 if running Slither locally

### 2. Clone and install dependencies

```bash
git clone <your-repo-url>
cd gamefi-economy-capstone
./scripts/setup.sh
```

Manual equivalent:

```bash
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6 --no-commit
npm install
cd frontend && npm install && cd ..
cd subgraph && npm install && cd ..
```

### 3. Configure environment

```bash
cp .env.example .env
```

Fill in:

```text
PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC_URL=...
BASESCAN_API_KEY=...
MAINNET_RPC_URL=...          # optional but needed for real fork interactions
CHAINLINK_PRICE_FEED=...     # optional; script deploys a mock if zero
VRF_COORDINATOR=...          # optional; script deploys a mock if zero
VRF_SUBSCRIPTION_ID=...
VRF_KEY_HASH=...
```

## Run locally

### Format, build, and test contracts

```bash
forge fmt --check
forge build
forge test -vvv
```

### Run fuzz and invariant tests with CI profile

```bash
FOUNDRY_PROFILE=ci forge test -vvv
```

### Coverage

```bash
forge coverage --report summary --report lcov
```

### Slither

```bash
python3 -m pip install slither-analyzer
slither . --filter-paths "test|script|lib" --exclude-dependencies --fail-medium
```

### One-command local check

```bash
./scripts/run-all.sh
```

## Deploy to an L2 testnet

Base Sepolia example:

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$BASESCAN_API_KEY" \
  -vvvv
```

Copy the printed contract addresses into `deployments/base-sepolia.json` and into `frontend/.env.local` created from `frontend/.env.example`.

Post-deployment verification:

```bash
export GOVERNOR=0x...
export TIMELOCK=0x...
export VAULT=0x...
export DEPLOYER=0x... # optional: checks the deployer has no admin backdoor
forge script script/VerifyPostDeploy.s.sol:VerifyPostDeploy \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" \
  -vvvv
```

## Frontend setup

Create `frontend/.env.local` from the checked-in template:

```bash
cp frontend/.env.example frontend/.env.local
```

Then replace the zero addresses with the deployed contract addresses.

Run:

```bash
cd frontend
npm run dev
```

Build:

```bash
cd frontend
npm run build
```

## Subgraph setup

1. Replace the zero addresses in `subgraph/subgraph.yaml` with deployed contract addresses.
2. Run:

```bash
cd subgraph
npm run codegen
npm run build
```

Deploy to The Graph Studio:

```bash
graph auth --studio <deploy-key>
npm run deploy:studio
```

Documented queries are in `subgraph/queries.md`.

## L1 vs L2 gas table

Run:

```bash
./scripts/l2-gas-report.sh
```

Then replace the `TBD` rows in `docs/L1_L2_GAS_COMPARISON.md` with transaction measurements from Ethereum Sepolia and your selected L2 testnet.

## Final submission checklist

- [ ] All contracts compile.
- [ ] `forge test -vvv` passes.
- [ ] `forge coverage` line coverage is at least 90%.
- [ ] Slither has zero High and zero Medium findings.
- [ ] L2 contracts are deployed and verified.
- [ ] `deployments/<network>.json` contains addresses and explorer links.
- [ ] Subgraph is live and queried by the frontend.
- [ ] Architecture, audit, gas, coverage, and presentation files are finalized.
- [ ] Every member can explain every component at architecture level.
#   B l o c k c h a i n T 2 - G a m e F i  
 