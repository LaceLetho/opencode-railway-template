#!/bin/bash
# Change to workspace directory and exec OpenCode
cd /data/workspace
exec bunx opencode-ai web --port "${OPENCODE_PORT:-4096}" --hostname 0.0.0.0
