#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs
forge snapshot --snap docs/.gas-snapshot
cat > docs/L1_L2_GAS_COMPARISON.md <<'MARKDOWN'
# L1 vs L2 Gas Comparison

Replace the estimate columns after running the same operations on Ethereum Sepolia and the selected L2 testnet.

| Operation | L1 gas used | L2 gas used | Notes |
|---|---:|---:|---|
| Craft recipe #1 | TBD | TBD | Burns GOLD/CRYSTAL and mints ERC-1155 item |
| Open loot box | TBD | TBD | VRF request transaction only |
| Fulfill loot drop | TBD | TBD | Coordinator callback |
| AMM add liquidity | TBD | TBD | Mints LP tokens |
| AMM swap | TBD | TBD | 0.3% fee constant-product swap |
| Vault deposit | TBD | TBD | ERC-4626 deposit |
| Proposal vote | TBD | TBD | Governor castVote |

Attach transaction hashes and explorer links for all measured rows before final submission.
MARKDOWN

echo "Gas snapshot written. Fill docs/L1_L2_GAS_COMPARISON.md with deployed transaction measurements."
