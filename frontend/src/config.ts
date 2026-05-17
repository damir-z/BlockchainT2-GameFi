import { baseSepolia } from 'viem/chains';

export const targetChain = baseSepolia;

export const addresses = {
  gameToken: (import.meta.env.VITE_GAME_TOKEN ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  gold: (import.meta.env.VITE_GOLD ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  crystal: (import.meta.env.VITE_CRYSTAL ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  items: (import.meta.env.VITE_ITEMS ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  crafting: (import.meta.env.VITE_CRAFTING ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  lootDrop: (import.meta.env.VITE_LOOT_DROP ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  rentalVault: (import.meta.env.VITE_RENTAL_VAULT ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  ammPool: (import.meta.env.VITE_AMM_POOL ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  vault: (import.meta.env.VITE_VAULT ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
  governor: (import.meta.env.VITE_GOVERNOR ??
    '0x0000000000000000000000000000000000000000') as `0x${string}`,
};

export const subgraphUrl = import.meta.env.VITE_SUBGRAPH_URL ?? '';
