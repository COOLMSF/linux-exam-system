#!/bin/bash
# 用户与权限管理检查（满分 8 分）
# 自动适配 MySQL / 达梦数据库
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
USER_EXPECTED="${USER_EXPECTED:-exam_user}"
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    COLLATION=$($MYSQL_CMD -e "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
    if echo "$COLLATION" | grep -qi "utf8mb4"; then
        echo "✓ 数据库字符集配置正确 (+1)"
    else
        echo "✗ 数据库字符集配置不正确 (-1)"; SCORE=$((SCORE-1))
    fi

    USER_EXISTS=$($MYSQL_CMD -e "SELECT User FROM mysql.user WHERE User='${USER_EXPECTED}' LIMIT 1" 2>/dev/null)
    if [ -n "$USER_EXISTS" ]; then
        echo "✓ 用户 ${USER_EXPECTED} 存在 (+1)"
    else
        echo "✗ 用户 ${USER_EXPECTED} 不存在 (-1)"; SCORE=$((SCORE-1))
    fi

    PWD_LIFE=$($MYSQL_CMD -e "SELECT password_lifetime FROM mysql.user WHERE User='${USER_EXPECTED}' LIMIT 1" 2>/dev/null)
    if [ "$PWD_LIFE" = "120" ]; then
        echo "✓ 密码过期策略 120 天 (+1)"
    else
        echo "✗ 密码过期策略不正确 (当前: ${PWD_LIFE:-未设置}) (-1)"; SCORE=$((SCORE-1))
    fi

    GRANTS=$($MYSQL_CMD -e "SHOW GRANTS FOR '${USER_EXPECTED}'@'%'" 2>/dev/null)
    for priv in "SELECT" "CREATE" "CREATE ROUTINE" "EXECUTE" "DELETE"; do
        if echo "$GRANTS" | grep -qi "$priv"; then
            echo "✓ 拥有 ${priv} 权限 (+1)"
        else
            echo "✗ 缺少 ${priv} 权限 (-1)"; SCORE=$((SCORE-1))
        fi
    done
else
    # ── 达梦模式 ──
    # 检查表空间 TBS
    TBS_INIT=$($DMPATH/disql -s "$DM_CONN" -e "SELECT FILE_SIZE/1048576 FROM V\$DATAFILE WHERE TABLESPACE_NAME='TBS';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$TBS_INIT" = "64" ]; then
        echo "✓ 表空间 TBS 初始大小 64M (+1)"
    else
        echo "✗ 表空间初始大小不正确 (当前: ${TBS_INIT:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 检查用户存在
    UTEST=$($DMPATH/disql -s "$DM_CONN" -e "SELECT USERNAME FROM DBA_USERS WHERE USERNAME=UPPER('${USER_EXPECTED}');" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$UTEST" ]; then
        echo "✓ 用户 ${USER_EXPECTED} 存在 (+1)"
    else
        echo "✗ 用户 ${USER_EXPECTED} 不存在 (-1)"; SCORE=$((SCORE-1))
    fi

    # 密码过期策略
    PWD_LIFE=$($DMPATH/disql -s "$DM_CONN" -e "SELECT PASSWORD_LIFE_TIME FROM DBA_USERS WHERE USERNAME=UPPER('${USER_EXPECTED}');" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$PWD_LIFE" = "120" ]; then
        echo "✓ 密码过期策略 120 天 (+1)"
    else
        echo "✗ 密码过期策略不正确 (当前: ${PWD_LIFE:-未设置}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 默认表空间
    DEF_TBS=$($DMPATH/disql -s "$DM_CONN" -e "SELECT DEFAULT_TABLESPACE FROM DBA_USERS WHERE USERNAME=UPPER('${USER_EXPECTED}');" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$DEF_TBS" = "TBS" ]; then
        echo "✓ 默认表空间为 TBS (+1)"
    else
        echo "✗ 默认表空间不正确 (当前: ${DEF_TBS:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    # 检查权限 (CREATE TABLE + CREATE PROCEDURE)
    PRIV_TAB=$($DMPATH/disql -s "$DM_CONN" -e "SELECT PRIVILEGE FROM DBA_SYS_PRIVS WHERE GRANTEE=UPPER('${USER_EXPECTED}') AND PRIVILEGE='CREATE TABLE';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$PRIV_TAB" = "CREATE" ] || echo "$PRIV_TAB" | grep -qi "TABLE"; then
        echo "✓ 拥有 CREATE TABLE 权限 (+2)"
    else
        echo "✗ 缺少 CREATE TABLE 权限 (-2)"; SCORE=$((SCORE-2))
    fi

    PRIV_PROC=$($DMPATH/disql -s "$DM_CONN" -e "SELECT PRIVILEGE FROM DBA_SYS_PRIVS WHERE GRANTEE=UPPER('${USER_EXPECTED}') AND PRIVILEGE='CREATE PROCEDURE';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$PRIV_PROC" = "CREATE" ] || echo "$PRIV_PROC" | grep -qi "PROCEDURE"; then
        echo "✓ 拥有 CREATE PROCEDURE 权限 (+2)"
    else
        echo "✗ 缺少 CREATE PROCEDURE 权限 (-2)"; SCORE=$((SCORE-2))
    fi
fi

echo "SCORE:$SCORE"
