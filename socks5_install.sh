#!/bin/bash
#
# Dante SOCKS5 一键安装脚本 (Docker 版)
# 支持: Ubuntu / Debian / CentOS / RHEL
# 镜像: lozyme/sockd
# 仓库: https://github.com/Lozy/danted
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DOCKER_IMAGE="lozyme/sockd"
CONTAINER_NAME="sockd"
CONTAINER_INTERNAL_PORT=2020
DATA_DIR="/opt/socks5"
PASSWD_FILE="${DATA_DIR}/sockd.passwd"
CONFIG_FILE="${DATA_DIR}/sockd.conf"

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
die() { log_error "$1"; exit 1; }

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Dante SOCKS5 Proxy 一键安装 (Docker 版)   ║"
    echo "║   支持: Ubuntu / Debian / CentOS            ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行此脚本"
}

detect_os() {
    OS_TYPE=""
    if [ -s /etc/os-release ]; then
        OS_NAME=$(sed -n 's/PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)
        if echo "${OS_NAME}" | grep -Eiq 'debian|ubuntu'; then
            OS_TYPE="debian"
        elif echo "${OS_NAME}" | grep -Eiq 'centos|rhel|red hat|alma|rocky|fedora|oracle'; then
            OS_TYPE="centos"
        fi
    fi
    [ -n "$OS_TYPE" ] || die "不支持的操作系统，仅支持 Ubuntu/Debian/CentOS"
    log_info "检测到系统: ${OS_NAME}"
}

get_default_ip() {
    ip addr | grep 'inet ' | grep -Ev 'inet 127|inet 192\.168|inet 10\.|inet 172\.' | \
        sed "s/[[:space:]]*inet \([0-9.]*\)\/.*/\1/" | head -n1
}

# ======================== Docker 安装 ========================

install_docker() {
    if command -v docker &>/dev/null; then
        log_info "Docker 已安装: $(docker --version)"
        if ! systemctl is-active --quiet docker 2>/dev/null; then
            systemctl start docker
        fi
        return 0
    fi

    log_info "开始安装 Docker..."

    if command -v apt-get &>/dev/null; then
        # Ubuntu / Debian
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # 检测具体发行版
        local distro
        distro=$(. /etc/os-release && echo "$ID")

        curl -fsSL "https://download.docker.com/linux/${distro}/gpg" | \
            gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
            https://download.docker.com/linux/${distro} $(lsb_release -cs) stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io

    elif command -v yum &>/dev/null; then
        # CentOS / RHEL
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io

    elif command -v dnf &>/dev/null; then
        # Fedora
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io

    else
        die "不支持的包管理器，请手动安装 Docker 后重试"
    fi

    command -v docker &>/dev/null || die "Docker 安装失败，请手动安装后重试"

    systemctl start docker
    systemctl enable docker
    systemctl daemon-reload

    log_info "Docker 安装完成并已设为开机启动"
}

# ======================== 用户配置 ========================

read_user_config() {
    local default_ip
    default_ip=$(get_default_ip)
    [ -z "$default_ip" ] && default_ip=$(ip addr | grep 'inet ' | grep -v '127.0.0' | \
        sed "s/[[:space:]]*inet \([0-9.]*\)\/.*/\1/" | head -n1)

    echo ""
    echo -e "${BOLD}========== 请配置 SOCKS5 代理参数 ==========${NC}"
    echo ""

    read -rp "$(echo -e "${CYAN}[1/4]${NC} 服务器公网 IP [默认: ${default_ip}]: ")" INPUT_IP
    SOCKS_IP="${INPUT_IP:-$default_ip}"

    read -rp "$(echo -e "${CYAN}[2/4]${NC} 监听端口 [默认: 2020]: ")" INPUT_PORT
    SOCKS_PORT="${INPUT_PORT:-2020}"

    read -rp "$(echo -e "${CYAN}[3/4]${NC} 认证用户名 [默认: sockd]: ")" INPUT_USER
    SOCKS_USER="${INPUT_USER:-sockd}"

    while true; do
        read -rp "$(echo -e "${CYAN}[4/4]${NC} 认证密码 (不能为空): ")" INPUT_PASS
        if [ -n "$INPUT_PASS" ]; then
            SOCKS_PASS="$INPUT_PASS"
            break
        fi
        log_warn "密码不能为空，请重新输入"
    done

    echo ""
    echo -e "${BOLD}========== 确认配置信息 ==========${NC}"
    echo -e "  服务器 IP: ${GREEN}${SOCKS_IP}${NC}"
    echo -e "  监听端口:  ${GREEN}${SOCKS_PORT}${NC}"
    echo -e "  用户名:    ${GREEN}${SOCKS_USER}${NC}"
    echo -e "  密码:      ${GREEN}${SOCKS_PASS}${NC}"
    echo ""
    read -rp "确认以上配置开始安装? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_info "已取消安装"
        exit 0
    fi
}

parse_args() {
    for param in "$@"; do
        case "$param" in
            --ip=*)       SOCKS_IP="${param#--ip=}" ;;
            --port=*)     SOCKS_PORT="${param#--port=}" ;;
            --user=*)     SOCKS_USER="${param#--user=}" ;;
            --passwd=*)   SOCKS_PASS="${param#--passwd=}" ;;
            --uninstall)  do_uninstall; exit 0 ;;
            --adduser)    ACTION="adduser" ;;
            --deluser)    ACTION="deluser" ;;
            --showuser)   ACTION="showuser" ;;
            --help|-h)    show_help; exit 0 ;;
        esac
    done
}

show_help() {
    echo "用法: bash $0 [选项]"
    echo ""
    echo "安装:"
    echo "  bash $0                                         交互式安装"
    echo "  bash $0 --ip=IP --port=PORT --user=U --passwd=P 静默安装"
    echo ""
    echo "管理:"
    echo "  bash $0 --adduser --user=NAME --passwd=PASS     添加用户"
    echo "  bash $0 --deluser --user=NAME                   删除用户"
    echo "  bash $0 --showuser                              查看用户列表"
    echo "  bash $0 --uninstall                             卸载"
    echo "  bash $0 --help                                  帮助"
}

# ======================== 用户管理 ========================

do_adduser() {
    local user="$1"
    local pass="$2"
    [ -z "$user" ] || [ -z "$pass" ] && die "用户名和密码不能为空"

    docker exec "${CONTAINER_NAME}" script/pam add "$user" "$pass" || \
        die "添加用户失败"
    log_info "用户 ${user} 添加成功"
}

do_deluser() {
    local user="$1"
    [ -z "$user" ] && die "用户名不能为空"

    docker exec "${CONTAINER_NAME}" script/pam del "$user" || \
        die "删除用户失败"
    log_info "用户 ${user} 删除成功"
}

do_showuser() {
    echo -e "${BOLD}当前 SOCKS5 用户列表:${NC}"
    docker exec "${CONTAINER_NAME}" script/pam show
}

# ======================== 卸载 ========================

do_uninstall() {
    log_info "正在卸载 SOCKS5 服务..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true

    read -rp "是否删除配置和数据目录 ${DATA_DIR}? [y/N]: " DEL_DATA
    if [[ "$DEL_DATA" =~ ^[Yy]$ ]]; then
        rm -rf "${DATA_DIR}"
        log_info "数据目录已删除"
    fi

    read -rp "是否删除 Docker 镜像 ${DOCKER_IMAGE}? [y/N]: " DEL_IMG
    if [[ "$DEL_IMG" =~ ^[Yy]$ ]]; then
        docker rmi "${DOCKER_IMAGE}" 2>/dev/null || true
        log_info "Docker 镜像已删除"
    fi

    log_info "卸载完成"
}

# ======================== 防火墙 ========================

setup_firewall() {
    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="${SOCKS_PORT}"/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        log_info "firewalld 已放行端口 ${SOCKS_PORT}"
    elif command -v ufw &>/dev/null; then
        ufw allow "${SOCKS_PORT}"/tcp 2>/dev/null
        log_info "UFW 已放行端口 ${SOCKS_PORT}"
    fi

    if command -v iptables &>/dev/null; then
        if ! iptables -C INPUT -p tcp --dport "${SOCKS_PORT}" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p tcp --dport "${SOCKS_PORT}" -j ACCEPT 2>/dev/null
            log_info "iptables 已放行端口 ${SOCKS_PORT}"
            if [ -f /etc/sysconfig/iptables ]; then
                service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            fi
        fi
    fi
}

# ======================== 部署 ========================

deploy_container() {
    mkdir -p "${DATA_DIR}"

    # 生成自定义配置文件
    log_info "生成配置文件..."
    cat > "${CONFIG_FILE}" << 'CFGEOF'
internal: 0.0.0.0 port = 2020
external: eth0

method: pam none
clientmethod: none

user.privileged: root
user.notprivileged: nobody

logoutput: stdout

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

client block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    method: pam
    log: connect disconnect
}

block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
CFGEOF

    # 生成空密码文件 (后面通过 docker exec 添加用户)
    touch "${PASSWD_FILE}"

    # 移除旧容器
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true

    # 拉取镜像
    log_info "拉取 Docker 镜像 ${DOCKER_IMAGE}..."
    docker pull "${DOCKER_IMAGE}" || die "拉取镜像失败，请检查网络"

    # 启动容器
    log_info "启动容器..."
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart=always \
        --publish "${SOCKS_PORT}:${CONTAINER_INTERNAL_PORT}" \
        --volume "${PASSWD_FILE}:/home/danted/conf/sockd.passwd" \
        --volume "${CONFIG_FILE}:/home/danted/conf/sockd.conf" \
        "${DOCKER_IMAGE}" || die "启动容器失败"

    sleep 2

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "容器启动成功"
    else
        log_error "容器启动失败，查看日志:"
        docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
        die "容器启动异常"
    fi

    # 添加用户
    log_info "添加认证用户 ${SOCKS_USER}..."
    docker exec "${CONTAINER_NAME}" script/pam add "${SOCKS_USER}" "${SOCKS_PASS}" || \
        die "添加用户失败"

    log_info "部署完成"
}

# ======================== 结果展示 ========================

show_result() {
    local status
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        status="${GREEN}● 运行中${NC}"
    else
        status="${RED}● 未运行${NC}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              SOCKS5 代理服务 安装完成!                      ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}服务状态:${NC}  $status"
    echo -e "  ${BOLD}服务地址:${NC}  ${GREEN}${SOCKS_IP}${NC}"
    echo -e "  ${BOLD}服务端口:${NC}  ${GREEN}${SOCKS_PORT}${NC}"
    echo -e "  ${BOLD}用户名  :${NC}  ${GREEN}${SOCKS_USER}${NC}"
    echo -e "  ${BOLD}密码    :${NC}  ${GREEN}${SOCKS_PASS}${NC}"
    echo -e "  ${BOLD}协议    :${NC}  SOCKS5"
    echo -e "  ${BOLD}开机启动:${NC}  ${GREEN}已启用 (Docker restart=always)${NC}"
    echo ""
    echo -e "  ${BOLD}配置文件:${NC}  ${CONFIG_FILE}"
    echo -e "  ${BOLD}密码文件:${NC}  ${PASSWD_FILE}"
    echo ""
    echo -e "  ${CYAN}${BOLD}服务管理:${NC}"
    echo -e "    启动:   ${YELLOW}docker start ${CONTAINER_NAME}${NC}"
    echo -e "    停止:   ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
    echo -e "    重启:   ${YELLOW}docker restart ${CONTAINER_NAME}${NC}"
    echo -e "    日志:   ${YELLOW}docker logs -f ${CONTAINER_NAME}${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}用户管理:${NC}"
    echo -e "    查看用户:  ${YELLOW}docker exec ${CONTAINER_NAME} script/pam show${NC}"
    echo -e "    添加用户:  ${YELLOW}docker exec ${CONTAINER_NAME} script/pam add 用户名 密码${NC}"
    echo -e "    删除用户:  ${YELLOW}docker exec ${CONTAINER_NAME} script/pam del 用户名${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}测试连接:${NC}"
    echo -e "    ${YELLOW}curl -x socks5h://${SOCKS_USER}:${SOCKS_PASS}@${SOCKS_IP}:${SOCKS_PORT} https://ifconfig.co${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}卸载:${NC}"
    echo -e "    ${YELLOW}bash $0 --uninstall${NC}"
    echo ""
}

# ======================== 主流程 ========================

main() {
    print_banner
    check_root
    detect_os

    parse_args "$@"

    # 用户管理子命令
    case "${ACTION}" in
        adduser)
            [ -z "$SOCKS_USER" ] || [ -z "$SOCKS_PASS" ] && die "请指定 --user= 和 --passwd="
            do_adduser "$SOCKS_USER" "$SOCKS_PASS"
            exit 0 ;;
        deluser)
            [ -z "$SOCKS_USER" ] && die "请指定 --user="
            do_deluser "$SOCKS_USER"
            exit 0 ;;
        showuser)
            do_showuser
            exit 0 ;;
    esac

    # 安装流程
    if [ -z "$SOCKS_PASS" ]; then
        read_user_config
    else
        SOCKS_IP="${SOCKS_IP:-$(get_default_ip)}"
        SOCKS_PORT="${SOCKS_PORT:-2020}"
        SOCKS_USER="${SOCKS_USER:-sockd}"
    fi

    install_docker
    setup_firewall
    deploy_container
    show_result
}

main "$@"
