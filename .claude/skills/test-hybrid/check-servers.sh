#!/usr/bin/env bash
# Check if backend and frontend servers are running
# Usage: bash .claude/skills/test-hybrid/check-servers.sh

status=0

if lsof -iTCP:9292 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Backend:  running on :9292"
else
  echo "Backend:  NOT running"
  status=1
fi

if lsof -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Frontend: running on :8080"
else
  echo "Frontend: NOT running"
  status=1
fi

exit $status
