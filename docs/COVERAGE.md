# Coverage Report

Run coverage on the final commit:

```bash
forge coverage --report summary --report lcov
```

Paste the summary here before submission. The required line coverage is at least 90% across `contracts/`.

```text
<final forge coverage output here>
```

Current test inventory in this generated repository:

- Unit/fork/fuzz/case-study test functions: 88
- Invariant functions: 6
- Fuzz tests include AMM swap, vault deposit/withdraw/redeem, and governance voting power.
- Invariants include AMM k, reserves vs balances, LP supply conservation, treasury accounting, vault rounding, and resource supply coverage.
- Fork tests interact with USDC, Chainlink ETH/USD, and Uniswap V2 router when `MAINNET_RPC_URL` is configured.
