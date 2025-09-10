#!/usr/bin/env python3
# Minimal Clash subscription server (standard library only)
# Listens on 0.0.0.0:11356 and renders a Clash YAML from query parameters.

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import sys

HOST = "0.0.0.0"
PORT = 11356  # 你会把 clash.v1an.xyz 反代到这里

class Handler(BaseHTTPRequestHandler):
    def _ok(self, payload: str):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload.encode("utf-8"))))
        self.end_headers()
        self.wfile.write(payload.encode("utf-8"))

    def _bad(self, msg: str):
        payload = f"bad request: {msg}\n"
        self.send_response(400)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(payload.encode("utf-8"))

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        ip       = (qs.get("ip") or [""])[0].strip()
        port     = (qs.get("port") or [""])[0].strip()
        ss_type  = (qs.get("type") or ["ss"])[0].strip()
        cipher   = (qs.get("cipher") or [""])[0].strip()
        password = (qs.get("password") or [""])[0].strip()

        if not ip:
            return self._bad("missing ip")
        if not port.isdigit():
            return self._bad("port must be integer")
        if not cipher:
            return self._bad("missing cipher")
        if not password:
            return self._bad("missing password")

        # YAML 输出
        yaml_lines = []
        yaml_lines.append("port: 7890")
        yaml_lines.append("socks-port: 7891")
        yaml_lines.append("allow-lan: true")
        yaml_lines.append("mode: rule")
        yaml_lines.append("log-level: info")
        yaml_lines.append("external-controller: :9090")
        yaml_lines.append("proxies:")
        yaml_lines.append(f"  - {{name: proxy, server: {ip}, port: {port}, type: {ss_type}, cipher: {cipher}, password: {password}}}")
        yaml_lines.append("proxy-groups:")
        yaml_lines.append("  - {name: proxyGroup, type: select, proxies: [proxy]}")
        yaml_lines.append("rules:")
        yaml_lines.append("  - 'MATCH,proxyGroup'")
        yaml_text = "\n".join(yaml_lines) + "\n"

        self._ok(yaml_text)

    def log_message(self, fmt, *args):
        sys.stderr.write("[clash-server] %s - %s\n" % (self.address_string(), fmt % args))

if __name__ == "__main__":
    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"Clash subscription server listening on http://{HOST}:{PORT}")
    httpd.serve_forever()
