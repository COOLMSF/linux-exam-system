#!/bin/bash
# 数据库安全与备份恢复检查（满分 10 分）
# 自动适配 MySQL / 达梦数据库
SCORE=10

# ── 自动检测数据库类型 ──
if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    DB_TYPE="dameng"
    DMPATH="${DMPATH:-/dm/bin}"
    DM_CONN="sysdba/Dameng123@localhost:${PORT_EXPECTED:-5236}"
else
    DB_TYPE="mysql"
    # 自动探测 MySQL root 连接（支持密码 + TCP）
    _ROOT_PASS=""
    for _pf in "$(dirname "$0")/../.mysql_root_pass" "/opt/linux-exam-system/.mysql_root_pass" "/home/ubuntu/linux-exam-system/.mysql_root_pass"; do
        [ -f "$_pf" ] && _ROOT_PASS=$(cat "$_pf") && break
    done
    if [ -n "$_ROOT_PASS" ] && mysql -u root -p"${_ROOT_PASS}" -h 127.0.0.1 -N -s -e "SELECT 1" &>/dev/null; then
        MYSQL_CMD="mysql -u root -p${_ROOT_PASS} -h 127.0.0.1 -N -s"
    elif mysql -u root -h 127.0.0.1 -N -s -e "SELECT 1" &>/dev/null; then
        MYSQL_CMD="mysql -u root -h 127.0.0.1 -N -s"
    elif mysql -u root -N -s -e "SELECT 1" &>/dev/null; then
        MYSQL_CMD="mysql -u root -N -s"
    else
        MYSQL_CMD="mysql -u root -N -s"
    fi
fi
DB_EXPECTED="${DB_EXPECTED:-examdb_a}"
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    BINLOG=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'log_bin'" 2>/dev/null | awk '{print $2}')
    if [ "$BINLOG" = "ON" ]; then
        echo "✓ 二进制日志已开启 (+1)"
    else
        echo "✗ 二进制日志未开启 (-1)"; SCORE=$((SCORE-1))
    fi

    BINLOG_FMT=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'binlog_format'" 2>/dev/null | awk '{print $2}')
    if [ "$BINLOG_FMT" = "ROW" ]; then
        echo "✓ binlog 格式为 ROW (+1)"
    else
        echo "✗ binlog 格式不是 ROW (当前: ${BINLOG_FMT:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    EXPIRE=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'binlog_expire_logs_seconds'" 2>/dev/null | awk '{print $2}')
    if [ -n "$EXPIRE" ] && [ "$EXPIRE" -gt 0 ] 2>/dev/null; then
        echo "✓ 二进制日志过期时间已设置 (+1)"
    else
        echo "✗ 二进制日志过期时间未设置 (-1)"; SCORE=$((SCORE-1))
    fi

    if [ -d "/var/lib/mysql_backup" ]; then
        echo "✓ 备份目录存在 (+1)"
    else
        echo "✗ 备份目录不存在 (-1)"; SCORE=$((SCORE-1))
    fi

    if [ -f "/var/lib/mysql_backup/full_backup.sql" ]; then
        echo "✓ 全库备份文件存在 (+3)"
    else
        echo "✗ 全库备份文件不存在 (-3)"; SCORE=$((SCORE-3))
    fi

    if [ -f "/var/lib/mysql_backup/${DB_EXPECTED}.sql" ]; then
        echo "✓ 单库备份文件存在 (+3)"
    else
        echo "✗ 单库备份文件不存在 (-3)"; SCORE=$((SCORE-3))
    fi
else
    # ── 达梦模式 ──
    # 归档模式检查
    ARCHMODE=$($DMPATH/disql -s "$DM_CONN" -e "SELECT ARCH_MODE FROM V\$DATABASE;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$ARCHMODE" = "Y" ]; then
        echo "✓ 归档模式已开启 (+1)"
    else
        echo "✗ 归档模式未开启 (-1)"; SCORE=$((SCORE-1))
    fi

    # 归档路径
    ARCHDEST=$($DMPATH/disql -s "$DM_CONN" -e "SELECT ARCH_DEST FROM V\$DM_ARCH_INI WHERE ARCH_TYPE='LOCAL';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$ARCHDEST" = "/dm/arch" ]; then
        echo "✓ 归档路径为 /dm/arch (+1)"
    else
        echo "✗ 归档路径不正确 (当前: ${ARCHDEST:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 归档文件大小
    ARCHFILE=$($DMPATH/disql -s "$DM_CONN" -e "SELECT ARCH_FILE_SIZE FROM V\$DM_ARCH_INI WHERE ARCH_TYPE='LOCAL';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$ARCHFILE" = "128" ]; then
        echo "✓ 归档文件大小为 128M (+1)"
    else
        echo "✗ 归档文件大小不正确 (当前: ${ARCHFILE:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 备份目录
    if [ -d "/dm/backup" ]; then
        echo "✓ 备份目录 /dm/backup 存在 (+1)"
    else
        echo "✗ 备份目录 /dm/backup 不存在 (-1)"; SCORE=$((SCORE-1))
    fi

    # 整库备份（物理备份 .meta 文件）
    FULLBAK=$(find /dm/backup -name "*.meta" 2>/dev/null | wc -l)
    if [ "$FULLBAK" -ge 1 ] 2>/dev/null; then
        echo "✓ 整库物理备份存在 (+3)"
    else
        echo "✗ 整库物理备份不存在 (-3)"; SCORE=$((SCORE-3))
    fi

    # 逻辑备份（dmp + log）
    if [ -f "/dm/backup/dmexam.dmp" ] && [ -f "/dm/backup/dmexam.log" ]; then
        echo "✓ 逻辑备份文件存在 (+3)"
    elif ls /dm/backup/*.dmp &>/dev/null; then
        echo "✓ 逻辑备份 dmp 文件存在 (+3)"
    else
        echo "✗ 逻辑备份不存在 (-3)"; SCORE=$((SCORE-3))
    fi
fi

echo "SCORE:$SCORE"
