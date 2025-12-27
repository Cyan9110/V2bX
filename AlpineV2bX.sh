#!/bin/bash
# Alpine V2bX Install / Manage Script (No geoip / geosite)

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

V2BX_DIR="/etc/V2bX"
V2BX_BIN="/usr/bin/V2bX"
SERVICE_FILE="/etc/init.d/V2bX"

echo -e "${green}#####################################"
echo -e "######  Alpine V2bX 管理脚本  ######"
echo -e "#####################################${plain}"

echo -e "${yellow}请选择操作:${plain}"
echo -e " 1) 安装 V2bX"
echo -e " 2) 卸载 V2bX"
echo -e " 3) 配置 V2bX"
echo -e " 4) 重启 V2bX"
echo -e " 5) 查看状态"
echo -e "${green}#####################################${plain}"

read -rp "请输入数字: " choice
echo

ensure_env() {
  apk update
  apk add --no-cache curl wget unzip jq openrc bash
}

install_v2bx() {
  echo -e "${green}开始安装 V2bX...${plain}"

  ensure_env
  mkdir -p "$V2BX_DIR"

  arch=$(arch)
  case "$arch" in
    x86_64|amd64) arch="64" ;;
    aarch64|arm64) arch="arm64-v8a" ;;
    s390x) arch="s390x" ;;
    *) arch="64"; echo -e "${yellow}未知架构，使用默认 64${plain}" ;;
  esac

  version=$(curl -Ls https://api.github.com/repos/wyx2685/V2bX/releases/latest \
    | jq -r .tag_name)

  [[ -z "$version" || "$version" == "null" ]] && version="v0.0.1-20240128"

  echo -e "${green}检测到版本：${version}${plain}"

  wget -q -O "$V2BX_DIR/V2bX.zip" \
    "https://github.com/wyx2685/V2bX/releases/download/${version}/V2bX-linux-${arch}.zip"

  unzip -o "$V2BX_DIR/V2bX.zip" -d "$V2BX_DIR"
  chmod +x "$V2BX_DIR/V2bX"
  ln -sf "$V2BX_DIR/V2bX" "$V2BX_BIN"

  cat > "$SERVICE_FILE" <<'EOF'
#!/sbin/openrc-run
depend() { need net; after sshd; after crond; }
command="/usr/bin/V2bX"
command_args="server"
pidfile="/run/V2bX.pid"
start() { ebegin "Starting V2bX"; start-stop-daemon --start --background --make-pidfile --pidfile "$pidfile" --exec $command -- $command_args; eend $?; }
stop() { ebegin "Stopping V2bX"; start-stop-daemon --stop --pidfile "$pidfile"; eend $?; }
restart() { svc_stop; sleep 1; svc_start; }
EOF

  chmod +x "$SERVICE_FILE"
  rc-update add V2bX default

  echo -e "${green}安装完成，可执行“配置 V2bX”继续${plain}"
}

gen_config() {
  echo -e "${yellow}开始生成配置文件…${plain}"

  read -rp "请输入面板地址(含协议): " panel
  read -rp "请输入面板节点ID: " node
  read -rp "请输入面板密钥(Token): " token
  read -rp "是否启用TLS回源?(y/n): " tls_choice

  [[ "$tls_choice" == "y" ]] && tls="true" || tls="false"

  cat > "$V2BX_DIR/config.json" <<EOF
{
  "PanelType": "V2board",
  "ApiConfig": {
    "ApiHost": "$panel",
    "ApiKey": "$token",
    "NodeID": $node,
    "NodeType": "V2ray",
    "Timeout": 30
  },
  "Certificates": [],
  "LogConfig": {
    "Level": "info"
  },
  "ControllerConfig": {
    "EnableTLS": $tls,
    "ForceCloseTLS": false,
    "SpeedLimit": 0,
    "Sniffing": true
  }
}
EOF

  echo -e "${green}配置已写入 ${V2BX_DIR}/config.json${plain}"
  rc-service V2bX restart
}

uninstall_v2bx() {
  echo -e "${red}开始卸载 V2bX...${plain}"
  rc-service V2bX stop || true
  rc-update del V2bX || true
  rm -f "$SERVICE_FILE" "$V2BX_BIN"
  rm -rf "$V2BX_DIR"
  echo -e "${green}卸载完成${plain}"
}

restart_v2bx() {
  rc-service V2bX restart
}

status_v2bx() {
  rc-service V2bX status || true
}

case "$choice" in
  1) install_v2bx; gen_config ;;
  2) uninstall_v2bx ;;
  3) gen_config ;;
  4) restart_v2bx ;;
  5) status_v2bx ;;
  *) echo -e "${red}无效选项${plain}" ;;
esac
