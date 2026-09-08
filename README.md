# Agentic Fleet Cockpit

Standalone control panel for the Claude Code tmux fleet: a localhost web UI to
enable, start, stop and attach to `claude-fw` sessions running in detached
root tmux sessions, one per `/opt` project.

Extracted from fan-dashboard (its former "Claude Sessions" tab, T-089/T-090/
T-091) by the T-043 dispatch / T-092 so the fleet system can evolve
independently of fan control.

## Pieces

| File | Role |
|------|------|
| `cockpit-server.py` | stdlib-only HTTP server: UI at `/`, `/api/claude/*` endpoints. Binds `127.0.0.1:8090`; fleet API refuses to serve off-loopback (no auth exists). |
| `index.html` | The cockpit UI (single file, inline JS/CSS). |
| `fleet.json` | Persisted per-project fleet config (the human's saved selection). Written atomically (tmp + `os.replace`). |
| `scripts/claude-fleet-start.sh` | Boot starter. Spawns `fleet-<dirname>` tmux sessions on the ROOT tmux server running `claude-fw -c` with a fresh-session fallback. Encodes the T-041 spike constraints (sanitized `env -i`, never pipe claude's stdout, idempotent, `tmux server-access -a dimitri-mint-dev`). |
| `scripts/claude-fleet-attach.sh` | XFCE login helper (runs as the desktop user): opens a terminal window per running, unattached fleet session. |
| `scripts/claude-fleet-attach.desktop` | Autostart entry source; installed/healed to `~dimitri-mint-dev/.config/autostart/` by the starter on every boot. |
| `scripts/cs` | CLI helper (installed at `/usr/local/bin/cs`): list/attach fleet sessions. |
| `agentic-fleet-cockpit.service` | systemd unit source: runs the server and owns the boot fleet spawn (`ExecStartPost` starter). |
| `scripts/install.sh` | Copy-on-change installer for the unit + `cs` (T-603 Option F pattern). |

## Run

```
sudo systemctl status agentic-fleet-cockpit    # normally running, enabled at boot
xdg-open http://localhost:8090/
```

After changing the unit, server, or `cs`:
`sudo /opt/055-agentic-fleet-cockpit/scripts/install.sh && sudo systemctl restart agentic-fleet-cockpit`.

fan-dashboard (`http://localhost:8087/`) links here from its nav; `GET /claude`
on 8087 301-redirects here for old bookmarks.
