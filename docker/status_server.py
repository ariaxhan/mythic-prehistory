#!/usr/bin/env python3
"""Minimal authenticated status endpoint.

Deliberately small. It answers "is it up, is it ready, who is on, what broke"
without adding a single Minecraft mod and without exposing any control surface:
there is no start, stop, command, or RCON passthrough here. The only unguarded
route is /healthz, which returns a bare literal for Fly's health check and
leaks nothing.

Auth: `Authorization: Bearer <STATUS_TOKEN>` (or `?token=` for convenience in a
browser). Compared in constant time. If STATUS_TOKEN is unset the endpoint
fails CLOSED -- every authenticated route returns 503 rather than opening up.
"""

from __future__ import annotations

import hmac
import json
import os
import re
import socket
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

MC_DIR = os.environ.get("MC_DIR", "/data")
DC_BIN = os.environ.get("DC_BIN", "/opt/mp")
STATE = os.path.join(MC_DIR, ".dc")
BACKUPS = os.path.join(MC_DIR, "backups")
PORT = int(os.environ.get("STATUS_PORT", "8080"))
TOKEN = os.environ.get("STATUS_TOKEN", "")

READY_FLAG = os.path.join(STATE, "ready")
PID_FILE = os.path.join(STATE, "mc.pid")
SHUTDOWN_REASON = os.path.join(STATE, "shutdown-reason")
LAST_BACKUP = os.path.join(STATE, "last-backup")
LAST_FAILURE = os.path.join(STATE, "last-failure")
CRASH_COUNT = os.path.join(STATE, "crash-count")
RCON_PASS = os.path.join(STATE, "rcon.pass")
CONSOLE_LOG = os.path.join(MC_DIR, "logs", "console.log")


def read_text(path: str, default: str = "") -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read().strip()
    except OSError:
        return default


def mc_pid() -> int | None:
    raw = read_text(PID_FILE)
    if not raw.isdigit():
        return None
    pid = int(raw)
    try:
        os.kill(pid, 0)
    except OSError:
        return None
    return pid


def proc_rss_bytes(pid: int) -> int | None:
    for line in read_text(f"/proc/{pid}/status").splitlines():
        if line.startswith("VmRSS:"):
            parts = line.split()
            if len(parts) >= 2 and parts[1].isdigit():
                return int(parts[1]) * 1024
    return None


def machine_memory() -> dict:
    info: dict[str, int] = {}
    for line in read_text("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        value = rest.strip().split(" ")[0]
        if value.isdigit():
            info[key] = int(value) * 1024
    total = info.get("MemTotal", 0)
    available = info.get("MemAvailable", 0)
    return {
        "total_bytes": total,
        "available_bytes": available,
        "used_bytes": total - available if total else 0,
        "used_percent": round((total - available) / total * 100, 1) if total else None,
    }


_cpu_prev: tuple[int, int] | None = None


def cpu_percent() -> float | None:
    """CPU utilisation since the previous call. First call returns None."""
    global _cpu_prev
    first = read_text("/proc/stat").splitlines()[:1]
    if not first:
        return None
    fields = [int(x) for x in first[0].split()[1:] if x.isdigit()]
    if len(fields) < 4:
        return None
    idle = fields[3] + (fields[4] if len(fields) > 4 else 0)
    total = sum(fields)
    prev = _cpu_prev
    _cpu_prev = (idle, total)
    if prev is None:
        return None
    d_idle = idle - prev[0]
    d_total = total - prev[1]
    if d_total <= 0:
        return None
    return round((1 - d_idle / d_total) * 100, 1)


def rcon_list() -> tuple[int | None, list[str]]:
    """Ask the server who is connected. (None, []) means 'could not determine'."""
    password = read_text(RCON_PASS)
    if not password or mc_pid() is None or not os.path.exists(READY_FLAG):
        return None, []
    try:
        result = subprocess.run(
            ["python3", os.path.join(DC_BIN, "rcon.py"),
             "--host", "127.0.0.1",
             "--port", os.environ.get("RCON_PORT", "25575"),
             "list"],
            env={**os.environ, "RCON_PASSWORD": password},
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return None, []
    if result.returncode != 0:
        return None, []
    match = re.search(r"There are (\d+) of a max", result.stdout)
    if not match:
        return None, []
    count = int(match.group(1))
    names_match = re.search(r"players online:\s*(.*)", result.stdout)
    names = []
    if names_match and names_match.group(1).strip():
        names = [n.strip() for n in names_match.group(1).split(",") if n.strip()]
    return count, names


def latest_crash_report() -> dict | None:
    crash_dir = os.path.join(MC_DIR, "crash-reports")
    try:
        entries = [
            os.path.join(crash_dir, name)
            for name in os.listdir(crash_dir)
            if name.startswith("crash-") and name.endswith(".txt")
        ]
    except OSError:
        return None
    if not entries:
        return None
    newest = max(entries, key=lambda p: os.path.getmtime(p))
    with open(newest, "r", encoding="utf-8", errors="replace") as handle:
        head = [next(handle, "") for _ in range(40)]
    return {
        "file": os.path.basename(newest),
        "modified_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(os.path.getmtime(newest))),
        "head": "".join(head).strip(),
    }


def backups_summary() -> dict:
    try:
        archives = sorted(
            (name for name in os.listdir(BACKUPS) if name.endswith(".tar.zst")),
            reverse=True,
        )
    except OSError:
        archives = []
    newest = None
    if archives:
        path = os.path.join(BACKUPS, archives[0])
        newest = {
            "file": archives[0],
            "bytes": os.path.getsize(path),
            "modified_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(os.path.getmtime(path))),
        }
    return {
        "local_count": len(archives),
        "newest": newest,
        "last_backup_utc": read_text(LAST_BACKUP) or None,
        "offsite_configured": bool(os.environ.get("R2_BUCKET")),
    }


def build_status() -> dict:
    pid = mc_pid()
    ready_at = read_text(READY_FLAG)
    count, names = rcon_list()
    reason_raw = read_text(SHUTDOWN_REASON)
    reason = reason_raw.split("\t", 1)[-1] if reason_raw else None

    if pid is None:
        process_state = "stopped"
    elif ready_at:
        process_state = "ready"
    else:
        process_state = "starting"

    failure = {}
    for line in read_text(LAST_FAILURE).splitlines():
        key, _, value = line.partition("=")
        if key:
            failure[key] = value

    return {
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "machine": {
            "state": "running",  # this code only executes on a running machine
            "id": os.environ.get("FLY_MACHINE_ID"),
            "region": os.environ.get("FLY_REGION"),
            "app": os.environ.get("FLY_APP_NAME"),
            "hostname": socket.gethostname(),
            "uptime_seconds": int(float(read_text("/proc/uptime", "0 0").split()[0] or 0)),
        },
        "pack": {
            "name": "Mythic Prehistory",
            "version": read_text(os.path.join(STATE, "pack-version")) or None,
            "minecraft": os.environ.get("MINECRAFT_VERSION", "1.18.2"),
            "forge": os.environ.get("FORGE_VERSION", "40.2.4"),
        },
        "minecraft": {
            "process_state": process_state,
            "ready": bool(ready_at),
            "ready_since_utc": ready_at or None,
            "pid": pid,
            "heap": os.environ.get("MC_HEAP"),
            "jvm_rss_bytes": proc_rss_bytes(pid) if pid else None,
        },
        "players": {
            # null means "could not determine", which is NOT the same as zero.
            "count": count,
            "names": names,
            "max": int(os.environ.get("MAX_PLAYERS", "4")),
        },
        "resources": {
            "cpu_percent": cpu_percent(),
            "memory": machine_memory(),
        },
        "backups": backups_summary(),
        "last_shutdown_reason": reason,
        "crash": {
            "restarts_this_run": int(read_text(CRASH_COUNT, "0") or 0),
            "last_failure": failure or None,
            "latest_report": latest_crash_report(),
        },
    }


def recent_logs(lines: int = 200) -> str:
    try:
        with open(CONSOLE_LOG, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            # Read a bounded tail rather than the whole file.
            window = min(size, 256 * 1024)
            handle.seek(size - window)
            data = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return "(no console log yet)"
    return "\n".join(data.splitlines()[-lines:])


class Handler(BaseHTTPRequestHandler):
    server_version = "dc-status"
    sys_version = ""

    def log_message(self, fmt, *args):  # noqa: A003
        # Log without the token-bearing query string.
        path = urlparse(self.path).path
        print(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} [status] "
              f"{self.address_string()} {self.command} {path} {fmt % args}")

    def _authorised(self) -> bool:
        if not TOKEN:
            return False
        header = self.headers.get("Authorization", "")
        presented = ""
        if header.startswith("Bearer "):
            presented = header[7:].strip()
        if not presented:
            presented = (parse_qs(urlparse(self.path).query).get("token") or [""])[0]
        if not presented:
            return False
        return hmac.compare_digest(presented, TOKEN)

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, code: int, payload: dict) -> None:
        self._send(code, json.dumps(payload, indent=2).encode(), "application/json; charset=utf-8")

    def do_HEAD(self):  # noqa: N802
        self.do_GET()

    def do_GET(self):  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"

        # Unauthenticated liveness only. No state, no data.
        if path in ("/healthz", "/"):
            self._send(200, b"ok\n", "text/plain; charset=utf-8")
            return

        if not TOKEN:
            self._json(503, {"error": "STATUS_TOKEN is not configured; "
                                      "authenticated endpoints are disabled"})
            return

        if not self._authorised():
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Bearer realm="mythic-prehistory"')
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if path == "/status":
            self._json(200, build_status())
            return

        if path == "/logs":
            qs = parse_qs(urlparse(self.path).query)
            try:
                lines = max(1, min(2000, int((qs.get("lines") or ["200"])[0])))
            except ValueError:
                lines = 200
            self._send(200, recent_logs(lines).encode(), "text/plain; charset=utf-8")
            return

        self._json(404, {"error": "not found", "routes": ["/healthz", "/status", "/logs"]})


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.daemon_threads = True
    if not TOKEN:
        print(f"[status] WARNING: STATUS_TOKEN unset -- /status and /logs will refuse all requests")
    print(f"[status] listening on :{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
