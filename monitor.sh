#!/bin/bash
# OpenCode Railway Smart Monitor - v4.1 (Global SSE)
# Improvements: use /global/event SSE endpoint to detect global activity and fix PID matching

set -uo pipefail

# ==================== Configuration ====================
IDLE_TIME_MINUTES=${IDLE_TIME_MINUTES:-10}
CHECK_INTERVAL_SECONDS=${CHECK_INTERVAL_SECONDS:-60}
MEMORY_THRESHOLD_MB=${MEMORY_THRESHOLD_MB:-2000}
CPU_THRESHOLD_PERCENT=${CPU_THRESHOLD_PERCENT:-5.0}
GENERATION_GRACE_SECONDS=${GENERATION_GRACE_SECONDS:-60}
LOG_FILE="${LOG_FILE:-/tmp/opencode_monitor_script.log}"
STATE_DIR="/tmp/opencode_monitor_state_v4"
mkdir -p "$STATE_DIR"

LAST_ACTIVITY_FILE="$STATE_DIR/last_activity"
LAST_GENERATION_FILE="$STATE_DIR/last_generation_time"
EVENT_MONITOR_PID_FILE="$STATE_DIR/event_monitor.pid"

RAILWAY_API_TOKEN="${RAILWAY_API_TOKEN:-}"
# These are automatically injected by Railway - no need to set manually
RAILWAY_PROJECT_ID="${RAILWAY_PROJECT_ID:-}"
RAILWAY_ENVIRONMENT_ID="${RAILWAY_ENVIRONMENT_ID:-}"
RAILWAY_SERVICE_ID="${RAILWAY_SERVICE_ID:-}"

API_URL="http://127.0.0.1:18080"

log() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | tee -a "$LOG_FILE"
}

echo "========================================"
echo "🚂 OpenCode Railway Monitor v4.1"
echo "========================================"

get_current_deployment_id() {
    local graphql_query='{"query": "query deployments($input: DeploymentListInput!) { deployments(input: $input, first: 1) { edges { node { id status } } } }", "variables": { "input": { "projectId": "'"$RAILWAY_PROJECT_ID"'", "serviceId": "'"$RAILWAY_SERVICE_ID"'", "environmentId": "'"$RAILWAY_ENVIRONMENT_ID"'" } } }'
    
    local response
    response=$(curl -s -X POST https://backboard.railway.com/graphql/v2 \
        -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$graphql_query" 2>&1)
    
    # Extract deployment ID from response
    local deployment_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"$//')
    
    if [ -n "$deployment_id" ]; then
        echo "$deployment_id"
        return 0
    else
        return 1
    fi
}

trigger_deployment_restart() {
    log "  🚀 Calling Railway API to restart current deployment..."
    
    if [ -z "$RAILWAY_API_TOKEN" ] || [ -z "$RAILWAY_PROJECT_ID" ] || [ -z "$RAILWAY_ENVIRONMENT_ID" ] || [ -z "$RAILWAY_SERVICE_ID" ]; then
        log "  ⚠️ Required environment variables are not set, skipping API restart"
        log "     Please set: RAILWAY_API_TOKEN, RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID, RAILWAY_SERVICE_ID"
        return 1
    fi
    
    # Get current deployment ID
    local deployment_id
    deployment_id=$(get_current_deployment_id)
    
    if [ -z "$deployment_id" ]; then
        log "  ⚠️ Failed to get current deployment ID, trying redeploy..."
        trigger_railway_redeploy
        return $?
    fi
    
    log "  📦 Current deployment ID: $deployment_id"
    
    local graphql_query='{"query": "mutation deploymentRestart($id: String!) { deploymentRestart(id: $id) }", "variables": { "id": "'"$deployment_id"'" } }'
    
    local response
    response=$(curl -s -X POST https://backboard.railway.com/graphql/v2 \
        -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$graphql_query" 2>&1)
    
    local http_code=$?
    
    if [ $http_code -eq 0 ] && echo "$response" | grep -q "deploymentRestart"; then
        log "  ✅ Railway deployment restart triggered"
        return 0
    else
        log "  ⚠️ Railway API call failed: $response"
        log "  🔄 Trying redeploy..."
        trigger_railway_redeploy
        return $?
    fi
}

trigger_railway_redeploy() {
    log "  🚀 Calling Railway API to trigger redeploy..."
    
    if [ -z "$RAILWAY_API_TOKEN" ] || [ -z "$RAILWAY_PROJECT_ID" ] || [ -z "$RAILWAY_ENVIRONMENT_ID" ] || [ -z "$RAILWAY_SERVICE_ID" ]; then
        log "  ⚠️ Required environment variables are not set, skipping API deploy"
        log "     Please set: RAILWAY_API_TOKEN, RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID, RAILWAY_SERVICE_ID"
        return 1
    fi
    
    local graphql_query='{"query": "mutation environmentTriggersDeploy($input: EnvironmentTriggersDeployInput!) { environmentTriggersDeploy(input: $input) }", "variables": { "input": { "projectId": "'"$RAILWAY_PROJECT_ID"'", "environmentId": "'"$RAILWAY_ENVIRONMENT_ID"'", "serviceId": "'"$RAILWAY_SERVICE_ID"'" } } }'
    
    local response
    response=$(curl -s -X POST https://backboard.railway.com/graphql/v2 \
        -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$graphql_query" 2>&1)
    
    local http_code=$?
    
    if [ $http_code -eq 0 ] && echo "$response" | grep -q "environmentTriggersDeploy"; then
        log "  ✅ Railway redeploy triggered"
        return 0
    else
        log "  ⚠️ Railway API call failed: $response"
        return 1
    fi
}

# ==================== Get OpenCode Process ID ====================
get_opencode_pid() {
    pgrep -f "/\.opencode web" | head -1
}

# ==================== Method 1: SSE Event Stream Monitoring ====================
start_event_monitor() {
    # Run event monitoring in background (silent mode)
    (
        while true; do
            curl -N -s "${API_URL}/global/event" 2>/dev/null | while read -r line; do
                if echo "$line" | grep -qE "data:"; then
                    if ! echo "$line" | grep -qE '"type":"server\.(heartbeat|connected)"'; then
                        date +%s > "$LAST_ACTIVITY_FILE"
                    fi
                fi
            done
            sleep 5
        done
    ) &
    
    local pid=$!
    echo $pid > "$EVENT_MONITOR_PID_FILE"
}

stop_event_monitor() {
    if [ -f "$EVENT_MONITOR_PID_FILE" ]; then
        local pid=$(cat "$EVENT_MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            log "  [SSE] Event monitoring stopped"
        fi
        rm -f "$EVENT_MONITOR_PID_FILE"
    fi
}

# ==================== Activity Detection ====================
is_generating_content() {
    local pid
    pid=$(get_opencode_pid)
    [ -z "$pid" ] && echo "NO_PID" && return 1
    
    local is_generating=0
    local reasons=""
    
    # Check 1: SSE activity (check last activity timestamp)
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local current=$(date +%s)
        local time_since_activity=$((current - last_activity))
        
        if [ "$time_since_activity" -lt 15 ]; then
            is_generating=1
            reasons="${reasons}SSE activity(${time_since_activity}s) "
            date +%s > "$LAST_GENERATION_FILE"
        fi
    fi
    
    # Check 2: Cooldown window
    if [ -f "$LAST_GENERATION_FILE" ]; then
        local last_gen
        last_gen=$(cat "$LAST_GENERATION_FILE")
        local current
        current=$(date +%s)
        local time_since_gen=$((current - last_gen))
        if [ "$time_since_gen" -lt "$GENERATION_GRACE_SECONDS" ]; then
            is_generating=1
            reasons="${reasons}cooldown(${time_since_gen}s) "
        fi
    fi
    
    if [ $is_generating -eq 1 ]; then
        echo "GENERATING|$reasons"
        return 0
    else
        echo "IDLE"
        return 1
    fi
}

# ==================== Get Memory Usage ====================
get_memory_mb() {
    # Sum RSS of all user processes
    local total_kb=$(ps aux | awk 'NR>1 {sum+=$6} END {print sum}' 2>/dev/null || echo 0)
    echo $((total_kb / 1024))
}

# ==================== Restart ====================
restart_opencode() {
    local reason="$1"
    local mem_before
    mem_before=$(get_memory_mb)
    
    log "========================================"
    log "🔄 Triggering OpenCode redeploy"
    log "  Reason: $reason"
    log "  Current memory: ${mem_before}MB"
    
    stop_event_monitor
    
    rm -f "$LAST_GENERATION_FILE" "$LAST_ACTIVITY_FILE"
    
    # Call Railway API directly to trigger deployment restart
    trigger_deployment_restart
    
    log "  ✅ Deployment restart request sent"
    log "========================================"
    
    # Continue monitoring while Railway redeploys the container
    sleep 60
}

# ==================== Main Loop ====================
main() {
    local start_time
    start_time=$(date +%s)
    local consecutive_checks=0
    local check_count=0
    
    # Initialize activity timestamp
    date +%s > "$LAST_ACTIVITY_FILE"
    
    # Start SSE event monitoring
    start_event_monitor
    
    log "🚀 Monitor started"
    
    while true; do
        check_count=$((check_count + 1))
        
        pid=$(get_opencode_pid)
        if [ -z "$pid" ]; then
            sleep "$CHECK_INTERVAL_SECONDS"
            continue
        fi
        
        local current_mem
        current_mem=$(get_memory_mb)
        local uptime
        uptime=$(($(date +%s) - start_time))
        local uptime_hours=$((uptime / 3600))
        
        # Check generation state
        local gen_status
        gen_status=$(is_generating_content)
        local gen_state
        gen_state=$(echo "$gen_status" | cut -d'|' -f1)
        
        # If generating, reset counters
        if [ "$gen_state" = "GENERATING" ]; then
            consecutive_checks=0
            sleep "$CHECK_INTERVAL_SECONDS"
            continue
        fi
        
        # Check whether idle
        if [ -f "$LAST_ACTIVITY_FILE" ]; then
            local last_activity=$(cat "$LAST_ACTIVITY_FILE")
            local current=$(date +%s)
            local idle_time=$(( (current - last_activity) / 60 ))
            
            if [ $idle_time -ge "$IDLE_TIME_MINUTES" ] && [ "$current_mem" -gt "$MEMORY_THRESHOLD_MB" ]; then
                log "💤 Idle for ${idle_time} minutes with memory at ${current_mem}MB, restarting"
                restart_opencode "idle with high memory"
            fi
        fi
        
        sleep "$CHECK_INTERVAL_SECONDS"
    done
}

trap 'log "🛑 Monitor exiting"; stop_event_monitor; exit 0' SIGINT SIGTERM
main "$@"
