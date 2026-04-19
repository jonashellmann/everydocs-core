.PHONY: start stop restart status smoke check clean help

.DEFAULT_GOAL := help

PROJECT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PID_DIR := tmp/pids
PID_FILE := $(PID_DIR)/everydocs.pid
LOG_DIR := log

help:
	@echo "EveryDocs Core - Make Commands"
	@echo "=============================================="
	@echo ""
	@echo "Commands:"
	@echo "  start       - Start the EveryDocs server"
	@echo "  stop        - Stop the EveryDocs server"
	@echo "  restart     - Restart the EveryDocs server"
	@echo "  status      - Check server status"
	@echo "  smoke       - Run smoke test (start -> probe /version -> stop)"
	@echo "  check       - Run quick check (.env + dependencies + tests)"
	@echo "  test        - Run Rails tests"
	@echo "  logs        - Tail the server logs"
	@echo "  clean-logs  - Clean log files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Environment Variables (can be set in .env file):"
	@echo "  RAILS_ENV       - Rails environment (default: production)"
	@echo "  PORT            - Server port (default: 5678)"
	@echo "  SECRET_KEY_BASE - Rails secret key (required)"
	@echo "  MYSQL_PASSWORD  - Database password (required)"
	@echo ""
	@echo "Examples:"
	@echo "  make start"
	@echo "  make stop"
	@echo "  make smoke"
	@echo "  make check"
	@echo ""

start:
	@echo "Starting EveryDocs Core..."
	@cd $(PROJECT_DIR) && ./start-app.sh

stop:
	@echo "Stopping EveryDocs Core..."
	@cd $(PROJECT_DIR) && ./stop-app.sh || true

restart: stop start

status:
	@cd $(PROJECT_DIR) && ./status.sh

logs:
	@echo "Tailing logs (Ctrl+C to exit)..."
	@tail -f $(LOG_DIR)/everydocs.log $(LOG_DIR)/everydocs.error.log 2>/dev/null || echo "Log files not found yet"

logs-error:
	@echo "Tailing error logs (Ctrl+C to exit)..."
	@tail -f $(LOG_DIR)/everydocs.error.log 2>/dev/null || echo "Error log file not found yet"

clean-logs:
	@echo "Cleaning log files..."
	@rm -f $(LOG_DIR)/everydocs.log $(LOG_DIR)/everydocs.error.log
	@echo "Log files cleaned"

test:
	@echo "Running Rails tests..."
	@cd $(PROJECT_DIR) && rails test RAILS_ENV=test

test-controllers:
	@echo "Running controller tests..."
	@cd $(PROJECT_DIR) && rails test test/controllers/ RAILS_ENV=test

db-migrate:
	@echo "Running database migrations..."
	@cd $(PROJECT_DIR) && rails db:migrate

db-migrate-test:
	@echo "Running database migrations (test env)..."
	@cd $(PROJECT_DIR) && rails db:migrate RAILS_ENV=test

smoke:
	@cd $(PROJECT_DIR) && ./smoke-ci.sh

check:
	@echo "=============================================="
	@echo "EveryDocs Core - Quick Check"
	@echo "=============================================="
	@echo ""
	@echo "Phase 1: Checking prerequisites..."
	@cd $(PROJECT_DIR) && if [ ! -f .env ]; then \
		echo "  ERROR: .env file not found"; \
		echo "  Create one from .env.example: cp .env.example .env"; \
		exit 1; \
	else \
		echo "  ✓ .env file exists"; \
	fi
	@cd $(PROJECT_DIR) && if grep -q "your_secret_key_base_here" .env 2>/dev/null; then \
		echo "  ERROR: SECRET_KEY_BASE not set in .env"; \
		echo "  Generate one with: openssl rand -hex 64"; \
		exit 1; \
	else \
		echo "  ✓ SECRET_KEY_BASE appears to be set"; \
	fi
	@echo ""
	
	@echo "Phase 2: Checking required commands..."
	@which ruby >/dev/null 2>&1 && echo "  ✓ ruby" || (echo "  ✗ ruby (required)" && exit 1)
	@which bundle >/dev/null 2>&1 && echo "  ✓ bundle" || (echo "  ✗ bundle (required)" && exit 1)
	@which rails >/dev/null 2>&1 && echo "  ✓ rails" || (echo "  ✗ rails (required)" && exit 1)
	@echo ""
	
	@echo "Phase 3: Checking bundle dependencies..."
	@cd $(PROJECT_DIR) && bundle check 2>/dev/null && echo "  ✓ Dependencies satisfied" || (echo "  ✗ Dependencies missing. Run: bundle install" && exit 1)
	@echo ""
	
	@echo "Phase 4: Checking test setup..."
	@cd $(PROJECT_DIR) && rails db:migrate RAILS_ENV=test 2>&1 | tail -1
	@echo ""
	
	@echo "Phase 5: Running basic tests..."
	@cd $(PROJECT_DIR) && rails test RAILS_ENV=test 2>&1
	@echo ""
	
	@echo "=============================================="
	@echo "Quick Check Completed"
	@echo "=============================================="
