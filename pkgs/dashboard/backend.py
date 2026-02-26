import json
import os
import pwd
import re
import subprocess
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HOST = os.environ.get("DASHBOARD_BACKEND_HOST", "127.0.0.1")
PORT = int(os.environ.get("DASHBOARD_BACKEND_PORT", "9401"))


def safe_read(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except Exception:
        return "-"


def proc_detail(pid):
    proc_dir = f"/proc/{pid}"
    if not os.path.isdir(proc_dir):
        return None

    detail = {
        "pid": str(pid),
        "cwd": "-",
        "exe": "-",
        "cmdline": "-",
        "ppid": "-",
        "user": "-",
        "elapsed": "-",
        "startedAt": "-",
        "otherListeningPorts": [],
    }

    try:
        detail["cwd"] = os.path.realpath(f"{proc_dir}/cwd")
    except Exception:
        pass
    try:
        detail["exe"] = os.path.realpath(f"{proc_dir}/exe")
    except Exception:
        pass

    raw_cmdline = safe_read(f"{proc_dir}/cmdline")
    if raw_cmdline != "-":
        detail["cmdline"] = raw_cmdline.replace("\x00", " ").strip() or "-"

    status_text = safe_read(f"{proc_dir}/status")
    if status_text != "-":
        for line in status_text.splitlines():
            if line.startswith("PPid:"):
                detail["ppid"] = line.split(":", 1)[1].strip()
            if line.startswith("Uid:"):
                uid = line.split(":", 1)[1].strip().split()[0]
                try:
                    detail["user"] = pwd.getpwuid(int(uid)).pw_name
                except Exception:
                    detail["user"] = uid

    try:
        ps_out = subprocess.check_output(
            ["ps", "-o", "lstart=,etime=", "-p", str(pid)],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if ps_out:
            match = re.match(r"^(.*[0-9]{4})\s+([0-9:-]+)$", ps_out)
            if match:
                detail["startedAt"] = match.group(1).strip()
                detail["elapsed"] = match.group(2).strip()
    except Exception:
        pass

    try:
        ss_out = subprocess.check_output(
            ["ss", "-lntupH"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        ports = []
        pid_token = f"pid={pid},"
        for line in ss_out.splitlines():
            if pid_token not in line:
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            local = parts[4]
            ports.append(local.split(":")[-1])
        detail["otherListeningPorts"] = sorted(
            list(set(ports)), key=lambda x: int(x) if x.isdigit() else x
        )
    except Exception:
        pass

    return detail


def ports_snapshot():
    snapshot = {
        "updatedAt": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "ports": [],
    }
    try:
        ss_out = subprocess.check_output(
            ["ss", "-lntupH"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return snapshot

    for line in ss_out.splitlines():
        parts = line.split()
        if len(parts) < 6:
            continue

        proto = parts[0]
        local = parts[4]
        users = line.split("users:", 1)[1] if "users:" in line else ""
        process_match = re.search(r'"([^"]+)"', users)
        pid_match = re.search(r"pid=(\d+)", users)

        addr = local.rsplit(":", 1)[0]
        port = local.rsplit(":", 1)[-1]
        ip_version = "ipv4" if "." in addr else "ipv6"
        process = process_match.group(1) if process_match else "-"
        pid = pid_match.group(1) if pid_match else "-"
        cwd = "-"

        if pid.isdigit():
            try:
                cwd = os.path.realpath(f"/proc/{pid}/cwd")
            except Exception:
                pass

        snapshot["ports"].append(
            {
                "proto": proto,
                "ipVersion": ip_version,
                "address": addr,
                "port": port,
                "process": process,
                "pid": pid,
                "cwd": cwd,
            }
        )

    return snapshot


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/data/ports.json":
            self._write_json(200, ports_snapshot())
            return

        if not path.startswith("/process/"):
            self._write_json(404, {"error": "not found", "path": path})
            return

        pid = path.rsplit("/", 1)[-1]
        if not pid.isdigit():
            self._write_json(400, {"error": "invalid pid"})
            return

        detail = proc_detail(pid)
        if detail is None:
            self._write_json(404, {"error": "process not found"})
            return
        self._write_json(200, detail)

    def log_message(self, _fmt, *_args):
        return


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
