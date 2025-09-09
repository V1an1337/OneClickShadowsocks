#!/usr/bin/env python3
# Minimal Clash subscription server (standard library only)
# Listens on 0.0.0.0:10342 and renders a Clash YAML from query parameters.

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import sys

HOST = "0.0.0.0"
PORT = 11356  # 你会把 clash.v1an.xyz 反代到这里

# 固定部分（可按需修改）
BASE_CFG = {
    "port": 7890,
    "socks-port": 7891,
    "allow-lan": True,
    "mode": "global",
    "log-level": "info",
    "external-controller": ":9090",
}

def to_bool(v):
    if isinstance(v, bool):
        return v
    return str(v).lower() in ("1", "true", "yes", "on")

def yaml_bool(v):
    return "true" if to_bool(v) else "false"

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
        ss_type  = (qs.get("type") or ["ss"])[0].strip()  # 默认 ss
        cipher   = (qs.get("cipher") or [""])[0].strip()
        password = (qs.get("password") or [""])[0].strip()

        # 基本校验
        if not ip:
            return self._bad("missing ip")
        if not port.isdigit():
            return self._bad("port must be integer")
        if not cipher:
            return self._bad("missing cipher")
        if not password:
            return self._bad("missing password")

        # 生成 YAML（简单手拼，避免额外依赖）
        # BASE_CFG 为固定部分；proxies 使用入参
        yaml_lines = []
        yaml_lines.append(f"port: {BASE_CFG['port']}")
        yaml_lines.append(f"socks-port: {BASE_CFG['socks-port']}")
        yaml_lines.append(f"allow-lan: {yaml_bool(BASE_CFG['allow-lan'])}")
        yaml_lines.append(f"mode: {BASE_CFG['mode']}")
        yaml_lines.append(f"log-level: {BASE_CFG['log-level']}")
        yaml_lines.append(f"external-controller: {BASE_CFG['external-controller']}")
        yaml_lines.append("proxies:")
        yaml_lines.append(f"  - {{name: proxy, server: {ip}, port: {port}, type: {ss_type}, cipher: {cipher}, password: {password}}}")
        yaml_text = "\n".join(yaml_lines) + "\n"

        self._ok(yaml_text)

    def log_message(self, fmt, *args):
        # 简单控制台日志
        sys.stderr.write("[clash-server] %s - %s\n" % (self.address_string(), fmt % args))

if __name__ == "__main__":
    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"Clash subscription server listening on http://{HOST}:{PORT}")
    httpd.serve_forever()
