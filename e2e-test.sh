#!/bin/bash
#
# Claude Crew — End-to-End Smoke Test
# Creates an agent, environment, session, sends a task, streams output, verifies result.
#
set -euo pipefail

API_KEY="${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY}"
BASE="https://api.anthropic.com/v1"
HEADERS=(
  -H "x-api-key: $API_KEY"
  -H "anthropic-version: 2023-06-01"
  -H "anthropic-beta: managed-agents-2026-04-01"
  -H "content-type: application/json"
)

SCREENSHOTS_DIR="${1:-./e2e-screenshots}"
mkdir -p "$SCREENSHOTS_DIR"

log() { echo "[$(date +%H:%M:%S)] $*"; }
fail() { log "FAIL: $*"; exit 1; }

AGENT_ID=""
ENV_ID=""
SESSION_ID=""

cleanup() {
  log "Cleaning up..."
  if [ -n "$SESSION_ID" ]; then
    curl -sS "${BASE}/sessions/${SESSION_ID}/events" "${HEADERS[@]}" \
      -d '{"events":[{"type":"user.interrupt"}]}' > /dev/null 2>&1 || true
    sleep 5
    curl -sS -X POST "${BASE}/sessions/${SESSION_ID}/archive" "${HEADERS[@]}" > /dev/null 2>&1 || true
    log "  Archived session $SESSION_ID"
  fi
  if [ -n "$AGENT_ID" ]; then
    curl -sS -X POST "${BASE}/agents/${AGENT_ID}/archive" "${HEADERS[@]}" > /dev/null 2>&1 || true
    log "  Archived agent $AGENT_ID"
  fi
  if [ -n "$ENV_ID" ]; then
    curl -sS -X POST "${BASE}/environments/${ENV_ID}/archive" "${HEADERS[@]}" > /dev/null 2>&1 || true
    log "  Archived environment $ENV_ID"
  fi
}
trap cleanup EXIT

# ─── Step 1: Create Agent ─────────────────────────────────────────
log "Step 1: Creating agent..."
AGENT_RESPONSE=$(curl -sS --fail-with-body "${BASE}/agents" "${HEADERS[@]}" \
  -d '{
  "name": "e2e-test-agent",
  "model": "claude-sonnet-4-6",
  "system": "You are a helpful assistant. Be concise. Complete the task and stop.",
  "tools": [{"type": "agent_toolset_20260401"}]
}')
AGENT_ID=$(echo "$AGENT_RESPONSE" | jq -r '.id')
[ "$AGENT_ID" != "null" ] && [ -n "$AGENT_ID" ] || fail "Failed to create agent: $AGENT_RESPONSE"
log "  ✅ Created agent: $AGENT_ID"
echo "$AGENT_RESPONSE" | jq . > "$SCREENSHOTS_DIR/01-agent.json"

# ─── Step 2: Create Environment ───────────────────────────────────
log "Step 2: Creating environment..."
ENV_RESPONSE=$(curl -sS --fail-with-body "${BASE}/environments" "${HEADERS[@]}" \
  -d '{
  "name": "e2e-test-env",
  "config": {
    "type": "cloud",
    "networking": {"type": "unrestricted"}
  }
}')
ENV_ID=$(echo "$ENV_RESPONSE" | jq -r '.id')
[ "$ENV_ID" != "null" ] && [ -n "$ENV_ID" ] || fail "Failed to create environment: $ENV_RESPONSE"
log "  ✅ Created environment: $ENV_ID"
echo "$ENV_RESPONSE" | jq . > "$SCREENSHOTS_DIR/02-environment.json"

# ─── Step 3: Create Session ───────────────────────────────────────
log "Step 3: Creating session..."
SESSION_RESPONSE=$(curl -sS --fail-with-body "${BASE}/sessions" "${HEADERS[@]}" \
  -d "{
  \"agent\": \"$AGENT_ID\",
  \"environment_id\": \"$ENV_ID\",
  \"title\": \"E2E smoke test\"
}")
SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.id')
[ "$SESSION_ID" != "null" ] && [ -n "$SESSION_ID" ] || fail "Failed to create session: $SESSION_RESPONSE"
log "  ✅ Created session: $SESSION_ID"
echo "$SESSION_RESPONSE" | jq . > "$SCREENSHOTS_DIR/03-session.json"

# ─── Step 4: Send task ────────────────────────────────────────────
log "Step 4: Sending task..."
curl -sS --fail-with-body "${BASE}/sessions/${SESSION_ID}/events" "${HEADERS[@]}" \
  -d '{
  "events": [{
    "type": "user.message",
    "content": [{"type": "text", "text": "Write a Python script that creates a JSON file with the 5 largest countries by area (name, capital, area_km2). Save it to countries.json, read it back, and print a formatted summary. Then show the file contents with cat."}]
  }]
}' > /dev/null
log "  ✅ Message sent"

# ─── Step 5: Stream events via process substitution ───────────────
log "Step 5: Streaming events (max 120s)..."
EVENT_LOG="$SCREENSHOTS_DIR/04-events.log"
RAW_STREAM="$SCREENSHOTS_DIR/04-raw-stream.txt"
> "$EVENT_LOG"

# Stream to a temp file, process in background
curl -sS -N -L --max-time 120 "${BASE}/sessions/${SESSION_ID}/stream" \
  -H "x-api-key: $API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: agent-api-2026-03-01" \
  -H "Accept: text/event-stream" > "$RAW_STREAM" 2>/dev/null &
CURL_PID=$!

# Wait for stream to accumulate, polling for idle
IDLE_FOUND=0
for i in $(seq 1 60); do
  sleep 2

  # Check if curl is still running
  if ! kill -0 $CURL_PID 2>/dev/null; then
    break
  fi

  # Check session status
  STATUS=$(curl -sS "${BASE}/sessions/${SESSION_ID}" "${HEADERS[@]}" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")

  if [ "$STATUS" = "idle" ]; then
    log "  Session is idle — agent finished"
    IDLE_FOUND=1
    kill $CURL_PID 2>/dev/null || true
    break
  fi

  log "  Poll $i: status=$STATUS"
done

# Kill curl if still running
kill $CURL_PID 2>/dev/null || true
wait $CURL_PID 2>/dev/null || true

# Parse the raw stream into readable log
log "  Parsing event stream..."
while IFS= read -r line; do
  [[ "$line" == data:* ]] || continue
  json="${line#data: }"
  TYPE=$(echo "$json" | jq -r '.type' 2>/dev/null || echo "?")
  TS=$(date +%H:%M:%S)

  case "$TYPE" in
    agent|agent.message)
      TEXT=$(echo "$json" | jq -r '[.content[]? | select(.type=="text") | .text] | join("")' 2>/dev/null || echo "")
      if [ -n "$TEXT" ]; then
        echo "[$TS] MESSAGE: ${TEXT:0:200}" >> "$EVENT_LOG"
        log "  💬 ${TEXT:0:100}"
      fi
      ;;
    agent_tool_use|agent.tool_use)
      NAME=$(echo "$json" | jq -r '.tool_name // .name // "?"' 2>/dev/null)
      echo "[$TS] TOOL_USE: $NAME" >> "$EVENT_LOG"
      log "  🔧 tool: $NAME"
      ;;
    agent_tool_result|agent.tool_result)
      OUTPUT=$(echo "$json" | jq -r '[.content[]? | select(.type=="text") | .text] | join("") // .output // ""' 2>/dev/null || echo "")
      echo "[$TS] TOOL_RESULT: ${OUTPUT:0:300}" >> "$EVENT_LOG"
      [ -n "$OUTPUT" ] && log "  📋 result: ${OUTPUT:0:80}"
      ;;
    status_idle|session.status_idle)
      echo "[$TS] STATUS: idle" >> "$EVENT_LOG"
      ;;
    status_running|session.status_running)
      echo "[$TS] STATUS: running" >> "$EVENT_LOG"
      ;;
    session.error|error)
      MSG=$(echo "$json" | jq -r '.error.message // "?"' 2>/dev/null)
      echo "[$TS] ERROR: $MSG" >> "$EVENT_LOG"
      log "  ❌ error: $MSG"
      ;;
    *)
      echo "[$TS] $TYPE" >> "$EVENT_LOG"
      ;;
  esac
done < "$RAW_STREAM"

# ─── Step 6: Final verification ──────────────────────────────────
log "Step 6: Verifying..."
sleep 2
FINAL=$(curl -sS "${BASE}/sessions/${SESSION_ID}" "${HEADERS[@]}")
FINAL_STATUS=$(echo "$FINAL" | jq -r '.status')
echo "$FINAL" | jq . > "$SCREENSHOTS_DIR/05-final-session.json"

EVENT_LINES=$(grep -c "" "$EVENT_LOG" 2>/dev/null || echo 0)
TOOL_COUNT=$(grep -c "TOOL_USE:" "$EVENT_LOG" 2>/dev/null || echo 0)
MSG_COUNT=$(grep -c "MESSAGE:" "$EVENT_LOG" 2>/dev/null || echo 0)
RAW_SIZE=$(wc -c < "$RAW_STREAM" 2>/dev/null | tr -d ' ')

# ─── Step 7: Report ──────────────────────────────────────────────
REPORT="$SCREENSHOTS_DIR/06-report.txt"
cat > "$REPORT" <<REPORT

════════════════════════════════════════════════════
  CLAUDE CREW — E2E TEST REPORT
  $(date)
════════════════════════════════════════════════════

  RESOURCES CREATED:
    Agent:       $AGENT_ID
    Environment: $ENV_ID
    Session:     $SESSION_ID

  RESULTS:
    Final status:    $FINAL_STATUS
    Raw stream:      $RAW_SIZE bytes
    Event log:       $EVENT_LINES entries
    Agent messages:  $MSG_COUNT
    Tool calls:      $TOOL_COUNT
    Agent went idle: $([ "$IDLE_FOUND" -gt 0 ] && echo "YES" || echo "NO")

REPORT

if [ "$IDLE_FOUND" -gt 0 ] && [ "$TOOL_COUNT" -gt 0 ]; then
  echo "  ✅ E2E TEST PASSED" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "  The agent successfully:" >> "$REPORT"
  echo "    - Received the task" >> "$REPORT"
  echo "    - Used $TOOL_COUNT tool(s)" >> "$REPORT"
  echo "    - Sent $MSG_COUNT message(s)" >> "$REPORT"
  echo "    - Completed and went idle" >> "$REPORT"
  RESULT="PASSED"
else
  echo "  ❌ E2E TEST FAILED" >> "$REPORT"
  echo "    Expected: idle status + tool calls" >> "$REPORT"
  RESULT="FAILED"
fi
echo "════════════════════════════════════════════════════" >> "$REPORT"

cat "$REPORT"

echo ""
log "Event log:"
cat "$EVENT_LOG"

echo ""
log "Artifacts saved to $SCREENSHOTS_DIR/"
ls -la "$SCREENSHOTS_DIR/"

[ "$RESULT" = "PASSED" ] || exit 1
