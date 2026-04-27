#!/bin/bash

# Astro 一键安装脚本
# 支持的系统: 主流Linux发行版

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[ASTRO-INSTALL]${NC} $1"
}

# 验证channel参数（纯数字且长度<24字节）
validate_channel_id() {
    local ch="$1"
    if [ -z "$ch" ]; then
        return 1
    fi
    if ! [[ "$ch" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ ${#ch} -ge 24 ]; then
        return 1
    fi
    return 0
}

# 从脚本参数中解析 channel（支持 --channel 123、--channel=123、-c 123、channel=123）
parse_channel_from_args() {
    local ch=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --channel)
                if [ $# -ge 2 ]; then
                    ch="$2"
                    shift 2
                    continue
                else
                    shift
                    continue
                fi
                ;;
            --channel=*)
                ch="${1#--channel=}"
                shift
                continue
                ;;
            -c)
                if [ $# -ge 2 ]; then
                    ch="$2"
                    shift 2
                    continue
                else
                    shift
                    continue
                fi
                ;;
            channel=*)
                ch="${1#channel=}"
                shift
                continue
                ;;
            *)
                shift
                ;;
        esac
    done
    echo "$ch"
}

log_warn() {
    echo -e "${YELLOW}[ASTRO-INSTALL]${NC} $1"
}

log_error() {
    echo -e "${RED}[ASTRO-INSTALL]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "此脚本需要root权限运行，请使用 sudo 执行"
        exit 1
    fi
}

# 检查CPU架构
check_architecture() {
    log_info "检查CPU架构..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            log_info "CPU架构: $ARCH ✓"
            ;;
        *)
            log_error "不支持的CPU架构: $ARCH"
            log_error "此脚本仅支持 x86-64 架构"
            exit 1
            ;;
    esac
}

# 检查操作系统
check_os() {
    log_info "检查操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        log_info "操作系统: $OS $VERSION"
        
        # 检查是否为支持的Linux发行版
        case $ID in
            ubuntu|debian|centos|rhel|fedora|opensuse|sles|amzn)
                log_info "支持的Linux发行版 ✓"
                ;;
            *)
                log_warn "未经测试的Linux发行版: $ID"
                log_warn "脚本将继续运行，但可能遇到问题"
                ;;
        esac
    else
        log_error "无法识别操作系统"
        exit 1
    fi
}

# 检查Docker是否已安装
check_docker() {
    log_info "检查Docker安装状态..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker已安装"
        
        # 检查Docker服务状态
        if systemctl is-active --quiet docker; then
            log_info "Docker服务正在运行 ✓"
        else
            log_info "启动Docker服务..."
            systemctl start docker
            systemctl enable docker
        fi
        
        # 检查Docker权限
        if docker info &> /dev/null; then
            log_info "Docker权限正常 ✓"
        else
            log_error "Docker权限检查失败"
            exit 1
        fi
    else
        log_warn "Docker未安装，开始安装..."
        install_docker
    fi
}

# 安装Docker
install_docker() {
    log_info "开始安装Docker..."
    
    # 更新包管理器
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # 添加Docker官方GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 添加Docker APT仓库
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 安装Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL/Amazon Linux
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
        
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io
        
    else
        log_error "不支持的包管理器，请手动安装Docker"
        exit 1
    fi
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 确保Docker服务开机自启
    systemctl daemon-reload
    
    log_info "Docker安装完成 ✓"
}

# 生成随机字符串（基于 /dev/urandom，加密安全）
generate_random_string() {
    local length=$1
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# 生成Google Authenticator密钥（Base32，基于 /dev/urandom）
generate_2fa_secret() {
    LC_ALL=C tr -dc 'A-Z2-7' </dev/urandom | head -c 32
}

# 生成管理员登录密码（前7位随机字母数字 + 末位 @）
generate_security_code() {
    local prefix
    prefix=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 7)
    echo "${prefix}@"
}

# IP验证函数
validate_ip() {
    local ip=$1
    
    # Check if empty
    if [ -z "$ip" ]; then
        return 1
    fi
    
    # Check basic format: should have exactly 3 dots
    if [ "$(echo "$ip" | tr -cd '.' | wc -c)" -ne 3 ]; then
        return 1
    fi
    
    # Split IP into parts and validate each part
    IFS='.' read -r part1 part2 part3 part4 <<< "$ip"
    
    # Check each part is a number between 0-255
    for part in "$part1" "$part2" "$part3" "$part4"; do
        # Check if part is numeric
        if ! [[ "$part" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        # Check range 0-255
        if [ "$part" -lt 0 ] || [ "$part" -gt 255 ]; then
            return 1
        fi
        # Check no leading zeros (except for "0")
        if [ "${#part}" -gt 1 ] && [ "${part:0:1}" = "0" ]; then
            return 1
        fi
    done
    
    return 0
}

# 可靠的IP获取函数
get_server_ip() {
    # 尝试自动获取公网IP
    auto_ip=$(curl -s https://api.ipify.org || true)
    
    if validate_ip "$auto_ip"; then
        echo "----> [ASTRO-INSTALL] Detected public IP: $auto_ip" > /dev/tty
        
        # 询问是否使用自动获取的IP
        read -p $'\n----> [ASTRO-INSTALL] Use this IP? [Y/n] ' confirm < /dev/tty
        if [[ -z "$confirm" || "$confirm" =~ ^[Yy] ]]; then
            SERVER_IP="$auto_ip"
            return
        fi
    fi
    
    # 手动输入
    while true; do
        echo -e "\n----> [ASTRO-INSTALL] Please enter your server's public IP address" > /dev/tty
        read -p "IP: " SERVER_IP < /dev/tty
        
        if validate_ip "$SERVER_IP"; then
            break
        else
            echo "ERROR: Invalid IP format (e.g. 192.168.1.1)" > /dev/tty
        fi
    done
}

# 安装二维码生成工具
install_qrencode() {
    log_info "安装二维码生成工具..."
    
    if command -v qrencode &> /dev/null; then
        log_info "qrencode已安装 ✓"
        return
    fi
    
    if command -v apt-get &> /dev/null; then
        apt-get install -y qrencode
    elif command -v yum &> /dev/null; then
        yum install -y qrencode
    elif command -v dnf &> /dev/null; then
        dnf install -y qrencode
    else
        log_warn "无法自动安装qrencode，请手动安装以显示二维码"
        return
    fi
    
    log_info "qrencode安装完成 ✓"
}

# 生成并显示二维码
show_2fa_qrcode() {
    local secret=$1
    local ip=$2
    
    # Google Authenticator URI格式
    local uri="otpauth://totp/?secret=${secret}&issuer=Astro"
    
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSI "${uri}"
        echo ""
        log_info "方法一: 请使用Google Authenticator扫描上方二维码"
    else
        log_warn "未安装qrencode，无法显示二维码"
        log_info "请手动添加密钥到Google Authenticator"
    fi
    
    log_info "方法二: 手动输入密钥，步骤："
    echo -e "   1. 打开Google Authenticator应用"
    echo -e "   2. 点击 '+' 按钮"
    echo -e "   3. 选择 '输入提供的密钥'"
    echo -e "   4. 输入密钥: ${GREEN}${secret}${NC}"
    echo -e "   5. 选择 '基于时间' 类型"
    echo -e "   6. 点击 '添加' 完成设置"
    echo ""
}

# 验证重启配置
verify_restart_configuration() {
    log_info "验证重启配置..."
    
    # 检查Docker服务是否启用
    if systemctl is-enabled docker &>/dev/null; then
        log_info "Docker服务已设置为开机自启 ✓"
    else
        log_warn "Docker服务未设置为开机自启，正在修复..."
        systemctl enable docker
    fi
    
    # 检查容器重启策略
    restart_policy=$(docker inspect astro-app --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
    if [ "$restart_policy" = "always" ]; then
        log_info "容器重启策略已设置为 always ✓"
    else
        log_warn "容器重启策略异常: $restart_policy"
    fi
    
    # 验证容器健康检查
    if docker inspect astro-app --format='{{.Config.Healthcheck.Test}}' 2>/dev/null | grep -q "pm2"; then
        log_info "容器健康检查已配置 ✓"
    else
        log_warn "容器健康检查未正确配置"
    fi
    
    # 验证配置文件
    if [ -f "astro-server/.env" ]; then
        log_info "配置文件已创建 ✓"
        log_info "配置文件位置: $(pwd)/astro-server/.env"
    else
        log_warn "配置文件未找到"
    fi
    

    
    # 验证卷映射
    if docker inspect astro-app --format='{{range .Mounts}}{{.Source}}:{{.Destination}}{{end}}' 2>/dev/null | grep -q "astro-server/.env"; then
        log_info "配置文件映射已配置 ✓"
    else
        log_warn "配置文件映射未正确配置"
    fi
    
    # 验证容器启动命令
    if docker inspect astro-app --format='{{.Config.Cmd}}' 2>/dev/null | grep -q "pm2 resurrect"; then
        log_info "容器启动命令已配置PM2恢复 ✓"
    else
        log_warn "容器启动命令未包含PM2恢复逻辑"
    fi
    
    log_info "重启配置验证完成"
}

# 主安装函数
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                ║"
    echo "║                          🚀 Astro 一键安装脚本 🚀                                ║"
    echo "║                                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    log_info "开始安装 Astro..."
    
    # 系统检查
    check_root
    check_architecture
    check_os
    
    # Docker检查和安装
    check_docker
    
    # 安装二维码生成工具
    install_qrencode
    
    # 获取服务器IP
    echo "----> [ASTRO-INSTALL] Starting Astro installation..." > /dev/tty
    get_server_ip
    
    # 解析 channel 参数（优先脚本参数，其次环境变量）
    CHANNEL_ID=""
    _arg_channel="$(parse_channel_from_args "$@" || true)"
    if validate_channel_id "$_arg_channel"; then
        CHANNEL_ID="$_arg_channel"
        log_info "检测到 channel 参数: $CHANNEL_ID"
    elif validate_channel_id "$CHANNEL_ID"; then
        # 已存在且有效的环境变量 CHANNEL_ID
        log_info "检测到环境变量 CHANNEL_ID: $CHANNEL_ID"
    else
        log_info "未检测到有效的 channel 参数，将使用空字符串"
        CHANNEL_ID=""
    fi
    
    # 生成随机配置
    log_info "生成安全配置..."
    
    ADMIN_PREFIX=$(generate_random_string 10)
    ADMIN_2FA_SECRET=$(generate_2fa_secret)
    ADMIN_JWT_SECRET=$(generate_random_string 32)
    ADMIN_SECURITY_CODE=$(generate_security_code)
    
    log_info "配置生成完成 ✓"
    
    # 创建配置目录
    log_info "创建配置目录..."
    mkdir -p astro-server
    
    # 创建.env文件
    log_info "生成配置文件..."
    cat > astro-server/.env << EOF
PORT=8443
ALLOWED_DOMAIN=$SERVER_IP
ADMIN_PREFIX=$ADMIN_PREFIX
ADMIN_SECURITY_CODE=$ADMIN_SECURITY_CODE
ADMIN_2FA_SECRET=$ADMIN_2FA_SECRET
ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET
ADMIN_JWT_EXPIRESIN=240h
CHANNEL_ID=$CHANNEL_ID
EOF
    
    # 设置环境变量
    export PORT=8443
    export ALLOWED_DOMAIN="$SERVER_IP"
    export ADMIN_PREFIX="$ADMIN_PREFIX"
    export ADMIN_SECURITY_CODE="$ADMIN_SECURITY_CODE"
    export ADMIN_2FA_SECRET="$ADMIN_2FA_SECRET"
    export ADMIN_JWT_SECRET="$ADMIN_JWT_SECRET"
    export ADMIN_JWT_EXPIRESIN="240h"
    export CHANNEL_ID="$CHANNEL_ID"
    
    log_info "配置文件已保存到: astro-server/.env"
    
    # 停止并删除旧容器（如果存在）
    log_info "清理旧容器..."
    docker stop astro-app 2>/dev/null || true
    docker rm astro-app 2>/dev/null || true
    
    # 拉取Docker镜像
    log_info "拉取Docker镜像..."
    docker pull astrobtc/astro:latest
    
    # 运行Docker容器
    log_info "启动Astro容器..."
    docker run -d \
        --name astro-app \
        --restart always \
        --health-cmd="pm2 status && pm2 list | grep -q online" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        -p 8443:8443 \
        -v "$(pwd)/astro-server/.env:/home/ubuntu/astro-server/.env" \
        astrobtc/astro:latest \
        bash -c "
            echo '=== 容器启动，恢复PM2进程 ==='
            echo '时间: $(date)'
            
            # 等待5秒确保容器完全启动
            sleep 5
            
            # 恢复PM2进程
            echo '执行 pm2 resurrect...'
            pm2 resurrect
            
            # 等待恢复完成
            sleep 3
            
            # 检查PM2状态
            echo '检查PM2状态...'
            pm2 status
            
            echo '=== PM2恢复完成 ==='
            
            # 保持容器运行
            tail -f /dev/null
        "
    
    # 等待容器启动
    log_info "等待容器启动..."
    sleep 5
    
    # 检查容器状态
    if docker ps | grep -q astro-app; then
        log_info "容器启动成功 ✓"
    else
        log_error "容器启动失败"
        docker logs astro-app
        exit 1
    fi
    
    # 等待PM2进程恢复完成
    log_info "等待PM2进程恢复完成..."
    sleep 10
    
    # 检查pm2状态
    if docker exec astro-app pm2 status &>/dev/null && docker exec astro-app pm2 list | grep -q "online"; then
        log_info "pm2进程启动成功 ✓"
        
        # 显示pm2状态
        echo -e "\n${BLUE}PM2 进程状态:${NC}"
        docker exec astro-app pm2 status
        echo ""
    else
        log_warn "pm2状态检查失败，查看启动日志..."
        echo -e "\n${YELLOW}=== 容器启动日志 ===${NC}"
        docker logs --tail 30 astro-app
        echo ""
    fi
    
    # 验证重启配置
    verify_restart_configuration
    
    # 显示安装完成信息
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                ║${NC}"
    echo -e "${GREEN}║                         🎉 安装完成！🎉                                         ║${NC}"
    echo -e "${GREEN}║                                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}📋 安装信息:${NC}"
    echo -e "   🌐 访问地址: ${GREEN}https://$SERVER_IP:$PORT/$ADMIN_PREFIX${NC}"
    echo -e "   🔑 密  码: ${YELLOW}$ADMIN_SECURITY_CODE${NC}"
    echo -e "   📱 2FA密钥: ${YELLOW}$ADMIN_2FA_SECRET${NC}"
    echo -e "   📁 配置文件: ${GREEN}$(pwd)/astro-server/.env${NC}"
    echo ""

    # 显示二维码
    show_2fa_qrcode "$ADMIN_2FA_SECRET" "$SERVER_IP"
    
    log_info "Astro安装完成！感谢使用！"
}

# 执行主函数
main "$@" 
