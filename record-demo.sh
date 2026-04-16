#!/bin/bash
#
# Record Claude Crew demo video.
# Clean start → create agent + env + session via API → launch app → record navigation
#
set -euo pipefail

API_KEY="${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY}"
APP_PATH="${1:-$HOME/ClaudeCrew.app}"
OUT_DIR="$HOME/claude-crew-demo"
mkdir -p "$OUT_DIR"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

which cliclick >/dev/null 2>&1 || brew install cliclick
which ffmpeg >/dev/null 2>&1 || brew install ffmpeg

log() { echo "[$(date +%H:%M:%S)] $*"; }

# Write window-ID helper
cat > /tmp/get_winid.swift << 'SWIFTEOF'
import CoreGraphics
let w = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
var best: (Int, Int) = (0, 0)
for x in w {
    let owner = x[kCGWindowOwnerName as String] as? String ?? ""
    if owner == "Claude Crew" {
        let wid = x[kCGWindowNumber as String] as? Int ?? 0
        let bounds = x[kCGWindowBounds as String] as? [String: Int] ?? [:]
        let area = (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
        if area > best.1 { best = (wid, area) }
    }
}
if best.0 > 0 { print(best.0) }
SWIFTEOF

get_winid() { swift /tmp/get_winid.swift 2>/dev/null; }
capture() { screencapture -l "$(get_winid)" "$1" 2>/dev/null; }

BASE="https://api.anthropic.com/v1"
H=(-H "x-api-key: $API_KEY" -H "anthropic-version: 2023-06-01" -H "anthropic-beta: managed-agents-2026-04-01" -H "content-type: application/json")

# ─── Create resources ─────────────────────────────────────────────
log "Creating Scout agent..."
AGENT=$(curl -sS --fail-with-body "${BASE}/agents" "${H[@]}" -d '{
  "name": "Scout",
  "model": "claude-sonnet-4-6",
  "system": "You are Scout, a sharp and efficient code reviewer. You explore codebases quickly, identify real issues, and propose clear fixes. Be concise — no fluff.",
  "tools": [{"type": "agent_toolset_20260401"}],
  "description": "Explores repos, triages issues, proposes fixes."
}')
AGENT_ID=$(echo "$AGENT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
log "  Agent: $AGENT_ID"

log "Creating environment..."
ENV=$(curl -sS --fail-with-body "${BASE}/environments" "${H[@]}" -d '{
  "name": "scout-workspace",
  "config": {"type": "cloud", "packages": {"apt": ["git", "build-essential"]}, "networking": {"type": "unrestricted"}}
}')
ENV_ID=$(echo "$ENV" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
log "  Environment: $ENV_ID"

log "Creating session and sending task..."
SESSION=$(curl -sS --fail-with-body "${BASE}/sessions" "${H[@]}" -d "{
  \"agent\": \"$AGENT_ID\",
  \"environment_id\": \"$ENV_ID\",
  \"title\": \"Scout reviews pi-blaster\"
}")
SESSION_ID=$(echo "$SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

curl -sS --fail-with-body "${BASE}/sessions/${SESSION_ID}/events" "${H[@]}" \
  -d '{"events": [{"type": "user.message", "content": [{"type": "text", "text": "Clone https://github.com/sarfata/pi-blaster/ and read the README. Then fetch open issues from https://api.github.com/repos/sarfata/pi-blaster/issues?state=open and pick one you can fix. Implement the fix and show a git diff."}]}]}' > /dev/null
log "  Session: $SESSION_ID — Scout is working!"

echo "$AGENT_ID" > "$OUT_DIR/agent_id"
echo "$ENV_ID" > "$OUT_DIR/env_id"
echo "$SESSION_ID" > "$OUT_DIR/session_id"

# ─── Launch app ───────────────────────────────────────────────────
log "Launching app..."
pkill -f "Claude Crew" 2>/dev/null || true
sleep 1
ANTHROPIC_API_KEY="$API_KEY" open "$APP_PATH"
sleep 5

osascript -e '
tell application "Claude Crew" to activate
delay 0.5
tell application "System Events"
    tell process "Claude Crew"
        set position of window 1 to {200, 100}
        set size of window 1 to {900, 560}
    end tell
end tell
' 2>/dev/null || log "  (resize failed — using default)"
sleep 2

WINID=$(get_winid)
log "Window ID: $WINID"

# Get window position for click coordinates
WPOS=$(swift -e '
import CoreGraphics
let w = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
for x in w {
    if (x[kCGWindowOwnerName as String] as? String ?? "") == "Claude Crew" {
        let b = x[kCGWindowBounds as String] as! [String: Int]
        let area = (b["Width"] ?? 0) * (b["Height"] ?? 0)
        if area > 10000 { print("\(b["X"]!) \(b["Y"]!) \(b["Width"]!) \(b["Height"]!)"); break }
    }
}
' 2>/dev/null)
WX=$(echo $WPOS | cut -d' ' -f1)
WY=$(echo $WPOS | cut -d' ' -f2)
WW=$(echo $WPOS | cut -d' ' -f3)
WH=$(echo $WPOS | cut -d' ' -f4)
log "Window at: ${WX},${WY} ${WW}x${WH}"

# Click offsets relative to window origin
sidebar_x=$((WX + 80))
list_x=$((WX + 200))
# Sidebar rows (relative to window top)
row_sessions=$((WY + 75))
row_agents=$((WY + 107))
row_environments=$((WY + 139))
# First item in content list
first_row=$((WY + 85))

# ─── Start recording ─────────────────────────────────────────────
log "Recording..."
screencapture -v -l "$WINID" "$OUT_DIR/demo-raw.mov" &
REC_PID=$!
sleep 2

# ─── Scene 1: Sessions list with Scout running (4s) ──────────────
log "  Scene 1: Sessions list"
sleep 4

# ─── Scene 2: Click Scout session → event stream (12s) ───────────
log "  Scene 2: Session detail"
cliclick c:$((list_x + 100)),$first_row
sleep 12

# ─── Scene 3: Agents list (3s) ───────────────────────────────────
log "  Scene 3: Agents"
cliclick c:$sidebar_x,$row_agents
sleep 3

# ─── Scene 4: Click Scout agent → detail (5s) ────────────────────
log "  Scene 4: Agent detail"
cliclick c:$((list_x + 100)),$first_row
sleep 5

# ─── Scene 5: Environments (4s) ──────────────────────────────────
log "  Scene 5: Environments"
cliclick c:$sidebar_x,$row_environments
sleep 4

# ─── Scene 6: Back to Sessions → click Scout session (8s) ────────
log "  Scene 6: Back to session"
cliclick c:$sidebar_x,$row_sessions
sleep 2
cliclick c:$((list_x + 100)),$first_row
sleep 6

# ─── Stop recording ──────────────────────────────────────────────
log "Stopping recording..."
kill -INT $REC_PID 2>/dev/null || true
sleep 3

# ─── Speed up 4x → mp4 ──────────────────────────────────────────
log "Converting..."
ffmpeg -y -i "$OUT_DIR/demo-raw.mov" \
  -filter_complex "[0:v]setpts=0.25*PTS[v]" \
  -map "[v]" -an \
  -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart \
  "$OUT_DIR/demo.mp4" 2>/dev/null

DUR=$(ffprobe -v quiet -print_format json -show_format "$OUT_DIR/demo.mp4" | python3 -c "import sys,json; print(f'{float(json.load(sys.stdin)[\"format\"][\"duration\"]):.1f}')")
SIZE=$(ls -lh "$OUT_DIR/demo.mp4" | awk '{print $5}')
log "Done: $OUT_DIR/demo.mp4 (${DUR}s, ${SIZE})"

# ─── Cleanup ─────────────────────────────────────────────────────
log "Cleaning up..."
curl -sS "${BASE}/sessions/${SESSION_ID}/events" "${H[@]}" -d '{"events":[{"type":"user.interrupt"}]}' > /dev/null 2>&1 || true
sleep 3
curl -sS -X POST "${BASE}/sessions/${SESSION_ID}/archive" "${H[@]}" > /dev/null 2>&1 || true
curl -sS -X POST "${BASE}/agents/${AGENT_ID}/archive" "${H[@]}" > /dev/null 2>&1 || true
curl -sS -X POST "${BASE}/environments/${ENV_ID}/archive" "${H[@]}" > /dev/null 2>&1 || true
pkill -f "Claude Crew" 2>/dev/null || true
log "All done!"
