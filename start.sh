#!/bin/sh
set -e

# Railway 注入的端口
PORT="${PORT:-8080}"

# 验证必需的环境变量
if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  echo "ERROR: OPENCODE_SERVER_PASSWORD is required" >&2
  exit 1
fi

# 创建持久化目录
mkdir -p /data/workspace /data/.local/share/opencode /data/.local/state/opencode /data/.config/opencode

# 设置 HOME 为持久化目录，这样 OpenCode 的数据会存储在 /data 下
# - 数据库: /data/.local/share/opencode/opencode.db
# - 配置: /data/.config/opencode/
# - 状态: /data/.local/state/opencode/
export HOME="/data"

# 设置配置目录（可选，覆盖默认的 XDG 路径）
export OPENCODE_CONFIG_DIR="/data/.config/opencode"
export OPENCODE_CONFIG="/data/.config/opencode/config.json"

# 进入工作目录并启动 OpenCode Web 服务
cd /data/workspace

echo "Starting OpenCode Web on port $PORT..."
echo "Workspace: $(pwd)"

# 启动 opencode web
# --port: 使用 Railway 提供的端口
# --hostname 0.0.0.0: 让网络可访问
exec bunx opencode web --port "$PORT" --hostname 0.0.0.0
