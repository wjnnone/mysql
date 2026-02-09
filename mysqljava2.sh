#!/bin/bash
set -e  # 遇到错误立即退出，避免脚本继续执行

# ====================== 1. 安全获取 MySQL 密码（优先环境变量，其次交互式输入） ======================
# 优先从环境变量获取密码（适合自动化执行）
if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_PASS="$MYSQL_ROOT_PASSWORD"
    echo "✅ 从环境变量获取到 MySQL 密码"
else
    # 交互式输入密码（避免明文显示）
    read -s -p "请输入 MySQL root 密码：" MYSQL_PASS
    echo -e "\n✅ 密码输入完成"
    # 二次验证（可选，提高准确性）
    read -s -p "请再次输入 MySQL root 密码确认：" MYSQL_PASS_CONFIRM
    echo ""
    if [ "$MYSQL_PASS" != "$MYSQL_PASS_CONFIRM" ]; then
        echo "❌ 两次输入的密码不一致，脚本退出"
        exit 1
    fi
fi

# ====================== 2. 可配置的全局变量（无硬编码） ======================
# 需要处理的目录列表（可按需修改）
DIRS=("sky_master" "xiyou_main" "xiyou_ceshi1")
# Java 安装包名称（可按需调整版本）
JAVA_PACKAGE="java-1.8.0-openjdk*"

# ====================== 3. 自动检测 MySQL 数据目录 ======================
echo -e "\n🔍 开始检测 MySQL 数据目录..."
# 优先从 MySQL 配置中获取数据目录（最准确）
MYSQL_DATA_DIR=$(mysql -uroot -p"$MYSQL_PASS" -Nse "SELECT @@datadir;" 2>/dev/null || true)
# 如果获取失败，检测常见路径
if [ -z "$MYSQL_DATA_DIR" ]; then
    if [ -d "/var/lib/mysql" ]; then
        MYSQL_DATA_DIR="/var/lib/mysql"
        echo "✅ 检测到 MySQL 数据目录：$MYSQL_DATA_DIR"
    elif [ -d "/www/server/data" ]; then
        MYSQL_DATA_DIR="/www/server/data"
        echo "✅ 检测到 MySQL 数据目录：$MYSQL_DATA_DIR"
    else
        echo "❌ 错误：未找到 MySQL 数据目录（/var/lib/mysql 或 /www/server/data）"
        exit 1
    fi
else
    echo "✅ 从 MySQL 配置获取到数据目录：$MYSQL_DATA_DIR"
fi

# 关键修改：让 TARGET_BASE_DIR 继承检测到的 MySQL 数据目录
# 保留环境变量覆盖的能力（如果手动指定 TARGET_BASE_DIR 仍生效）
TARGET_BASE_DIR=${TARGET_BASE_DIR:-$MYSQL_DATA_DIR}
echo "🔔 最终要操作的目标目录：$TARGET_BASE_DIR"

# ====================== 4. 执行核心操作 ======================
# 4.1 更改 /home/ 目录权限（注意：777 权限风险极高，建议根据实际需求调整为 755/775）
echo -e "\n🔧 开始设置 /home/ 目录权限为 777..."
chmod -R 777 /home/
echo "✅ /home/ 目录权限设置完成。"

# 4.2 安装 Java 1.8（自动确认安装）
echo -e "\n🔧 开始安装 Java 1.8..."
yum install -y $JAVA_PACKAGE
echo "✅ Java 1.8 安装完成。"

# 4.3 MySQL 授权（允许 root 远程访问，密码无硬编码）
echo -e "\n🔧 开始执行 MySQL 授权操作..."
mysql -uroot -p"$MYSQL_PASS" -e "
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ MySQL 授权操作完成：允许 root 从任意主机访问"
else
    echo "⚠️ 警告：MySQL 授权操作可能执行失败，请检查密码或 MySQL 服务状态"
fi

# 4.4 切换到目标目录（现在会用检测到的目录）并创建目录（如果不存在）
echo -e "\n🔧 切换到目标目录：$TARGET_BASE_DIR"
# 新增：如果目录不存在，自动创建
if [ ! -d "$TARGET_BASE_DIR" ]; then
    echo "⚠️ 目标目录不存在，自动创建：$TARGET_BASE_DIR"
    mkdir -p "$TARGET_BASE_DIR"
    chown mysql:mysql "$TARGET_BASE_DIR"  # 创建后设置默认属主
fi

cd "$TARGET_BASE_DIR" || {
    echo "❌ 错误：无法切换到目录 $TARGET_BASE_DIR"
    exit 1
}
echo "✅ 成功切换到目标目录：$TARGET_BASE_DIR"

# 4.5 更改目录所有者和组
echo -e "\n🔧 开始设置目录所有者和组为 mysql..."
for dir in "${DIRS[@]}"; do
    # 拼接完整路径
    full_dir="$TARGET_BASE_DIR/$dir"
    if [ -d "$full_dir" ]; then
        chown -R mysql:mysql "$full_dir"
        echo "✅ 更改 $full_dir 目录的所有者和组为 mysql 完成。"
    else
        echo "⚠️ 警告：目录 $full_dir 不存在，跳过权限设置"
    fi
done

# 4.6 更改目录权限（777 仅为示例，生产环境建议调整）
echo -e "\n🔧 开始设置目录权限为 777..."
for dir in "${DIRS[@]}"; do
    full_dir="$TARGET_BASE_DIR/$dir"
    if [ -d "$full_dir" ]; then
        chmod -R 777 "$full_dir"
        echo "✅ 更改 $full_dir 目录的权限为 777 完成。"
    else
        echo "⚠️ 警告：目录 $full_dir 不存在，跳过权限设置"
    fi
done

# 4.7 重新加载 MySQL 配置和刷新表
echo -e "\n🔧 重新加载 MySQL 配置并刷新表..."
mysqladmin -uroot -p"$MYSQL_PASS" reload 2>/dev/null
mysqladmin -uroot -p"$MYSQL_PASS" flush-tables 2>/dev/null
echo "✅ MySQL 重新加载和刷新表完成。"

# ====================== 5. 脚本执行完成 ======================
echo -e "\n=============================="
echo "🎉 所有操作执行完成！"
echo "📌 MySQL 数据目录：$MYSQL_DATA_DIR"
echo "📌 实际操作目录：$TARGET_BASE_DIR"
echo "=============================="
