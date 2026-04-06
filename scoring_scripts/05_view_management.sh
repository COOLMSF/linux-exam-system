#!/bin/bash
# 视图管理检查（满分 8 分）
# 自动适配 MySQL / 达梦数据库
SCORE=8

# ── 自动检测数据库类型 ──
if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    DB_TYPE="dameng"
    DMPATH="${DMPATH:-/dm/bin}"
    DM_CONN="sysdba/Dameng123@localhost:${PORT_EXPECTED:-5236}"
else
    DB_TYPE="mysql"
    MYSQL_CMD="mysql -u root -N -s"
fi
DB_EXPECTED="${DB_EXPECTED:-examdb_a}"
USER_EXPECTED="${USER_EXPECTED:-exam_user}"
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    V1_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='v_empnum'" 2>/dev/null)
    if [ -n "$V1_EXISTS" ]; then
        echo "✓ 视图 v_empnum 存在 (+2)"
    else
        echo "✗ 视图 v_empnum 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    V1_DATA=$($MYSQL_CMD -e "SELECT dept_name FROM ${DB_EXPECTED}.v_empnum WHERE dept_name LIKE '%开发%' OR dept_name LIKE '%部门1%' LIMIT 1" 2>/dev/null)
    if [ -n "$V1_DATA" ]; then
        echo "✓ v_empnum 查询结果包含目标部门 (+2)"
    else
        echo "✗ v_empnum 查询结果不含目标部门 (-2)"; SCORE=$((SCORE-2))
    fi

    V2_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='v_empsal'" 2>/dev/null)
    if [ -n "$V2_EXISTS" ]; then
        echo "✓ 视图 v_empsal 存在 (+2)"
    else
        echo "✗ 视图 v_empsal 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    V2_COUNT=$($MYSQL_CMD -e "SELECT high_salary_count FROM ${DB_EXPECTED}.v_empsal" 2>/dev/null)
    if [ -n "$V2_COUNT" ] && [ "$V2_COUNT" -gt 0 ] 2>/dev/null; then
        echo "✓ v_empsal 中 high_salary_count > 0 (+2)"
    else
        echo "✗ v_empsal 中 high_salary_count 不大于 0 (-2)"; SCORE=$((SCORE-2))
    fi
else
    # ── 达梦模式 ──
    V1_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT VIEW_NAME FROM ALL_VIEWS WHERE OWNER=UPPER('${USER_EXPECTED}') AND VIEW_NAME='V_EMPNUM';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$V1_EXISTS" = "V_EMPNUM" ]; then
        echo "✓ 视图 V_EMPNUM 存在 (+2)"
    else
        echo "✗ 视图 V_EMPNUM 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    V1_DATA=$($DMPATH/disql -s "$DM_CONN" -e "SELECT DEPT_NAME FROM ${USER_EXPECTED}.V_EMPNUM WHERE DEPT_NAME LIKE '%开发%' FETCH FIRST 1 ROWS ONLY;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$V1_DATA" ] && [ "$V1_DATA" != "no" ]; then
        echo "✓ V_EMPNUM 查询结果包含"开发部" (+2)"
    else
        echo "✗ V_EMPNUM 查询结果不含目标部门 (-2)"; SCORE=$((SCORE-2))
    fi

    V2_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT VIEW_NAME FROM ALL_VIEWS WHERE OWNER=UPPER('${USER_EXPECTED}') AND VIEW_NAME='V_EMPSAL';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$V2_EXISTS" = "V_EMPSAL" ]; then
        echo "✓ 视图 V_EMPSAL 存在 (+2)"
    else
        echo "✗ 视图 V_EMPSAL 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    V2_COUNT=$($DMPATH/disql -s "$DM_CONN" -e "SELECT HIGH_SALARY_COUNT FROM ${USER_EXPECTED}.V_EMPSAL;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$V2_COUNT" ] && [ "$V2_COUNT" -gt 0 ] 2>/dev/null; then
        echo "✓ V_EMPSAL 中 HIGH_SALARY_COUNT > 0 (+2)"
    else
        echo "✗ V_EMPSAL 中 HIGH_SALARY_COUNT 不大于 0 (-2)"; SCORE=$((SCORE-2))
    fi
fi

echo "SCORE:$SCORE"
