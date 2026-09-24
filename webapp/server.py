#!/usr/bin/env python3
"""Local-only web control plane for the course simulation workspace."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "webapp"
RUNS = WEB / "runs"
PYTHON = str(ROOT / ".conda" / "bin" / "python") if (ROOT / ".conda" / "bin" / "python").exists() else sys.executable
ENV = {**os.environ, "PATH": f"{ROOT / '.conda' / 'bin'}:{os.environ.get('PATH', '')}"}


def run_command(args: list[str], timeout: int = 120) -> dict:
    started = time.time()
    try:
        proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout, env=ENV)
        return {"ok": proc.returncode == 0, "code": proc.returncode, "stdout": proc.stdout[-12000:], "stderr": proc.stderr[-6000:], "seconds": round(time.time() - started, 2)}
    except subprocess.TimeoutExpired as exc:
        return {"ok": False, "code": 124, "stdout": (exc.stdout or "")[-12000:], "stderr": "Timed out", "seconds": round(time.time() - started, 2)}


class Handler(BaseHTTPRequestHandler):
    def _json(self, status: int, value: dict):
        body = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/health":
            self._json(200, {"ok": True, "python": PYTHON, "root": str(ROOT)})
            return
        if path.startswith("/api/runs/"):
            relative = Path(path.removeprefix("/api/runs/"))
            target = (RUNS / relative).resolve()
            if RUNS.resolve() not in target.parents:
                self._json(403, {"error": "invalid run path"})
                return
            if target.is_file() and target.suffix == ".json":
                self._json(200, json.loads(target.read_text()))
                return
            if target.is_file():
                body = target.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Disposition", f'attachment; filename="{target.name}"')
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self._json(404, {"error": "run file not found"})
            return
        rel = "index.html" if path in ("/", "") else path.removeprefix("/")
        target = WEB / rel
        resolved = target.resolve()
        if target.is_file() and (WEB in resolved.parents or ROOT in resolved.parents):
            content_type = {".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".tex": "text/plain", ".sv": "text/plain", ".py": "text/plain"}.get(target.suffix, "application/octet-stream")
            body = target.read_bytes()
            self.send_response(200); self.send_header("Content-Type", content_type); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            data = self._body()
        except (ValueError, json.JSONDecodeError):
            self._json(400, {"ok": False, "error": "request body must be valid JSON"})
            return
        if path == "/api/python-sim":
            try:
                dimensions = {key: int(data.get(key, default)) for key, default in (("height", 8), ("width", 8), ("channels", 4), ("outputs", 4))}
            except (TypeError, ValueError):
                self._json(400, {"ok": False, "error": "卷积尺寸必须是整数"})
                return
            if any(value < 1 for value in dimensions.values()):
                self._json(400, {"ok": False, "error": "卷积尺寸必须大于 0"})
                return
            run_dir = RUNS / f"python-{int(time.time())}"
            run_dir.mkdir(parents=True, exist_ok=True)
            args = [PYTHON, "-m", "assignment1_fpga.sim.generate_golden", "--height", str(dimensions["height"]), "--width", str(dimensions["width"]), "--channels", str(dimensions["channels"]), "--outputs", str(dimensions["outputs"]), "--out", str(run_dir)]
            result = run_command(args)
            result.update({"kind": "python", "run": run_dir.name, "files": [{"name": p.name, "url": f"/api/runs/{run_dir.name}/{p.name}"} for p in sorted(run_dir.iterdir())]})
            (run_dir.with_suffix(".json")).write_text(json.dumps(result, ensure_ascii=False, indent=2))
            self._json(200, result); return
        if path == "/api/rtl-sim":
            mode = "course" if data.get("mode") == "course" else "small"
            result = run_command(["bash", "scripts/run_rtl_sim.sh", mode], timeout=300 if mode == "course" else 120)
            result.update({"kind": "rtl", "mode": mode})
            self._json(200, result); return
        if path == "/api/board-config":
            config = {"host": str(data.get("host", "192.168.2.99")), "overlay": str(data.get("overlay", "conv2d.bit")), "protocol": "PYNQ Overlay + AXI DMA", "tensor_layout": "NHWC/HWIO", "precision": "int8 input/weight/output, int32 accumulation"}
            target = RUNS / "board_config.json"; target.write_text(json.dumps(config, ensure_ascii=False, indent=2))
            self._json(200, {"ok": True, "config": config, "path": str(target.relative_to(ROOT))}); return
        self._json(404, {"error": "unknown endpoint"})

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8765"))
    print(f"AI Chip Design Lab: http://127.0.0.1:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
