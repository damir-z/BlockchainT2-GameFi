# Team Ownership

## Person 1 - Game Mechanics Lead

Owns:

- `GameItems1155.sol`
- `CraftingManager.sol`
- `LootDrop.sol`
- `RentalVault.sol`
- Loot/crafting/rental unit tests
- Game mechanics sections of architecture and audit documents

## Person 2 - Economy, DeFi, Oracle, Governance Lead

Owns:

- `GameToken.sol`
- `ResourceToken.sol`
- `AMMPool.sol`
- `AMMPoolFactory.sol`
- `GameVault4626.sol`
- `PriceFeedAdapter.sol`
- `GameGovernor.sol`
- UUPS upgrade path and Yul benchmark
- AMM, vault, governance, oracle, fuzz, and invariant tests

## Person 3 - Integration, DevOps, Frontend, Subgraph, Docs Lead

Owns:

- `frontend/`
- `subgraph/`
- `.github/workflows/ci.yml`
- `script/Deploy.s.sol`
- `script/VerifyPostDeploy.s.sol`
- README, architecture report, audit report, gas report, slide deck
- Final demo coordination

## Shared responsibilities

- All members review pull requests.
- All members run tests locally before merge.
- All members participate in threat modeling and audit findings.
- All members rehearse the final Q&A. The defense rule is that every person must be able to explain the full architecture.

## Commit convention

Use Conventional Commits:

- `feat(amm): add constant product swap with slippage checks`
- `test(vault): add ERC4626 rounding fuzz cases`
- `fix(rental): update withdrawal state before external transfer`
- `docs(audit): document oracle and governance attack analysis`
- `ci(slither): fail pipeline on high or medium findings`
