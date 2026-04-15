#!/bin/bash
# 存储过程与触发器检查（满分 20 分）
# 自动适配 MySQL / 达梦数据库
SCORE=20

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
    SP_EXISTS=$($MYSQL_CMD -e "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='${DB_EXPECTED}' AND ROUTINE_NAME='sp_emp_salary_sum' AND ROUTINE_TYPE='PROCEDURE'" 2>/dev/null)
    if [ -n "$SP_EXISTS" ]; then
        echo "✓ 存储过程 sp_emp_salary_sum 存在 (+5)"
    else
        echo "✗ 存储过程 sp_emp_salary_sum 不存在 (-5)"; SCORE=$((SCORE-5))
    fi

    SP_RESULT=$($MYSQL_CMD -e "CALL ${DB_EXPECTED}.sp_emp_salary_sum(1, @total); SELECT @total" 2>/dev/null)
    if [ -n "$SP_RESULT" ] && [ "$SP_RESULT" != "NULL" ] && [ "$SP_RESULT" != "0" ]; then
        echo "✓ 存储过程调用成功，返回 ${SP_RESULT} (+5)"
    else
        echo "✗ 存储过程调用失败或返回空值 (-5)"; SCORE=$((SCORE-5))
    fi

    TBL_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='t_eventlog'" 2>/dev/null)
    if [ -n "$TBL_EXISTS" ]; then
        echo "✓ 事件日志表 t_eventlog 存在 (+2)"
    else
        echo "✗ 事件日志表 t_eventlog 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    TR_EXISTS=$($MYSQL_CMD -e "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='${DB_EXPECTED}' AND TRIGGER_NAME='tr_eventlog'" 2>/dev/null)
    if [ -n "$TR_EXISTS" ]; then
        echo "✓ 触发器 tr_eventlog 存在 (+4)"
        $MYSQL_CMD -e "INSERT INTO ${DB_EXPECTED}.tab_emp(employee_name,dept_id,salary,hire_date) VALUES('_score_test_',1,1000,CURDATE())" 2>/dev/null
        TLOG_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.t_eventlog WHERE event_data LIKE '%_score_test_%'" 2>/dev/null)
        if [ -n "$TLOG_COUNT" ] && [ "$TLOG_COUNT" -gt 0 ] 2>/dev/null; then
            echo "✓ 触发器触发成功 (+4)"
        else
            echo "✗ 触发器未触发 (-4)"; SCORE=$((SCORE-4))
        fi
        $MYSQL_CMD -e "DELETE FROM ${DB_EXPECTED}.tab_emp WHERE employee_name='_score_test_'" 2>/dev/null
        $MYSQL_CMD -e "DELETE FROM ${DB_EXPECTED}.t_eventlog WHERE event_data LIKE '%_score_test_%'" 2>/dev/null
    else
        echo "✗ 触发器 tr_eventlog 不存在 (-8)"; SCORE=$((SCORE-8))
    fi
else
    # ── 达梦模式 ──
    # 存储过程/函数检查（达梦用 PROCEDURE 或 FUNCTION）
    PROC_RESULT=$($DMPATH/disql -s "$DM_CONN" -e "
        DECLARE v_total NUMBER;
        BEGIN ${USER_EXPECTED}.SP_EMP_SALARY_SUM(1, v_total); DBMS_OUTPUT.PUT_LINE(v_total); END;
    " 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$PROC_RESULT" ] && [ "$PROC_RESULT" != "0" ] && echo "$PROC_RESULT" | grep -qE '^[0-9]+'; then
        echo "✓ 存储过程 SP_EMP_SALARY_SUM 存在且返回 ${PROC_RESULT} (+10)"
    else
        SP_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT OBJECT_NAME FROM ALL_PROCEDURES WHERE OWNER=UPPER('${USER_EXPECTED}') AND OBJECT_NAME='SP_EMP_SALARY_SUM';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
        if [ "$SP_EXISTS" = "SP_EMP_SALARY_SUM" ]; then
            echo "✓ 存储过程 SP_EMP_SALARY_SUM 存在 (+5)"
            echo "✗ 但调用返回异常 (-5)"; SCORE=$((SCORE-5))
        else
            echo "✗ 存储过程 SP_EMP_SALARY_SUM 不存在 (-10)"; SCORE=$((SCORE-10))
        fi
    fi

    # 事件日志表
    TBL_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER=UPPER('${USER_EXPECTED}') AND TABLE_NAME='T_EVENTLOG';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$TBL_EXISTS" = "T_EVENTLOG" ]; then
        echo "✓ 事件日志表 T_EVENTLOG 存在 (+2)"
    else
        echo "✗ 事件日志表 T_EVENTLOG 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    # 触发器
    TR_EXISTS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT TRIGGER_NAME FROM ALL_TRIGGERS WHERE OWNER=UPPER('${USER_EXPECTED}') AND TRIGGER_NAME='TR_EVENTLOG';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$TR_EXISTS" = "TR_EVENTLOG" ]; then
        echo "✓ 触发器 TR_EVENTLOG 存在 (+4)"

        # 测试触发器是否工作
        $DMPATH/disql -s "$DM_CONN" -e "INSERT INTO ${USER_EXPECTED}.TAB_EMP(EMPLOYEE_NAME,DEPT_ID,SALARY,HIRE_DATE) VALUES('_score_test_',1,1000,SYSDATE);" 2>/dev/null
        TLOG=$($DMPATH/disql -s "$DM_CONN" -e "SELECT COUNT(*) FROM ${USER_EXPECTED}.T_EVENTLOG WHERE EVENT_DATA LIKE '%_score_test_%';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
        if [ -n "$TLOG" ] && [ "$TLOG" -gt 0 ] 2>/dev/null; then
            echo "✓ 触发器触发成功 (+4)"
        else
            echo "✗ 触发器未触发 (-4)"; SCORE=$((SCORE-4))
        fi
        $DMPATH/disql -s "$DM_CONN" -e "DELETE FROM ${USER_EXPECTED}.TAB_EMP WHERE EMPLOYEE_NAME='_score_test_';" 2>/dev/null
        $DMPATH/disql -s "$DM_CONN" -e "DELETE FROM ${USER_EXPECTED}.T_EVENTLOG WHERE EVENT_DATA LIKE '%_score_test_%';" 2>/dev/null
    else
        echo "✗ 触发器 TR_EVENTLOG 不存在 (-8)"; SCORE=$((SCORE-8))
    fi
fi

echo "SCORE:$SCORE"
