#!/bin/bash
# claude-fleet-start.sh — Claude fleet boot starter (T-089, from T-041 dispatch).
#
# Spawns a detached tmux session on the ROOT tmux server for each enabled
# project in /opt/055-agentic-fleet-cockpit/fleet.json, running `claude-fw -c` (continue)
# with a fresh-session fallback. Invoked by agentic-fleet-cockpit.service at
# boot and by the cockpit UI's Start button (T-090, extracted in T-092).
#
# Usage:
#   claude-fleet-start.sh --boot            start every enabled project
#   claude-fleet-start.sh /opt/NAME [...]   start specific project dir(s),
#                                           regardless of the enabled flag
#
# Spike findings this script encodes (validated in the T-041 inception):
#   (a) NEVER pipe claude's stdout — it breaks interactive mode. The command
#       runs directly in the tmux pane (a pty), no pipes.
#   (b) CLAUDE* env vars leaking in put claude into child-session mode (trust
#       dialogs reappear, -c finds nothing) — hence the `env -i` sanitized
#       environment.
#   (c) `claude-fw -c` exits 1 cleanly when there is no resumable conversation
#       (only background-job transcripts) — the fresh fallback is mandatory.

set -u

FLEET_JSON=/opt/055-agentic-fleet-cockpit/fleet.json
TMUX_BIN=/usr/bin/tmux
DESKTOP_USER=dimitri-mint-dev
# Overridable so tests can inject a mock claude-fw ahead of the real one.
SANE_PATH=${CLAUDE_FLEET_PATH:-/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}

log() { echo "[claude-fleet] $*"; }

# All tmux client calls go through this wrapper with TMUX/TMUX_PANE scrubbed.
# A leaked $TMUX is interpreted by the client as its server socket path — when
# this script once ran with TMUX=/usr/bin/tmux exported, the client's new
# server unlink()ed the tmux BINARY and bound a socket in its place. Never let
# a caller's tmux nesting vars reach these invocations.
tmx() { env -u TMUX -u TMUX_PANE "$TMUX_BIN" "$@"; }

session_name() {  # tmux forbids : and . in names; spaces break -t matching
    echo "fleet-$(basename "$1" | sed 's/[^A-Za-z0-9_-]/_/g')"
}

# project_opts <path> -> "termlink autorestart" as 0/1 0/1 (defaults 0 1)
project_opts() {
    python3 - "$1" <<'EOF'
import json, sys
try:
    cfg = json.load(open("/opt/055-agentic-fleet-cockpit/fleet.json")).get("projects", {})
except Exception:
    cfg = {}
p = cfg.get(sys.argv[1], {})
print(int(bool(p.get("termlink", False))), int(bool(p.get("autorestart", True))))
EOF
}

enabled_projects() {
    python3 - <<'EOF'
import json
try:
    cfg = json.load(open("/opt/055-agentic-fleet-cockpit/fleet.json")).get("projects", {})
except Exception:
    cfg = {}
for path, p in sorted(cfg.items()):
    if isinstance(p, dict) and p.get("enabled"):
        print(path)
EOF
}

start_project() {
    local path="$1"
    if [ ! -d "$path" ]; then
        log "skip $path: not a directory"
        return 1
    fi
    local sess; sess=$(session_name "$path")
    if tmx has-session -t "=$sess" 2>/dev/null; then
        log "skip $path: session $sess already running"
        return 0
    fi

    local termlink autorestart flags=""
    read -r termlink autorestart < <(project_opts "$path")
    [ "$termlink" = "1" ] && flags="$flags --termlink"
    [ "$autorestart" = "1" ] || flags="$flags --no-restart"

    # resume_mode continue-else-fresh: try -c; ONLY exit 1 (no conversation to
    # resume) falls through to a fresh session. Other exits end the session so
    # a real failure stays visible in `tmux ls` absence, not masked by a
    # surprise fresh launch.
    local inner="claude-fw -c$flags; rc=\$?; if [ \$rc -eq 1 ]; then exec claude-fw$flags; fi; exit \$rc"

    tmx new-session -d -s "$sess" -c "$path" \
        env -i HOME=/root USER=root LOGNAME=root TERM=xterm-256color \
        PATH="$SANE_PATH" \
        bash -c "$inner" || { log "FAILED to spawn $sess for $path"; return 1; }
    log "started $sess ($path) flags:${flags:- none}"
}

install_attach_autostart() {
    # T-091 (T-603 copy-on-change pattern): the XFCE autostart entry lives as a
    # git-tracked artifact in scripts/ and is installed/healed here on every
    # boot, so the desktop user's login attach windows survive home-dir drift.
    local src=/opt/055-agentic-fleet-cockpit/scripts/claude-fleet-attach.desktop
    local dst_dir="/home/$DESKTOP_USER/.config/autostart"
    local dst="$dst_dir/claude-fleet-attach.desktop"
    [ -f "$src" ] || return 0
    if ! cmp -s "$src" "$dst" 2>/dev/null; then
        install -o "$DESKTOP_USER" -g "$DESKTOP_USER" -D -m 644 "$src" "$dst" \
            && log "installed autostart entry $dst" \
            || log "WARN: could not install $dst"
    fi
}

grant_desktop_access() {
    # Let the desktop user attach without sudo: tmux-level ACL + group-root
    # traverse on the socket dir ($DESKTOP_USER is in group root). Verified
    # 2026-09-08. If group membership ever changes, fallback is a sudoers rule:
    #   dimitri-mint-dev ALL=(root) NOPASSWD: /usr/bin/tmux
    tmx server-access -a "$DESKTOP_USER" 2>/dev/null || true
    local sockdir
    sockdir=$(dirname "$(tmx display-message -p '#{socket_path}' 2>/dev/null || echo /tmp/tmux-0/default)")
    chmod 750 "$sockdir" 2>/dev/null || true
}

rc=0
install_attach_autostart
if [ "${1:-}" = "--boot" ] || [ $# -eq 0 ]; then
    started_any=0
    while IFS= read -r proj; do
        [ -n "$proj" ] || continue
        start_project "$proj" || rc=1
        started_any=1
    done < <(enabled_projects)
    [ "$started_any" = "0" ] && log "no enabled projects in $FLEET_JSON"
else
    for proj in "$@"; do
        start_project "$proj" || rc=1
    done
fi

# Grant access whenever a server is up (even if all spawns were idempotent skips)
if tmx ls >/dev/null 2>&1; then
    grant_desktop_access
fi
exit $rc
