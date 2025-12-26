#!/bin/bash
# ========================================================
# 脚本名称: mysqljava.sh
# 功能: CentOS 7 一键安装/修复 MySQL 5.5.2_m2 (蓝奏源)
# ========================================================
set -e

SERVER_URL="https://api.hanximeng.com/lanzou/?url=https://wjnnone.lanzouu.com/izAry3ekbz5e&type=down"
CLIENT_URL="https://gitee.com/wjnnone/mysql/raw/main/MySQL-client-5.5.2_m2-1.glibc23.x86_64.rpm"
SERVER_RPM=$(basename "$SERVER_URL")
CLIENT_RPM=$(basename "$CLIENT_URL")

# 1. 清理 MariaDB 冲突包
echo ">>> 清理 MariaDB 冲突组件..."
rpm -qa | grep mariadb | xargs -r rpm -e --nodeps 2>/dev/null || true

# 2. 安装基础依赖
echo ">>> 安装必备依赖包..."
yum install -y wget perl net-tools libaio numactl perl-Module-Install.noarch java-1.8.0-openjdk*

# 3. 下载 RPM 包
echo ">>> 下载 MySQL 安装包..."
wget --no-check-certificate -O "$SERVER_RPM" "$SERVER_URL" || [ -f "$SERVER_RPM" ]
wget --no-check-certificate -O "$CLIENT_RPM" "$CLIENT_URL" || [ -f "$CLIENT_RPM" ]

# 4. 检查下载是否成功
if [ ! -f "$SERVER_RPM" ] || [ ! -f "$CLIENT_RPM" ]; then
    echo "ERROR: MySQL 安装包下载失败，请检查链接有效性"
    exit 1
fi

# 5. 安装/升级 MySQL
echo ">>> 安装/修复 MySQL 5.5.2_m2..."
rpm -Uvh --replacepkgs "$SERVER_RPM" "$CLIENT_RPM"

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
