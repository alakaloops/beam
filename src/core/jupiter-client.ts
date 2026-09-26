import { DEFAULT_SLIPPAGE_BPS } from '../config.js';

export interface SwapQuoteParams {
  inputMint: string;
  outputMint: string;
  amount: string;
  slippageBps?: number;
}

export interface SwapRoutePlanStep {
  percent: number;
  inputMint: string;
  outputMint: string;
  protocol?: string;
  poolAddress?: string;
}

export interface JupiterSwapQuote {
  inputMint: string;
  outputMint: string;
  inAmount: string;
  outAmount: string;
  priceImpactPct?: number;
  slippageBps: number;
  router: string;
  routePlan?: SwapRoutePlanStep[];
  feeEstimate?: {
    networkFeeLamports: number;
    protocolFeeTokens?: number;
  };
  rawQuote: Record<string, unknown>;
}

export interface BuildSwapTxParams {
  userPublicKey: string;
  quote: JupiterSwapQuote;
  wrapAndUnwrapSol?: boolean;
  priorityFeeLamports?: number;
}

export interface BuildSwapTxResponse {
  swapTransaction: string;
  lastValidBlockHeight?: number;
  router: string;
}

const JUPITER_API_BASE = 'https://quote-api.jup.ag/v6';

export async function fetchSwapQuote(params: SwapQuoteParams): Promise<JupiterSwapQuote> {
  const slippageBps = params.slippageBps ?? DEFAULT_SLIPPAGE_BPS;

  const query = new URLSearchParams({
    inputMint: params.inputMint.trim(),
    outputMint: params.outputMint.trim(),
    amount: params.amount.trim(),
    slippageBps: String(slippageBps),
    onlyDirectRoutes: 'false',
    asLegacyTransaction: 'false',
  });

  const url = `${JUPITER_API_BASE}/quote?${query.toString()}`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/json',
    },
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Jupiter quote failed (${response.status}): ${errorBody || response.statusText}`);
  }

  const data = (await response.json()) as Record<string, any>;

  return {
    inputMint: params.inputMint,
    outputMint: params.outputMint,
    inAmount: String(data.inAmount || params.amount),
    outAmount: String(data.outAmount || '0'),
    priceImpactPct: data.priceImpactPct != null ? Number(data.priceImpactPct) : undefined,
    slippageBps,
    router: 'jupiter',
    routePlan: data.routePlan,
    feeEstimate: {
      networkFeeLamports: 5000,
    },
    rawQuote: data,
  };
}

export async function buildSwapTransaction(params: BuildSwapTxParams): Promise<BuildSwapTxResponse> {
  const url = `${JUPITER_API_BASE}/swap`;

  const payload = {
    userPublicKey: params.userPublicKey.trim(),
    quoteResponse: params.quote.rawQuote,
    wrapAndUnwrapSol: params.wrapAndUnwrapSol ?? true,
    prioritizationFeeLamports: params.priorityFeeLamports ?? 10000,
    asLegacyTransaction: false,
    useSharedAccounts: true,
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Jupiter swap build failed (${response.status}): ${errorBody || response.statusText}`);
  }

  const data = (await response.json()) as { swapTransaction?: string; swapTx?: string };
  const swapTx = data.swapTransaction || data.swapTx;

  if (!swapTx) {
    throw new Error('Jupiter API did not return a valid swapTransaction');
  }

  return {
    swapTransaction: swapTx,
    router: params.quote.router,
  };
}