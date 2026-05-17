import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { injected, walletConnect } from 'wagmi/connectors';
import { baseSepolia } from 'wagmi/chains';

import App from './App';
import './index.css';
import './style.css';

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';
const rpcUrl = import.meta.env.VITE_RPC_URL || 'http://127.0.0.1:8545';

const connectors = [
  injected({ target: 'metaMask' }),
  ...(projectId ? [walletConnect({ projectId, showQrModal: true })] : []),
];

const config = createConfig({
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http(rpcUrl),
  },
  connectors,
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
);
