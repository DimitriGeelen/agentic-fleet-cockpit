#!/bin/bash
# install.sh — install/heal the cockpit's system artifacts (T-092).
#
# Copy-on-change pattern (T-603 Option F): the systemd unit and the cs helper
# are git-tracked here and copied to their system locations only when they
# differ, so the project stays the single source of truth and re-running is
# always safe. The XFCE autostart .desktop entry is installed the same way by
# claude-fleet-start.sh on every boot.
#
# Run as root:  sudo /opt/055-agentic-fleet-cockpit/scripts/install.sh

set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)

changed=0
sync_file() {  # sync_file <src> <dst> <mode>
    if ! cmp -s "$1" "$2" 2>/dev/null; then
        install -m "$3" "$1" "$2"
        echo "installed $2"
        changed=1
    fi
}

sync_file "$HERE/agentic-fleet-cockpit.service" \
          /etc/systemd/system/agentic-fleet-cockpit.service 644
sync_file "$HERE/scripts/cs" /usr/local/bin/cs 755

if [ "$changed" = 1 ]; then
    systemctl daemon-reload
fi
systemctl enable agentic-fleet-cockpit.service >/dev/null 2>&1 || true
echo "ok — enable state: $(systemctl is-enabled agentic-fleet-cockpit)"
