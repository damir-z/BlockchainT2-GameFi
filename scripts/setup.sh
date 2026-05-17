#!/usr/bin/env bash
set -euo pipefail

if ! command -v forge >/dev/null 2>&1; then
  echo "Foundry is not installed. Install it from https://book.getfoundry.sh/getting-started/installation"
  exit 1
fi

forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6 --no-commit
npm install
(cd frontend && npm install)
(cd subgraph && npm install)

echo "Setup complete. Copy .env.example to .env and fill RPC/API keys before deployment."
