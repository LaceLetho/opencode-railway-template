#!/usr/bin/env bash
set -euo pipefail

# Ensure persistent directories exist
mkdir -p /data/workspace /data/sidecars /data/openwork

# ── Generate OPENCODE_CONFIG_CONTENT from env vars ──────────────────────────
# Build provider JSON only for keys that are set.
# Anthropic auto-discovers ANTHROPIC_API_KEY; no explicit block needed.

PROVIDERS="{}"

if [ -n "${MINIMAX_API_KEY:-}" ]; then
  MINIMAX_URL="${MINIMAX_BASE_URL:-https://api.minimax.chat/v1}"
  PROVIDERS=$(node -e "
    const p = JSON.parse(process.env.PROVIDERS || '{}');
    p.minimax = {
      npm: '@ai-sdk/openai-compatible',
      options: { name: 'minimax', apiKey: process.env.MINIMAX_API_KEY, baseURL: process.env.MINIMAX_URL }
    };
    process.stdout.write(JSON.stringify(p));
  " PROVIDERS="$PROVIDERS" MINIMAX_API_KEY="$MINIMAX_API_KEY" MINIMAX_URL="$MINIMAX_URL")
fi

if [ -n "${GLM_API_KEY:-}" ]; then
  GLM_URL="${GLM_BASE_URL:-https://open.bigmodel.cn/api/paas/v4}"
  PROVIDERS=$(node -e "
    const p = JSON.parse(process.env.PROVIDERS || '{}');
    p.zhipu = {
      npm: '@ai-sdk/openai-compatible',
      options: { name: 'zhipu', apiKey: process.env.GLM_API_KEY, baseURL: process.env.GLM_URL }
    };
    process.stdout.write(JSON.stringify(p));
  " PROVIDERS="$PROVIDERS" GLM_API_KEY="$GLM_API_KEY" GLM_URL="$GLM_URL")
fi

MODEL="${OPENCODE_MODEL:-}"

export OPENCODE_CONFIG_CONTENT=$(node -e "
  const cfg = { '\$schema': 'https://opencode.ai/config.json' };
  const model = process.env.MODEL;
  if (model) cfg.model = model;
  const providers = JSON.parse(process.env.PROVIDERS || '{}');
  if (Object.keys(providers).length > 0) cfg.provider = providers;
  process.stdout.write(JSON.stringify(cfg));
" MODEL="$MODEL" PROVIDERS="$PROVIDERS")

# ── Validate required env ────────────────────────────────────────────────────
if [ -z "${SETUP_PASSWORD:-}" ]; then
  echo "ERROR: SETUP_PASSWORD is required" >&2
  exit 1
fi

# ── Start proxy (background) ─────────────────────────────────────────────────
node src/server.js &
PROXY_PID=$!
echo "proxy started (pid $PROXY_PID)"

# ── Start openwork orchestrator (foreground) ─────────────────────────────────
exec openwork serve \
  --workspace /data/workspace \
  --approval auto \
  --no-tui \
  --openwork-port "${OPENWORK_PORT:-8787}"
