#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, mimetypes, os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
ASSETS = PROJECT / "TIZEN/project/NX300/image/rootdir/usr/share/edje/di-camera-app-nx300/images"

def version():
    newest = 0
    for root in (HERE / "web", ASSETS):
        for base, _, files in os.walk(root):
            for name in files:
                try: newest = max(newest, (Path(base) / name).stat().st_mtime_ns)
                except FileNotFoundError: pass
    return newest

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/version":
            return self.send_data(json.dumps({"version": version()}).encode(), "application/json")
        if path.startswith("/assets/"):
            target = (ASSETS / unquote(path[8:])).resolve(); root = ASSETS.resolve()
        else:
            target = (HERE / "web" / (path.lstrip("/") or "index.html")).resolve(); root = (HERE / "web").resolve()
        if root not in target.parents or not target.is_file(): return self.send_error(404)
        self.send_data(target.read_bytes(), mimetypes.guess_type(target.name)[0] or "application/octet-stream")
    def send_data(self, data, kind):
        self.send_response(200); self.send_header("Content-Type", kind)
        self.send_header("Cache-Control", "no-store"); self.send_header("Content-Length", str(len(data)))
        self.end_headers(); self.wfile.write(data)
    def log_message(self, fmt, *args):
        if not self.path.startswith("/api/version"): super().log_message(fmt, *args)

def main():
    p=argparse.ArgumentParser(); p.add_argument("--host",default="127.0.0.1"); p.add_argument("--port",type=int,default=8300); a=p.parse_args()
    server=ThreadingHTTPServer((a.host,a.port),Handler); print(f"NX300 UI Lab: http://{a.host}:{a.port}")
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
    return 0
if __name__ == "__main__": raise SystemExit(main())
