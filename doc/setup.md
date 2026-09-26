# Beam Setup Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Bun** | ≥1.2 | `curl -fsSL https://bun.sh/install \| bash` |
| **Git** | Any | [git-scm.com](https://git-scm.com) |
| **Solana Wallet** | Phantom / Solflare | See below |

---

## 1. Clone & Install

```bash
git clone https://github.com/alakaloops/beam/
cd Beam
bun install
```

---

## 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```env
# Server
PORT=3000
NODE_ENV=development

# Solana Network
SOLANA_NETWORK=devnet          # or mainnet-beta

# Solana RPC (REQUIRED for production)
SOLANA_RPC_URL=https://your-rpc-endpoint.com
```

### Getting a QuickNode RPC URL (Free)

1. Go to **[quicknode.com](https://quicknode.com)** → Sign up (free tier: 10M requests/month)
2. Click **"Create an endpoint"**
3. Select:
   - **Chain**: Solana
   - **Network**: Devnet (or Mainnet)
4. Click **Create endpoint**
5. Copy the **HTTPS URL** (looks like: `https://fabled-broken-research.solana-devnet.quiknode.pro/abc123.../`)
6. Paste into `.env`:
   ```env
   SOLANA_RPC_URL=https://your-endpoint.quiknode.pro/your-token/
   ```

> **Why not public RPC?** Public endpoints (`api.devnet.solana.com`) are rate-limited and cause timeouts on wallet balance queries and transaction building. QuickNode/Helius provide dedicated throughput.

### Alternative: Helius (Free Tier)

1. Go to **[helius.dev](https://helius.dev)** → Sign up
2. Create project → Select **Devnet**
3. Copy **API Key**
4. Add to `.env`:
   ```env
   HELIUS_API_KEY=your_helius_api_key
   SOLANA_NETWORK=devnet
   ```

---

## 3. Run Development Server

```bash
bun run dev
```

Output:
```
⚡ Beam Server running at http://localhost:3000
🔗 API Health: http://localhost:3000/api/health
📡 Solana RPC: https://your-rpc-endpoint.com
🌐 Web UI: http://localhost:3000
```

---

## 4. Install Solana Wallet

### Phantom (Recommended)

| Platform | Link |
|----------|------|
| Chrome/Edge/Brave | [Chrome Web Store](https://chrome.google.com/webstore/detail/phantom/bfnaelmomeimhlpmgjnjophhpkkoljpa) |
| Firefox | [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/phantom-app/) |
| iOS / Android | [App Store](https://apps.apple.com/app/phantom-solana-wallet/id1598432977) / [Play Store](https://play.google.com/store/apps/details?id=app.phantom) |

### Solflare

| Platform | Link |
|----------|------|
| Chrome/Edge/Brave | [Chrome Web Store](https://chrome.google.com/webstore/detail/solflare-wallet/bhhhlbepdkbapadjdnnojkbgioiodbic) |
| Web App | [solflare.com](https://solflare.com/access-wallet) |

### Setup Wallet for Devnet

1. Install extension → Create new wallet / Import seed phrase
2. **Switch to Devnet**: Click network dropdown (top right) → **Devnet**
3. **Get Devnet SOL**: 
   - [faucet.solana.com](https://faucet.solana.com) — 2 SOL/day
   - [quicknode.com/faucet](https://faucet.quicknode.com/solana/devnet) — 1 SOL/day
4. **Get Devnet USDC** (optional):
   - Go to [jup.ag](https://jup.ag) → Switch to **Devnet** (top right)
   - Swap SOL → USDC (devnet mint: `4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU`)

---

## 5. Test the Demo

### Browser UI
1. Open **http://localhost:3000**
2. **Preloaded demos**:
   - Coffee: `http://localhost:3000/pay/demo-coffee` ($5 USDC)
   - Invoice: `http://localhost:3000/pay/demo-invoice` ($25 USDC)
3. Or create your own: Click "Use Connected" → Enter amount → Create link

### API Test
```bash
# Run automated test suite
./test-api.sh

# Or individual endpoints
curl http://localhost:3000/api/health
curl http://localhost:3000/api/tokens
```

---

## 6. Production Deployment

### Railway / Render

1. Push to GitHub
2. Create new service → Link repo
3. Settings:
   - **Build**: `bun install`
   - **Start**: `bun src/index.ts`
4. Environment Variables:
   ```env
   PORT=3000
   NODE_ENV=production
   SOLANA_NETWORK=mainnet-beta
   SOLANA_RPC_URL=https://your-mainnet-rpc.quiknode.pro/token/
   ```

### Docker (Optional)

```dockerfile
FROM oven/bun:1.2
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --production
COPY . .
RUN bun run build
EXPOSE 3000
CMD ["bun", "src/index.ts"]
```

---

## 7. Common Issues

| Issue | Solution |
|-------|----------|
| `TimeoutError` on RPC | Use QuickNode/Helius instead of public RPC |
| `Live quote unavailable` | Jupiter API blocked — fallback works, but add dedicated RPC |
| Wallet won't connect | Ensure Devnet selected in Phantom; refresh page |
| `Insufficient balance` | Get devnet SOL from faucet |
| Port 3000 in use | Change `PORT` in `.env` or kill process: `lsof -ti:3000 \| xargs kill` |

---

## 8. Project Structure

```
Beam/
├── src/
│   ├── config.ts           # Environment config
│   ├── index.ts            # Express server + routes
│   ├── core/
│   │   ├── solana.ts       # RPC connection, ATA helpers
│   │   ├── tokens.ts       # Token registry + formatting
│   │   └── jupiter-client.ts  # Jupiter v6 API client
│   ├── intent/
│   │   ├── store.ts        # File-based intent persistence
│   │   ├── types.ts        # TypeScript interfaces
│   │   └── schema.ts       # Zod validation
│   ├── routes/
│   │   ├── intent.routes.ts
│   │   ├── swap.routes.ts
│   │   ├── token.routes.ts
│   │   └── verify.routes.ts
│   ├── swap/
│   │   ├── quote.ts        # Exact-out calculation
│   │   └── composer.ts     # Atomic v0 composition
│   └── services/
│       └── verifier.ts     # On-chain settlement verification
├── web/
│   ├── index.html          # SPA entry
│   ├── app.js              # Frontend logic
│   └── style.css           # Styling
├── test/
│   ├── intent.test.ts
│   └── tokens.test.ts
├── data/                   # Runtime data (gitignored)
│   └── intents.json
├── .env.example
├── .env                    # Your config (gitignored)
├── package.json
├── tsconfig.json
└── README.md
```

---

## 9. Useful Commands

```bash
# Development
bun run dev          # Watch mode
bun run start        # Production mode
bun run build        # TypeScript compile
bun run typecheck    # Type check only
bun test             # Run tests

# Debug
curl http://localhost:3000/api/health
curl http://localhost:3000/api/tokens
```
