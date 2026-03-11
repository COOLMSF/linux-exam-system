#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Linux 考试系统 - 达梦数据库 DM8 评分脚本模板
# 版本: 1.0.0
# 说明: 此脚本由系统根据评分规则自动生成，请勿手动修改
#       {{username}} 占位符会被替换为实际学生用户名
# ═══════════════════════════════════════════════════════════════

# 全局变量
EXAM_USER="{{username}}"
TOTAL_SCORE=0
FAIL_MESSAGES=()

# ─────────────────────────────────────────────
# 工具函数
# ─────────────────────────────────────────────

# 检查文件是否存在（存在则扣分）
check_file_exists() {
    local description="$1"
    local file_path="$2"
    local deduction="$3"
    local fail_msg="$4"

    if [ -e "$file_path" ]; then
        TOTAL_SCORE=$((TOTAL_SCORE - deduction))
        FAIL_MESSAGES+=("${fail_msg:-$description}:-$deduction")
    fi
}

# 检查文件是否不存在（不存在则扣分）
check_file_not_exists() {
    local description="$1"
    local file_path="$2"
    local deduction="$3"
    local fail_msg="$4"

    if [ ! -e "$file_path" ]; then
        TOTAL_SCORE=$((TOTAL_SCORE - deduction))
        FAIL_MESSAGES+=("${fail_msg:-$description}:-$deduction")
    fi
}

# 检查命令输出（输出不符合预期则扣分）
check_command_output() {
    local description="$1"
    local command="$2"
    local expected="$3"
    local operator="$4"   # eq, ne, contains, gt, lt
    local deduction="$5"
    local fail_msg="$6"

    local actual
    actual=$(eval "$command" 2>/dev/null | tr -d '[:space:]')
    local expected_clean
    expected_clean=$(echo "$expected" | tr -d '[:space:]')

    local passed=false
    case "$operator" in
        eq)       [ "$actual" = "$expected_clean" ] && passed=true ;;
        ne)       [ "$actual" != "$expected_clean" ] && passed=true ;;
        contains) echo "$actual" | grep -q "$expected_clean" && passed=true ;;
        gt)       [ "$actual" -gt "$expected_clean" ] 2>/dev/null && passed=true ;;
        lt)       [ "$actual" -lt "$expected_clean" ] 2>/dev/null && passed=true ;;
        *)        [ "$actual" = "$expected_clean" ] && passed=true ;;
    esac

    if [ "$passed" = false ]; then
        TOTAL_SCORE=$((TOTAL_SCORE - deduction))
        FAIL_MESSAGES+=("${fail_msg:-$description}:-$deduction")
    fi
}

# 执行 SQL 查询检查（通过 disql 工具）
check_db_query() {
    local description="$1"
    local sql_file="$2"
    local expected="$3"
    local operator="$4"
    local deduction="$5"
    local fail_msg="$6"

    if [ ! -f "$sql_file" ]; then
        TOTAL_SCORE=$((TOTAL_SCORE - deduction))
        FAIL_MESSAGES+=("${fail_msg:-SQL文件不存在}:-$deduction")
        return
    fi

    # 使用 disql 执行 SQL（达梦数据库命令行工具）
    local actual
    actual=$(disql SYSDBA/SYSDBA@localhost:5236 \`"$sql_file" 2>/dev/null | grep -v "^$" | tail -1 | tr -d '[:space:]')

    check_command_output "$description" "echo '$actual'" "$expected" "$operator" "$deduction" "$fail_msg"
}

# 执行自定义脚本检查
check_custom_script() {
    local description="$1"
    local script_content="$2"
    local deduction="$3"
    local fail_msg="$4"

    local tmp_script
    tmp_script=$(mktemp /tmp/exam_check_XXXXXX.sh)
    echo "$script_content" > "$tmp_script"
    chmod +x "$tmp_script"

    if ! bash "$tmp_script" 2>/dev/null; then
        TOTAL_SCORE=$((TOTAL_SCORE - deduction))
        FAIL_MESSAGES+=("${fail_msg:-$description}:-$deduction")
    fi
    rm -f "$tmp_script"
}

# ─────────────────────────────────────────────
# 输出结果（JSON 格式，供 Agent 解析）
# ─────────────────────────────────────────────
output_result() {
    echo ""
    echo "=== 评分结果 ==="
    echo "总分: $TOTAL_SCORE"
    echo ""

    # 输出失败项
    if [ ${#FAIL_MESSAGES[@]} -gt 0 ]; then
        echo "扣分详情:"
        for msg in "${FAIL_MESSAGES[@]}"; do
            echo "  $msg"
        done
    fi

    # 输出 JSON 格式（供程序解析）
    local details_json="["
    local first=true
    for msg in "${FAIL_MESSAGES[@]}"; do
        if [ "$first" = false ]; then
            details_json+=","
        fi
        local desc="${msg%:-*}"
        local ded="${msg##*:-}"
        details_json+="{\"description\":\"$desc\",\"deduction\":$ded,\"passed\":false}"
        first=false
    done
    details_json+="]"

    echo ""
    echo "{\"totalScore\":$TOTAL_SCORE,\"details\":$details_json}"
}

# ═══════════════════════════════════════════════════════════════
# 以下为各题目评分规则（由系统根据配置自动生成）
# ═══════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────
# 第1题: 数据库卸载 (初始分: 10分)
# ─────────────────────────────────────────────
Q1_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q1_SCORE))

# 检查项1: 数据库软件目录不应存在（如仍存在则扣4分）
check_file_exists \
    "数据库软件未成功卸载" \
    "/home/dmdba/dmdbms/jar" \
    4 \
    "数据库软件未成功卸载:-4"

# 检查项2: 数据库服务不应运行（如仍运行则扣3分）
check_command_output \
    "数据库服务仍在运行" \
    "systemctl is-active DmServiceDMSERVER 2>/dev/null || echo inactive" \
    "inactive" \
    "eq" \
    3 \
    "数据库服务未停止:-3"

# 检查项3: 数据库进程不应存在（如仍存在则扣3分）
check_command_output \
    "数据库进程仍在运行" \
    "pgrep -c dmserver 2>/dev/null || echo 0" \
    "0" \
    "eq" \
    3 \
    "数据库进程未终止:-3"

# ─────────────────────────────────────────────
# 第2题: 数据库安装 (初始分: 10分)
# ─────────────────────────────────────────────
Q2_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q2_SCORE))

# 检查项1: 数据库安装目录应存在
check_file_not_exists \
    "数据库未安装" \
    "/home/dmdba/dmdbms/bin/dmserver" \
    5 \
    "数据库未成功安装:-5"

# 检查项2: dmdba 用户应存在
check_command_output \
    "dmdba用户不存在" \
    "id dmdba 2>/dev/null && echo exists || echo missing" \
    "exists" \
    "contains" \
    3 \
    "dmdba用户未创建:-3"

# 检查项3: 数据库服务应注册
check_command_output \
    "数据库服务未注册" \
    "systemctl list-unit-files | grep -c DmService || echo 0" \
    "0" \
    "ne" \
    2 \
    "数据库服务未注册:-2"

# ─────────────────────────────────────────────
# 第3题: 数据库初始化配置 (初始分: 10分)
# ─────────────────────────────────────────────
Q3_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q3_SCORE))

# 检查项1: 数据库名称配置
check_db_query \
    "数据库名称配置错误" \
    "/var/local/sc/rw_dbname.sql" \
    "DAMENG" \
    "eq" \
    4 \
    "数据库名称配置错误:-4"

# 检查项2: 字符集配置
check_db_query \
    "字符集配置错误" \
    "/var/local/sc/rw_charset.sql" \
    "GB18030" \
    "eq" \
    3 \
    "字符集配置错误:-3"

# 检查项3: 页大小配置
check_db_query \
    "页大小配置错误" \
    "/var/local/sc/rw_pagesize.sql" \
    "32" \
    "eq" \
    3 \
    "页大小配置错误:-3"

# ─────────────────────────────────────────────
# 第4题: 表空间管理 (初始分: 10分)
# ─────────────────────────────────────────────
Q4_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q4_SCORE))

check_db_query \
    "表空间未创建" \
    "/var/local/sc/rw_tablespace.sql" \
    "EXAM_TS" \
    "contains" \
    5 \
    "EXAM_TS表空间未创建:-5"

check_db_query \
    "表空间大小不符" \
    "/var/local/sc/rw_ts_size.sql" \
    "512" \
    "ge" \
    5 \
    "表空间大小不符合要求:-5"

# ─────────────────────────────────────────────
# 第5题: 用户与权限管理 (初始分: 10分)
# ─────────────────────────────────────────────
Q5_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q5_SCORE))

check_db_query \
    "考试用户未创建" \
    "/var/local/sc/rw_user_${EXAM_USER}.sql" \
    "${EXAM_USER}" \
    "contains" \
    5 \
    "用户 ${EXAM_USER} 未创建:-5"

check_db_query \
    "用户权限未授予" \
    "/var/local/sc/rw_user_priv.sql" \
    "DBA" \
    "contains" \
    5 \
    "用户权限未正确授予:-5"

# ─────────────────────────────────────────────
# 第6题: 表创建与数据操作 (初始分: 15分)
# ─────────────────────────────────────────────
Q6_SCORE=15
TOTAL_SCORE=$((TOTAL_SCORE + Q6_SCORE))

check_db_query \
    "数据表未创建" \
    "/var/local/sc/rw_table_exists.sql" \
    "STUDENT_INFO" \
    "contains" \
    5 \
    "STUDENT_INFO表未创建:-5"

check_db_query \
    "表数据未插入" \
    "/var/local/sc/rw_table_count.sql" \
    "0" \
    "ne" \
    5 \
    "表中无数据:-5"

check_db_query \
    "视图未创建" \
    "/var/local/sc/rw_view_exists.sql" \
    "V_STUDENT" \
    "contains" \
    5 \
    "V_STUDENT视图未创建:-5"

# ─────────────────────────────────────────────
# 第7题: 存储过程与函数 (初始分: 10分)
# ─────────────────────────────────────────────
Q7_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q7_SCORE))

check_db_query \
    "存储过程未创建" \
    "/var/local/sc/rw_proc_exists.sql" \
    "PROC_INSERT_STUDENT" \
    "contains" \
    5 \
    "存储过程未创建:-5"

check_db_query \
    "函数未创建" \
    "/var/local/sc/rw_func_exists.sql" \
    "FUNC_GET_STUDENT" \
    "contains" \
    5 \
    "函数未创建:-5"

# ─────────────────────────────────────────────
# 第8题: 触发器 (初始分: 10分)
# ─────────────────────────────────────────────
Q8_SCORE=10
TOTAL_SCORE=$((TOTAL_SCORE + Q8_SCORE))

check_db_query \
    "触发器未创建" \
    "/var/local/sc/rw_trigger_exists.sql" \
    "TRG_STUDENT_AUDIT" \
    "contains" \
    5 \
    "触发器未创建:-5"

check_db_query \
    "触发器状态异常" \
    "/var/local/sc/rw_trigger_status.sql" \
    "VALID" \
    "eq" \
    5 \
    "触发器状态异常:-5"

# ─────────────────────────────────────────────
# 第9题: 定时作业 (初始分: 15分)
# ─────────────────────────────────────────────
Q9_SCORE=15
TOTAL_SCORE=$((TOTAL_SCORE + Q9_SCORE))

check_db_query \
    "定时作业未创建" \
    "/var/local/sc/rw_job_exists.sql" \
    "EXAM_BACKUP_JOB" \
    "contains" \
    8 \
    "定时备份作业未创建:-8"

check_db_query \
    "作业调度配置错误" \
    "/var/local/sc/rw_job_schedule.sql" \
    "ENABLED" \
    "contains" \
    7 \
    "作业调度未启用:-7"

# ═══════════════════════════════════════════════════════════════
# 输出最终评分结果
# ═══════════════════════════════════════════════════════════════
output_result
