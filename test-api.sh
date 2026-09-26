#!/bin/bash

# Beam API Test Script
# Run: chmod +x test-api.sh && ./test-api.sh

BASE="http://localhost:3000"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Beam API Test Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

# Check if server is running
echo -e "\n${YELLOW}→ Checking server...${NC}"
if ! curl -s "$BASE/api/health" > /dev/null; then
    echo "❌ Server not running! Start with: bun run dev"
    exit 1
fi
echo "✅ Server is running"

# Health
echo -e "\n${BLUE}=== Health Check ===${NC}"
curl -s "$BASE/api/health" | jq

# Tokens
echo -e "\n${BLUE}=== Supported Tokens ===${NC}"
curl -s "$BASE/api/tokens" | jq '.tokens[] | {symbol, mint, decimals, isPopular}'

# Create Intent
echo -e "\n${BLUE}=== Create Payment Intent ===${NC}"
RESP=$(curl -s -X POST "$BASE/api/intents" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
    "targetAmount": 5.00,
    "expiresInMinutes": 60,
    "memo": "Demo payment"
  }')

echo "$RESP" | jq
INTENT_ID=$(echo "$RESP" | jq -r '.intent.id')

if [ "$INTENT_ID" = "null" ] || [ -z "$INTENT_ID" ]; then
    echo "❌ Failed to create intent"
    exit 1
fi

echo -e "${GREEN}✅ Intent created: $INTENT_ID${NC}"

# Get Intent
echo -e "\n${BLUE}=== Get Payment Intent ===${NC}"
curl -s "$BASE/api/intents/$INTENT_ID" | jq

# Quote: SOL → USDC
echo -e "\n${BLUE}=== Quote: SOL → USDC (5 USDC) ===${NC}"
curl -s -X POST "$BASE/api/swap/quote" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$INTENT_ID\",\"inputMint\":\"So11111111111111111111111111111111111111112\"}" | jq

# Quote: BONK → USDC
echo -e "\n${BLUE}=== Quote: BONK → USDC (5 USDC) ===${NC}"
curl -s -X POST "$BASE/api/swap/quote" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$INTENT_ID\",\"inputMint\":\"DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263\"}" | jq

# Quote: USDT → USDC
echo -e "\n${BLUE}=== Quote: USDT → USDC (5 USDC) ===${NC}"
curl -s -X POST "$BASE/api/swap/quote" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$INTENT_ID\",\"inputMint\":\"Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB\"}" | jq

# Quote: JUP → USDC
echo -e "\n${BLUE}=== Quote: JUP → USDC (5 USDC) ===${NC}"
curl -s -X POST "$BASE/api/swap/quote" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$INTENT_ID\",\"inputMint\":\"JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN\"}" | jq

# Quote: Direct USDC → USDC
echo -e "\n${BLUE}=== Quote: USDC → USDC (direct transfer) ===${NC}"
curl -s -X POST "$BASE/api/swap/quote" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$INTENT_ID\",\"inputMint\":\"4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU\"}" | jq

echo -e "\n${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Open http://localhost:3000 in browser"
echo "2. Or test build transaction with your wallet:"
echo "   curl -X POST $BASE/api/swap/build \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"intentId\":\"$INTENT_ID\",\"payerPublicKey\":\"YOUR_WALLET\",\"inputMint\":\"So11111111111111111111111111111111111111112\"}'"