#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  MySQL 数据库运维考试 — 评分脚本（题目集 A）
#  变量由服务端注入，请勿修改 {{}} 占位符
#  满分 100 分，共 9 道题
# ══════════════════════════════════════════════════════════════
USERNAME="{{username}}"
PORT_EXPECTED="{{port_expected}}"
DB_EXPECTED="{{db_expected}}"
USER_EXPECTED="{{user_expected}}"
SERVER_ID_EXPECTED="{{server_id_expected}}"

MYSQL_CMD="mysql -u root -N -s"
LOG="/tmp/score_${USERNAME}_$(date +%Y%m%d_%H%M%S).log"

echo "═══════════════════════════════════════════" | tee "$LOG"
echo " MySQL 数据库运维考试 评分（题目集 A）"      | tee -a "$LOG"
echo " 学生用户：$USERNAME"                         | tee -a "$LOG"
echo " 评分时间：$(date '+%Y-%m-%d %H:%M:%S')"     | tee -a "$LOG"
echo "═══════════════════════════════════════════" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第1题：MySQL 服务管理（满分 4 分）──────────────────────
q1=4; q1_max=4
echo "第1题：MySQL 服务管理 (${q1_max}分)" | tee -a "$LOG"

if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
    echo "  ✓ MySQL 服务正在运行 (+2)" | tee -a "$LOG"
else
    echo "  ✗ MySQL 服务未运行 (-2)" | tee -a "$LOG"
    q1=$((q1-2))
fi

if systemctl is-enabled --quiet mysql 2>/dev/null || systemctl is-enabled --quiet mysqld 2>/dev/null; then
    echo "  ✓ MySQL 已设置开机自启 (+1)" | tee -a "$LOG"
else
    echo "  ✗ MySQL 未设置开机自启 (-1)" | tee -a "$LOG"
    q1=$((q1-1))
fi

if [ ! -d "/tmp/mysql_old_data" ]; then
    echo "  ✓ /tmp/mysql_old_data 已清理 (+1)" | tee -a "$LOG"
else
    echo "  ✗ /tmp/mysql_old_data 仍然存在 (-1)" | tee -a "$LOG"
    q1=$((q1-1))
fi
echo "  得分：${q1}/${q1_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第2题：数据库安装与初始化配置（满分 14 分）─────────────
q2=14; q2_max=14
echo "第2题：数据库安装与初始化配置 (${q2_max}分)" | tee -a "$LOG"

# 检查数据库是否存在
DB_EXISTS=$($MYSQL_CMD -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
if [ -n "$DB_EXISTS" ]; then
    echo "  ✓ 数据库 ${DB_EXPECTED} 存在 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 数据库 ${DB_EXPECTED} 不存在 (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi

# 检查字符集
CHARSET=$($MYSQL_CMD -e "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
if [ "$CHARSET" = "utf8mb4" ]; then
    echo "  ✓ 字符集为 utf8mb4 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 字符集不是 utf8mb4 (当前: ${CHARSET:-N/A}) (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi

# 检查端口
ACTUAL_PORT=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'port'" 2>/dev/null | awk '{print $2}')
if [ "$ACTUAL_PORT" = "$PORT_EXPECTED" ]; then
    echo "  ✓ 端口为 ${PORT_EXPECTED} (+1)" | tee -a "$LOG"
else
    echo "  ✗ 端口不匹配 (期望: ${PORT_EXPECTED}, 实际: ${ACTUAL_PORT:-N/A}) (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi

# 检查 server-id
SID=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'server_id'" 2>/dev/null | awk '{print $2}')
if [ "$SID" = "$SERVER_ID_EXPECTED" ]; then
    echo "  ✓ server-id 为 ${SERVER_ID_EXPECTED} (+1)" | tee -a "$LOG"
else
    echo "  ✗ server-id 不匹配 (期望: ${SERVER_ID_EXPECTED}, 实际: ${SID:-N/A}) (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi

# 检查 max_connections
MAXCONN=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'max_connections'" 2>/dev/null | awk '{print $2}')
if [ "$MAXCONN" = "200" ]; then
    echo "  ✓ max_connections = 200 (+1)" | tee -a "$LOG"
else
    echo "  ✗ max_connections 不是 200 (当前: ${MAXCONN:-N/A}) (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi

# 检查数据恢复
RECOVER=$($MYSQL_CMD -e "SELECT id FROM ${DB_EXPECTED}.recovery_test WHERE id=107" 2>/dev/null)
if [ "$RECOVER" = "107" ]; then
    echo "  ✓ recovery_test 数据已恢复 (id=107) (+8)" | tee -a "$LOG"
else
    echo "  ✗ recovery_test 数据未恢复 (-8)" | tee -a "$LOG"
    q2=$((q2-8))
fi

# 检查导入文件
if [ -f "/var/lib/mysql_backup/examdata.sql" ]; then
    echo "  ✓ examdata.sql 存在 (+1)" | tee -a "$LOG"
else
    echo "  ✗ examdata.sql 不存在 (-1)" | tee -a "$LOG"
    q2=$((q2-1))
fi
echo "  得分：${q2}/${q2_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第3题：用户与权限管理（满分 8 分）─────────────────────
q3=8; q3_max=8
echo "第3题：用户与权限管理 (${q3_max}分)" | tee -a "$LOG"

# 检查数据库排序规则
COLLATION=$($MYSQL_CMD -e "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
if echo "$COLLATION" | grep -qi "utf8mb4"; then
    echo "  ✓ 数据库字符集配置正确 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 数据库字符集配置不正确 (-1)" | tee -a "$LOG"
    q3=$((q3-1))
fi

# 检查用户是否存在
USER_EXISTS=$($MYSQL_CMD -e "SELECT User FROM mysql.user WHERE User='${USER_EXPECTED}' LIMIT 1" 2>/dev/null)
if [ -n "$USER_EXISTS" ]; then
    echo "  ✓ 用户 ${USER_EXPECTED} 存在 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 用户 ${USER_EXPECTED} 不存在 (-1)" | tee -a "$LOG"
    q3=$((q3-1))
fi

# 检查密码过期策略
PWD_LIFE=$($MYSQL_CMD -e "SELECT password_lifetime FROM mysql.user WHERE User='${USER_EXPECTED}' LIMIT 1" 2>/dev/null)
if [ "$PWD_LIFE" = "120" ]; then
    echo "  ✓ 密码过期策略 120 天 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 密码过期策略不正确 (当前: ${PWD_LIFE:-未设置}) (-1)" | tee -a "$LOG"
    q3=$((q3-1))
fi

# 检查权限
GRANTS=$($MYSQL_CMD -e "SHOW GRANTS FOR '${USER_EXPECTED}'@'%'" 2>/dev/null)
for priv in "SELECT" "CREATE" "CREATE ROUTINE" "EXECUTE" "DELETE"; do
    if echo "$GRANTS" | grep -qi "$priv"; then
        echo "  ✓ 拥有 ${priv} 权限 (+1)" | tee -a "$LOG"
    else
        echo "  ✗ 缺少 ${priv} 权限 (-1)" | tee -a "$LOG"
        q3=$((q3-1))
    fi
done
echo "  得分：${q3}/${q3_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第4题：表管理与数据导入导出（满分 18 分）───────────────
q4=18; q4_max=18
echo "第4题：表管理与数据导入导出 (${q4_max}分)" | tee -a "$LOG"

# tab_dept
DEPT_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.tab_dept" 2>/dev/null)
if [ "$DEPT_COUNT" = "46" ]; then
    echo "  ✓ tab_dept 有 46 条记录 (+4)" | tee -a "$LOG"
else
    echo "  ✗ tab_dept 记录数不正确 (期望: 46, 实际: ${DEPT_COUNT:-表不存在}) (-4)" | tee -a "$LOG"
    q4=$((q4-4))
fi

# tab_emp
EMP_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.tab_emp" 2>/dev/null)
if [ -n "$EMP_COUNT" ] && [ "$EMP_COUNT" -ge 856 ] 2>/dev/null; then
    echo "  ✓ tab_emp 有 ${EMP_COUNT} 条记录 (≥856) (+4)" | tee -a "$LOG"
else
    echo "  ✗ tab_emp 记录数不足 (期望: ≥856, 实际: ${EMP_COUNT:-表不存在}) (-4)" | tee -a "$LOG"
    q4=$((q4-4))
fi

# create_time 列
COL_EXISTS=$($MYSQL_CMD -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND COLUMN_NAME='create_time'" 2>/dev/null)
if [ "$COL_EXISTS" = "create_time" ]; then
    echo "  ✓ tab_emp 有 create_time 列 (+2)" | tee -a "$LOG"
else
    echo "  ✗ tab_emp 缺少 create_time 列 (-2)" | tee -a "$LOG"
    q4=$((q4-2))
fi

# create_time 默认值
COL_DEFAULT=$($MYSQL_CMD -e "SELECT COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND COLUMN_NAME='create_time'" 2>/dev/null)
if echo "$COL_DEFAULT" | grep -qi "CURRENT_TIMESTAMP"; then
    echo "  ✓ create_time 默认值为 CURRENT_TIMESTAMP (+2)" | tee -a "$LOG"
else
    echo "  ✗ create_time 默认值不正确 (当前: ${COL_DEFAULT:-无}) (-2)" | tee -a "$LOG"
    q4=$((q4-2))
fi

# CSV 导出
CSV_FILE="/var/lib/mysql-files/tab_emp.csv"
if [ -f "$CSV_FILE" ]; then
    echo "  ✓ CSV 导出文件存在 (+4)" | tee -a "$LOG"
    CSV_SIZE=$(stat -c%s "$CSV_FILE" 2>/dev/null)
    if [ -n "$CSV_SIZE" ] && [ "$CSV_SIZE" -gt 100 ]; then
        echo "  ✓ CSV 文件内容非空 (${CSV_SIZE} bytes) (+2)" | tee -a "$LOG"
    else
        echo "  ✗ CSV 文件为空或过小 (-2)" | tee -a "$LOG"
        q4=$((q4-2))
    fi
else
    echo "  ✗ CSV 导出文件不存在: ${CSV_FILE} (-6)" | tee -a "$LOG"
    q4=$((q4-6))
fi
echo "  得分：${q4}/${q4_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第5题：视图管理（满分 8 分）───────────────────────────
q5=8; q5_max=8
echo "第5题：视图管理 (${q5_max}分)" | tee -a "$LOG"

# v_empnum
V1_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='v_empnum'" 2>/dev/null)
if [ "$V1_EXISTS" = "v_empnum" ]; then
    echo "  ✓ 视图 v_empnum 存在 (+2)" | tee -a "$LOG"
    V1_DATA=$($MYSQL_CMD -e "SELECT dept_name FROM ${DB_EXPECTED}.v_empnum LIMIT 5" 2>/dev/null)
    if echo "$V1_DATA" | grep -qiE "开发部|部门1"; then
        echo "  ✓ v_empnum 包含正确数据 (+2)" | tee -a "$LOG"
    else
        echo "  ✗ v_empnum 未查到"开发部"或"部门1" (-2)" | tee -a "$LOG"
        q5=$((q5-2))
    fi
else
    echo "  ✗ 视图 v_empnum 不存在 (-4)" | tee -a "$LOG"
    q5=$((q5-4))
fi

# v_empsal
V2_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='v_empsal'" 2>/dev/null)
if [ "$V2_EXISTS" = "v_empsal" ]; then
    echo "  ✓ 视图 v_empsal 存在 (+2)" | tee -a "$LOG"
    V2_COUNT=$($MYSQL_CMD -e "SELECT high_salary_count FROM ${DB_EXPECTED}.v_empsal" 2>/dev/null)
    if [ -n "$V2_COUNT" ] && [ "$V2_COUNT" -gt 0 ] 2>/dev/null; then
        echo "  ✓ v_empsal 高薪人数 = ${V2_COUNT} (+2)" | tee -a "$LOG"
    else
        echo "  ✗ v_empsal 高薪人数为 0 或查询失败 (-2)" | tee -a "$LOG"
        q5=$((q5-2))
    fi
else
    echo "  ✗ 视图 v_empsal 不存在 (-4)" | tee -a "$LOG"
    q5=$((q5-4))
fi
echo "  得分：${q5}/${q5_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第6题：存储过程与触发器（满分 20 分）───────────────────
q6=20; q6_max=20
echo "第6题：存储过程与触发器 (${q6_max}分)" | tee -a "$LOG"

# 存储过程
PROC_EXISTS=$($MYSQL_CMD -e "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='${DB_EXPECTED}' AND ROUTINE_NAME='sp_emp_salary_sum' AND ROUTINE_TYPE='PROCEDURE'" 2>/dev/null)
if [ "$PROC_EXISTS" = "sp_emp_salary_sum" ]; then
    echo "  ✓ 存储过程 sp_emp_salary_sum 存在 (+5)" | tee -a "$LOG"
    # 调用测试
    PROC_RESULT=$($MYSQL_CMD -e "CALL ${DB_EXPECTED}.sp_emp_salary_sum(1, @t); SELECT @t" 2>/dev/null)
    if [ -n "$PROC_RESULT" ] && [ "$PROC_RESULT" != "NULL" ]; then
        echo "  ✓ 存储过程调用成功 (结果: ${PROC_RESULT}) (+5)" | tee -a "$LOG"
    else
        echo "  ✗ 存储过程调用失败或返回 NULL (-5)" | tee -a "$LOG"
        q6=$((q6-5))
    fi
else
    echo "  ✗ 存储过程 sp_emp_salary_sum 不存在 (-10)" | tee -a "$LOG"
    q6=$((q6-10))
fi

# t_eventlog 表
TLOG_EXISTS=$($MYSQL_CMD -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='t_eventlog'" 2>/dev/null)
if [ "$TLOG_EXISTS" = "t_eventlog" ]; then
    echo "  ✓ 事件日志表 t_eventlog 存在 (+2)" | tee -a "$LOG"
else
    echo "  ✗ 事件日志表 t_eventlog 不存在 (-2)" | tee -a "$LOG"
    q6=$((q6-2))
fi

# 触发器
TRIG_EXISTS=$($MYSQL_CMD -e "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='${DB_EXPECTED}' AND TRIGGER_NAME='tr_eventlog'" 2>/dev/null)
if [ "$TRIG_EXISTS" = "tr_eventlog" ]; then
    echo "  ✓ 触发器 tr_eventlog 存在 (+4)" | tee -a "$LOG"

    TRIG_DEFINER=$($MYSQL_CMD -e "SELECT DEFINER FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='${DB_EXPECTED}' AND TRIGGER_NAME='tr_eventlog'" 2>/dev/null)
    if echo "$TRIG_DEFINER" | grep -qiE "${USER_EXPECTED}|root"; then
        echo "  ✓ 触发器属于正确用户 (+2)" | tee -a "$LOG"
    else
        echo "  ✗ 触发器 DEFINER 不正确 (${TRIG_DEFINER}) (-2)" | tee -a "$LOG"
        q6=$((q6-2))
    fi

    # 测试触发器：插入一条后检查 t_eventlog
    $MYSQL_CMD -e "INSERT INTO ${DB_EXPECTED}.tab_emp(employee_name,dept_id,salary,hire_date) VALUES('_score_test_',1,1000,CURDATE())" 2>/dev/null
    TLOG_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM ${DB_EXPECTED}.t_eventlog WHERE event_data LIKE '%_score_test_%'" 2>/dev/null)
    if [ -n "$TLOG_COUNT" ] && [ "$TLOG_COUNT" -gt 0 ] 2>/dev/null; then
        echo "  ✓ 触发器触发成功（t_eventlog 有记录） (+2)" | tee -a "$LOG"
    else
        echo "  ✗ 触发器未触发（t_eventlog 无记录） (-2)" | tee -a "$LOG"
        q6=$((q6-2))
    fi
    # 清理测试数据
    $MYSQL_CMD -e "DELETE FROM ${DB_EXPECTED}.tab_emp WHERE employee_name='_score_test_'" 2>/dev/null
    $MYSQL_CMD -e "DELETE FROM ${DB_EXPECTED}.t_eventlog WHERE event_data LIKE '%_score_test_%'" 2>/dev/null
else
    echo "  ✗ 触发器 tr_eventlog 不存在 (-8)" | tee -a "$LOG"
    q6=$((q6-8))
fi
echo "  得分：${q6}/${q6_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第7题：定时任务（满分 8 分）───────────────────────────
q7=8; q7_max=8
echo "第7题：定时任务 (${q7_max}分)" | tee -a "$LOG"

EVENT_SCHED=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'event_scheduler'" 2>/dev/null | awk '{print $2}')
if [ "$EVENT_SCHED" = "ON" ]; then
    echo "  ✓ Event Scheduler 已开启 (+2)" | tee -a "$LOG"
else
    echo "  ✗ Event Scheduler 未开启 (当前: ${EVENT_SCHED:-OFF}) (-2)" | tee -a "$LOG"
    q7=$((q7-2))
fi

EVT1=$($MYSQL_CMD -e "SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA='${DB_EXPECTED}' AND EVENT_NAME='evt_daily_backup'" 2>/dev/null)
if [ "$EVT1" = "evt_daily_backup" ]; then
    echo "  ✓ 事件 evt_daily_backup 存在 (+3)" | tee -a "$LOG"
else
    echo "  ✗ 事件 evt_daily_backup 不存在 (-3)" | tee -a "$LOG"
    q7=$((q7-3))
fi

EVT2=$($MYSQL_CMD -e "SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA='${DB_EXPECTED}' AND EVENT_NAME='evt_weekly_cleanup'" 2>/dev/null)
if [ "$EVT2" = "evt_weekly_cleanup" ]; then
    echo "  ✓ 事件 evt_weekly_cleanup 存在 (+3)" | tee -a "$LOG"
else
    echo "  ✗ 事件 evt_weekly_cleanup 不存在 (-3)" | tee -a "$LOG"
    q7=$((q7-3))
fi
echo "  得分：${q7}/${q7_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第8题：性能优化（满分 10 分）──────────────────────────
q8=10; q8_max=10
echo "第8题：性能优化 (${q8_max}分)" | tee -a "$LOG"

# 索引
IDX_EXISTS=$($MYSQL_CMD -e "SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND INDEX_NAME='ix_emp_empname' LIMIT 1" 2>/dev/null)
if [ "$IDX_EXISTS" = "ix_emp_empname" ]; then
    echo "  ✓ 索引 ix_emp_empname 存在 (+3)" | tee -a "$LOG"
    IDX_COL=$($MYSQL_CMD -e "SELECT COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp' AND INDEX_NAME='ix_emp_empname' LIMIT 1" 2>/dev/null)
    if [ "$IDX_COL" = "employee_name" ]; then
        echo "  ✓ 索引列为 employee_name (+1)" | tee -a "$LOG"
    else
        echo "  ✗ 索引列不正确 (${IDX_COL}) (-1)" | tee -a "$LOG"
        q8=$((q8-1))
    fi
else
    echo "  ✗ 索引 ix_emp_empname 不存在 (-4)" | tee -a "$LOG"
    q8=$((q8-4))
fi

# 统计信息
STAT_TIME=$($MYSQL_CMD -e "SELECT UPDATE_TIME FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_EXPECTED}' AND TABLE_NAME='tab_emp'" 2>/dev/null)
if [ -n "$STAT_TIME" ] && [ "$STAT_TIME" != "NULL" ]; then
    echo "  ✓ tab_emp 统计信息已更新 (+3)" | tee -a "$LOG"
else
    echo "  ✗ tab_emp 统计信息未更新 (-3)" | tee -a "$LOG"
    q8=$((q8-3))
fi

# innodb_buffer_pool_size
BUFPOOL=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size'" 2>/dev/null | awk '{print $2}')
if [ -n "$BUFPOOL" ] && [ "$BUFPOOL" -ge 268435456 ] 2>/dev/null; then
    echo "  ✓ innodb_buffer_pool_size ≥ 256M (${BUFPOOL}) (+3)" | tee -a "$LOG"
else
    echo "  ✗ innodb_buffer_pool_size < 256M (当前: ${BUFPOOL:-N/A}) (-3)" | tee -a "$LOG"
    q8=$((q8-3))
fi
echo "  得分：${q8}/${q8_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── 第9题：数据库安全与备份恢复（满分 10 分）───────────────
q9=10; q9_max=10
echo "第9题：数据库安全与备份恢复 (${q9_max}分)" | tee -a "$LOG"

# 二进制日志
BINLOG=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'log_bin'" 2>/dev/null | awk '{print $2}')
if [ "$BINLOG" = "ON" ]; then
    echo "  ✓ 二进制日志已开启 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 二进制日志未开启 (-1)" | tee -a "$LOG"
    q9=$((q9-1))
fi

BINLOG_FMT=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'binlog_format'" 2>/dev/null | awk '{print $2}')
if [ "$BINLOG_FMT" = "ROW" ]; then
    echo "  ✓ binlog_format = ROW (+1)" | tee -a "$LOG"
else
    echo "  ✗ binlog_format 不是 ROW (当前: ${BINLOG_FMT:-N/A}) (-1)" | tee -a "$LOG"
    q9=$((q9-1))
fi

# binlog 过期
EXPIRE_SEC=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'binlog_expire_logs_seconds'" 2>/dev/null | awk '{print $2}')
EXPIRE_DAY=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'expire_logs_days'" 2>/dev/null | awk '{print $2}')
if ([ -n "$EXPIRE_SEC" ] && [ "$EXPIRE_SEC" -gt 0 ] 2>/dev/null) || ([ -n "$EXPIRE_DAY" ] && [ "$EXPIRE_DAY" -gt 0 ] 2>/dev/null); then
    echo "  ✓ 二进制日志过期时间已设置 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 二进制日志过期时间未设置 (-1)" | tee -a "$LOG"
    q9=$((q9-1))
fi

# 备份目录
if [ -d "/var/lib/mysql_backup" ]; then
    echo "  ✓ 备份目录存在 (+1)" | tee -a "$LOG"
else
    echo "  ✗ 备份目录不存在 (-1)" | tee -a "$LOG"
    q9=$((q9-1))
fi

# 全库备份
if [ -f "/var/lib/mysql_backup/full_backup.sql" ]; then
    FSIZE=$(stat -c%s "/var/lib/mysql_backup/full_backup.sql" 2>/dev/null)
    if [ -n "$FSIZE" ] && [ "$FSIZE" -gt 1000 ]; then
        echo "  ✓ 全库备份文件存在 (${FSIZE} bytes) (+3)" | tee -a "$LOG"
    else
        echo "  ✗ 全库备份文件过小 (-3)" | tee -a "$LOG"
        q9=$((q9-3))
    fi
else
    echo "  ✗ 全库备份文件不存在 (-3)" | tee -a "$LOG"
    q9=$((q9-3))
fi

# 单库备份
if [ -f "/var/lib/mysql_backup/${DB_EXPECTED}.sql" ]; then
    DBSIZE=$(stat -c%s "/var/lib/mysql_backup/${DB_EXPECTED}.sql" 2>/dev/null)
    if [ -n "$DBSIZE" ] && [ "$DBSIZE" -gt 100 ]; then
        echo "  ✓ ${DB_EXPECTED} 库备份文件存在 (${DBSIZE} bytes) (+3)" | tee -a "$LOG"
    else
        echo "  ✗ ${DB_EXPECTED} 库备份文件过小 (-3)" | tee -a "$LOG"
        q9=$((q9-3))
    fi
else
    echo "  ✗ ${DB_EXPECTED} 库备份文件不存在 (-3)" | tee -a "$LOG"
    q9=$((q9-3))
fi
echo "  得分：${q9}/${q9_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ═══════════════════════════════════════════════
#  汇总
# ═══════════════════════════════════════════════
total=$((q1+q2+q3+q4+q5+q6+q7+q8+q9))
echo "═══════════════════════════════════════════" | tee -a "$LOG"
echo "  各题得分：" | tee -a "$LOG"
echo "    第1题（服务管理）：    ${q1}/${q1_max}" | tee -a "$LOG"
echo "    第2题（安装配置）：    ${q2}/${q2_max}" | tee -a "$LOG"
echo "    第3题（用户权限）：    ${q3}/${q3_max}" | tee -a "$LOG"
echo "    第4题（表与导出）：    ${q4}/${q4_max}" | tee -a "$LOG"
echo "    第5题（视图管理）：    ${q5}/${q5_max}" | tee -a "$LOG"
echo "    第6题（过程触发器）：  ${q6}/${q6_max}" | tee -a "$LOG"
echo "    第7题（定时任务）：    ${q7}/${q7_max}" | tee -a "$LOG"
echo "    第8题（性能优化）：    ${q8}/${q8_max}" | tee -a "$LOG"
echo "    第9题（安全备份）：    ${q9}/${q9_max}" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "  总分：${total}/100" | tee -a "$LOG"
echo "═══════════════════════════════════════════" | tee -a "$LOG"

# 机器可读输出
echo "Q1_SCORE=${q1}"
echo "Q2_SCORE=${q2}"
echo "Q3_SCORE=${q3}"
echo "Q4_SCORE=${q4}"
echo "Q5_SCORE=${q5}"
echo "Q6_SCORE=${q6}"
echo "Q7_SCORE=${q7}"
echo "Q8_SCORE=${q8}"
echo "Q9_SCORE=${q9}"
echo "TOTAL_SCORE=${total}"
echo "SCORE:${total}:${USERNAME}"
