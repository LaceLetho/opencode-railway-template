# OpenCode Railway Template

One-click Railway deploy for [OpenCode](https://opencode.ai) — an always-on autonomous AI coding agent with web interface.

## Deploy to Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/f0oQvM?referralCode=Se0h8C&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What this deploys

- **OpenCode** — AI coding agent with web UI
- **Reverse proxy** — HTTP Basic Auth protecting the UI

## Required environment variables

| Variable | Description |
|----------|-------------|
| `OPENCODE_SERVER_PASSWORD` | Password for HTTP Basic Auth (username: `openwork` by default) |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key (optional if using other providers) |
| `MINIMAX_API_KEY` | Minimax API key (optional) |
| `GLM_API_KEY` | ZhipuAI GLM API key (optional) |

At least one AI provider key must be set.

## Optional variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_MODEL` | `anthropic/claude-sonnet-4-5` | Default model (`provider/model-id`) |
| `OPENCODE_SERVER_USERNAME` | `openwork` | Username for HTTP Basic Auth |
| `MINIMAX_BASE_URL` | `https://api.minimax.chat/v1` | Minimax API base URL |
| `GLM_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` | ZhipuAI API base URL |

## Volume

Mount a Railway volume at `/data` — this persists the workspace and state.

## How to use

1. Deploy to Railway using the button above
2. Set your environment variables in the Railway dashboard
3. Open your Railway deployment URL in a browser
4. Enter the username and password you configured

You're now ready to use OpenCode via the web interface!

## Architecture

```
Internet → proxy ($PORT) → OpenCode (:4096)
                         ↕
                    app.opencode.ai (UI)
```
