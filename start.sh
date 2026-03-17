#!/bin/sh
set -e

# 监控功能开关，默认开启
: "${ENABLE_MONITOR:=true}"

# 如果监控功能开启，拉取并运行监控脚本
if [ "$ENABLE_MONITOR" = "true" ]; then
  echo "[Monitor] 监控功能已开启，正在拉取监控脚本..."
  
  # 克隆/更新监控仓库
  MONITOR_DIR="/tmp/opencode-railway-monitor"
  if [ -d "$MONITOR_DIR/.git" ]; then
    cd "$MONITOR_DIR" && git pull --quiet || echo "[Monitor] 更新仓库失败，使用现有版本"
  else
    rm -rf "$MONITOR_DIR"
    git clone --quiet https://github.com/LaceLetho/opencode-railway-monitor.git "$MONITOR_DIR" || echo "[Monitor] 克隆仓库失败"
  fi
  
  # 启动监控脚本（后台运行）
  if [ -f "$MONITOR_DIR/opencode_monitor_v3_1.sh" ]; then
    echo "[Monitor] 启动监控脚本..."
    chmod +x "$MONITOR_DIR/opencode_monitor_v3_1.sh"
    nohup "$MONITOR_DIR/opencode_monitor_v3_1.sh" > /tmp/opencode_monitor.log 2>&1 &
    echo $! > /tmp/opencode_monitor.pid
    echo "[Monitor] 监控脚本已在后台启动 (PID: $(cat /tmp/opencode_monitor.pid 2>/dev/null || echo 'unknown'))"
  else
    echo "[Monitor] 警告: 监控脚本未找到"
  fi
  
  cd /app
fi

exec node /app/server.js
