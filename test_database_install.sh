#!/bin/bash
# =============================================================================
# Linux 考试系统 - 数据库安装与迁移测试脚本
# 用途：测试 MySQL 安装、数据库初始化、迁移和连接
# 用法：bash test_database_install.sh [--unit | --integration | --all]
# =============================================================================
set -euo pipefail

# ─── 颜色输出 ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; \
                echo -e "${BOLD}${CYAN}  $*${NC}"; \
                echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"; }

# ─── 全局变量 ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_MODE="${1:---all}"
PASS=0
FAIL=0
SKIP=0

# ─── 测试辅助函数 ──────────────────────────────────────────────────────────────
test_pass() {
  ((PASS++)) || true
  echo -e "  ${GREEN}✓ PASS${NC}: $1"
}

test_fail() {
  ((FAIL++)) || true
  echo -e "  ${RED}✗ FAIL${NC}: $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "       ${YELLOW}原因：$2${NC}"
  fi
}

test_skip() {
  ((SKIP++)) || true
  echo -e "  ${YELLOW}⊘ SKIP${NC}: $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "       ${CYAN}提示：$2${NC}"
  fi
}

# ─── 单元测试：MySQL 安装检查 ──────────────────────────────────────────────────
test_mysql_installed() {
  log_section "单元测试：MySQL 客户端工具"

  # Test 1: mysql 命令可用
  echo -n "  [1.1] MySQL 客户端命令可用 ... "
  if command -v mysql &>/dev/null; then
    test_pass "mysql 命令已安装 ($(mysql --version | head -1))"
  else
    test_fail "mysql 命令未安装" "请运行 install.sh 安装 MySQL"
  fi

  # Test 2: mysqladmin 命令可用
  echo -n "  [1.2] MySQL 管理命令可用 ... "
  if command -v mysqladmin &>/dev/null; then
    test_pass "mysqladmin 命令已安装"
  else
    test_fail "mysqladmin 命令未安装"
  fi
}

# ─── 单元测试：MySQL 服务状态 ──────────────────────────────────────────────────
test_mysql_service() {
  log_section "单元测试：MySQL 服务状态"

  # Test 1: MySQL 服务运行
  echo -n "  [2.1] MySQL 服务正在运行 ... "
  if mysqladmin ping -h localhost &>/dev/null 2>&1; then
    test_pass "MySQL 服务响应正常"
  else
    test_fail "MySQL 服务无响应" "MySQL 可能未启动，请检查 systemctl status mysql"
    return 1
  fi

  # Test 2: MySQL 版本检查
  echo -n "  [2.2] MySQL 版本检查 ... "
  local version
  version=$(mysql --version 2>&1 | head -1)
  if [[ -n "$version" ]]; then
    test_pass "$version"
  else
    test_fail "无法获取 MySQL 版本"
  fi

  # Test 3: 端口监听
  echo -n "  [2.3] MySQL 端口 3306 监听 ... "
  if ss -tlnp 2>/dev/null | grep -q ":3306" || netstat -tlnp 2>/dev/null | grep -q ":3306"; then
    test_pass "端口 3306 正在监听"
  else
    test_skip "端口 3306 监听检查" "ss/netstat 不可用或端口未监听"
  fi
}

# ─── 单元测试：数据库配置 ──────────────────────────────────────────────────────
test_database_config() {
  log_section "单元测试：数据库配置文件"

  # Test 1: .env 文件存在
  echo -n "  [3.1] .env 配置文件存在 ... "
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    test_pass ".env 文件存在"
  else
    test_fail ".env 文件不存在" "请先运行 install.sh 生成配置文件"
    return 1
  fi

  # Test 2: DATABASE_URL 配置
  echo -n "  [3.2] DATABASE_URL 配置项 ... "
  if grep -q "^DATABASE_URL=" "$SCRIPT_DIR/.env"; then
    test_pass "DATABASE_URL 已配置"
  else
    test_fail "DATABASE_URL 未配置"
  fi

  # Test 3: DATABASE_URL 格式验证
  echo -n "  [3.3] DATABASE_URL 格式验证 ... "
  local db_url
  db_url=$(grep "^DATABASE_URL=" "$SCRIPT_DIR/.env" | cut -d= -f2-)
  if [[ "$db_url" =~ ^mysql://[^:]+:[^@]+@[^:]+:[0-9]+/.+ ]]; then
    test_pass "DATABASE_URL 格式正确"
  elif [[ "$db_url" == *"please-change"* ]] || [[ "$db_url" == *"placeholder"* ]]; then
    test_skip "DATABASE_URL 使用默认值" "请修改 .env 中的数据库连接信息"
  else
    test_fail "DATABASE_URL 格式错误: $db_url"
  fi
}

# ─── 集成测试：数据库连接 ──────────────────────────────────────────────────────
test_database_connection() {
  log_section "集成测试：数据库连接"

  # 解析 DATABASE_URL
  local env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    test_skip "数据库连接测试" ".env 文件不存在"
    return 1
  fi

  local db_url
  db_url=$(grep "^DATABASE_URL=" "$env_file" | cut -d= -f2-)

  # 跳过默认配置
  if [[ "$db_url" == *"please-change"* ]] || [[ -z "$db_url" ]]; then
    test_skip "数据库连接测试" "请使用实际数据库配置更新 .env"
    return 1
  fi

  # 解析连接字符串
  local db_user db_pass db_host db_port db_name
  db_user=$(echo "$db_url" | sed -E 's|mysql://([^:]+):.*|\1|')
  db_pass=$(echo "$db_url" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  db_pass=$(printf '%b' "${db_pass//%/\\x}")  # URL decode
  db_host=$(echo "$db_url" | sed -E 's|.*@([^:]+):.*|\1|')
  db_port=$(echo "$db_url" | sed -E 's|.*@[^:]+:([0-9]+)/.*|\1|')
  db_name=$(echo "$db_url" | sed -E 's|.*/([^?]+).*|\1|')

  # Test 1: 连接数据库
  echo -n "  [4.1] 数据库连接测试 ... "
  if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -e "SELECT 1" &>/dev/null; then
    test_pass "数据库连接成功 ($db_user@$db_host:$db_port/$db_name)"
  else
    test_fail "数据库连接失败" "请检查数据库服务状态和凭据"
    return 1
  fi

  # Test 2: 数据库存在性
  echo -n "  [4.2] 数据库 $db_name 存在性 ... "
  if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -e "USE $db_name" &>/dev/null; then
    test_pass "数据库 $db_name 存在"
  else
    test_fail "数据库 $db_name 不存在"
  fi

  # Test 3: 数据库字符集
  echo -n "  [4.3] 数据库字符集检查 ... "
  local charset
  charset=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -N -e \
    "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db_name'" 2>/dev/null || echo "")
  if [[ "$charset" == "utf8mb4" ]]; then
    test_pass "字符集：utf8mb4"
  else
    test_skip "字符集检查" "当前字符集：${charset:-未知}"
  fi
}

# ─── 集成测试：表结构验证 ──────────────────────────────────────────────────────
test_table_structure() {
  log_section "集成测试：数据库表结构"

  local env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    test_skip "表结构测试" ".env 文件不存在"
    return 1
  fi

  local db_url
  db_url=$(grep "^DATABASE_URL=" "$env_file" | cut -d= -f2-)

  if [[ "$db_url" == *"please-change"* ]] || [[ -z "$db_url" ]]; then
    test_skip "表结构测试" "请使用实际数据库配置更新 .env"
    return 1
  fi

  # 解析连接信息
  local db_user db_pass db_host db_port db_name
  db_user=$(echo "$db_url" | sed -E 's|mysql://([^:]+):.*|\1|')
  db_pass=$(echo "$db_url" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  db_pass=$(printf '%b' "${db_pass//%/\\x}")
  db_host=$(echo "$db_url" | sed -E 's|.*@([^:]+):.*|\1|')
  db_port=$(echo "$db_url" | sed -E 's|.*@[^:]+:([0-9]+)/.*|\1|')
  db_name=$(echo "$db_url" | sed -E 's|.*/([^?]+).*|\1|')

  # Test 1: 表数量检查
  echo -n "  [5.1] 数据库表数量 ... "
  local table_count
  table_count=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$db_name'" 2>/dev/null || echo "0")

  if [[ "$table_count" -gt 0 ]]; then
    test_pass "共 $table_count 个表"
  else
    test_fail "数据库中没有表" "请先运行数据库迁移"
  fi

  # Test 2: 核心表存在性
  echo -n "  [5.2] 核心表存在性检查 ... "
  local required_tables=("users" "students" "questions" "exam_sessions" "exam_records")
  local missing_tables=()

  for table in "${required_tables[@]}"; do
    if ! MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -N -e \
       "SELECT 1 FROM information_schema.tables WHERE table_schema='$db_name' AND table_name='$table'" 2>/dev/null | grep -q "1"; then
      missing_tables+=("$table")
    fi
  done

  if [[ ${#missing_tables[@]} -eq 0 ]]; then
    test_pass "所有核心表存在 (${#required_tables[@]} 个)"
  else
    test_fail "缺少核心表：${missing_tables[*]}"
  fi

  # Test 3: 表结构详细检查
  echo -n "  [5.3] users 表结构检查 ... "
  local users_cols
  users_cols=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -N -e \
    "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$db_name' AND table_name='users'" 2>/dev/null || echo "0")

  if [[ "$users_cols" -ge 5 ]]; then
    test_pass "users 表有 $users_cols 个字段"
  else
    test_fail "users 表字段不足 (期望>=5, 实际=$users_cols)"
  fi

  # Test 4: 外键约束检查
  echo -n "  [5.4] 外键约束检查 ... "
  local fk_count
  fk_count=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -N -e \
    "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='$db_name' AND CONSTRAINT_TYPE='FOREIGN KEY'" 2>/dev/null || echo "0")

  if [[ "$fk_count" -gt 0 ]]; then
    test_pass "共 $fk_count 个外键约束"
  else
    test_skip "外键约束检查" "未检测到外键约束"
  fi

  # Test 5: 显示所有表
  echo ""
  log_info "数据库表列表:"
  MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | while read -r table; do
    echo "    - $table"
  done
}

# ─── 集成测试：数据库迁移验证 ──────────────────────────────────────────────────
test_migration_files() {
  log_section "集成测试：迁移文件检查"

  # Test 1: 迁移目录存在
  echo -n "  [6.1] drizzle 迁移目录 ... "
  if [[ -d "$SCRIPT_DIR/drizzle" ]]; then
    test_pass "drizzle 目录存在"
  else
    test_fail "drizzle 目录不存在"
  fi

  # Test 2: schema.ts 存在
  echo -n "  [6.2] schema.ts 文件 ... "
  if [[ -f "$SCRIPT_DIR/drizzle/schema.ts" ]]; then
    test_pass "schema.ts 存在"
  else
    test_fail "schema.ts 不存在"
  fi

  # Test 3: SQL 迁移文件
  echo -n "  [6.3] SQL 迁移文件 ... "
  local sql_files
  sql_files=$(ls -1 "$SCRIPT_DIR/drizzle"/*.sql 2>/dev/null | wc -l || echo "0")
  if [[ "$sql_files" -gt 0 ]]; then
    test_pass "找到 $sql_files 个 SQL 迁移文件"
    ls -1 "$SCRIPT_DIR/drizzle"/*.sql 2>/dev/null | while read -r f; do
      echo "    - $(basename "$f")"
    done
  else
    test_fail "未找到 SQL 迁移文件"
  fi

  # Test 4: drizzle.config.ts 存在
  echo -n "  [6.4] drizzle.config.ts 配置 ... "
  if [[ -f "$SCRIPT_DIR/drizzle.config.ts" ]]; then
    test_pass "drizzle.config.ts 存在"
  else
    test_fail "drizzle.config.ts 不存在"
  fi
}

# ─── 功能测试：数据库 CRUD 操作 ────────────────────────────────────────────────
test_database_crud() {
  log_section "功能测试：数据库 CRUD 操作"

  local env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    test_skip "CRUD 测试" ".env 文件不存在"
    return 1
  fi

  local db_url
  db_url=$(grep "^DATABASE_URL=" "$env_file" | cut -d= -f2-)

  if [[ "$db_url" == *"please-change"* ]] || [[ -z "$db_url" ]]; then
    test_skip "CRUD 测试" "请使用实际数据库配置更新 .env"
    return 1
  fi

  # 解析连接信息
  local db_user db_pass db_host db_port db_name
  db_user=$(echo "$db_url" | sed -E 's|mysql://([^:]+):.*|\1|')
  db_pass=$(echo "$db_url" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  db_pass=$(printf '%b' "${db_pass//%/\\x}")
  db_host=$(echo "$db_url" | sed -E 's|.*@([^:]+):.*|\1|')
  db_port=$(echo "$db_url" | sed -E 's|.*@[^:]+:([0-9]+)/.*|\1|')
  db_name=$(echo "$db_url" | sed -E 's|.*/([^?]+).*|\1|')

  # Test 1: INSERT 测试
  echo -n "  [7.1] INSERT 操作测试 ... "
  local test_id
  test_id=$(date +%s)
  if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -e \
     "INSERT INTO users (openId, name, loginMethod, role, createdAt, lastSignedIn) VALUES ('test_$test_id', 'Test User', 'test', 'user', NOW(), NOW())" 2>/dev/null; then
    test_pass "INSERT 成功"
  else
    test_fail "INSERT 失败" "检查表结构或权限"
  fi

  # Test 2: SELECT 测试
  echo -n "  [7.2] SELECT 操作测试 ... "
  local result
  result=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -N -e \
    "SELECT name FROM users WHERE openId='test_$test_id'" 2>/dev/null || echo "")
  if [[ "$result" == "Test User" ]]; then
    test_pass "SELECT 成功 (name=$result)"
  else
    test_fail "SELECT 失败 (结果=$result)"
  fi

  # Test 3: UPDATE 测试
  echo -n "  [7.3] UPDATE 操作测试 ... "
  if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -e \
     "UPDATE users SET name='Updated User' WHERE openId='test_$test_id'" 2>/dev/null; then
    test_pass "UPDATE 成功"
  else
    test_fail "UPDATE 失败"
  fi

  # Test 4: 验证 UPDATE
  echo -n "  [7.4] 验证 UPDATE 结果 ... "
  result=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -N -e \
    "SELECT name FROM users WHERE openId='test_$test_id'" 2>/dev/null || echo "")
  if [[ "$result" == "Updated User" ]]; then
    test_pass "UPDATE 验证成功"
  else
    test_fail "UPDATE 验证失败"
  fi

  # Test 5: DELETE 测试
  echo -n "  [7.5] DELETE 操作测试 ... "
  if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -e \
     "DELETE FROM users WHERE openId='test_$test_id'" 2>/dev/null; then
    test_pass "DELETE 成功"
  else
    test_fail "DELETE 失败"
  fi

  # Test 6: 验证 DELETE
  echo -n "  [7.6] 验证 DELETE 结果 ... "
  result=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -N -e \
    "SELECT COUNT(*) FROM users WHERE openId='test_$test_id'" 2>/dev/null || echo "1")
  if [[ "$result" == "0" ]]; then
    test_pass "DELETE 验证成功 (记录已删除)"
  else
    test_fail "DELETE 验证失败 (仍存在 $result 条记录)"
  fi
}

# ─── 性能测试：数据库连接池 ────────────────────────────────────────────────────
test_database_performance() {
  log_section "性能测试：数据库连接"

  local env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    test_skip "性能测试" ".env 文件不存在"
    return 1
  fi

  local db_url
  db_url=$(grep "^DATABASE_URL=" "$env_file" | cut -d= -f2-)

  if [[ "$db_url" == *"please-change"* ]] || [[ -z "$db_url" ]]; then
    test_skip "性能测试" "请使用实际数据库配置更新 .env"
    return 1
  fi

  # 解析连接信息
  local db_user db_pass db_host db_port db_name
  db_user=$(echo "$db_url" | sed -E 's|mysql://([^:]+):.*|\1|')
  db_pass=$(echo "$db_url" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  db_pass=$(printf '%b' "${db_pass//%/\\x}")
  db_host=$(echo "$db_url" | sed -E 's|.*@([^:]+):.*|\1|')
  db_port=$(echo "$db_url" | sed -E 's|.*@[^:]+:([0-9]+)/.*|\1|')
  db_name=$(echo "$db_url" | sed -E 's|.*/([^?]+).*|\1|')

  # Test 1: 连接延迟
  echo -n "  [8.1] 数据库连接延迟 ... "
  local start_time end_time latency
  start_time=$(date +%s%N)
  MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -e "SELECT 1" &>/dev/null
  end_time=$(date +%s%N)
  latency=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒

  if [[ "$latency" -lt 100 ]]; then
    test_pass "连接延迟 ${latency}ms (<100ms)"
  elif [[ "$latency" -lt 500 ]]; then
    test_pass "连接延迟 ${latency}ms (<500ms)"
  else
    test_fail "连接延迟 ${latency}ms (>=500ms)" "数据库响应慢"
  fi

  # Test 2: 并发连接测试
  echo -n "  [8.2] 并发连接测试 (10 个连接) ... "
  local success=0
  for i in {1..10}; do
    if MYSQL_PWD="$db_pass" mysql -h "$db_host" -P "$db_port" -u "$db_user" "$db_name" -e "SELECT 1" &>/dev/null; then
      ((success++)) || true
    fi
  done

  if [[ "$success" -eq 10 ]]; then
    test_pass "10 个并发连接全部成功"
  else
    test_fail "并发连接测试失败 ($success/10 成功)"
  fi
}

# ─── 汇总结果 ─────────────────────────────────────────────────────────────────
print_summary() {
  log_section "测试结果汇总"

  local total=$((PASS + FAIL + SKIP))

  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}  测试统计${NC}"
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "  总计：$total"
  echo -e "  通过：${GREEN}${PASS}${NC}"
  echo -e "  失败：${RED}${FAIL}${NC}"
  echo -e "  跳过：${YELLOW}${SKIP}${NC}"
  echo ""

  if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ 所有测试通过！数据库已就绪。${NC}"
    return 0
  elif [[ "$FAIL" -le 2 ]]; then
    echo -e "${YELLOW}${BOLD}  ⚠ 部分测试未通过，请检查上方 FAIL 项目。${NC}"
    return 1
  else
    echo -e "${RED}${BOLD}  ✗ 多项测试失败，请检查数据库安装和配置。${NC}"
    return 1
  fi
}

# ─── 主流程 ───────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}${CYAN}"
  echo "  ██████╗  ██████╗ ██╗  ██╗██╗   ██╗███████╗"
  echo "  ██╔══██╗██╔═══██╗╚██╗██╔╝██║   ██║██╔════╝"
  echo "  ██████╔╝██║   ██║ ╚███╔╝ ██║   ██║███████╗"
  echo "  ██╔══██╗██║   ██║ ██╔██╗ ██║   ██║╚════██║"
  echo "  ██████╔╝╚██████╔╝██╔╝ ██╗╚██████╔╝███████║"
  echo "  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
  echo -e "${NC}"
  echo -e "${BOLD}  Linux 考试系统 - 数据库测试脚本 v1.0${NC}"
  echo ""

  case "$TEST_MODE" in
    --unit|-u)
      test_mysql_installed
      test_mysql_service
      test_database_config
      ;;
    --integration|-i)
      test_database_connection
      test_table_structure
      test_migration_files
      ;;
    --all|-a)
      test_mysql_installed
      test_mysql_service
      test_database_config
      test_database_connection
      test_table_structure
      test_migration_files
      test_database_crud
      test_database_performance
      ;;
    --help|-h)
      echo "用法：bash test_database_install.sh [选项]"
      echo ""
      echo "选项:"
      echo "  --unit, -u        仅运行单元测试（MySQL 安装和配置）"
      echo "  --integration, -i 仅运行集成测试（连接和表结构）"
      echo "  --all, -a         运行所有测试（默认）"
      echo "  --help, -h        显示此帮助信息"
      echo ""
      echo "示例:"
      echo "  bash test_database_install.sh --unit        # 单元测试"
      echo "  bash test_database_install.sh --integration # 集成测试"
      echo "  bash test_database_install.sh               # 完整测试"
      exit 0
      ;;
    *)
      echo "未知选项：$TEST_MODE"
      echo "使用 --help 查看帮助"
      exit 1
      ;;
  esac

  print_summary
}

main "$TEST_MODE"
