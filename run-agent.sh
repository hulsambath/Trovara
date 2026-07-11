#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

MAX_ITERATIONS=20

for i in $(seq 1 "$MAX_ITERATIONS"); do
  if grep -q "Status: COMPLETE" ROADMAP.md; then
    echo "[run-agent] ROADMAP.md reports COMPLETE — stopping (iteration $i)."
    exit 0
  fi

  echo "[run-agent] Iteration $i/$MAX_ITERATIONS — dispatching agent."

  claude -p "Follow the Autonomous Execution Protocol in CLAUDE.md."

  echo "[run-agent] Iteration $i/$MAX_ITERATIONS complete."
done

echo "[run-agent] Reached MAX_ITERATIONS ($MAX_ITERATIONS) without COMPLETE status."
exit 1
