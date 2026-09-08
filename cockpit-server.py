#!/usr/bin/env python3
"""
Agentic Fleet Cockpit backend (T-092, extracted from fan-dashboard T-089/T-090).

A tiny stdlib-only HTTP server that serves the Claude Sessions fleet UI and the
/api/claude/* control endpoints:
  - lists every /opt project dir with its fleet-<dirname> tmux session state
  - persists per-project fleet config (fleet.json, atomic tmp+os.replace)
  - starts/stops detached Claude sessions on the ROOT tmux server via
    scripts/claude-fleet-start.sh (the T-041 spike constraints live there)

Must run as root (spawns root tmux sessions):
    sudo python3 cockpit-server.py [PORT] [--host HOST]

Security model: there is NO auth. The mutating endpoints spawn/kill root
shells, so the whole fleet API refuses to serve unless the bind address is
loopback. Default bind is 127.0.0.1:8090.

History: built inside fan-dashboard as the "Claude Sessions" tab (T-089/T-090,
from the T-041/T-042 dispatch), extracted to this standalone project by the
T-043 dispatch so it can evolve independently. Payload shapes are unchanged.
"""
import json
import os
import re
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))

# CLI: [PORT] [--host HOST]. Default binds localhost only (security); the
# fleet API disables itself when exposed beyond loopback (no auth exists).
_args = [a for a in sys.argv[1:] if a != ""]
HOST = "127.0.0.1"
if "--host" in _args:
    i = _args.index("--host")
    HOST = _args[i + 1]
    del _args[i:i + 2]
PORT = int(_args[0]) if _args else 8090

# --- Claude fleet (T-089/T-090, from the T-041 dispatch) ---------------------
# Config + control for auto-started Claude sessions in root tmux. The UI lists
# every /opt project dir; enabled ones are booted by scripts/claude-fleet-start.sh
# (via agentic-fleet-cockpit.service ExecStartPost) and controllable here.

FLEET_PATH = os.path.join(HERE, "fleet.json")
FLEET_STARTER = os.path.join(HERE, "scripts", "claude-fleet-start.sh")
FLEET_OPT = "/opt"
FLEET_TMUX = ["env", "-u", "TMUX", "-u", "TMUX_PANE", "/usr/bin/tmux"]
FLEET_RESUME_MODES = ("continue-else-fresh",)
FLEET_DEFAULTS = {"enabled": False, "termlink": False, "autorestart": True,
                  "resume_mode": "continue-else-fresh",
                  "autonomous": False}   # stub — persisted but has no effect yet
FLEET_LOCK = threading.Lock()

def fleet_localhost_only():
    """These endpoints spawn root shells; with no auth they must never be
    reachable off-box. Refuse whenever the bind address is not loopback."""
    return HOST in ("127.0.0.1", "localhost", "::1")

def fleet_session_name(dirname):
    # tmux forbids ':' and '.' in names and spaces break -t matching; must stay
    # in lockstep with session_name() in scripts/claude-fleet-start.sh.
    return "fleet-" + re.sub(r"[^A-Za-z0-9_-]", "_", dirname)

def fleet_load():
    try:
        with open(FLEET_PATH) as f:
            data = json.load(f)
        projects = data.get("projects", {})
        return {"projects": projects if isinstance(projects, dict) else {}}
    except Exception:
        return {"projects": {}}

def fleet_save(cfg):
    tmp = FLEET_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=1)
    os.replace(tmp, FLEET_PATH)

def fleet_valid_project(path):
    """Only direct children of /opt that exist as dirs — everything else is
    refused so a request body can never smuggle an arbitrary path into tmux."""
    if not isinstance(path, str) or path != os.path.normpath(path):
        return False
    head, dirname = os.path.split(path)
    return (head == FLEET_OPT and dirname not in ("", ".", "..")
            and os.path.isdir(path))

def fleet_sanitize_entry(raw):
    if not isinstance(raw, dict):
        raw = {}
    ent = dict(FLEET_DEFAULTS)
    for k in ("enabled", "termlink", "autorestart", "autonomous"):
        if k in raw:
            ent[k] = bool(raw[k])
    if raw.get("resume_mode") in FLEET_RESUME_MODES:
        ent["resume_mode"] = raw["resume_mode"]
    return ent

def fleet_tmux_sessions():
    """session name -> attached client count, from the root tmux server."""
    try:
        out = subprocess.run(
            FLEET_TMUX + ["list-sessions", "-F",
                          "#{session_name}\t#{session_attached}"],
            capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return {}
    sessions = {}
    for line in out.splitlines():
        name, _, attached = line.partition("\t")
        if name:
            try:
                sessions[name] = int(attached or 0)
            except ValueError:
                sessions[name] = 0
    return sessions

def fleet_view():
    cfg = fleet_load()["projects"]
    sessions = fleet_tmux_sessions()
    projects = []
    try:
        entries = sorted(e.name for e in os.scandir(FLEET_OPT)
                         if e.is_dir(follow_symlinks=False)
                         and not e.name.startswith("."))
    except Exception:
        entries = []
    for dirname in entries:
        path = os.path.join(FLEET_OPT, dirname)
        sess = fleet_session_name(dirname)
        projects.append({
            "path": path,
            "dirname": dirname,
            "session": sess,
            "running": sess in sessions,
            "attached": sessions.get(sess, 0) > 0,
            # Desktop user attaches across users, so the root server's socket
            # must be explicit — plain `tmux attach` would hit their own server.
            "attach_cmd": f"tmux -S /tmp/tmux-0/default attach -t {sess}",
            "config": fleet_sanitize_entry(cfg.get(path)),
            "configured": path in cfg,
        })
    return {"projects": projects, "resume_modes": list(FLEET_RESUME_MODES),
            "localhost_only": fleet_localhost_only()}

def fleet_set_config(raw_projects):
    if not isinstance(raw_projects, dict):
        return False, "projects must be an object"
    clean, rejected = {}, []
    for path, ent in raw_projects.items():
        if fleet_valid_project(path):
            clean[path] = fleet_sanitize_entry(ent)
        else:
            rejected.append(path)
    if rejected:
        return False, f"invalid project path(s): {', '.join(sorted(rejected)[:5])}"
    with FLEET_LOCK:
        fleet_save({"projects": clean})
    return True, {"saved": len(clean)}

def fleet_start(path):
    if not fleet_valid_project(path):
        return False, "invalid project path"
    try:
        r = subprocess.run([FLEET_STARTER, path], capture_output=True,
                           text=True, timeout=30)
    except Exception as e:
        return False, f"starter failed: {e}"
    out = (r.stdout + r.stderr).strip()
    if r.returncode != 0:
        return False, out or f"starter exit {r.returncode}"
    sess = fleet_session_name(os.path.basename(path))
    return True, {"session": sess, "log": out,
                  "running": sess in fleet_tmux_sessions()}

def fleet_stop(path):
    if not fleet_valid_project(path):
        return False, "invalid project path"
    sess = fleet_session_name(os.path.basename(path))
    if sess not in fleet_tmux_sessions():
        return False, f"session {sess} not running"
    try:
        # '=' prefix: exact-match only, no prefix matching onto another session
        r = subprocess.run(FLEET_TMUX + ["kill-session", "-t", "=" + sess],
                           capture_output=True, text=True, timeout=10)
    except Exception as e:
        return False, f"tmux kill-session failed: {e}"
    if r.returncode != 0:
        return False, r.stderr.strip() or "kill-session failed"
    return True, {"session": sess, "stopped": True}


class Handler(BaseHTTPRequestHandler):
    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")   # never serve stale status
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass  # quiet

    def do_GET(self):
        # Legacy paths kept so pre-extraction bookmarks deep-linking the
        # fan-dashboard tab keep working after the 8087 redirect lands here.
        if self.path in ("/", "/index.html",
                         "/claude", "/claude-sessions", "/claude-sessions.html"):
            self._serve_file("index.html", "text/html")
            return
        if self.path == "/api/claude/fleet":
            if not fleet_localhost_only():
                self._json({"error": "claude fleet API is localhost-only "
                                     "(server is bound to " + HOST + ")"}, 403)
                return
            self._json(fleet_view())
            return
        self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            data = {}
        if self.path.startswith("/api/claude/"):
            # These spawn/kill root tmux sessions and there is no auth: refuse
            # everything the moment the server is bound beyond loopback.
            if not fleet_localhost_only():
                self._json({"error": "claude fleet API is localhost-only "
                                     "(server is bound to " + HOST + ")"}, 403)
                return
            if self.path == "/api/claude/config":
                ok, res = fleet_set_config(data.get("projects"))
                self._json({"ok": ok, "result": res}, 200 if ok else 400)
                return
            if self.path == "/api/claude/start":
                ok, res = fleet_start(data.get("project"))
                self._json({"ok": ok, "result": res}, 200 if ok else 400)
                return
            if self.path == "/api/claude/stop":
                ok, res = fleet_stop(data.get("project"))
                self._json({"ok": ok, "result": res}, 200 if ok else 400)
                return
        self.send_error(404)

    def _serve_file(self, name, ctype):
        path = os.path.join(HERE, name)
        try:
            with open(path, "rb") as f:
                body = f.read()
        except Exception:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        # The cockpit is one HTML file with inline JS/CSS. Without these, the
        # browser caches the whole app, so an already-open tab keeps running
        # PRE-FIX JS after a deploy+restart — making verified fixes look unfixed.
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")          # legacy proxies/browsers
        self.send_header("Expires", "0")
        self.end_headers()
        self.wfile.write(body)


def main():
    if os.geteuid() != 0:
        print("WARNING: not running as root — tmux fleet control will target "
              "the wrong tmux server and spawns will fail.")
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Agentic Fleet Cockpit on http://{HOST}:{PORT}/  (Ctrl+C to stop)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.shutdown()


if __name__ == "__main__":
    main()
