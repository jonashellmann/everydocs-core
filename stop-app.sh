#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

DEFAULT_RAILS_ENV="production"
DEFAULT_PORT=5678
DEFAULT_PID_DIR="tmp/pids"

EXIT_CODE_SUCCESS=0
EXIT_CODE_NO_PROCESS=1
EXIT_CODE_STOP_FAILED=2
EXIT_CODE_ERROR=3

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
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

stop_process_gracefully() {
    local pid="$1"
    local timeout=30
    local interval=1
    
    log_info "Stopping process PID: $pid..."
    
    kill -TERM "$pid" 2>/dev/null || true
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if ! is_process_running "$pid"; then
            log_success "Process stopped gracefully"
            return 0
        fi
        sleep $interval
        ((elapsed += interval))
        if [[ $((elapsed % 5)) -eq 0 ]]; then
            log_info "Waiting for process to stop... (${elapsed}s/${timeout}s)"
        fi
    done
    
    log_warning "Process did not stop gracefully after $timeout seconds"
    log_info "Sending SIGKILL..."
    kill -9 "$pid" 2>/dev/null || true
    
    sleep 1
    
    if is_process_running "$pid"; then
        log_error "Failed to stop process PID: $pid"
        return 1
    else
        log_success "Process forcefully stopped"
        return 0
    fi
}

main() {
    load_env_file

    PID_DIR=$(get_config_value "PID_DIR" "$DEFAULT_PID_DIR")
    PORT=$(get_config_value "PORT" "$DEFAULT_PORT")

    if [[ "$PID_DIR" != /* ]]; then
        PID_DIR="$PROJECT_ROOT/$PID_DIR"
    fi

    PID_FILE="$PID_DIR/everydocs.pid"

    log_info "=============================================="
    log_info "Stopping EveryDocs Core"
    log_info "=============================================="

    local pids_to_stop=()
    local stopped_count=0

    if [[ -f "$PID_FILE" ]]; then
        local pid_from_file=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid_from_file" ]] && [[ "$pid_from_file" =~ ^[0-9]+$ ]]; then
            if is_process_running "$pid_from_file"; then
                pids_to_stop+=("$pid_from_file")
            else
                log_info "PID file exists but process $pid_from_file is not running"
                log_info "Removing stale PID file..."
                rm -f "$PID_FILE"
            fi
        else
            log_info "PID file contains invalid PID, removing..."
            rm -f "$PID_FILE"
        fi
    else
        log_info "No PID file found at: $PID_FILE"
    fi

    local pid_from_port=$(get_pid_from_port "$PORT")
    if [[ -n "$pid_from_port" ]] && [[ "$pid_from_port" =~ ^[0-9]+$ ]]; then
        local already_included=false
        for pid in "${pids_to_stop[@]}"; do
            if [[ "$pid" == "$pid_from_port" ]]; then
                already_included=true
                break
            fi
        done
        
        if [[ "$already_included" == false ]] && is_process_running "$pid_from_port"; then
            log_info "Found process on port $PORT (PID: $pid_from_port)"
            pids_to_stop+=("$pid_from_port")
        fi
    fi

    if [[ ${#pids_to_stop[@]} -eq 0 ]]; then
        log_info "=============================================="
        log_info "No running EveryDocs process found"
        log_info "=============================================="
        exit $EXIT_CODE_NO_PROCESS
    fi

    log_info "Found ${#pids_to_stop[@]} process(es) to stop"

    for pid in "${pids_to_stop[@]}"; do
        if stop_process_gracefully "$pid"; then
            ((stopped_count++))
        fi
    done

    if [[ -f "$PID_FILE" ]]; then
        log_info "Removing PID file..."
        rm -f "$PID_FILE"
    fi

    log_info "=============================================="
    if [[ $stopped_count -eq ${#pids_to_stop[@]} ]]; then
        log_success "All processes stopped successfully!"
        log_success "=============================================="
        log_success "EveryDocs Core has been stopped"
        log_success "=============================================="
        exit $EXIT_CODE_SUCCESS
    else
        log_error "Stopped $stopped_count/${#pids_to_stop[@]} processes"
        log_error "=============================================="
        exit $EXIT_CODE_STOP_FAILED
    fi
}

main "$@"
