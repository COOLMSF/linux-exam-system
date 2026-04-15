#!/bin/bash
# 表管理与数据导入导出检查（满分 18 分）
# 自动适配 MySQL / 达梦数据库
SCORE=18

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
    CSV_FILE="/tmp/${DB_EXPECTED}_emp_export.csv"

    DEPT_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.tab_dept" 2>/dev/null)
    if [ "$DEPT_COUNT" = "46" ]; then
        echo "✓ tab_dept 有 46 条记录 (+4)"
    else
        echo "✗ tab_dept 记录数不正确 (期望: 46, 实际: ${DEPT_COUNT:-表不存在}) (-4)"; SCORE=$((SCORE-4))
    fi

    EMP_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.tab_emp" 2>/dev/null)
    if [ -n "$EMP_COUNT" ] && [ "$EMP_COUNT" -ge 856 ] 2>/dev/null; then
        echo "✓ tab_emp 有 ${EMP_COUNT} 条记录 (≥856) (+4)"
    else
        echo "✗ tab_emp 记录数不足 (期望: ≥856, 实际: ${EMP_COUNT:-表不存在}) (-4)"; SCORE=$((SCORE-4))
    fi

    COL_EXISTS=$($MYSQL_CMD -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND COLUMN_NAME='create_time'" 2>/dev/null)
    if [ -n "$COL_EXISTS" ]; then
        echo "✓ tab_emp 有 create_time 列 (+2)"
    else
        echo "✗ tab_emp 缺少 create_time 列 (-2)"; SCORE=$((SCORE-2))
    fi

    COL_DEFAULT=$($MYSQL_CMD -e "SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND COLUMN_NAME='create_time'" 2>/dev/null)
    if echo "$COL_DEFAULT" | grep -qi "CURRENT_TIMESTAMP"; then
        echo "✓ create_time 默认值为 CURRENT_TIMESTAMP (+2)"
    else
        echo "✗ create_time 默认值不正确 (当前: ${COL_DEFAULT:-无}) (-2)"; SCORE=$((SCORE-2))
    fi

    if [ -f "$CSV_FILE" ]; then
        CSV_SIZE=$(stat -c%s "$CSV_FILE" 2>/dev/null || echo 0)
        if [ "$CSV_SIZE" -gt 100 ] 2>/dev/null; then
            echo "✓ CSV 文件内容非空 (${CSV_SIZE} bytes) (+6)"
        else
            echo "✗ CSV 文件为空或过小 (-2)"; SCORE=$((SCORE-2))
        fi
    else
        echo "✗ CSV 导出文件不存在: ${CSV_FILE} (-6)"; SCORE=$((SCORE-6))
    fi
else
    # ── 达梦模式 ──
    DEPT_COUNT=$($DMPATH/disql -s "$DM_CONN" -e "SELECT COUNT(*) FROM ${USER_EXPECTED}.TAB_DEPT;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$DEPT_COUNT" = "46" ]; then
        echo "✓ TAB_DEPT 有 46 条记录 (+4)"
    else
        echo "✗ TAB_DEPT 记录数不正确 (期望: 46, 实际: ${DEPT_COUNT:-表不存在}) (-4)"; SCORE=$((SCORE-4))
    fi

    EMP_COUNT=$($DMPATH/disql -s "$DM_CONN" -e "SELECT COUNT(*) FROM ${USER_EXPECTED}.TAB_EMP;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$EMP_COUNT" ] && [ "$EMP_COUNT" -ge 856 ] 2>/dev/null; then
        echo "✓ TAB_EMP 有 ${EMP_COUNT} 条记录 (≥856) (+4)"
    else
        echo "✗ TAB_EMP 记录数不足 (期望: ≥856, 实际: ${EMP_COUNT:-表不存在}) (-4)"; SCORE=$((SCORE-4))
    fi

    # 检查 CREATETIME 列（达梦列名大写）
    COL_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE OWNER=UPPER('${USER_EXPECTED}') AND TABLE_NAME='TAB_EMP' AND COLUMN_NAME='CREATETIME';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$COL_EXISTS" = "CREATETIME" ]; then
        echo "✓ TAB_EMP 有 CREATETIME 列 (+2)"
    else
        echo "✗ TAB_EMP 缺少 CREATETIME 列 (-2)"; SCORE=$((SCORE-2))
    fi

    DATA_DEF=$($DMPATH/disql -s "$DM_CONN" -e "SELECT DATA_DEFAULT FROM ALL_TAB_COLUMNS WHERE OWNER=UPPER('${USER_EXPECTED}') AND TABLE_NAME='TAB_EMP' AND COLUMN_NAME='CREATETIME';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if echo "$DATA_DEF" | grep -qi "SYSDATE"; then
        echo "✓ CREATETIME 默认值为 SYSDATE (+2)"
    else
        echo "✗ CREATETIME 默认值不正确 (当前: ${DATA_DEF:-无}) (-2)"; SCORE=$((SCORE-2))
    fi

    # 达梦导出检查（CSV 或 dmp）
    if [ -f "/dm/data/TAB_EMP.CSV" ] || [ -f "/dm/data/TAB_EMP.csv" ]; then
        echo "✓ TAB_EMP 数据已导出 (+6)"
    else
        echo "✗ TAB_EMP 导出文件不存在 (-6)"; SCORE=$((SCORE-6))
    fi
fi

echo "SCORE:$SCORE"
