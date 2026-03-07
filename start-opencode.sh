#!/bin/bash
# Start OpenCode with explicit working directory
cd /data/workspace
# Use bun directly instead of bunx for better control
# Also export HOME to ensure proper behavior
export HOME=/root
exec /root/.bun/bin/bunx opencode-ai web --port "${OPENCODE_PORT:-4096}" --hostname 0.0.0.0
