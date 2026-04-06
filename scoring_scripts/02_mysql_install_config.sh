#!/bin/bash
# 数据库安装与初始化配置检查（满分 14 分）
# 自动适配 MySQL / 达梦数据库
# 变量由服务端注入：DB_EXPECTED, PORT_EXPECTED, SERVER_ID_EXPECTED
SCORE=14

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
PORT_EXPECTED="${PORT_EXPECTED:-3306}"
SERVER_ID_EXPECTED="${SERVER_ID_EXPECTED:-1}"
echo "[检测] 数据库类型：$DB_TYPE"

if [ "$DB_TYPE" = "mysql" ]; then
    # ── MySQL 模式 ──
    DB_EXISTS=$($MYSQL_CMD -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
    if [ -n "$DB_EXISTS" ]; then
        echo "✓ 数据库 ${DB_EXPECTED} 存在 (+1)"
    else
        echo "✗ 数据库 ${DB_EXPECTED} 不存在 (-1)"; SCORE=$((SCORE-1))
    fi

    CHARSET=$($MYSQL_CMD -e "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_EXPECTED}'" 2>/dev/null)
    if [ "$CHARSET" = "utf8mb4" ]; then
        echo "✓ 字符集为 utf8mb4 (+1)"
    else
        echo "✗ 字符集不是 utf8mb4 (当前: ${CHARSET:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    ACTUAL_PORT=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'port'" 2>/dev/null | awk '{print $2}')
    if [ "$ACTUAL_PORT" = "$PORT_EXPECTED" ]; then
        echo "✓ 端口为 ${PORT_EXPECTED} (+1)"
    else
        echo "✗ 端口不匹配 (期望: ${PORT_EXPECTED}, 实际: ${ACTUAL_PORT:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    SID=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'server_id'" 2>/dev/null | awk '{print $2}')
    if [ "$SID" = "$SERVER_ID_EXPECTED" ]; then
        echo "✓ server-id 为 ${SERVER_ID_EXPECTED} (+1)"
    else
        echo "✗ server-id 不匹配 (期望: ${SERVER_ID_EXPECTED}, 实际: ${SID:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    MAXCONN=$($MYSQL_CMD -e "SHOW VARIABLES LIKE 'max_connections'" 2>/dev/null | awk '{print $2}')
    if [ "$MAXCONN" = "200" ]; then
        echo "✓ max_connections = 200 (+1)"
    else
        echo "✗ max_connections 不是 200 (当前: ${MAXCONN:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    RECOVER=$($MYSQL_CMD -e "SELECT id FROM ${DB_EXPECTED}.recovery_test WHERE id=107" 2>/dev/null)
    if [ "$RECOVER" = "107" ]; then
        echo "✓ recovery_test 数据已恢复 (id=107) (+8)"
    else
        echo "✗ recovery_test 数据未恢复 (-8)"; SCORE=$((SCORE-8))
    fi

    if [ -f "/var/lib/mysql_backup/examdata.sql" ]; then
        echo "✓ examdata.sql 存在 (+1)"
    else
        echo "✗ examdata.sql 不存在 (-1)"; SCORE=$((SCORE-1))
    fi
else
    # ── 达梦模式 ──
    if [ -d "/dm" ]; then
        echo "✓ 安装路径 /dm 存在 (+2)"
    else
        echo "✗ 安装路径 /dm 不存在 (-2)"; SCORE=$((SCORE-2))
    fi

    DBNAME=$($DMPATH/disql -s "$DM_CONN" -e "SELECT NAME FROM V\$DATABASE;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$DBNAME" = "${DB_EXPECTED}" ]; then
        echo "✓ 数据库名为 ${DB_EXPECTED} (+1)"
    else
        echo "✗ 数据库名不匹配 (期望: ${DB_EXPECTED}, 实际: ${DBNAME:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    INS_NAME=$($DMPATH/disql -s "$DM_CONN" -e "SELECT INSTANCE_NAME FROM V\$INSTANCE;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ -n "$INS_NAME" ]; then
        echo "✓ 实例名为 ${INS_NAME} (+1)"
    else
        echo "✗ 无法获取实例名 (-1)"; SCORE=$((SCORE-1))
    fi

    PORT_NUM=$($DMPATH/disql -s "$DM_CONN" -e "SELECT PARA_VALUE FROM V\$DM_INI WHERE PARA_NAME='PORT_NUM';" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$PORT_NUM" = "$PORT_EXPECTED" ]; then
        echo "✓ 端口为 ${PORT_EXPECTED} (+1)"
    else
        echo "✗ 端口不匹配 (期望: ${PORT_EXPECTED}, 实际: ${PORT_NUM:-N/A}) (-1)"; SCORE=$((SCORE-1))
    fi

    CHARSET=$($DMPATH/disql -s "$DM_CONN" -e "SELECT UNICODE FROM V\$DATABASE;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$CHARSET" = "1" ]; then
        echo "✓ 字符集为 UTF-8 (+1)"
    else
        echo "✗ 字符集不是 UTF-8 (-1)"; SCORE=$((SCORE-1))
    fi

    RECOVER=$($DMPATH/disql -s "$DM_CONN" -e "SELECT ID FROM RECOVERY_TEST WHERE ID=107;" 2>/dev/null | head -1 | tr -s " " | cut -d " " -f 2)
    if [ "$RECOVER" = "107" ]; then
        echo "✓ recovery_test 数据已恢复 (id=107) (+8)"
    else
        echo "✗ 原有数据库数据未恢复 (-8)"; SCORE=$((SCORE-8))
    fi
fi

echo "SCORE:$SCORE"
