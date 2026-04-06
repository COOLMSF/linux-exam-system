#!/bin/bash
# 数据库服务管理检查（满分 4 分）
# 自动适配 MySQL / 达梦数据库
SCORE=4

# ── 自动检测数据库类型 ──
if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    DB_TYPE="dameng"
else
    DB_TYPE="mysql"
fi
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
        echo "✓ MySQL 服务正在运行 (+2)"
    else
        echo "✗ MySQL 服务未运行 (-2)"
        SCORE=$((SCORE-2))
    fi

    if systemctl is-enabled --quiet mysql 2>/dev/null || systemctl is-enabled --quiet mysqld 2>/dev/null; then
        echo "✓ MySQL 已设置开机自启 (+1)"
    else
        echo "✗ MySQL 未设置开机自启 (-1)"
        SCORE=$((SCORE-1))
    fi

    if [ ! -d "/tmp/mysql_old_data" ]; then
        echo "✓ /tmp/mysql_old_data 已清理 (+1)"
    else
        echo "✗ /tmp/mysql_old_data 仍然存在 (-1)"
        SCORE=$((SCORE-1))
    fi
else
    # ── 达梦模式 ──
    DM_SVC=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "DmService" | awk '{print $1}' | head -1)
    if [ -n "$DM_SVC" ] && systemctl is-active --quiet "$DM_SVC" 2>/dev/null; then
        echo "✓ 达梦服务 $DM_SVC 正在运行 (+2)"
    elif pgrep -x dmserver &>/dev/null; then
        echo "✓ 达梦 dmserver 进程在运行 (+2)"
    else
        echo "✗ 达梦数据库服务未运行 (-2)"
        SCORE=$((SCORE-2))
    fi

    if [ -n "$DM_SVC" ] && systemctl is-enabled --quiet "$DM_SVC" 2>/dev/null; then
        echo "✓ 达梦服务已设置开机自启 (+1)"
    else
        echo "✗ 达梦服务未设置开机自启 (-1)"
        SCORE=$((SCORE-1))
    fi

    if [ ! -d "/home/dmdba/dmdbms_old" ] && [ ! -d "/tmp/dm_old_data" ]; then
        echo "✓ 旧数据目录已清理 (+1)"
    else
        echo "✗ 旧数据目录仍然存在 (-1)"
        SCORE=$((SCORE-1))
    fi
fi

echo "SCORE:$SCORE"
