#!/usr/bin/env bash
# Start backend API and frontend dev servers for hybrid testing
# Usage: bash .claude/skills/test-hybrid/start-servers.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

check_port() {
  lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

# Start backend if not running
if check_port 9292; then
  echo "Backend already running on :9292"
else
  echo "Starting backend API server..."
  rake run:api > /tmp/tyto-api.log 2>&1 &
  disown
  for i in $(seq 1 15); do
    if check_port 9292; then
      echo "Backend started on :9292"
      break
    fi
    sleep 1
  done
  if ! check_port 9292; then
    echo "ERROR: Backend failed to start. Check /tmp/tyto-api.log"
    exit 1
  fi
fi

# Start frontend if not running
if check_port 8080; then
  echo "Frontend already running on :8080"
else
  echo "Starting frontend dev server..."
  npm run dev > /tmp/tyto-frontend.log 2>&1 &
  disown
  for i in $(seq 1 20); do
    if check_port 8080; then
      echo "Frontend started on :8080"
      break
    fi
    sleep 1
  done
  if ! check_port 8080; then
    echo "ERROR: Frontend failed to start. Check /tmp/tyto-frontend.log"
    exit 1
  fi
fi

echo "Both servers ready."
