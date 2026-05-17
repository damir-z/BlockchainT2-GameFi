# Gas Optimization Report

## Summary

This report documents expected gas-sensitive areas and the required before/after benchmark for the inline Yul optimization. The actual numeric values should be regenerated on the final commit with `forge snapshot` and pasted into this report before submission.

## Optimization target

The AMM quote calculation is used in swaps and frontend quoting. The project includes two equivalent functions:

- `AMMMath.quoteOutSolidity`
- `AMMMath.quoteOutYul`

The test suite checks that both return the same value for normal inputs and fuzzed inputs. The Yul function removes some high-level Solidity overhead in the arithmetic path.

## Benchmark command

```bash
forge snapshot --match-contract GameFiUnitTest --snap docs/.gas-snapshot
forge test --gas-report
```

## Before / after table

| Function      | Implementation            | Gas before | Gas after | Result                             |
| ------------- | ------------------------- | ---------: | --------: | ---------------------------------- |
| AMM quote     | Solidity arithmetic       |        TBD |       N/A | Baseline                           |
| AMM quote     | Inline Yul arithmetic     |        N/A |       TBD | Expected lower gas                 |
| AMM swap      | Uses quote path           |        TBD |       TBD | Compare after implementation       |
| Craft recipe  | Resource burn + item mint |        TBD |       TBD | No Yul used                        |
| Vault deposit | ERC-4626 deposit          |        TBD |       TBD | OZ baseline                        |
| Rental claim  | Pull-payment ETH claim    |        TBD |       TBD | CEI chosen over micro-optimization |

## L1 vs L2 gas comparison

A separate table is in `docs/L1_L2_GAS_COMPARISON.md`. It must include at least six operations measured on Ethereum Sepolia and the chosen L2 testnet.

Required rows:

1. Craft recipe #1
2. Open loot box request
3. Fulfill loot drop callback
4. AMM add liquidity
5. AMM swap
6. ERC-4626 vault deposit
7. Governor castVote

## Optimization decisions

### Keep SafeERC20 despite small overhead

SafeERC20 is required for correctness across ERC-20 implementations. The slight gas overhead is justified because unchecked ERC-20 return values are a known source of token integration bugs.

### Use uint112 reserves

AMM reserves are stored as `uint112`, similar to established constant-product AMM designs. This reduces storage footprint and is sufficient for expected resource token supplies.

### Avoid over-optimizing governance

Governor and Timelock are not hot paths. The project favors standard OpenZeppelin components over custom gas-optimized governance code.

### Use pull payments for rentals

Pull payments may require an extra transaction, but they reduce risk and simplify state transitions. Security is prioritized over minimizing the number of calls.

### Use UUPS only for parameters

Only the parameter module is upgradeable. This avoids proxy overhead on high-frequency AMM, crafting, and vault operations.

## Final action items

- [ ] Run `forge snapshot` on the final commit.
- [ ] Paste the gas snapshot into this document or link `docs/.gas-snapshot`.
- [ ] Fill before/after numbers for Yul and Solidity quote paths.
- [ ] Fill L1 vs L2 table with explorer transaction links.
