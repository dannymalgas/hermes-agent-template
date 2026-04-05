#!/bin/bash
set -e

mkdir -p /data/.hermes/sessions /data/.hermes/skills /data/.hermes/workspace /data/.hermes/pairing

# If Claude Code credentials are provided, write them and start Meridian proxy
if [ -n "$CLAUDE_CREDENTIALS" ]; then
    mkdir -p /data/.claude
    echo "$CLAUDE_CREDENTIALS" > /data/.claude/.credentials.json
    echo "[start] Claude credentials written"

    meridian >> /tmp/meridian.log 2>&1 &
    echo "[start] Meridian proxy starting on http://127.0.0.1:3456"

    # Wait up to 15s for Meridian to be ready
    for i in $(seq 1 15); do
        if (echo >/dev/tcp/127.0.0.1/3456) 2>/dev/null; then
            echo "[start] Meridian is ready"
            break
        fi
        if [ "$i" -eq 15 ]; then
            echo "[start] WARNING: Meridian did not start in time — check /tmp/meridian.log"
        fi
        sleep 1
    done
fi

exec python /app/server.py
