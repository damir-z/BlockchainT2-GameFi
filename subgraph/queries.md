# Documented GraphQL Queries

## 1. Recent crafts by player

```graphql
{
  crafts(where: { player: "0xplayer" }, orderBy: blockNumber, orderDirection: desc) {
    id
    recipeId
    outputItemId
    amount
    transactionHash
  }
}
```

## 2. Active rentals

```graphql
{
  rentals(where: { state: "Rented" }) {
    id
    lender {
      id
    }
    renter {
      id
    }
    tokenId
    priceWei
    expiresAt
  }
}
```

## 3. AMM swap history

```graphql
{
  swaps(first: 20, orderBy: blockNumber, orderDirection: desc) {
    id
    trader
    tokenIn
    amountIn
    amountOut
    transactionHash
  }
}
```

## 4. Pool activity summary

```graphql
{
  pools {
    id
    swapCount
    liquidityEvents(first: 5, orderBy: blockNumber, orderDirection: desc) {
      amount0
      amount1
      liquidity
    }
  }
}
```

## 5. Governance proposals and votes

```graphql
{
  proposals(first: 10, orderBy: createdAt, orderDirection: desc) {
    id
    proposer
    state
    description
    votes {
      voter
      support
      weight
    }
  }
}
```
