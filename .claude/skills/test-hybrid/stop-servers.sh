#!/usr/bin/env bash
# Stop backend and frontend servers
# Usage: bash .claude/skills/test-hybrid/stop-servers.sh

if lsof -iTCP:9292 -sTCP:LISTEN >/dev/null 2>&1; then
  pid=$(lsof -iTCP:9292 -sTCP:LISTEN -t 2>/dev/null)
  kill "$pid" 2>/dev/null && echo "Backend stopped (PID $pid)" || echo "Backend: failed to stop"
else
  echo "Backend: not running"
fi

if lsof -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
  pid=$(lsof -iTCP:8080 -sTCP:LISTEN -t 2>/dev/null)
  kill "$pid" 2>/dev/null && echo "Frontend stopped (PID $pid)" || echo "Frontend: failed to stop"
else
  echo "Frontend: not running"
fi
