#!/bin/bash
# 性能优化检查（满分 10 分）
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
USER_EXPECTED="${USER_EXPECTED:-exam_user}"
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    IDX_EXISTS=$($MYSQL_CMD -e "SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND INDEX_NAME='ix_emp_empname'" 2>/dev/null)
    if [ -n "$IDX_EXISTS" ]; then
        echo "✓ 索引 ix_emp_empname 存在 (+3)"
    else
        echo "✗ 索引 ix_emp_empname 不存在 (-3)"; SCORE=$((SCORE-3))
    fi

    IDX_COL=$($MYSQL_CMD -e "SELECT COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND INDEX_NAME='ix_emp_empname'" 2>/dev/null)
    if [ "$IDX_COL" = "employee_name" ]; then
        echo "✓ 索引列为 employee_name (+1)"
    else
        echo "✗ 索引列不正确 (当前: ${IDX_COL:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    UPDATE_TIME=$($MYSQL_CMD -e "SELECT UPDATE_TIME FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp'" 2>/dev/null)
    if [ -n "$UPDATE_TIME" ] && [ "$UPDATE_TIME" != "NULL" ]; then
        echo "✓ tab_emp 表统计信息已更新 (+3)"
    else
        echo "✗ tab_emp 表统计信息未更新 (-3)"; SCORE=$((SCORE-3))
    fi

    POOL_SIZE=$($MYSQL_CMD -e "SELECT @@innodb_buffer_pool_size" 2>/dev/null)
    if [ -n "$POOL_SIZE" ] && [ "$POOL_SIZE" -ge 268435456 ] 2>/dev/null; then
        echo "✓ innodb_buffer_pool_size ≥ 256M (+3)"
    else
        echo "✗ innodb_buffer_pool_size < 256M (当前: ${POOL_SIZE:-N/A}) (-3)"; SCORE=$((SCORE-3))
    fi
else
    # ── 达梦模式 ──
    # 索引检查
    IDX_NAME=$($DMPATH/disql -s "$DM_CONN" -e "SELECT INDEX_NAME FROM ALL_INDEXES WHERE OWNER=UPPER('${USER_EXPECTED}') AND TABLE_NAME='TAB_EMP' AND INDEX_NAME='IX_EMP_EMPNAME';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$IDX_NAME" = "IX_EMP_EMPNAME" ]; then
        echo "✓ 索引 IX_EMP_EMPNAME 存在 (+3)"
    else
        echo "✗ 索引 IX_EMP_EMPNAME 不存在 (-3)"; SCORE=$((SCORE-3))
    fi

    IDX_COL=$($DMPATH/disql -s "$DM_CONN" -e "SELECT COLUMN_NAME FROM ALL_IND_COLUMNS WHERE INDEX_OWNER=UPPER('${USER_EXPECTED}') AND INDEX_NAME='IX_EMP_EMPNAME';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$IDX_COL" = "EMPLOYEE_NAME" ]; then
        echo "✓ 索引列为 EMPLOYEE_NAME (+1)"
    else
        echo "✗ 索引列不正确 (当前: ${IDX_COL:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 统计信息检查
    STAT=$($DMPATH/disql -s "$DM_CONN" -e "SELECT NUM_ROWS FROM ALL_TABLES WHERE OWNER=UPPER('${USER_EXPECTED}') AND TABLE_NAME='TAB_EMP';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$STAT" ] && [ "$STAT" != "NULL" ] && [ "$STAT" != "" ]; then
        echo "✓ TAB_EMP 表统计信息已收集 (NUM_ROWS=${STAT}) (+3)"
    else
        echo "✗ TAB_EMP 表统计信息未收集 (-3)"; SCORE=$((SCORE-3))
    fi

    # SQL 缓冲区大小（达梦特有）
    SQLBUF=$($DMPATH/disql -s "$DM_CONN" -e "SELECT PARA_VALUE FROM V\$DM_INI WHERE PARA_NAME='CACHE_POOL_SIZE';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$SQLBUF" = "500" ]; then
        echo "✓ SQL 缓冲区大小为 500 (+3)"
    else
        echo "✗ SQL 缓冲区大小不正确 (当前: ${SQLBUF:-N/A}) (-3)"; SCORE=$((SCORE-3))
    fi
fi

echo "SCORE:$SCORE"
