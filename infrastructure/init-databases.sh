#!/usr/bin/env bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置值
DEFAULT_HOST="localhost"
DEFAULT_PORT="55432"
DEFAULT_USER="postgres"
DEFAULT_PASSWORD="devpassword"

# 从环境变量读取或使用默认值
PGHOST="${PGHOST:-$DEFAULT_HOST}"
PGPORT="${PGPORT:-$DEFAULT_PORT}"
PGUSER="${PGUSER:-$DEFAULT_USER}"
PGPASSWORD="${PGPASSWORD:-$DEFAULT_PASSWORD}"

# 需要创建的数据库列表
DATABASES=("dify" "plugin_daemon" "enterprise" "audit")

# 提示用户输入函数
prompt_input() {
    local prompt_text="$1"
    local default_value="$2"
    local is_password="${3:-false}"
    local result
    
    if [ "$is_password" = "true" ]; then
        if [ -n "$default_value" ]; then
            printf "${CYAN}${prompt_text}${NC} [默认: ${default_value}]: " >&2
            read -s result
            printf "\n" >&2
        else
            printf "${CYAN}${prompt_text}${NC}: " >&2
            read -s result
            printf "\n" >&2
        fi
    else
        if [ -n "$default_value" ]; then
            printf "${CYAN}${prompt_text}${NC} [默认: ${default_value}]: " >&2
            read result
        else
            printf "${CYAN}${prompt_text}${NC}: " >&2
            read result
        fi
    fi
    
    # 如果用户输入为空，使用默认值
    printf "%s\n" "${result:-$default_value}"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PostgreSQL 数据库检查和创建脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}请输入 PostgreSQL 连接信息（可直接回车使用默认值）${NC}"
echo ""

# 交互式输入配置
PGHOST=$(prompt_input "PostgreSQL 主机地址" "$PGHOST")
PGPORT=$(prompt_input "PostgreSQL 端口" "$PGPORT")
PGUSER=$(prompt_input "PostgreSQL 用户名" "$PGUSER")
PGPASSWORD=$(prompt_input "PostgreSQL 密码" "$PGPASSWORD" "true")

# 导出密码环境变量（psql 使用 PGPASSWORD）
export PGPASSWORD

echo ""
echo -e "${BLUE}连接信息:${NC}"
echo -e "  主机: ${PGHOST}"
echo -e "  端口: ${PGPORT}"
echo -e "  用户: ${PGUSER}"
echo ""

# 检查 psql 是否安装
if ! command -v psql &> /dev/null; then
    echo -e "${RED}✗ 错误: 未找到 psql 命令${NC}"
    echo -e "${YELLOW}请安装 PostgreSQL 客户端:${NC}"
    echo -e "  macOS: brew install postgresql"
    echo -e "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo -e "  CentOS/RHEL: sudo yum install postgresql"
    exit 1
fi

# 检查 PostgreSQL 连接
echo -e "${BLUE}➤ 检查 PostgreSQL 连接...${NC}"
if PGPASSWORD="${PGPASSWORD}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL 连接成功${NC}"
else
    echo -e "${RED}✗ 错误: 无法连接到 PostgreSQL${NC}"
    echo -e "${YELLOW}请检查:${NC}"
    echo -e "  1. PostgreSQL 服务是否已启动"
    echo -e "  2. 连接信息是否正确 (host: ${PGHOST}, port: ${PGPORT})"
    echo -e "  3. 用户名和密码是否正确"
    echo -e "  4. 如果从 kind 集群内访问，请使用 'host.docker.internal' 作为主机"
    echo ""
    echo -e "${YELLOW}测试连接命令:${NC}"
    echo -e "  PGPASSWORD=${PGPASSWORD} psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d postgres -c 'SELECT 1;'"
    exit 1
fi

echo ""

# 检查并创建数据库
echo -e "${BLUE}➤ 检查数据库...${NC}"
for db in "${DATABASES[@]}"; do
    echo -n "  检查数据库 '${db}'... "
    
    # 检查数据库是否存在
    DB_EXISTS=$(PGPASSWORD="${PGPASSWORD}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${db}';" 2>/dev/null || echo "")
    
    if [ "${DB_EXISTS}" = "1" ]; then
        echo -e "${GREEN}✓ 已存在${NC}"
    else
        echo -e "${YELLOW}不存在，正在创建...${NC}"
        
        # 创建数据库
        if PGPASSWORD="${PGPASSWORD}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -c "CREATE DATABASE \"${db}\";" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✓ 数据库 '${db}' 创建成功${NC}"
        else
            echo -e "    ${RED}✗ 创建数据库 '${db}' 失败${NC}"
            exit 1
        fi
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 所有数据库检查完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 显示数据库列表
echo -e "${BLUE}当前数据库列表:${NC}"
PGPASSWORD="${PGPASSWORD}" psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d postgres -c "\l" | grep -E "^\s+(dify|plugin_daemon|enterprise|audit|postgres|template)" || true

echo ""
echo -e "${GREEN}可以继续部署 Dify Enterprise Edition 了！${NC}"

