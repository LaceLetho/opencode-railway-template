#!/bin/sh
set -e

# Monitoring feature toggle, enabled by default
# Actual monitor startup logic moved to server.js and runs after OpenCode is ready
export ENABLE_MONITOR="${ENABLE_MONITOR:-true}"
export SOURCE_MODE="${SOURCE_MODE:-true}"

exec node /app/server.js
