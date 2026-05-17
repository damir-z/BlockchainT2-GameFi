#!/usr/bin/env bash
set -euo pipefail

forge fmt --check
npm run lint:sol
forge build
forge test -vvv
forge coverage --report summary --report lcov
slither . --filter-paths "test|script|lib" --exclude-dependencies --fail-medium
(cd frontend && npm run lint && npm run build)
(cd subgraph && npm run codegen && npm run build)
