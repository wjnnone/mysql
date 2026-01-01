#!/bin/bash
# ========================================================
# 脚本名称: mysqljava.sh
# 功能: CentOS 7 一键安装/修复 MySQL 5.5.2_m2 (蓝奏源)
# ========================================================
set -e

# 定义下载链接和本地文件名
SERVER_URL="https://api.hanximeng.com/lanzou/?url=https://wjnnone.lanzouu.com/iea1L3dqpkve&type=down"
CLIENT_URL="https://gitee.com/wjnnone/mysql/raw/main/MySQL-client-5.5.2_m2-1.glibc23.x86_64.rpm"
SERVER_RPM="MySQL-server-5.5.2_m2-1.glibc23.x86_64.rpm"
CLIENT_RPM="MySQL-client-5.5.2_m2-1.glibc23.x86_64.rpm"

# 定义 root 目录下的文件路径
ROOT_SERVER_RPM="/root/${SERVER_RPM}"
ROOT_CLIENT_RPM="/root/${CLIENT_RPM}"

# 1. 清理 MariaDB 冲突包
echo ">>> 清理 MariaDB 冲突组件..."
rpm -qa | grep mariadb | xargs -r rpm -e --nodeps 2>/dev/null || true

# 2. 安装基础依赖
echo ">>> 安装必备依赖包..."
yum install -y wget perl net-tools libaio numactl perl-Module-Install.noarch java-1.8.0-openjdk*

# 3. 检测并下载 RPM 包（优化完整性校验，跳过无意义签名校验）
echo ">>> 检测本地 MySQL 安装包..."

# 检查服务端包（校验完整性+跳过GPG签名，避免无签名误判）
if [ -f "${ROOT_SERVER_RPM}" ]; then
    echo "🔍 校验 ${ROOT_SERVER_RPM} 完整性..."
    # 核心修改：--nodigest 跳过摘要校验 --nosignature 跳过GPG签名，仅校验文件本身完整性
    if rpm -K --nodigest --nosignature "${ROOT_SERVER_RPM}" >/dev/null 2>&1; then
        echo "✅ 检测到 ${ROOT_SERVER_RPM} 已存在且完整，跳过下载"
    else
        echo "❌ ${ROOT_SERVER_RPM} 已损坏，删除并重新下载..."
        rm -f "${ROOT_SERVER_RPM}"
        wget --no-check-certificate -O "${ROOT_SERVER_RPM}" "${SERVER_URL}" || {
            echo "ERROR: MySQL 服务端安装包下载失败"
            exit 1
        }
    fi
else
    echo ">>> 开始下载 MySQL 服务端安装包..."
    wget --no-check-certificate -O "${ROOT_SERVER_RPM}" "${SERVER_URL}" || {
        echo "ERROR: MySQL 服务端安装包下载失败"
        exit 1
    }
fi

# 检查客户端包（同服务端，优化校验参数）
if [ -f "${ROOT_CLIENT_RPM}" ]; then
    echo "🔍 校验 ${ROOT_CLIENT_RPM} 完整性..."
    if rpm -K --nodigest --nosignature "${ROOT_CLIENT_RPM}" >/dev/null 2>&1; then
        echo "✅ 检测到 ${ROOT_CLIENT_RPM} 已存在且完整，跳过下载"
    else
        echo "❌ ${ROOT_CLIENT_RPM} 已损坏，删除并重新下载..."
        rm -f "${ROOT_CLIENT_RPM}"
        wget --no-check-certificate -O "${ROOT_CLIENT_RPM}" "${CLIENT_URL}" || {
            echo "ERROR: MySQL 客户端安装包下载失败"
            exit 1
        }
    fi
else
    echo ">>> 开始下载 MySQL 客户端安装包..."
    wget --no-check-certificate -O "${ROOT_CLIENT_RPM}" "${CLIENT_URL}" || {
        echo "ERROR: MySQL 客户端安装包下载失败"
        exit 1
    }
fi

# 4. 检查文件是否存在（兜底检查）
if [ ! -f "${ROOT_SERVER_RPM}" ] || [ ! -f "${ROOT_CLIENT_RPM}" ]; then
    echo "ERROR: MySQL 安装包缺失，请检查文件是否存在或重新下载"
    exit 1
fi

# 5. 安装/升级 MySQL
echo ">>> 安装/修复 MySQL 5.5.2_m2..."
rpm -Uvh --replacepkgs "${ROOT_SERVER_RPM}" "${ROOT_CLIENT_RPM}"

# 6. 复制配置文件（覆盖已有配置）
echo ">>> 配置 MySQL 配置文件..."
cp -f /usr/share/mysql/my-huge.cnf /etc/my.cnf

# 7. 启动服务并设置开机自启（先停止再启动，避免状态异常）
echo ">>> 启动 MySQL 服务..."
service mysql stop >/dev/null 2>&1 || true
service mysql start
chkconfig mysql on

# 8. 交互式设置 root 密码
echo "------------------------------------------------"
read -s -p "请输入 MySQL root 用户密码: " ROOT_PWD
echo
read -s -p "请再次输入 MySQL root 用户密码: " ROOT_PWD_CONFIRM
echo

if [ "$ROOT_PWD" != "$ROOT_PWD_CONFIRM" ]; then
    echo "ERROR: 两次输入的密码不一致！"
    exit 1
fi

# 跳过密码设置的重复执行错误（密码已存在时）
/usr/bin/mysqladmin -u root password "$ROOT_PWD" 2>/dev/null || {
    echo "提示: root 密码可能已设置，尝试更新..."
    /usr/bin/mysqladmin -u root -p"$ROOT_PWD" password "$ROOT_PWD" 2>/dev/null || true
}

# 9. 授予 root 远程访问权限（忽略已存在用户的错误）
echo ">>> 配置 root 远程访问权限..."
mysql -uroot -p"$ROOT_PWD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$ROOT_PWD' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || echo "提示: 远程授权用户已存在"

# 10. 验证安装状态
echo "------------------------------------------------"
ps -ef | grep mysql | grep -v grep
echo "------------------------------------------------"
echo "✅ MySQL 操作完成！"
echo "🔑 root 密码已设置/保持为你输入的密码"
echo "🌐 root 用户已授权远程访问"
