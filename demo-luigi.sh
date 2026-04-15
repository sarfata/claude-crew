#!/bin/bash
#
# Demo: Luigi the Linux Plumber reviews pi-blaster issues and prepares a PR
#
set -euo pipefail

API_KEY="${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY}"
BASE="https://api.anthropic.com/v1"
H=(-H "x-api-key: $API_KEY" -H "anthropic-version: 2023-06-01" -H "anthropic-beta: managed-agents-2026-04-01" -H "content-type: application/json")
DIR="./demo-screenshots"
mkdir -p "$DIR"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# ─── Create Agent: Luigi the Linux Plumber ────────────────────────
log "Creating agent: Luigi the Linux Plumber..."
AGENT=$(curl -sS --fail-with-body "${BASE}/agents" "${H[@]}" -d '{
  "name": "Luigi the Linux Plumber",
  "model": "claude-sonnet-4-6",
  "system": "You are Luigi, a cheerful Linux plumber who loves fixing pipes (and code). You speak with occasional plumbing metaphors. You are thorough, methodical, and always test your fixes. When reviewing code, you look for real problems you can actually fix. Keep your responses concise but friendly.",
  "tools": [{"type": "agent_toolset_20260401"}],
  "description": "A friendly Linux expert who reviews repos, triages issues, and prepares fixes."
}')
AGENT_ID=$(echo "$AGENT" | jq -r '.id')
log "  Agent: $AGENT_ID"
echo "$AGENT" | jq . > "$DIR/01-agent.json"

# ─── Create Environment ──────────────────────────────────────────
log "Creating environment..."
ENV=$(curl -sS --fail-with-body "${BASE}/environments" "${H[@]}" -d '{
  "name": "luigi-workshop",
  "config": {
    "type": "cloud",
    "packages": {"apt": ["git", "build-essential", "gcc", "make"]},
    "networking": {"type": "unrestricted"}
  }
}')
ENV_ID=$(echo "$ENV" | jq -r '.id')
log "  Environment: $ENV_ID"
echo "$ENV" | jq . > "$DIR/02-environment.json"

# ─── Create Session ──────────────────────────────────────────────
log "Creating session..."
SESSION=$(curl -sS --fail-with-body "${BASE}/sessions" "${H[@]}" -d "{
  \"agent\": \"$AGENT_ID\",
  \"environment_id\": \"$ENV_ID\",
  \"title\": \"Luigi reviews pi-blaster\"
}")
SESSION_ID=$(echo "$SESSION" | jq -r '.id')
log "  Session: $SESSION_ID"
echo "$SESSION" | jq . > "$DIR/03-session.json"

# ─── Send the task ───────────────────────────────────────────────
log "Sending task to Luigi..."
TASK='Hey Luigi! I need your help with a project.

1. Clone https://github.com/sarfata/pi-blaster/
2. Read the README to understand what the project does
3. Look at all the open GitHub issues (use web_fetch to read https://api.github.com/repos/sarfata/pi-blaster/issues?state=open&per_page=30)
4. Pick ONE issue that you think you can realistically fix based on the codebase
5. Explain why you picked it and what the fix would be
6. Implement the fix - create or modify the necessary files
7. Show me a git diff of your changes

Be thorough but efficient. Focus on an issue you can actually fix with a code change.'

curl -sS --fail-with-body "${BASE}/sessions/${SESSION_ID}/events" "${H[@]}" \
  -d "$(jq -n --arg t "$TASK" '{events: [{type: "user.message", content: [{type: "text", text: $t}]}]}')" > /dev/null
log "  Task sent!"

# ─── Stream and log events ───────────────────────────────────────
log "Streaming events..."
RAW="$DIR/04-raw-stream.txt"
LOG="$DIR/04-events.log"
> "$LOG"

curl -sS -N -L --max-time 300 "${BASE}/sessions/${SESSION_ID}/stream" \
  -H "x-api-key: $API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: agent-api-2026-03-01" \
  -H "Accept: text/event-stream" > "$RAW" 2>/dev/null &
PID=$!

for i in $(seq 1 150); do
  sleep 2
  if ! kill -0 $PID 2>/dev/null; then break; fi
  STATUS=$(curl -sS "${BASE}/sessions/${SESSION_ID}" "${H[@]}" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "?")
  if [ "$STATUS" = "idle" ]; then
    log "  Luigi finished! (idle)"
    kill $PID 2>/dev/null || true
    break
  fi
  [ $((i % 5)) -eq 0 ] && log "  Still working... (poll $i, status=$STATUS)"
done
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true

# ─── Parse events ────────────────────────────────────────────────
log "Parsing events..."
while IFS= read -r line; do
  [[ "$line" == data:* ]] || continue
  json="${line#data: }"
  TYPE=$(echo "$json" | jq -r '.type' 2>/dev/null || continue)
  TS=$(date +%H:%M:%S)
  case "$TYPE" in
    agent)
      TEXT=$(echo "$json" | jq -r '[.content[]? | select(.type=="text") | .text] | join("")' 2>/dev/null || echo "")
      [ -n "$TEXT" ] && echo "[$TS] LUIGI: $TEXT" >> "$LOG"
      [ -n "$TEXT" ] && log "  🔧 Luigi: ${TEXT:0:120}..."
      ;;
    agent_tool_use)
      NAME=$(echo "$json" | jq -r '.tool_name // "?"' 2>/dev/null)
      echo "[$TS] TOOL: $NAME" >> "$LOG"
      log "  🛠️  Tool: $NAME"
      ;;
    agent_tool_result)
      OUTPUT=$(echo "$json" | jq -r '[.content[]? | select(.type=="text") | .text] | join("")' 2>/dev/null || echo "")
      echo "[$TS] RESULT: ${OUTPUT:0:500}" >> "$LOG"
      ;;
    status_idle) echo "[$TS] STATUS: idle" >> "$LOG" ;;
    status_running) echo "[$TS] STATUS: running" >> "$LOG" ;;
    *) echo "[$TS] $TYPE" >> "$LOG" ;;
  esac
done < "$RAW"

# ─── Summary ─────────────────────────────────────────────────────
TOOLS=$(grep -c "^.*TOOL:" "$LOG" 2>/dev/null || echo 0)
MSGS=$(grep -c "^.*LUIGI:" "$LOG" 2>/dev/null || echo 0)
RAW_KB=$(( $(wc -c < "$RAW" | tr -d ' ') / 1024 ))

log ""
log "═══════════════════════════════════════════════"
log "  DEMO COMPLETE"
log "═══════════════════════════════════════════════"
log "  Agent:    Luigi the Linux Plumber ($AGENT_ID)"
log "  Session:  $SESSION_ID"
log "  Messages: $MSGS, Tool calls: $TOOLS"
log "  Raw stream: ${RAW_KB}KB"
log ""
log "  Full event log: $LOG"
log "  Raw stream: $RAW"
log "═══════════════════════════════════════════════"

# Save IDs for cleanup
echo "$AGENT_ID" > "$DIR/agent_id"
echo "$ENV_ID" > "$DIR/env_id"
echo "$SESSION_ID" > "$DIR/session_id"
