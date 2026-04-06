#!/bin/bash
set -e

mkdir -p /data/.hermes/sessions /data/.hermes/skills /data/.hermes/workspace /data/.hermes/pairing

# If Claude Code credentials are provided, write them and start Meridian proxy
if [ -n "$CLAUDE_CREDENTIALS" ]; then
    mkdir -p /data/.claude
    echo "$CLAUDE_CREDENTIALS" > /data/.claude/.credentials.json
    echo "[start] Claude credentials written"

    meridian >> /tmp/meridian.log 2>&1 &
    MERIDIAN_PID=$!
    echo "[start] Meridian proxy starting on http://127.0.0.1:3456 (PID $MERIDIAN_PID)"

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

    # Watchdog: restart Meridian if it crashes, stop gateway if it can't recover
    (
        FAIL_COUNT=0
        while true; do
            sleep 30
            if ! (echo >/dev/tcp/127.0.0.1/3456) 2>/dev/null; then
                FAIL_COUNT=$((FAIL_COUNT + 1))
                echo "[watchdog] Meridian not responding (attempt $FAIL_COUNT/3) — restarting..."
                meridian >> /tmp/meridian.log 2>&1 &
                sleep 10
                if (echo >/dev/tcp/127.0.0.1/3456) 2>/dev/null; then
                    echo "[watchdog] Meridian recovered"
                    FAIL_COUNT=0
                elif [ "$FAIL_COUNT" -ge 3 ]; then
                    echo "[watchdog] CRITICAL: Meridian failed 3 times — stopping gateway to prevent direct API charges"
                    curl -sf http://localhost:${PORT:-8080}/api/gateway/stop -X POST -u "${ADMIN_USERNAME:-admin}:${ADMIN_PASSWORD}" >/dev/null 2>&1 || true
                    FAIL_COUNT=0
                fi
            else
                FAIL_COUNT=0
            fi
        done
    ) &
fi

exec python /app/server.py
