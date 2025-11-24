#!/usr/bin/env python3
"""
PostgreSQL 数据库检查和创建脚本
支持从环境变量或命令行参数读取配置
"""

import os
import sys
import subprocess
import argparse
from typing import List, Tuple

# 颜色定义
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color


def print_colored(text: str, color: str = Colors.NC):
    """打印带颜色的文本"""
    print(f"{color}{text}{Colors.NC}")


def check_psql_available() -> bool:
    """检查 psql 是否可用"""
    try:
        subprocess.run(['psql', '--version'], 
                      capture_output=True, 
                      check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def execute_psql(host: str, port: int, user: str, password: str, 
                 database: str, command: str) -> Tuple[bool, str]:
    """
    执行 PostgreSQL 命令
    
    Returns:
        (success, output)
    """
    env = os.environ.copy()
    env['PGPASSWORD'] = password
    
    try:
        result = subprocess.run(
            ['psql', '-h', host, '-p', str(port), '-U', user, '-d', database, '-c', command],
            capture_output=True,
            text=True,
            env=env,
            timeout=10
        )
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "命令执行超时"
    except Exception as e:
        return False, str(e)


def check_database_exists(host: str, port: int, user: str, password: str, 
                         dbname: str) -> bool:
    """检查数据库是否存在"""
    command = f"SELECT 1 FROM pg_database WHERE datname='{dbname}';"
    success, output = execute_psql(host, port, user, password, 'postgres', command)
    
    if not success:
        return False
    
    # 检查输出中是否包含 "1"
    return '1' in output.strip()


def create_database(host: str, port: int, user: str, password: str, 
                   dbname: str) -> Tuple[bool, str]:
    """创建数据库"""
    command = f'CREATE DATABASE "{dbname}";'
    return execute_psql(host, port, user, password, 'postgres', command)


def check_connection(host: str, port: int, user: str, password: str) -> bool:
    """检查 PostgreSQL 连接"""
    success, _ = execute_psql(host, port, user, password, 'postgres', 'SELECT 1;')
    return success


def list_databases(host: str, port: int, user: str, password: str) -> str:
    """列出数据库"""
    success, output = execute_psql(host, port, user, password, 'postgres', '\l')
    if success:
        return output
    return ""


def prompt_input(prompt_text: str, default_value: str = "", is_password: bool = False) -> str:
    """提示用户输入，支持默认值"""
    import getpass
    
    if default_value:
        prompt_str = f"{Colors.CYAN}{prompt_text}{Colors.NC} [默认: {default_value}]: "
    else:
        prompt_str = f"{Colors.CYAN}{prompt_text}{Colors.NC}: "
    
    if is_password:
        value = getpass.getpass(prompt_str)
    else:
        value = input(prompt_str).strip()
    
    # 如果用户输入为空，使用默认值
    return value if value else default_value


def main():
    parser = argparse.ArgumentParser(
        description='PostgreSQL 数据库检查和创建脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 交互式输入配置（推荐）
  python check-and-create-databases.py

  # 使用命令行参数（跳过交互式输入）
  python check-and-create-databases.py --host localhost --port 55432 --user postgres --password devpassword

  # 从 kind 集群内访问
  python check-and-create-databases.py --host host.docker.internal --port 55432

  # 使用环境变量（跳过交互式输入）
  export PGHOST=localhost PGPORT=55432 PGUSER=postgres PGPASSWORD=devpassword
  python check-and-create-databases.py
        """
    )
    
    # 默认值：优先使用环境变量，否则使用硬编码默认值
    default_host = os.getenv('PGHOST', 'localhost')
    default_port = int(os.getenv('PGPORT', '55432'))
    default_user = os.getenv('PGUSER', 'postgres')
    default_password = os.getenv('PGPASSWORD', 'devpassword')
    
    parser.add_argument('--host', default=None,
                       help='PostgreSQL 主机地址 (默认: localhost 或 $PGHOST)')
    parser.add_argument('--port', type=int, default=None,
                       help='PostgreSQL 端口 (默认: 55432 或 $PGPORT)')
    parser.add_argument('--user', default=None,
                       help='PostgreSQL 用户名 (默认: postgres 或 $PGUSER)')
    parser.add_argument('--password', default=None,
                       help='PostgreSQL 密码 (默认: devpassword 或 $PGPASSWORD)')
    parser.add_argument('--non-interactive', action='store_true',
                       help='非交互模式，使用默认值或命令行参数')
    parser.add_argument('--databases', nargs='+',
                       default=['dify', 'plugin_daemon', 'enterprise', 'audit'],
                       help='要检查的数据库列表 (默认: dify plugin_daemon enterprise audit)')
    
    args = parser.parse_args()
    
    # 如果未提供参数且不是非交互模式，则提示用户输入
    if not args.non_interactive:
        if args.host is None or args.port is None or args.user is None or args.password is None:
            print_colored("=" * 40, Colors.BLUE)
            print_colored("PostgreSQL 数据库检查和创建脚本", Colors.BLUE)
            print_colored("=" * 40, Colors.BLUE)
            print()
            print_colored("请输入 PostgreSQL 连接信息（可直接回车使用默认值）", Colors.YELLOW)
            print()
            
            # 交互式输入
            host = prompt_input("PostgreSQL 主机地址", default_host) if args.host is None else args.host
            port_str = prompt_input("PostgreSQL 端口", str(default_port)) if args.port is None else str(args.port)
            user = prompt_input("PostgreSQL 用户名", default_user) if args.user is None else args.user
            password = prompt_input("PostgreSQL 密码", default_password, is_password=True) if args.password is None else args.password
            
            try:
                port = int(port_str)
            except ValueError:
                print_colored(f"✗ 错误: 无效的端口号: {port_str}", Colors.RED)
                sys.exit(1)
        else:
            # 所有参数都已提供，直接使用
            host = args.host
            port = args.port
            user = args.user
            password = args.password
    else:
        # 非交互模式，使用提供的参数或默认值
        host = args.host if args.host is not None else default_host
        port = args.port if args.port is not None else default_port
        user = args.user if args.user is not None else default_user
        password = args.password if args.password is not None else default_password
    
    # 打印连接信息（如果之前没有打印过）
    if args.non_interactive or (args.host is not None and args.port is not None and args.user is not None and args.password is not None):
        print_colored("=" * 40, Colors.BLUE)
        print_colored("PostgreSQL 数据库检查和创建脚本", Colors.BLUE)
        print_colored("=" * 40, Colors.BLUE)
        print()
    
    print_colored("连接信息:", Colors.BLUE)
    print(f"  主机: {host}")
    print(f"  端口: {port}")
    print(f"  用户: {user}")
    print()
    
    # 检查 psql 是否可用
    if not check_psql_available():
        print_colored("✗ 错误: 未找到 psql 命令", Colors.RED)
        print_colored("请安装 PostgreSQL 客户端:", Colors.YELLOW)
        print("  macOS: brew install postgresql")
        print("  Ubuntu/Debian: sudo apt-get install postgresql-client")
        print("  CentOS/RHEL: sudo yum install postgresql")
        sys.exit(1)
    
    # 检查连接
    print_colored("➤ 检查 PostgreSQL 连接...", Colors.BLUE)
    if check_connection(host, port, user, password):
        print_colored("✓ PostgreSQL 连接成功", Colors.GREEN)
    else:
        print_colored("✗ 错误: 无法连接到 PostgreSQL", Colors.RED)
        print_colored("请检查:", Colors.YELLOW)
        print(f"  1. PostgreSQL 服务是否已启动")
        print(f"  2. 连接信息是否正确 (host: {host}, port: {port})")
        print(f"  3. 用户名和密码是否正确")
        print(f"  4. 如果从 kind 集群内访问，请使用 'host.docker.internal' 作为主机")
        print()
        print_colored("测试连接命令:", Colors.YELLOW)
        print(f"  PGPASSWORD={password} psql -h {host} -p {port} -U {user} -d postgres -c 'SELECT 1;'")
        sys.exit(1)
    
    print()
    
    # 检查并创建数据库
    print_colored("➤ 检查数据库...", Colors.BLUE)
    all_success = True
    
    for db in args.databases:
        print(f"  检查数据库 '{db}'... ", end='', flush=True)
        
        if check_database_exists(host, port, user, password, db):
            print_colored("✓ 已存在", Colors.GREEN)
        else:
            print_colored("不存在，正在创建...", Colors.YELLOW)
            success, error_msg = create_database(host, port, user, password, db)
            if success:
                print(f"    ", end='')
                print_colored(f"✓ 数据库 '{db}' 创建成功", Colors.GREEN)
            else:
                print(f"    ", end='')
                print_colored(f"✗ 创建数据库 '{db}' 失败: {error_msg}", Colors.RED)
                all_success = False
    
    print()
    
    if not all_success:
        print_colored("✗ 部分数据库创建失败，请检查错误信息", Colors.RED)
        sys.exit(1)
    
    print_colored("=" * 40, Colors.GREEN)
    print_colored("✓ 所有数据库检查完成", Colors.GREEN)
    print_colored("=" * 40, Colors.GREEN)
    print()
    
    # 显示数据库列表
    print_colored("当前数据库列表:", Colors.BLUE)
    db_list = list_databases(host, port, user, password)
    if db_list:
        # 过滤显示相关数据库
        for line in db_list.split('\n'):
            if any(db in line for db in args.databases) or 'postgres' in line.lower() or 'template' in line.lower():
                print(line)
    
    print()
    print_colored("可以继续部署 Dify Enterprise Edition 了！", Colors.GREEN)


if __name__ == '__main__':
    main()

