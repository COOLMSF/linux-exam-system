#!/bin/bash
# 数据库软件卸载检查（满分 4 分）
# 自动适配 MySQL / 达梦数据库
SCORE=4

# ── 自动检测数据库类型 ──
# 注意：卸载场景下需检测残留而非运行状态
if [ -d "/home/dmdba/dmdbms" ] || [ -d "/dm/bin" ] || [ -f "/etc/init.d/DmServiceDMSERVER" ]; then
    DB_TYPE="dameng"
else
    DB_TYPE="mysql"
fi
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
        echo "✗ MySQL 服务仍在运行 (-1)"; SCORE=$((SCORE-1))
    else
        echo "✓ MySQL 服务已停止"
    fi

    if dpkg -l 2>/dev/null | grep -qi "mysql-server"; then
        echo "✗ MySQL 软件包仍安装 (-2)"; SCORE=$((SCORE-2))
    elif rpm -qa 2>/dev/null | grep -qi "mysql-server"; then
        echo "✗ MySQL 软件包仍安装 (-2)"; SCORE=$((SCORE-2))
    else
        echo "✓ MySQL 软件包已卸载"
    fi

    if pgrep -x mysqld &>/dev/null; then
        echo "✗ mysqld 进程仍在运行 (-1)"; SCORE=$((SCORE-1))
    else
        echo "✓ mysqld 进程已清理"
    fi
else
    # ── 达梦模式 ──
    # 检查达梦服务是否已停止
    DM_SVC=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "DmService" | awk '{print $1}' | head -1)
    if [ -n "$DM_SVC" ] && systemctl is-active --quiet "$DM_SVC" 2>/dev/null; then
        echo "✗ 达梦服务 $DM_SVC 仍在运行 (-1)"; SCORE=$((SCORE-1))
    elif pgrep -x dmserver &>/dev/null; then
        echo "✗ dmserver 进程仍在运行 (-1)"; SCORE=$((SCORE-1))
    else
        echo "✓ 达梦数据库服务已停止"
    fi

    # 检查达梦软件是否已卸载（检查安装目录）
    if [ -d "/home/dmdba/dmdbms/jar" ]; then
        echo "✗ 达梦软件未成功卸载（/home/dmdba/dmdbms/jar 仍存在）(-2)"; SCORE=$((SCORE-2))
    elif [ -d "/home/dmdba/dmdbms/bin" ]; then
        echo "✗ 达梦软件未成功卸载（/home/dmdba/dmdbms/bin 仍存在）(-2)"; SCORE=$((SCORE-2))
    else
        echo "✓ 达梦软件已卸载"
    fi

    # 检查达梦进程是否已清理
    if pgrep -x dmserver &>/dev/null || pgrep -x dmap &>/dev/null; then
        echo "✗ 达梦进程仍在运行 (-1)"; SCORE=$((SCORE-1))
    else
        echo "✓ 达梦进程已清理"
    fi
fi

echo "SCORE:$SCORE"
