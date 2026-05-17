# L1 vs L2 Gas Comparison

Fill this table after deploying to Ethereum Sepolia and the chosen L2 testnet. The project is designed for Base Sepolia, Arbitrum Sepolia, or Optimism Sepolia.

| Operation         | Ethereum Sepolia tx | Ethereum Sepolia gas | L2 tx | L2 gas | Notes                                      |
| ----------------- | ------------------- | -------------------: | ----- | -----: | ------------------------------------------ |
| Craft recipe #1   | TBD                 |                  TBD | TBD   |    TBD | Burns GOLD/CRYSTAL and mints ERC-1155 item |
| Open loot box     | TBD                 |                  TBD | TBD   |    TBD | VRF request transaction                    |
| Fulfill loot drop | TBD                 |                  TBD | TBD   |    TBD | Coordinator callback                       |
| AMM add liquidity | TBD                 |                  TBD | TBD   |    TBD | Mints LP tokens                            |
| AMM swap          | TBD                 |                  TBD | TBD   |    TBD | 0.3% fee swap                              |
| Vault deposit     | TBD                 |                  TBD | TBD   |    TBD | ERC-4626 deposit                           |
| Governor vote     | TBD                 |                  TBD | TBD   |    TBD | `castVote`                                 |

## How to collect numbers

1. Deploy to Ethereum Sepolia and the selected L2 testnet with the same script.
2. Execute the same operation on both networks.
3. Copy gas used from each explorer transaction page.
4. Add explorer links and gas values to the table.
