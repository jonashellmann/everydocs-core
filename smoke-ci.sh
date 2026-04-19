#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_DIR="$PROJECT_ROOT/log"
PID_DIR="$PROJECT_ROOT/tmp/pids"

EXIT_CODE_SUCCESS=0
EXIT_CODE_SETUP_FAILED=1
EXIT_CODE_START_FAILED=2
EXIT_CODE_PROBE_FAILED=3
EXIT_CODE_STOP_FAILED=4

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

cleanup() {
    log_info "Cleaning up..."
    if [[ -n "${SMOKE_PORT:-}" ]]; then
        cd "$PROJECT_ROOT" && PORT="$SMOKE_PORT" RAILS_ENV=test ./stop-app.sh 2>/dev/null || true
    fi
}

trap cleanup EXIT

generate_random_port() {
    local min_port=1024
    local max_port=65535
    local range=$((max_port - min_port + 1))
    
    if command -v awk &>/dev/null; then
        awk -v min="$min_port" -v max="$max_port" 'BEGIN{srand(); print int(min + rand() * (max - min + 1))}'
    elif command -v python3 &>/dev/null; then
        python3 -c "import random; print(random.randint($min_port, $max_port))"
    elif command -v python &>/dev/null; then
        python -c "import random; print(random.randint($min_port, $max_port))"
    else
        local seed=${RANDOM:-$$}
        echo $(( (seed % (max_port - min_port + 1)) + min_port ))
    fi
}

tail_logs() {
    local lines=${1:-50}
    log_info "=== Debug: Last $lines lines of logs ==="
    
    if [[ -f "$LOG_DIR/everydocs.log" ]]; then
        log_info "--- Main Log ---"
        tail -"$lines" "$LOG_DIR/everydocs.log" 2>/dev/null || true
    fi
    
    if [[ -f "$LOG_DIR/everydocs.error.log" ]]; then
        log_info "--- Error Log ---"
        tail -"$lines" "$LOG_DIR/everydocs.error.log" 2>/dev/null || true
    fi
}

main() {
    SMOKE_PORT=$(generate_random_port)
    export RAILS_ENV=test
    export PORT="$SMOKE_PORT"
    export SECRET_KEY_BASE="ci_smoke_test_secret_key_base_$(date +%s)"
    
    echo "=============================================="
    echo "EveryDocs Core - CI Smoke Test"
    echo "=============================================="
    echo ""
    echo "Configuration:"
    echo "  RAILS_ENV: $RAILS_ENV"
    echo "  PORT: $SMOKE_PORT"
    echo "  SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:20}... (truncated)"
    echo ""

    log_info "Phase 1: Cleanup any existing instance..."
    mkdir -p "$LOG_DIR"
    mkdir -p "$PID_DIR"
    rm -f "$LOG_DIR/everydocs.log"
    rm -f "$LOG_DIR/everydocs.error.log"
    
    if cd "$PROJECT_ROOT" && PORT="$SMOKE_PORT" RAILS_ENV=test ./stop-app.sh 2>/dev/null; then
        log_info "  ✓ Cleanup complete"
    else
        log_info "  ✓ No existing instance to stop"
    fi
    echo ""

    log_info "Phase 2: Setup test database..."
    if cd "$PROJECT_ROOT" && rails db:migrate RAILS_ENV=test 2>&1; then
        log_success "  ✓ Database migrated"
    else
        log_error "  ✗ Database migration failed"
        exit $EXIT_CODE_SETUP_FAILED
    fi
    echo ""

    log_info "Phase 3: Start server..."
    cd "$PROJECT_ROOT"
    if ./start-app.sh; then
        log_success "  ✓ Start command executed"
    else
        log_error "  ✗ Start command failed"
        tail_logs 100
        exit $EXIT_CODE_START_FAILED
    fi
    echo ""

    log_info "Phase 4: Wait for server to start..."
    local max_attempts=60
    local attempt=1
    local started=false
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --connect-timeout 2 "http://localhost:$SMOKE_PORT/version" >/dev/null 2>&1; then
            started=true
            log_success "  ✓ Server started after $attempt seconds"
            break
        fi
        
        log_info "  Waiting... ($attempt/$max_attempts)"
        sleep 1
        ((attempt++))
    done
    
    if [[ "$started" == false ]]; then
        log_error "  ✗ Server failed to start within $max_attempts seconds"
        echo ""
        tail_logs 100
        exit $EXIT_CODE_START_FAILED
    fi
    echo ""

    log_info "Phase 5: Probe /version endpoint..."
    local response
    response=$(curl -s "http://localhost:$SMOKE_PORT/version" 2>/dev/null || true)
    
    if [[ -z "$response" ]]; then
        log_error "  ✗ /version returned empty response"
        tail_logs 50
        exit $EXIT_CODE_PROBE_FAILED
    else
        log_success "  ✓ /version responded: $response"
    fi
    echo ""

    log_info "Phase 6: Stop server..."
    cd "$PROJECT_ROOT"
    if PORT="$SMOKE_PORT" RAILS_ENV=test ./stop-app.sh; then
        log_success "  ✓ Server stopped"
    else
        log_error "  ⚠ Stop command returned non-zero exit code (process may already be stopped)"
    fi
    echo ""

    echo "=============================================="
    log_success "CI Smoke Test PASSED!"
    echo "=============================================="
    
    exit $EXIT_CODE_SUCCESS
}

main "$@"
