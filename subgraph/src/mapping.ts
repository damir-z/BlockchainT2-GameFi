import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { ItemCrafted } from "../generated/CraftingManager/CraftingManager";
import { LiquidityAdded, Swap as SwapEvent } from "../generated/AMMPool/AMMPool";
import { Listed, RentalFinished, Rented } from "../generated/RentalVault/RentalVault";
import {
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast,
} from "../generated/GameGovernor/GameGovernor";
import {
  Craft,
  ItemBalance,
  LiquidityEvent,
  Player,
  Pool,
  Proposal,
  Rental,
  Swap,
  Vote,
} from "../generated/schema";

function ensurePlayer(id: Bytes): Player {
  let player = Player.load(id);
  if (player == null) {
    player = new Player(id);
    player.save();
  }
  return player;
}

function ensurePool(id: Bytes): Pool {
  let pool = Pool.load(id);
  if (pool == null) {
    pool = new Pool(id);
    pool.swapCount = BigInt.zero();
    pool.save();
  }
  return pool;
}

export function handleItemCrafted(event: ItemCrafted): void {
  let player = ensurePlayer(event.params.player);
  let craftId = event.transaction.hash.concatI32(event.logIndex.toI32());
  let craft = new Craft(craftId);
  craft.player = player.id;
  craft.recipeId = event.params.recipeId;
  craft.outputItemId = event.params.outputItemId;
  craft.amount = event.params.amount;
  craft.blockNumber = event.block.number;
  craft.transactionHash = event.transaction.hash;
  craft.save();

  let balanceId = event.params.player.toHexString() + "-" + event.params.outputItemId.toString();
  let balance = ItemBalance.load(balanceId);
  if (balance == null) {
    balance = new ItemBalance(balanceId);
    balance.player = player.id;
    balance.itemId = event.params.outputItemId;
    balance.amount = BigInt.zero();
  }
  balance.amount = balance.amount.plus(event.params.amount);
  balance.save();
}

export function handleSwap(event: SwapEvent): void {
  let pool = ensurePool(event.address);
  pool.swapCount = pool.swapCount.plus(BigInt.fromI32(1));
  pool.save();

  let swap = new Swap(event.transaction.hash.concatI32(event.logIndex.toI32()));
  swap.pool = pool.id;
  swap.trader = event.params.trader;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.to = event.params.to;
  swap.blockNumber = event.block.number;
  swap.transactionHash = event.transaction.hash;
  swap.save();
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let pool = ensurePool(event.address);
  let liquidityEvent = new LiquidityEvent(event.transaction.hash.concatI32(event.logIndex.toI32()));
  liquidityEvent.pool = pool.id;
  liquidityEvent.provider = event.params.provider;
  liquidityEvent.amount0 = event.params.amount0;
  liquidityEvent.amount1 = event.params.amount1;
  liquidityEvent.liquidity = event.params.liquidity;
  liquidityEvent.blockNumber = event.block.number;
  liquidityEvent.save();
}

export function handleListed(event: Listed): void {
  let lender = ensurePlayer(event.params.lender);
  let rental = new Rental(event.params.listingId.toString());
  rental.lender = lender.id;
  rental.renter = null;
  rental.tokenId = event.params.tokenId;
  rental.amount = event.params.amount;
  rental.priceWei = event.params.priceWei;
  rental.state = "Listed";
  rental.expiresAt = null;
  rental.blockNumber = event.block.number;
  rental.save();
}

export function handleRented(event: Rented): void {
  let renter = ensurePlayer(event.params.renter);
  let rental = Rental.load(event.params.listingId.toString());
  if (rental == null) return;
  rental.renter = renter.id;
  rental.state = "Rented";
  rental.expiresAt = BigInt.fromI64(event.params.expiresAt.toI64());
  rental.save();
}

export function handleRentalFinished(event: RentalFinished): void {
  let rental = Rental.load(event.params.listingId.toString());
  if (rental == null) return;
  rental.state = "Listed";
  rental.renter = null;
  rental.expiresAt = null;
  rental.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.state = "Pending";
  proposal.startBlock = event.params.startBlock;
  proposal.endBlock = event.params.endBlock;
  proposal.createdAt = event.block.timestamp;
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let vote = new Vote(event.transaction.hash.concatI32(event.logIndex.toI32()));
  vote.proposal = event.params.proposalId.toString();
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;
  proposal.state = "Queued";
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;
  proposal.state = "Executed";
  proposal.save();
}
