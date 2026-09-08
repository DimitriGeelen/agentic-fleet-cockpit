#!/usr/bin/env bash
# smoke.sh — post-deploy smoke test for the Agentic Fleet Cockpit (T-007).
#
# Read-only: verifies the running service, the API surface, the loopback-only
# bind, and that installed artifacts match this repo. Does NOT start/stop any
# fleet session. Run after scripts/install.sh + systemctl restart.
#
# Exit 0 = all checks pass; non-zero = first failing check named on stderr.
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PORT=8090
BASE="http://127.0.0.1:${PORT}"
fails=0

check() { # check <name> <cmd...>
  local name="$1"; shift
  if "$@" > /dev/null 2>&1; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name" >&2
    fails=$((fails + 1))
  fi
}

check "systemd unit active"        systemctl is-active --quiet agentic-fleet-cockpit
check "UI serves at /"             curl -sf "$BASE/"
check "legacy /claude path serves" curl -sf "$BASE/claude"
check "fleet API returns JSON"     sh -c "curl -sf '$BASE/api/claude/fleet' | python3 -c 'import json,sys; json.load(sys.stdin)'"
check "bind is loopback-only"      sh -c "ss -tln | grep -q '127.0.0.1:$PORT' && ! ss -tln | grep -qE '(0.0.0.0|\\[::\\]):$PORT '"
check "fleet.json is valid JSON"   python3 -c "import json; json.load(open('$HERE/fleet.json'))"
check "installed unit matches repo" diff -q /etc/systemd/system/agentic-fleet-cockpit.service "$HERE/agentic-fleet-cockpit.service"
check "installed cs matches repo"  diff -q /usr/local/bin/cs "$HERE/scripts/cs"
check "server source compiles"     python3 -m py_compile "$HERE/cockpit-server.py"

if [ "$fails" -gt 0 ]; then
  echo "smoke: $fails check(s) FAILED" >&2
  exit 1
fi
echo "smoke: all checks passed"
