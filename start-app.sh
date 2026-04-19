#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

DEFAULT_RAILS_ENV="production"
DEFAULT_PORT=5678
DEFAULT_LOG_DIR="log"
DEFAULT_PID_DIR="tmp/pids"

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
        log_info "Loading environment from $env_file"
        set -a
        source "$env_file"
        set +a
    else
        log_info "No .env file found, using defaults"
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

main() {
    load_env_file

    RAILS_ENV=$(get_config_value "RAILS_ENV" "$DEFAULT_RAILS_ENV")
    PORT=$(get_config_value "PORT" "$DEFAULT_PORT")
    LOG_DIR=$(get_config_value "LOG_DIR" "$DEFAULT_LOG_DIR")
    PID_DIR=$(get_config_value "PID_DIR" "$DEFAULT_PID_DIR")

    if [[ "$LOG_DIR" != /* ]]; then
        LOG_DIR="$PROJECT_ROOT/$LOG_DIR"
    fi
    if [[ "$PID_DIR" != /* ]]; then
        PID_DIR="$PROJECT_ROOT/$PID_DIR"
    fi

    mkdir -p "$LOG_DIR"
    mkdir -p "$PID_DIR"

    PID_FILE="$PID_DIR/everydocs.pid"
    LOG_FILE="$LOG_DIR/everydocs.log"
    STDERR_LOG="$LOG_DIR/everydocs.error.log"

    log_info "=============================================="
    log_info "Starting EveryDocs Core"
    log_info "=============================================="
    log_info "Configuration:"
    log_info "  RAILS_ENV: $RAILS_ENV"
    log_info "  PORT: $PORT"
    log_info "  LOG_DIR: $LOG_DIR"
    log_info "  PID_DIR: $PID_DIR"
    log_info "  PID_FILE: $PID_FILE"
    log_info "=============================================="

    local stale_pid=false
    local existing_pid=""

    if [[ -f "$PID_FILE" ]]; then
        existing_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$existing_pid" ]] && is_process_running "$existing_pid"; then
            log_error "EveryDocs is already running (PID: $existing_pid)"
            log_error "Use stop-app.sh to stop it first, or status.sh to check status"
            exit 1
        else
            log_info "Found stale PID file (PID: ${existing_pid:-empty}), removing..."
            stale_pid=true
            rm -f "$PID_FILE"
        fi
    fi

    local port_pid=$(get_pid_from_port "$PORT")
    if [[ -n "$port_pid" ]]; then
        if [[ "$port_pid" != "$existing_pid" ]] && is_process_running "$port_pid"; then
            log_error "Port $PORT is already in use by process $port_pid"
            log_error "Use a different port or stop the process first"
            exit 1
        fi
    fi

    cd "$PROJECT_ROOT"

    log_info "Checking required environment variables..."
    local missing_vars=()

    if [[ -z "${SECRET_KEY_BASE:-}" ]]; then
        missing_vars+=("SECRET_KEY_BASE")
    fi

    if [[ "$RAILS_ENV" == "production" ]] || [[ "$RAILS_ENV" == "development" ]]; then
        if [[ -z "${EVERYDOCS_DB_PASSWORD:-}" ]]; then
            log_info "Warning: EVERYDOCS_DB_PASSWORD not set (may use default)"
        fi
    fi

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        log_error "Please set these in your .env file"
        log_error "Example: SECRET_KEY_BASE=$(openssl rand -hex 64 2>/dev/null || echo '<generate with: openssl rand -hex 64>')"
        exit 1
    fi

    export RAILS_ENV
    export SECRET_KEY_BASE

    log_info "Starting Rails server..."

    nohup rails server --port "$PORT" \
        >"$LOG_FILE" 2>"$STDERR_LOG" \
        --pid "$PID_FILE" &

    local nohup_pid=$!

    sleep 2

    local max_attempts=30
    local attempt=1
    local started=false

    while [[ $attempt -le $max_attempts ]]; do
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE" 2>/dev/null || true)
            if [[ -n "$pid" ]] && is_process_running "$pid"; then
                started=true
                break
            fi
        fi

        local port_pid=$(get_pid_from_port "$PORT")
        if [[ -n "$port_pid" ]] && is_process_running "$port_pid"; then
            echo "$port_pid" > "$PID_FILE"
            started=true
            break
        fi

        log_info "Waiting for server to start... (attempt $attempt/$max_attempts)"
        sleep 1
        ((attempt++))
    done

    if [[ "$started" == true ]]; then
        local final_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        log_success "=============================================="
        log_success "EveryDocs Core started successfully!"
        log_success "=============================================="
        log_success "  PID: $final_pid"
        log_success "  Port: $PORT"
        log_success "  Environment: $RAILS_ENV"
        log_success "  PID File: $PID_FILE"
        log_success "  Log File: $LOG_FILE"
        log_success "  Error Log: $STDERR_LOG"
        log_success "=============================================="
        log_success "To stop: ./stop-app.sh"
        log_success "To check status: ./status.sh"
        log_success "=============================================="
        exit 0
    else
        log_error "=============================================="
        log_error "Failed to start EveryDocs Core"
        log_error "=============================================="
        log_error "Check logs for details:"
        log_error "  $LOG_FILE"
        log_error "  $STDERR_LOG"
        log_error "=============================================="

        if [[ -s "$STDERR_LOG" ]]; then
            log_error "Last 20 lines of error log:"
            tail -20 "$STDERR_LOG" | while read -r line; do
                log_error "  $line"
            done
        fi

        exit 1
    fi
}

main "$@"
