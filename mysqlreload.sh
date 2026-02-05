#!/bin/bash  

# 定义可能的目标目录列表
TARGET_DIRS=("/www/server/data" "/var/lib/mysql")
# 初始化实际使用的目录变量
ACTUAL_DIR=""

# 自动检测并选择存在的目录
for dir in "${TARGET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        ACTUAL_DIR="$dir"
        echo "检测到有效目录: $ACTUAL_DIR"
        break
    fi
done

# 如果没有找到任何有效目录，脚本退出
if [ -z "$ACTUAL_DIR" ]; then
    echo "错误：未找到以下目标目录中的任何一个："
    printf ' - %s\n' "${TARGET_DIRS[@]}"
    exit 1
fi

# 切换到检测到的目标目录
cd "$ACTUAL_DIR" || exit 1

# 更改目录和文件的所有者和组
DIRS=("sky_master" "xiyou_main" "xiyou_ceshi1")
for dir in "${DIRS[@]}"; do
    chown -R mysql "$dir"
    chgrp -R mysql "$dir"
    echo "更改 $dir 目录的所有者和组为 mysql 完成。"
done

# 更改目录的权限
for dir in "${DIRS[@]}"; do
    chmod -R 777 "$dir"
    echo "更改 $dir 目录的权限为 777 完成。"
done

# 使用环境变量中的密码
export MYSQL_PASS="ruankorcom"  

# 完全仿照原始脚本：使用 echo 管道传递密码给 mysqladmin
echo "$MYSQL_PASS" | mysqladmin -uroot -p reload
echo "执行 mysqladmin reload 命令完成。"

echo "$MYSQL_PASS" | mysqladmin -uroot -p flush-tables
echo "执行 mysqladmin flush-tables 命令完成。"