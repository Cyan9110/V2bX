#!/bin/sh

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

echo -e "${yellow}正在为 Alpine Linux 执行兼容性修复...${plain}"

# 1. 安装 Alpine 运行 glibc 程序必须的兼容层
echo -e "${green}步骤 1: 安装 glibc 兼容库及必要依赖...${plain}"
apk update
apk add --no-cache \
    gcompat \
    libc6-compat \
    libgcc \
    libstdc++ \
    ca-certificates \
    tzdata \
    curl

# 2. 修正 OpenRC 服务状态
echo -e "${green}步骤 2: 清理 OpenRC 异常状态...${plain}"
if [ -f /etc/init.d/V2bX ]; then
    # zap 命令用于强行将状态从 crashed 重置为 stopped
    rc-service V2bX zap >/dev/null 2>&1
    rc-service V2bX stop >/dev/null 2>&1
fi

# 3. 检查并修正二进制文件权限
echo -e "${green}步骤 3: 检查文件权限...${plain}"
if [ -f /usr/local/V2bX/V2bX ]; then
    chmod +x /usr/local/V2bX/V2bX
else
    echo -e "${red}错误：未发现 V2bX 二进制文件，请重新运行安装脚本！${plain}"
    exit 1
fi

# 4. 尝试直接启动并捕获输出 (进行冒烟测试)
echo -e "${green}步骤 4: 进行启动测试...${plain}"
# 尝试运行 2 秒看是否崩溃
timeout 2s /usr/local/V2bX/V2bX server -c /etc/V2bX/config.json > /tmp/v2bx_test.log 2>&1

if [ $? -eq 124 ]; then
    echo -e "${green}测试成功：程序可以正常运行。${plain}"
else
    echo -e "${red}测试失败：程序依然无法直接启动。${plain}"
    echo -e "${yellow}错误日志摘要：${plain}"
    cat /tmp/v2bx_test.log
    exit 1
fi

# 5. 重新启动服务
echo -e "${green}步骤 5: 启动 V2bX 服务...${plain}"
rc-service V2bX start

if [ $? -eq 0 ]; then
    echo -e "${green}修复完成！V2bX 应该已经正常在线。${plain}"
    rc-service V2bX status
else
    echo -e "${red}启动失败，请检查配置或输入 V2bX log 查看原因。${plain}"
fi
