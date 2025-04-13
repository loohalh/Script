#!/bin/bash

# 一键安装 frp 服务端/客户端
# 服务端面板端口默认为 6065


set -e

REMOTE_BIND_IP=""
REMOTE_BIND_PORT=""

SSH_LOCAL_SSH_PORT=22  # 客户端默认 ssh 端口
SSH_REMOTE_PORT=""

# 必要设置
if [[ -z "$REMOTE_BIND_IP" ]]; then
  echo "❌ 错误：REMOTE_BIND_IP 未设置，请设置服务端 IP。"
  exit 1
fi

if [[ -z "$REMOTE_BIND_PORT" ]]; then
  echo "❌ 错误：REMOTE_BIND_PORT 未设置，请设置服务端端口。"
  exit 1
fi

if [[ -z "$SSH_REMOTE_PORT" ]]; then
  echo "❌ 错误：SSH_REMOTE_PORT 未设置，请设置 SSH 穿透后远程端口。"
  exit 1
fi


# 默认版本
FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep tag_name | cut -d '"' -f 4)
ARCH="amd64"
INSTALL_DIR="/usr/local/frp"
SERVICE_NAME=""
BINARY_NAME=""
CONF_FILE=""



# 颜色输出函数
info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# 选择安装类型
echo "👉 你要安装 FRP 的哪种模式？"
echo "1) frps（服务端 - 运行在公网服务器）"
echo "2) frpc（客户端 - 运行在内网机器）"
read -p "请输入选项 [1/2]: " choice

if [[ "$choice" == "1" ]]; then
  MODE="frps"
  SERVICE_NAME="frps"
  BINARY_NAME="frps"
  CONF_FILE="frps.ini"
elif [[ "$choice" == "2" ]]; then
  MODE="frpc"
  SERVICE_NAME="frpc"
  BINARY_NAME="frpc"
  CONF_FILE="frpc.ini"
else
  error "无效选项！退出"
  exit 1
fi

info "✨ 安装 FRP [$MODE] 最新版本：$FRP_VERSION"

# 下载 FRP
cd /tmp
FRP_FILE="frp_${FRP_VERSION#v}_linux_${ARCH}.tar.gz"
wget -q --show-progress https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/${FRP_FILE}
tar -xzf $FRP_FILE
rm -f $FRP_FILE
cd frp_${FRP_VERSION#v}_linux_${ARCH}

# 安装目录
sudo mkdir -p $INSTALL_DIR
sudo cp ${BINARY_NAME} $INSTALL_DIR

cd /root
rm -rf frp_${FRP_VERSION#v}_linux_${ARCH}

# 配置文件
if [ "$MODE" == "frps" ]; then
  sudo tee $INSTALL_DIR/frps.ini > /dev/null <<EOF
[common]
bind_port = ${REMOTE_BIND_PORT}
dashboard_port = 6050
dashboard_user = admin
dashboard_pwd = admin
EOF
else
  sudo tee $INSTALL_DIR/frpc.ini > /dev/null <<EOF
[common]
server_addr = ${REMOTE_BIND_IP}
server_port = ${REMOTE_BIND_PORT}

[ssh]
type = tcp
local_port = ${SSH_LOCAL_SSH_PORT}
remote_port = ${SSH_REMOTE_PORT}
EOF
fi

# 设置 systemd 服务
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=FRP ${MODE^^} Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BINARY_NAME} -c ${INSTALL_DIR}/${CONF_FILE}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

if [ "$MODE" == "frps" ]; then
info "服务端面板地址：$REMOTE_BIND_IP:6065"
fi

info "🎉 FRP [$MODE] 安装完成并已启动"
info "👉 配置文件位置：$INSTALL_DIR/$CONF_FILE"
info "👉 修改配置后使用：sudo systemctl restart $SERVICE_NAME"

