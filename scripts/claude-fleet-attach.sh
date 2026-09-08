#!/bin/bash
# claude-fleet-attach.sh — open a terminal window per running Claude fleet
# session at XFCE login (T-091, from the T-041 dispatch).
#
# Runs as the desktop user (dimitri-mint-dev) via
# ~/.config/autostart/claude-fleet-attach.desktop. For each ENABLED project in
# /opt/055-agentic-fleet-cockpit/fleet.json whose fleet-<dirname> session is live on the
# ROOT tmux server and has no attached client, it opens:
#     xfce4-terminal --title "Claude: <dirname>" -e "tmux -S ... attach -t ..."
# Closing a window detaches (plain tmux semantics) — the session keeps running.
#
# Cross-user access to the root server relies on `tmux server-access -a` plus
# group-root traverse on /tmp/tmux-0, both set up by claude-fleet-start.sh.
#
# Usage:
#   claude-fleet-attach.sh            open windows
#   claude-fleet-attach.sh --dry-run  print what would be opened, open nothing

set -u

SOCK=/tmp/tmux-0/default
FLEET_JSON=/opt/055-agentic-fleet-cockpit/fleet.json
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

tmx() { env -u TMUX -u TMUX_PANE tmux -S "$SOCK" "$@"; }

# Root server not up or not accessible: nothing to attach, exit quietly.
sessions=$(tmx list-sessions -F '#{session_name}	#{session_attached}' 2>/dev/null) || exit 0

# enabled dirname<TAB>session pairs, session name sanitized in lockstep with
# claude-fleet-start.sh / fan-server.py fleet_session_name().
pairs=$(python3 - <<'EOF'
import json, os, re
try:
    cfg = json.load(open("/opt/055-agentic-fleet-cockpit/fleet.json")).get("projects", {})
except Exception:
    cfg = {}
for path, p in sorted(cfg.items()):
    if isinstance(p, dict) and p.get("enabled"):
        d = os.path.basename(path)
        print(d + "\t" + "fleet-" + re.sub(r"[^A-Za-z0-9_-]", "_", d))
EOF
)

opened=0
while IFS=$'\t' read -r dirname sess; do
    [ -n "$sess" ] || continue
    attached=$(printf '%s\n' "$sessions" | awk -F'\t' -v s="$sess" '$1==s {print $2}')
    if [ -z "$attached" ]; then
        [ "$DRY" = "1" ] && echo "skip $dirname: session $sess not running"
        continue
    fi
    if [ "$attached" != "0" ]; then
        [ "$DRY" = "1" ] && echo "skip $dirname: $sess already attached ($attached client(s))"
        continue
    fi
    if [ "$DRY" = "1" ]; then
        echo "would open: xfce4-terminal --title \"Claude: $dirname\" -e \"tmux -S $SOCK attach -t $sess\""
        continue
    fi
    xfce4-terminal --title "Claude: $dirname" \
        -e "tmux -S $SOCK attach -t $sess" &
    opened=$((opened + 1))
    sleep 0.3   # give the WM a beat so windows don't stack exactly on top
done <<< "$pairs"

[ "$DRY" = "1" ] || wait
exit 0
