import { useEffect, useMemo, useState } from 'react';
import { formatEther, parseEther } from 'viem';
import {
  useAccount,
  useChainId,
  useConnect,
  useDisconnect,
  useReadContract,
  useSwitchChain,
  useWriteContract,
} from 'wagmi';

import { ammAbi, craftingAbi, erc20Abi, governorAbi, vaultAbi, votesAbi } from './abis';
import { addresses, subgraphUrl, targetChain } from './config';

type Proposal = {
  id: string;
  description: string;
  state: string;
};

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const;
const stateNames = [
  'Pending',
  'Active',
  'Canceled',
  'Defeated',
  'Succeeded',
  'Queued',
  'Expired',
  'Executed',
];

function readableError(error: unknown): string {
  const msg = error instanceof Error ? error.message : String(error);
  if (/user rejected|rejected request|denied/i.test(msg)) return 'Transaction rejected in wallet.';
  if (/insufficient funds|exceeds balance/i.test(msg))
    return 'Insufficient balance for this transaction.';
  if (/wrong network|chain/i.test(msg)) return 'Wrong network. Please switch to Base Sepolia.';
  if (/ContractFunctionExecutionError/i.test(msg))
    return 'Contract call reverted. Check balance, approvals, and network.';
  return msg.split('\n')[0] || 'Unknown error.';
}

function formatValue(value: bigint | undefined): string {
  if (value === undefined) return '0';
  return Number(formatEther(value)).toLocaleString(undefined, { maximumFractionDigits: 4 });
}

export default function App() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { connectors, connect, error: connectError } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const { writeContractAsync, isPending } = useWriteContract();

  const [status, setStatus] = useState('Ready. Connect wallet and verify contract addresses.');
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [proposalId, setProposalId] = useState('');

  const wrongNetwork = isConnected && chainId !== targetChain.id;
  const account = address ?? ZERO_ADDRESS;

  const { data: goldBalance } = useReadContract({
    address: addresses.gold,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [account],
  });
  const { data: crystalBalance } = useReadContract({
    address: addresses.crystal,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [account],
  });
  const { data: votes } = useReadContract({
    address: addresses.gameToken,
    abi: votesAbi,
    functionName: 'getVotes',
    args: [account],
  });
  const { data: delegateAddress } = useReadContract({
    address: addresses.gameToken,
    abi: votesAbi,
    functionName: 'delegates',
    args: [account],
  });
  const { data: reserves } = useReadContract({
    address: addresses.ammPool,
    abi: ammAbi,
    functionName: 'getReserves',
  });
  const { data: vaultShares } = useReadContract({
    address: addresses.vault,
    abi: vaultAbi,
    functionName: 'balanceOf',
    args: [account],
  });

  const reserveText = useMemo(() => {
    if (!reserves) return '0 / 0';
    return `${formatValue(reserves[0])} / ${formatValue(reserves[1])}`;
  }, [reserves]);

  useEffect(() => {
    if (connectError) setStatus(readableError(connectError));
  }, [connectError]);

  useEffect(() => {
    if (!subgraphUrl) return;
    fetch(subgraphUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query: `{
          proposals(first: 10, orderBy: createdAt, orderDirection: desc) {
            id
            description
            state
          }
        }`,
      }),
    })
      .then((response) => response.json())
      .then((data) => setProposals(data.data?.proposals ?? []))
      .catch(() => setStatus('Subgraph is not reachable yet. Contract reads still work.'));
  }, []);

  async function requireReady() {
    if (!isConnected) throw new Error('Connect wallet first.');
    if (wrongNetwork) throw new Error('Wrong network. Please switch to Base Sepolia.');
    if (!address) throw new Error('Wallet address is unavailable.');
    return address;
  }

  async function runAction(label: string, action: () => Promise<unknown>) {
    try {
      setStatus(`${label}: waiting for wallet confirmation...`);
      await action();
      setStatus(`${label}: transaction submitted.`);
    } catch (error) {
      setStatus(readableError(error));
    }
  }

  const swapOneGold = () =>
    runAction('Swap 1 GOLD for CRYSTAL', async () => {
      const receiver = await requireReady();
      const amount = parseEther('1');
      await writeContractAsync({
        address: addresses.gold,
        abi: erc20Abi,
        functionName: 'approve',
        args: [addresses.ammPool, amount],
      });
      return writeContractAsync({
        address: addresses.ammPool,
        abi: ammAbi,
        functionName: 'swap',
        args: [addresses.gold, amount, 0n, receiver],
      });
    });

  const craftSword = () =>
    runAction('Craft sword', async () => {
      await requireReady();
      return writeContractAsync({
        address: addresses.crafting,
        abi: craftingAbi,
        functionName: 'craft',
        args: [1n],
      });
    });

  const depositVault = () =>
    runAction('Deposit 10 GOLD into vault', async () => {
      const receiver = await requireReady();
      const amount = parseEther('10');
      await writeContractAsync({
        address: addresses.gold,
        abi: erc20Abi,
        functionName: 'approve',
        args: [addresses.vault, amount],
      });
      return writeContractAsync({
        address: addresses.vault,
        abi: vaultAbi,
        functionName: 'deposit',
        args: [amount, receiver],
      });
    });

  const delegateToSelf = () =>
    runAction('Delegate votes to self', async () => {
      const delegatee = await requireReady();
      return writeContractAsync({
        address: addresses.gameToken,
        abi: votesAbi,
        functionName: 'delegate',
        args: [delegatee],
      });
    });

  const voteForProposal = (id: string) =>
    runAction('Vote for proposal', async () => {
      await requireReady();
      if (!id) throw new Error('Enter a proposal id first.');
      return writeContractAsync({
        address: addresses.governor,
        abi: governorAbi,
        functionName: 'castVote',
        args: [BigInt(id), 1],
      });
    });

  return (
    <main className="app-shell">
      <section className="hero">
        <div>
          <p className="eyebrow">Option B - GameFi Economy</p>
          <h1>ERC-1155 items, AMM resources, loot drops, rentals, and DAO control.</h1>
          <p className="subtle">
            Frontend reads wallet balances, voting power, delegate address, pool reserves, vault
            shares, and proposal data from The Graph.
          </p>
        </div>
        <div className="wallet-card">
          {isConnected ? (
            <>
              <span className="label">Connected</span>
              <strong>
                {address?.slice(0, 8)}...{address?.slice(-6)}
              </strong>
              <button onClick={() => disconnect()}>Disconnect</button>
            </>
          ) : (
            <>
              {connectors.map((connector) => (
                <button key={connector.uid} onClick={() => connect({ connector })}>
                  Connect {connector.name}
                </button>
              ))}
            </>
          )}
        </div>
      </section>

      {wrongNetwork && (
        <section className="warning">
          <strong>Wrong network.</strong> Switch to {targetChain.name} before sending transactions.
          <button onClick={() => switchChain({ chainId: targetChain.id })}>Switch network</button>
        </section>
      )}

      <section className="grid stats">
        <article>
          <span>GOLD</span>
          <strong>{formatValue(goldBalance)}</strong>
        </article>
        <article>
          <span>CRYSTAL</span>
          <strong>{formatValue(crystalBalance)}</strong>
        </article>
        <article>
          <span>Voting power</span>
          <strong>{formatValue(votes)}</strong>
        </article>
        <article>
          <span>Delegate</span>
          <strong className="address">{delegateAddress ?? ZERO_ADDRESS}</strong>
        </article>
        <article>
          <span>Pool reserves</span>
          <strong>{reserveText}</strong>
        </article>
        <article>
          <span>Vault shares</span>
          <strong>{formatValue(vaultShares)}</strong>
        </article>
      </section>

      <section className="panel">
        <h2>State-changing actions</h2>
        <div className="actions">
          <button disabled={isPending || !isConnected || wrongNetwork} onClick={swapOneGold}>
            Swap 1 GOLD
          </button>
          <button disabled={isPending || !isConnected || wrongNetwork} onClick={craftSword}>
            Craft sword
          </button>
          <button disabled={isPending || !isConnected || wrongNetwork} onClick={depositVault}>
            Deposit 10 GOLD
          </button>
          <button disabled={isPending || !isConnected || wrongNetwork} onClick={delegateToSelf}>
            Delegate votes
          </button>
        </div>
        <p className="status">{status}</p>
      </section>

      <section className="panel">
        <h2>Governance proposals</h2>
        <div className="proposal-input">
          <input
            value={proposalId}
            onChange={(event) => setProposalId(event.target.value)}
            placeholder="Proposal id for manual vote"
          />
          <button
            disabled={isPending || !isConnected || wrongNetwork}
            onClick={() => voteForProposal(proposalId)}
          >
            Vote For
          </button>
        </div>
        <div className="proposal-list">
          {proposals.length === 0 ? (
            <p className="subtle">
              No indexed proposals yet. Deploy the subgraph and set VITE_SUBGRAPH_URL.
            </p>
          ) : (
            proposals.map((proposal) => (
              <article key={proposal.id} className="proposal">
                <strong>{proposal.description || `Proposal ${proposal.id}`}</strong>
                <span>{stateNames[Number(proposal.state)] ?? proposal.state}</span>
                <button
                  disabled={isPending || !isConnected || wrongNetwork}
                  onClick={() => voteForProposal(proposal.id)}
                >
                  Vote For
                </button>
              </article>
            ))
          )}
        </div>
      </section>
    </main>
  );
}
