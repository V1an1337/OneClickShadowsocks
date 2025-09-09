#!/usr/bin/env bash
# Setup Shadowsocks-libev with basic logging + print IP + Clash subscribe URL

set -e
log() { echo "[$(date '+%F %T')] $*"; }

log "Updating package lists..."
sudo apt update -y

log "Installing shadowsocks-libev..."
sudo apt install -y shadowsocks-libev

log "Writing config to /etc/shadowsocks-libev/config.json ..."
sudo install -d -m 0755 /etc/shadowsocks-libev
sudo tee /etc/shadowsocks-libev/config.json >/dev/null <<'JSON'
{
    "server": ["0.0.0.0"],
    "server_port": 10342,
    "mode": "tcp_and_udp",
    "local_port": 1080,
    "password": "V1an1337",
    "timeout": 60,
    "method": "chacha20-ietf-poly1305",
    "ipv6_first": false
}
JSON

log "Restarting shadowsocks-libev service..."
sudo systemctl restart shadowsocks-libev

log "Appending BBR settings to /etc/sysctl.conf ..."
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf >/dev/null
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf >/dev/null

log "Applying sysctl settings..."
sudo sysctl -p

# ---- 新增：打印公网 IP + 生成 Clash 订阅链接，并尝试请求 ----
log "Detecting public IP..."
PUB_IP="$(curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me || true)"
if [ -z "$PUB_IP" ]; then
  # 退而求其次：可能只有内网 IP
  PUB_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
log "Public IP: ${PUB_IP}"

PORT="10342"
TYPE="ss"
CIPHER="chacha20-ietf-poly1305"
PASSWORD="V1an1337"

SUB_URL="http://clash.v1an.xyz?ip=${PUB_IP}&port=${PORT}&type=${TYPE}&cipher=${CIPHER}&password=${PASSWORD}"
log "Clash subscription URL:"
echo "${SUB_URL}"

log "Done."
