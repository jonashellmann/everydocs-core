#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

DEFAULT_RAILS_ENV="production"
DEFAULT_PORT=5678
DEFAULT_PID_DIR="tmp/pids"
DEFAULT_LOG_DIR="log"

EXIT_CODE_NOT_RUNNING=1
EXIT_CODE_ERROR=2

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

load_env_file() {
    local env_file="$PROJECT_ROOT/.env"
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
    fi
}

get_config_value() {
    local var_name="$1"
    local default_value="$2"
    local value="${!var_name:-}"
    
    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

is_process_running() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

get_pid_from_port() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -t -i:"$port" 2>/dev/null | head -1
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1
    elif command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep ":$port " | awk '{print $6}' | cut -d'/' -f1
    else
        echo ""
    fi
}

get_process_uptime() {
    local pid="$1"
    if command -v ps &>/dev/null; then
        if ps -o etime= -p "$pid" 2>/dev/null; then
            ps -o etime= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

get_process_start_time() {
    local pid="$1"
    if command -v ps &>/dev/null; then
        if ps -o lstart= -p "$pid" 2>/dev/null; then
            ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

get_process_memory() {
    local pid="$1"
    if command -v ps &>/dev/null; then
        local rss=$(ps -o rss= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$rss" && "$rss" =~ ^[0-9]+$ ]]; then
            local mb=$((rss / 1024))
            echo "${mb} MB (${rss} KB)"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

check_port_connectivity() {
    local port="$1"
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout 2 "http://localhost:$port/version" &>/dev/null; then
            echo "Connected (API responding)"
        elif curl -s --connect-timeout 2 "http://localhost:$port" &>/dev/null; then
            echo "Connected"
        elif curl -s --connect-timeout 2 "http://127.0.0.1:$port" &>/dev/null; then
            echo "Connected (127.0.0.1)"
        else
            echo "Port open but API not responding"
        fi
    else
        echo "Unable to check (curl not available)"
    fi
}

main() {
    load_env_file

    PID_DIR=$(get_config_value "PID_DIR" "$DEFAULT_PID_DIR")
    LOG_DIR=$(get_config_value "LOG_DIR" "$DEFAULT_LOG_DIR")
    PORT=$(get_config_value "PORT" "$DEFAULT_PORT")
    RAILS_ENV=$(get_config_value "RAILS_ENV" "$DEFAULT_RAILS_ENV")

    if [[ "$PID_DIR" != /* ]]; then
        PID_DIR="$PROJECT_ROOT/$PID_DIR"
    fi
    if [[ "$LOG_DIR" != /* ]]; then
        LOG_DIR="$PROJECT_ROOT/$LOG_DIR"
    fi

    PID_FILE="$PID_DIR/everydocs.pid"
    LOG_FILE="$LOG_DIR/everydocs.log"
    STDERR_LOG="$LOG_DIR/everydocs.error.log"

    echo "=============================================="
    echo "EveryDocs Core Status"
    echo "=============================================="
    echo ""
    echo "Configuration:"
    echo "  RAILS_ENV: $RAILS_ENV"
    echo "  Port: $PORT"
    echo "  PID File: $PID_FILE"
    echo "  Log File: $LOG_FILE"
    echo "  Error Log: $STDERR_LOG"
    echo ""

    local running=false
    local pid=""

    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
            if is_process_running "$pid"; then
                running=true
                log_success "EveryDocs Core is running"
            else
                log_error "PID file exists but process $pid is not running (stale PID file)"
            fi
        else
            log_error "PID file contains invalid PID: '$pid'"
        fi
    else
        log_info "PID file does not exist at: $PID_FILE"
    fi

    local port_pid=$(get_pid_from_port "$PORT")
    if [[ -n "$port_pid" ]] && [[ "$port_pid" =~ ^[0-9]+$ ]]; then
        if is_process_running "$port_pid"; then
            if [[ "$running" == false ]]; then
                running=true
                pid="$port_pid"
                log_success "EveryDocs Core is running on port $PORT (PID: $pid)"
            elif [[ "$port_pid" != "$pid" ]]; then
                log_warning "Another process is listening on port $PORT (PID: $port_pid)"
            fi
        fi
    fi

    echo ""
    echo "=============================================="

    if [[ "$running" == true ]]; then
        echo "Service Status: RUNNING"
        echo ""
        
        if [[ -n "$pid" ]]; then
            echo "Process Details:"
            echo "  PID: $pid"
            echo "  Uptime: $(get_process_uptime "$pid")"
            echo "  Started: $(get_process_start_time "$pid")"
            echo "  Memory Usage: $(get_process_memory "$pid")"
            echo ""
        fi

        echo "Port Status:"
        echo "  Port $PORT: $(check_port_connectivity "$PORT")"
        echo ""
        
        if [[ -f "$LOG_FILE" ]]; then
            local log_size=$(du -h "$LOG_FILE" 2>/dev/null | awk '{print $1}' || echo "Unknown")
            local log_lines=$(wc -l "$LOG_FILE" 2>/dev/null | awk '{print $1}' || echo "Unknown")
            echo "Log Status:"
            echo "  Main Log: $LOG_FILE"
            echo "    Size: $log_size"
            echo "    Lines: $log_lines"
            echo ""
        fi

        if [[ -f "$STDERR_LOG" && -s "$STDERR_LOG" ]]; then
            local err_size=$(du -h "$STDERR_LOG" 2>/dev/null | awk '{print $1}' || echo "Unknown")
            echo "  Error Log: $STDERR_LOG"
            echo "    Size: $err_size"
            echo ""
            echo "Last 5 error lines:"
            tail -5 "$STDERR_LOG" 2>/dev/null || echo "    (Unable to read)"
            echo ""
        fi

        echo "=============================================="
        echo "Quick Commands:"
        echo "  Stop:   ./stop-app.sh"
        echo "  Restart: ./stop-app.sh && ./start-app.sh"
        echo "  Logs:    tail -f $LOG_FILE"
        echo "=============================================="
        
        exit 0
    else
        echo "Service Status: NOT RUNNING"
        echo ""
        echo "Possible reasons:"
        echo "  - Service has not been started"
        echo "  - Service was stopped"
        echo "  - Service crashed"
        echo ""
        echo "To start:"
        echo "  ./start-app.sh"
        echo ""
        
        if [[ -f "$STDERR_LOG" && -s "$STDERR_LOG" ]]; then
            echo "Last 10 lines of error log (may help diagnose crash):"
            echo "----------------------------------------"
            tail -10 "$STDERR_LOG" 2>/dev/null || echo "  (Unable to read error log)"
            echo "----------------------------------------"
            echo ""
        fi
        
        echo "=============================================="
        
        exit $EXIT_CODE_NOT_RUNNING
    fi
}

main "$@"
