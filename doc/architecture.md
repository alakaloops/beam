# Beam Architecture

## Overview
Beam is a non-custodial Solana payment-link protocol. Merchants specify exact USDC amounts; payers pay with any SPL token. The protocol constructs a single atomic Versioned Transaction (v0) that swaps the input token via DEX aggregator and transfers exact USDC to recipient.

## System Architecture

```
┌─────────────┐     ┌─────────────────────┐     ┌────────────────┐
│   Payer     │────►│  Atomic Tx v0       │────►│   Recipient    │
│  (Any SPL)  │     │  1. DEX Swap        │     │  (Exact USDC)  │
└─────────────┘     │  2. USDC Transfer   │     └────────────────┘
                    └─────────────────────┘
```

## Key Components

### 1. Payment Intent (`src/intent/`)
- **Store**: File-based JSON persistence (`data/intents.json`)
- **Lifecycle**: `created` → `pending` → `paid` | `expired` | `underpaid` | `failed`
- **Expiry**: Configurable (default 60 min)

### 2. Swap Engine (`src/swap/`)
- **Quote** (`quote.ts`): Exact-out calculation with 1% buffer + 0.5% slippage
- **Composer** (`composer.ts`): Decompiles aggregator tx + appends settlement instructions → recompiles v0 with fresh blockhash + ALTs

### 3. DEX Aggregator (`src/core/jupiter-client.ts`)
- **Jupiter v6 API** (free, no API key)
- Endpoints: `/quote` + `/swap`
- Returns VersionedTransaction ready for signing

### 4. On-Chain Verification (`src/services/verifier.ts`)
- Fetches parsed transaction via RPC
- Compares pre/post token balances for recipient's USDC ATA
- Confirms `received >= targetAmountRaw` before marking `paid`

### 5. API Routes (`src/routes/`)
| Route | Purpose |
|-------|---------|
| `POST /api/intents` | Create payment intent |
| `GET /api/intents/:id` | Get intent status + countdown |
| `POST /api/swap/quote` | Calculate required input for target USDC |
| `POST /api/swap/build` | Build atomic v0 transaction |
| `POST /api/intents/:id/verify` | Verify on-chain settlement |
| `GET /api/tokens` | Supported token list |
| `GET /api/tokens/wallet/:addr/balances` | Wallet SPL balances |

### 6. Frontend (`web/`)
- Single-page app (Vanilla JS, no framework)
- Phantom/Solflare wallet adapter
- Real-time quote updates on token selection
- Countdown timer, status pills, receipt with Solscan link

## Data Flow

### Create Intent
```
POST /api/intents { recipient, targetAmount, memo?, expiry? }
→ Store intent with unique ID
→ Return payUrl: /pay/:id
```

### Checkout Flow
```
1. GET /api/intents/:id → intent details + timeLeft
2. User selects input token
3. POST /api/swap/quote { intentId, inputMint }
   → Probe 1 unit → calc rate → buffer → final quote
   → Fallback to reference prices if Jupiter unavailable
4. POST /api/swap/build { intentId, payerPublicKey, inputMint }
   → Get quote → Build Jupiter swap tx → Compose atomic v0
   → Return base64 VersionedTransaction
5. Frontend: signAndSendTransaction via wallet
6. POST /api/intents/:id/verify { signature, payerWallet }
   → Parse tx → Check balance delta → Update status
```

## Atomic Transaction Composition

```typescript
// 1. Decompile aggregator swap transaction
const decompiled = TransactionMessage.decompile(swapVTx.message, { altAccounts })

// 2. Append settlement instructions
const settlementIx = [
  createAssociatedTokenAccountIdempotentInstruction(payer, recipientAta, recipient, usdcMint),
  createTransferCheckedInstruction(payerAta, usdcMint, recipientAta, payer, targetAmountRaw, 6),
  memoInstruction
]

// 3. Recompile with fresh blockhash + same ALTs
const atomicMessage = new TransactionMessage({
  payerKey: payerPubkey,
  recentBlockhash: freshBlockhash,
  instructions: [...decompiled.instructions, ...settlementIx]
}).compileToV0Message(altAccounts)
```

## Security Guarantees

1. **Atomicity**: Swap + transfer in single tx → both succeed or both revert
2. **Exact-out**: 1% buffer ensures recipient gets ≥ target USDC
3. **Non-custodial**: Funds never leave payer's wallet until signed
4. **Verification**: On-chain balance delta confirms settlement
5. **Replay protection**: Fresh blockhash + lastValidBlockHeight