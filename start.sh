#!/bin/sh
set -e

# Monitoring feature toggle, disabled by default
# Actual monitor startup logic moved to server.js and runs after OpenCode is ready
export ENABLE_MONITOR="${ENABLE_MONITOR:-false}"
export SOURCE_MODE="${SOURCE_MODE:-true}"

exec node /app/server.js
