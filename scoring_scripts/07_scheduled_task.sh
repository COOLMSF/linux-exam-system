#!/bin/bash
# 定时任务检查（满分 8 分）
# 自动适配 MySQL Event Scheduler / 达梦 DBMS_JOB
SCORE=8

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
    EVENT_STATUS=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'event_scheduler'" 2>/dev/null | awk '{print $2}')
    if [ "$EVENT_STATUS" = "ON" ]; then
        echo "✓ 事件调度器已开启 (+2)"
    else
        echo "✗ 事件调度器未开启 (当前: ${EVENT_STATUS:-N/A}) (-2)"; SCORE=$((SCORE-2))
    fi

    EVT_EXISTS=$($MYSQL_CMD -e "SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA='${DB_EXPECTED}' AND EVENT_NAME='evt_daily_cleanup'" 2>/dev/null)
    if [ -n "$EVT_EXISTS" ]; then
        echo "✓ 定时事件 evt_daily_cleanup 存在 (+3)"
    else
        echo "✗ 定时事件 evt_daily_cleanup 不存在 (-3)"; SCORE=$((SCORE-3))
    fi

    EVT_STATUS=$($MYSQL_CMD -e "SELECT STATUS FROM information_schema.EVENTS WHERE EVENT_SCHEMA='${DB_EXPECTED}' AND EVENT_NAME='evt_daily_cleanup'" 2>/dev/null)
    if [ "$EVT_STATUS" = "ENABLED" ]; then
        echo "✓ 定时事件状态为 ENABLED (+3)"
    else
        echo "✗ 定时事件状态不是 ENABLED (当前: ${EVT_STATUS:-N/A}) (-3)"; SCORE=$((SCORE-3))
    fi
else
    # ── 达梦模式 ──
    # 检查作业 FULLBAK（每日全库备份）
    JOB1=$($DMPATH/disql -s "$DM_CONN" -e "SELECT NAME FROM SYSJOB.SYSJOBS WHERE UPPER(NAME)='FULLBAK';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$JOB1" ]; then
        echo "✓ 定时作业 FULLBAK 存在 (+4)"
    else
        echo "✗ 定时作业 FULLBAK 不存在 (-4)"; SCORE=$((SCORE-4))
    fi

    # 检查作业 DELARCH（定期清理归档日志）
    JOB2=$($DMPATH/disql -s "$DM_CONN" -e "SELECT NAME FROM SYSJOB.SYSJOBS WHERE UPPER(NAME)='DELARCH';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$JOB2" ]; then
        echo "✓ 定时作业 DELARCH 存在 (+4)"
    else
        echo "✗ 定时作业 DELARCH 不存在 (-4)"; SCORE=$((SCORE-4))
    fi
fi

echo "SCORE:$SCORE"
