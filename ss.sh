#!/usr/bin/env bash
# Setup Shadowsocks-libev with random port/password + firewall open + IP/subscribe URL
# Usage: bash ss.sh

set -e

log() { echo "[$(date '+%F %T')] $*"; }

# -------- 生成随机端口和密码 --------
# 端口范围：10000~60000
SERVER_PORT="$(shuf -i 10000-60000 -n 1)"
# 8位字母+数字密码
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 8 || true)"
[ -n "$PASSWORD" ] || PASSWORD="Pass$(date +%s | tail -c 8)"

TYPE="ss"
CIPHER="chacha20-ietf-poly1305"

log "Selected random server_port: ${SERVER_PORT}"
log "Generated random password: ${PASSWORD}"

# -------- 安装 shadowsocks-libev --------
log "Updating package lists..."
sudo apt update -y

log "Installing shadowsocks-libev..."
sudo apt install -y shadowsocks-libev curl

# -------- 写配置 --------
log "Writing config to /etc/shadowsocks-libev/config.json ..."
sudo install -d -m 0755 /etc/shadowsocks-libev
sudo tee /etc/shadowsocks-libev/config.json >/dev/null <<JSON
{
    "server": ["0.0.0.0"],
    "server_port": ${SERVER_PORT},
    "mode": "tcp_and_udp",
    "local_port": 1080,
    "password": "${PASSWORD}",
    "timeout": 60,
    "method": "${CIPHER}",
    "ipv6_first": false
}
JSON

# -------- 开放防火墙端口（TCP/UDP）--------
open_firewall() {
  local p="$1"
  log "Opening firewall for port ${p}/tcp and ${p}/udp (best-effort)..."

  # 先尝试 ufw（Ubuntu 常见）
  if command -v ufw >/dev/null 2>&1; then
    # 只在 UFW 已启用时添加规则，避免误开启影响现有策略
    if sudo ufw status | grep -qi "Status: active"; then
      sudo ufw allow "${p}/tcp" >/dev/null 2>&1 || true
      sudo ufw allow "${p}/udp" >/dev/null 2>&1 || true
      log "UFW rules added for ${p}."
      return 0
    else
      log "UFW installed but not active; skipping enabling to avoid policy changes."
    fi
  fi

  # 尝试 iptables（legacy）
  if command -v iptables >/dev/null 2>&1; then
    sudo iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || sudo iptables -I INPUT -p tcp --dport "$p" -j ACCEPT || true
    sudo iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || sudo iptables -I INPUT -p udp --dport "$p" -j ACCEPT || true
    # 尝试持久化（如果有 iptables-save）
    if command -v netfilter-persistent >/dev/null 2>&1; then
      sudo netfilter-persistent save || true
    elif command -v iptables-save >/dev/null 2>&1; then
      sudo sh -c 'iptables-save > /etc/iptables/rules.v4' 2>/dev/null || true
    fi
    log "iptables rules added for ${p}."
    return 0
  fi

  # 尝试 nftables（更现代）
  if command -v nft >/dev/null 2>&1; then
    # 建基础表/链（若不存在）
    sudo nft list table inet filter >/dev/null 2>&1 || sudo nft add table inet filter || true
    sudo nft list chain inet filter input >/dev/null 2>&1 || sudo nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }' || true
    # 添加规则（幂等）
    sudo nft add rule inet filter input tcp dport "$p" accept 2>/dev/null || true
    sudo nft add rule inet filter input udp dport "$p" accept 2>/dev/null || true
    # 持久化（若系统支持）
    if [ -d /etc/nftables.d ] || [ -f /etc/nftables.conf ]; then
      sudo sh -c 'nft list ruleset > /etc/nftables.conf' 2>/dev/null || true
    fi
    log "nftables rules added for ${p}."
    return 0
  fi

  log "No known firewall tool handled; ensure port ${p} is reachable in your environment."
}

open_firewall "${SERVER_PORT}"

# -------- 重启服务 --------
log "Restarting shadowsocks-libev service..."
sudo systemctl restart shadowsocks-libev

# -------- 启用/应用 BBR --------
log "Appending BBR settings to /etc/sysctl.conf ..."
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf >/dev/null
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf >/dev/null

log "Applying sysctl settings..."
sudo sysctl -p || true

# -------- 打印公网 IP，生成订阅链接并尝试请求 --------
log "Detecting public IP..."
PUB_IP="$(curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me || true)"
if [ -z "$PUB_IP" ]; then
  PUB_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
log "Public IP: ${PUB_IP}"

SUB_URL="http://clash.v1an.xyz?ip=${PUB_IP}&port=${SERVER_PORT}&type=${TYPE}&cipher=${CIPHER}&password=${PASSWORD}"
log "Clash subscription URL:"
echo "${SUB_URL}"

log "Trying to request the subscription URL (may fail if reverse proxy/service isn't ready yet)..."
curl -fsSL "${SUB_URL}" -o clash.yaml && log "Downloaded to ./clash.yaml" || log "Request failed (service may not be ready)."

# -------- 最终输出 --------
echo
log "==== SUMMARY ===="
echo "Public IP      : ${PUB_IP}"
echo "Server Port    : ${SERVER_PORT}"
echo "Password       : ${PASSWORD}"
echo "Cipher         : ${CIPHER}"
echo "Subscribe URL  : ${SUB_URL}"
log "All done."
