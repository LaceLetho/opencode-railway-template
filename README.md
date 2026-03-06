# OpenCode Railway Template

One-click Railway deploy for [OpenCode](https://opencode.ai) + [OpenWork](https://github.com/LaceLetho/openwork) — an always-on autonomous AI coding agent.

## Deploy to Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/f0oQvM?referralCode=Se0h8C&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What this deploys

- **OpenCode** — AI coding agent (headless API server)
- **OpenWork** — Web UI to send requirements and view results
- **Reverse proxy** — HTTP Basic Auth protecting the UI

## Required environment variables

| Variable | Description |
|----------|-------------|
| `SETUP_PASSWORD` | Password for browser HTTP Basic Auth (username: `openwork`) |
| `OPENWORK_TOKEN` | Access token for OpenWork client app |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key (optional if using other providers) |
| `MINIMAX_API_KEY` | Minimax API key (optional) |
| `GLM_API_KEY` | ZhipuAI GLM API key (optional) |

At least one AI provider key must be set.

## Optional variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_MODEL` | `anthropic/claude-sonnet-4-5` | Default model (`provider/model-id`) |
| `MINIMAX_BASE_URL` | `https://api.minimax.chat/v1` | Minimax API base URL |
| `GLM_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` | ZhipuAI API base URL |

## Volume

Mount a Railway volume at `/data` — this persists the workspace, OpenWork state, and sidecar cache.

## First boot

On first boot, `openwork-orchestrator` downloads its sidecars (~200MB). Subsequent restarts are fast as the cache lives on the volume.

## How to use

1. **Download OpenWork** — Get the desktop app from [openwork.software](https://openwork.software/) or the [releases page](https://github.com/LaceLetho/openwork/releases).

2. **Add a remote workspace** — In OpenWork:
   - Click "Add worker" → "Connect remote"
   - **URL**: Enter your Railway deployment URL (e.g., `https://your-project.up.railway.app`)
   - **Access Token**: Enter the `OPENWORK_TOKEN` you set during deployment

3. **Select your model** — After connecting, choose a model in the model dropdown:
   - If you set `ANTHROPIC_API_KEY` → select Claude models (e.g., `claude-sonnet-4-5`)
   - If you set `MINIMAX_API_KEY` → select Minimax models
   - If you set `GLM_API_KEY` → select GLM models

You're now ready to send requirements and let the autonomous agent work for you!

## Architecture

```
Internet → proxy ($PORT) → OpenWork server (:8787)
                               ↕
                          OpenCode (:4096)
```
