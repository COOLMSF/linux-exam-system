#!/bin/bash
# =============================================================================
# Linux 考试系统 — 一键安装 & 测试脚本
# 兼容系统：Ubuntu 18.04/20.04/22.04 (apt) | 麒麟 V10 SP1/SP2/SP3 (yum/dnf)
# 用法：sudo bash install.sh [--server-only | --client-only | --test-only]
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
INSTALL_DIR="/opt/linux-exam-system"
# 日志路径：root 时写 /var/log，否则写 /tmp
if [[ $EUID -eq 0 ]]; then
  LOG_FILE="/var/log/linux-exam-install.log"
else
  LOG_FILE="/tmp/linux-exam-install.log"
fi
NODE_VERSION_MIN=18
PYTHON_VERSION_MIN="3.8"
MODE="full"   # full | server-only | client-only | test-only

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --server-only) MODE="server-only" ;;
    --client-only) MODE="client-only" ;;
    --test-only)   MODE="test-only"   ;;
    --help|-h)
      echo "用法: sudo bash install.sh [选项]"
      echo "  --server-only   仅安装服务端"
      echo "  --client-only   仅安装客户端 Agent"
      echo "  --test-only     仅运行测试验证（不安装）"
      echo "  --help          显示帮助"
      exit 0
      ;;
  esac
done

# ─── 权限检查 ─────────────────────────────────────────────────────────────────
check_root() {
  # test-only 模式不强制要求 root
  if [[ "$MODE" == "test-only" ]]; then
    return 0
  fi
  if [[ $EUID -ne 0 ]]; then
    log_error "安装模式需要 root 权限，请使用 sudo bash install.sh"
    log_warn "若仅需运行测试，请使用: bash install.sh --test-only"
    exit 1
  fi
}

# ─── 扩展 PATH，兼容 nvm / 麒麟系统非标准路径 ──────────────────────────────────
expand_path() {
  # nvm 路径（当前用户 & root）
  for nvm_dir in "$HOME/.nvm" "/root/.nvm" "/home/ubuntu/.nvm" "/usr/local/nvm"; do
    if [[ -d "$nvm_dir/versions/node" ]]; then
      local latest
      latest=$(ls -t "$nvm_dir/versions/node" 2>/dev/null | head -1)
      if [[ -n "$latest" ]]; then
        export PATH="$nvm_dir/versions/node/$latest/bin:$PATH"
      fi
    fi
  done
  # 常见非标准路径
  for extra in /usr/local/bin /usr/bin /opt/node/bin /opt/nodejs/bin; do
    [[ -d "$extra" ]] && export PATH="$extra:$PATH" || true
  done
}

# ─── 系统检测 ─────────────────────────────────────────────────────────────────
detect_os() {
  log_section "系统环境检测"

  OS_ID=""
  OS_VERSION=""
  PKG_MANAGER=""

  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
  fi

  # 检测包管理器
  if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt"
    log_ok "检测到 APT 包管理器 (Ubuntu/Debian 系)"
  elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    log_ok "检测到 DNF 包管理器 (麒麟/Fedora/RHEL 系)"
  elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
    log_ok "检测到 YUM 包管理器 (麒麟/CentOS/RHEL 系)"
  else
    log_error "未检测到支持的包管理器（apt/dnf/yum），请手动安装依赖"
    exit 1
  fi

  log_info "操作系统: ${OS_ID} ${OS_VERSION}"
  log_info "内核版本: $(uname -r)"
  log_info "系统架构: $(uname -m)"
  log_info "安装模式: ${MODE}"

  # 麒麟系统特殊提示
  if [[ "$OS_ID" == "kylin" ]] || grep -qi "kylin" /etc/os-release 2>/dev/null; then
    log_info "检测到麒麟操作系统，将使用兼容模式安装"
    IS_KYLIN=true
  else
    IS_KYLIN=false
  fi
}

# ─── 包管理器统一封装 ─────────────────────────────────────────────────────────
pkg_update() {
  log_info "更新软件包索引..."
  case "$PKG_MANAGER" in
    apt) apt-get update -qq 2>>"$LOG_FILE" ;;
    dnf) dnf makecache -q 2>>"$LOG_FILE" || true ;;
    yum) yum makecache -q 2>>"$LOG_FILE" || true ;;
  esac
}

pkg_install() {
  local packages=("$@")
  log_info "安装: ${packages[*]}"
  case "$PKG_MANAGER" in
    apt) apt-get install -y -qq "${packages[@]}" 2>>"$LOG_FILE" ;;
    dnf) dnf install -y -q "${packages[@]}" 2>>"$LOG_FILE" ;;
    yum) yum install -y -q "${packages[@]}" 2>>"$LOG_FILE" ;;
  esac
}

pkg_install_if_missing() {
  local cmd="$1"
  shift
  local packages=("$@")
  if ! command -v "$cmd" &>/dev/null; then
    pkg_install "${packages[@]}"
  else
    log_ok "$cmd 已安装，跳过"
  fi
}

# ─── 基础依赖安装 ─────────────────────────────────────────────────────────────
install_base_deps() {
  log_section "安装基础依赖"
  pkg_update

  case "$PKG_MANAGER" in
    apt)
      pkg_install curl wget git unzip tar ca-certificates gnupg lsb-release \
                  build-essential openssl libssl-dev
      ;;
    dnf|yum)
      pkg_install curl wget git unzip tar ca-certificates openssl openssl-devel \
                  gcc gcc-c++ make
      ;;
  esac
  log_ok "基础依赖安装完成"
}

# ─── Node.js 安装 ─────────────────────────────────────────────────────────────
install_nodejs() {
  log_section "安装 Node.js"

  # 检查现有版本
  if command -v node &>/dev/null; then
    local current_ver
    current_ver=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
    if [[ "$current_ver" -ge "$NODE_VERSION_MIN" ]]; then
      log_ok "Node.js $(node --version) 已满足要求（>= v${NODE_VERSION_MIN}），跳过安装"
      return 0
    else
      log_warn "当前 Node.js v${current_ver} 版本过低，需要升级到 v${NODE_VERSION_MIN}+"
    fi
  fi

  case "$PKG_MANAGER" in
    apt)
      log_info "通过 NodeSource 安装 Node.js 20.x..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>>"$LOG_FILE"
      pkg_install nodejs
      ;;
    dnf|yum)
      log_info "通过 NodeSource 安装 Node.js 20.x..."
      curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - 2>>"$LOG_FILE"
      case "$PKG_MANAGER" in
        dnf) dnf install -y nodejs 2>>"$LOG_FILE" ;;
        yum) yum install -y nodejs 2>>"$LOG_FILE" ;;
      esac
      ;;
  esac

  # 验证
  if command -v node &>/dev/null; then
    log_ok "Node.js $(node --version) 安装成功"
    log_ok "npm $(npm --version) 安装成功"
  else
    log_error "Node.js 安装失败，请检查网络或手动安装"
    exit 1
  fi

  # 安装 pnpm
  log_info "安装 pnpm..."
  npm install -g pnpm@latest 2>>"$LOG_FILE"
  log_ok "pnpm $(pnpm --version) 安装成功"
}

# ─── Python 安装 ─────────────────────────────────────────────────────────────
install_python() {
  log_section "安装 Python 3"

  # 检查现有版本
  local py_cmd=""
  for cmd in python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$cmd" &>/dev/null; then
      local ver
      ver=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
      local major minor
      major=$(echo "$ver" | cut -d. -f1)
      minor=$(echo "$ver" | cut -d. -f2)
      if [[ "$major" -ge 3 && "$minor" -ge 8 ]]; then
        py_cmd="$cmd"
        log_ok "Python $ver 已满足要求（>= ${PYTHON_VERSION_MIN}），跳过安装"
        break
      fi
    fi
  done

  if [[ -z "$py_cmd" ]]; then
    log_info "安装 Python 3..."
    case "$PKG_MANAGER" in
      apt)
        pkg_install python3 python3-pip python3-venv python3-dev
        ;;
      dnf|yum)
        pkg_install python3 python3-pip python3-devel
        ;;
    esac
    log_ok "Python $(python3 --version) 安装成功"
  fi

  # 确保 pip 可用
  if ! command -v pip3 &>/dev/null; then
    log_info "安装 pip3..."
    case "$PKG_MANAGER" in
      apt) pkg_install python3-pip ;;
      dnf|yum) pkg_install python3-pip ;;
    esac
  fi
  log_ok "pip3 $(pip3 --version | awk '{print $2}') 可用"
}

# ─── 服务端部署 ───────────────────────────────────────────────────────────────
install_server() {
  log_section "部署服务端"

  # 检查源码目录
  if [[ ! -f "$SCRIPT_DIR/package.json" ]]; then
    log_error "未找到 package.json，请确保在项目根目录运行此脚本"
    exit 1
  fi

  # 创建安装目录
  mkdir -p "$INSTALL_DIR"
  log_info "复制项目文件到 $INSTALL_DIR..."
  rsync -a --exclude='node_modules' --exclude='.git' --exclude='dist' \
        "$SCRIPT_DIR/" "$INSTALL_DIR/" 2>>"$LOG_FILE"

  # 安装 Node.js 依赖
  log_info "安装 Node.js 依赖（pnpm install）..."
  cd "$INSTALL_DIR"
  pnpm install --frozen-lockfile 2>>"$LOG_FILE" || pnpm install 2>>"$LOG_FILE"
  log_ok "Node.js 依赖安装完成"

  # 创建环境变量文件（如不存在）
  if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    log_info "创建默认 .env 配置文件..."
    cat > "$INSTALL_DIR/.env" <<'EOF'
# Linux 考试系统 — 环境变量配置
# 请根据实际环境修改以下配置

# 数据库连接（MySQL 兼容模式，适用于达梦 DM8）
DATABASE_URL=mysql://exam_user:exam_password@localhost:3306/linux_exam

# JWT 密钥（请修改为随机字符串）
JWT_SECRET=please-change-this-to-a-random-secret-string

# 服务端口
PORT=3000

# 应用 ID（用于 OAuth，可留空使用本地认证）
VITE_APP_ID=

# 运行环境
NODE_ENV=production
EOF
    log_warn "已创建默认 .env 文件，请编辑 $INSTALL_DIR/.env 配置数据库连接信息"
  fi

  # 构建前端
  log_info "构建前端静态资源..."
  cd "$INSTALL_DIR"
  pnpm build 2>>"$LOG_FILE"
  log_ok "前端构建完成"

  # 创建 systemd 服务
  log_info "创建 systemd 服务..."
  cat > /etc/systemd/system/linux-exam.service <<EOF
[Unit]
Description=Linux Exam System Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$(which node) dist/index.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production
EnvironmentFile=$INSTALL_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  log_ok "systemd 服务 linux-exam.service 创建完成"
  log_info "启动服务: systemctl start linux-exam"
  log_info "开机自启: systemctl enable linux-exam"
}

# ─── 客户端 Agent 依赖安装 ────────────────────────────────────────────────────
install_client_agent() {
  log_section "安装客户端 Agent 依赖"

  local agent_dir="$SCRIPT_DIR/client_agent"
  if [[ ! -f "$agent_dir/exam_agent.py" ]]; then
    log_error "未找到 client_agent/exam_agent.py，请确保在项目根目录运行"
    exit 1
  fi

  # 安装 Python 依赖
  log_info "安装 Python 依赖包..."
  pip3 install --quiet requests colorama pyinstaller 2>>"$LOG_FILE"
  log_ok "Python 依赖安装完成"

  # 验证 Agent 可运行
  log_info "验证客户端 Agent..."
  if python3 "$agent_dir/exam_agent.py" --help &>/dev/null 2>&1; then
    log_ok "客户端 Agent 可正常运行"
  else
    log_warn "客户端 Agent 验证失败，请检查 Python 依赖"
  fi

  # 可选：PyInstaller 打包
  if command -v pyinstaller &>/dev/null; then
    log_info "检测到 PyInstaller，是否打包为可执行文件？(y/N)"
    read -r -t 10 answer || answer="n"
    if [[ "${answer,,}" == "y" ]]; then
      log_info "打包客户端 Agent..."
      cd "$agent_dir"
      pyinstaller exam_agent.spec --noconfirm 2>>"$LOG_FILE"
      if [[ -f "$agent_dir/dist/exam_agent" ]]; then
        log_ok "打包成功: $agent_dir/dist/exam_agent"
        chmod +x "$agent_dir/dist/exam_agent"
      fi
    fi
  fi
}

# ─── 功能测试 ─────────────────────────────────────────────────────────────────
run_tests() {
  log_section "运行功能测试"

  # 优先使用项目源码目录，如已安装则使用 INSTALL_DIR
  local test_dir="$SCRIPT_DIR"
  if [[ -d "$INSTALL_DIR/node_modules" ]]; then
    test_dir="$INSTALL_DIR"
  fi
  local pass=0
  local fail=0

  # ── 测试 1：Node.js 版本 ──
  echo -n "  [测试 1] Node.js 版本 >= v${NODE_VERSION_MIN} ... "
  if command -v node &>/dev/null; then
    local ver
    ver=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
    if [[ "$ver" -ge "$NODE_VERSION_MIN" ]]; then
      echo -e "${GREEN}PASS${NC} ($(node --version))"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (当前 v${ver}，需要 >= v${NODE_VERSION_MIN})"
      ((fail++)) || true
    fi
  else
    echo -e "${RED}FAIL${NC} (Node.js 未安装)"
    ((fail++)) || true
  fi

  # ── 测试 2：pnpm 可用 ──
  echo -n "  [测试 2] pnpm 包管理器可用 ... "
  if command -v pnpm &>/dev/null; then
    echo -e "${GREEN}PASS${NC} ($(pnpm --version))"
    ((pass++)) || true
  else
    echo -e "${RED}FAIL${NC} (pnpm 未安装)"
    ((fail++)) || true
  fi

  # ── 测试 3：Python 版本 ──
  echo -n "  [测试 3] Python 3 版本 >= ${PYTHON_VERSION_MIN} ... "
  local py_ok=false
  for cmd in python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$cmd" &>/dev/null; then
      local pver
      pver=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
      local pmaj pmin
      pmaj=$(echo "$pver" | cut -d. -f1)
      pmin=$(echo "$pver" | cut -d. -f2)
      if [[ "$pmaj" -ge 3 && "$pmin" -ge 8 ]]; then
        echo -e "${GREEN}PASS${NC} (Python $pver)"
        ((pass++)) || true
        py_ok=true
        break
      fi
    fi
  done
  if [[ "$py_ok" == false ]]; then
    echo -e "${RED}FAIL${NC} (Python >= ${PYTHON_VERSION_MIN} 未安装)"
    ((fail++)) || true
  fi

  # ── 测试 4：项目文件完整性 ──
  echo -n "  [测试 4] 项目核心文件完整性 ... "
  local required_files=(
    "package.json"
    "server/routers.ts"
    "server/db.ts"
    "drizzle/schema.ts"
    "client/src/App.tsx"
    "client_agent/exam_agent.py"
    "DEPLOYMENT.md"
  )
  local missing=()
  for f in "${required_files[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
      missing+=("$f")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC} (${#required_files[@]} 个文件均存在)"
    ((pass++)) || true
  else
    echo -e "${RED}FAIL${NC} (缺少文件: ${missing[*]})"
    ((fail++)) || true
  fi

  # ── 测试 5：Node.js 依赖安装 ──
  echo -n "  [测试 5] Node.js 依赖已安装 (node_modules) ... "
  local nm_dir="${test_dir}/node_modules"
  if [[ -d "$nm_dir" ]] && [[ $(ls "$nm_dir" | wc -l) -gt 10 ]]; then
    echo -e "${GREEN}PASS${NC} ($(ls "$nm_dir" | wc -l) 个包)"
    ((pass++)) || true
  else
    echo -e "${YELLOW}SKIP${NC} (node_modules 不存在，请先运行安装)"
    ((fail++)) || true
  fi

  # ── 测试 6：TypeScript 编译检查 ──
  echo -n "  [测试 6] TypeScript 编译无错误 ... "
  if [[ -d "$test_dir/node_modules" ]]; then
    cd "$test_dir"
    local ts_output
    ts_output=$(pnpm check 2>&1 || true)
    local ts_errors
    ts_errors=$(echo "$ts_output" | grep -c "error TS" || true)
    if [[ "$ts_errors" -eq 0 ]]; then
      echo -e "${GREEN}PASS${NC} (0 TypeScript 错误)"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (${ts_errors} 个 TypeScript 错误)"
      ((fail++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (依赖未安装)"
  fi

  # ── 测试 7：Vitest 单元测试 ──
  echo -n "  [测试 7] Vitest 单元测试 (21 个测试) ... "
  if [[ -d "$test_dir/node_modules" ]]; then
    cd "$test_dir"
    local test_output
    test_output=$(pnpm test 2>&1)
    local passed_count
    passed_count=$(echo "$test_output" | grep -oP '\d+(?= passed)' | tail -1 || echo "0")
    local failed_count
    failed_count=$(echo "$test_output" | grep -oP '\d+(?= failed)' | tail -1 || echo "0")
    if [[ "$failed_count" == "0" ]] && [[ "$passed_count" -gt 0 ]]; then
      echo -e "${GREEN}PASS${NC} (${passed_count} 个测试通过)"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (通过: ${passed_count}, 失败: ${failed_count})"
      ((fail++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (依赖未安装)"
  fi

  # ── 测试 8：Python Agent 语法检查 ──
  echo -n "  [测试 8] Python Agent 语法检查 ... "
  local agent_py="$SCRIPT_DIR/client_agent/exam_agent.py"
  if [[ -f "$agent_py" ]]; then
    if python3 -m py_compile "$agent_py" 2>/dev/null; then
      echo -e "${GREEN}PASS${NC} (语法正确)"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (语法错误)"
      ((fail++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (文件不存在)"
  fi

  # ── 测试 9：Shell 脚本语法检查 ──
  echo -n "  [测试 9] Shell 评分脚本模板语法检查 ... "
  local sh_tpl="$SCRIPT_DIR/client_agent/script_templates/dm8_scoring_template.sh"
  if [[ -f "$sh_tpl" ]]; then
    if bash -n "$sh_tpl" 2>/dev/null; then
      echo -e "${GREEN}PASS${NC} (语法正确)"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (语法错误)"
      ((fail++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (文件不存在)"
  fi

  # ── 测试 10：服务端口监听（如服务已运行）──
  echo -n "  [测试 10] 服务端口 3000 监听状态 ... "
  if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":3000"; then
      echo -e "${GREEN}PASS${NC} (端口 3000 正在监听)"
      ((pass++)) || true
    else
      echo -e "${YELLOW}SKIP${NC} (服务未运行，请启动后重新测试)"
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":3000"; then
      echo -e "${GREEN}PASS${NC} (端口 3000 正在监听)"
      ((pass++)) || true
    else
      echo -e "${YELLOW}SKIP${NC} (服务未运行)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (ss/netstat 不可用)"
  fi

  # ── 测试 11：API 健康检查（如服务已运行）──
  echo -n "  [测试 11] API 健康检查 (HTTP GET /api/trpc/auth.me) ... "
  if curl -sf --max-time 5 "http://localhost:3000/api/trpc/auth.me?batch=1&input=%7B%7D" \
       -o /dev/null 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} (API 响应正常)"
    ((pass++)) || true
  else
    echo -e "${YELLOW}SKIP${NC} (服务未运行或无法连接)"
  fi

  # ── 测试 12：数据库连接（如配置了 .env）──
  echo -n "  [测试 12] 数据库连接配置 ... "
  local env_file="${test_dir}/.env"
  if [[ -f "$env_file" ]] && grep -q "DATABASE_URL" "$env_file"; then
    local db_url
    db_url=$(grep "^DATABASE_URL" "$env_file" | cut -d= -f2-)
    if [[ "$db_url" != *"please-change"* ]] && [[ -n "$db_url" ]]; then
      echo -e "${GREEN}PASS${NC} (DATABASE_URL 已配置)"
      ((pass++)) || true
    else
      echo -e "${YELLOW}WARN${NC} (DATABASE_URL 使用默认值，请修改 .env)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (.env 文件不存在)"
  fi

  # ── 汇总结果 ──
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}  测试结果汇总${NC}"
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "  通过: ${GREEN}${pass}${NC}  失败: ${RED}${fail}${NC}"
  echo ""

  if [[ "$fail" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ 所有测试通过！系统已就绪。${NC}"
  elif [[ "$fail" -le 2 ]]; then
    echo -e "${YELLOW}${BOLD}  ⚠ 部分测试未通过，请检查上方 FAIL 项目。${NC}"
  else
    echo -e "${RED}${BOLD}  ✗ 多项测试失败，请检查安装日志: $LOG_FILE${NC}"
  fi
  echo ""
}

# ─── 安装后提示 ───────────────────────────────────────────────────────────────
print_summary() {
  log_section "安装完成"
  echo -e "${BOLD}后续步骤：${NC}"
  echo ""
  echo -e "  1. 编辑配置文件："
  echo -e "     ${CYAN}nano ${INSTALL_DIR}/.env${NC}"
  echo ""
  echo -e "  2. 配置数据库（MySQL 或达梦 DM8 MySQL 兼容模式）："
  echo -e "     修改 DATABASE_URL 为实际数据库连接字符串"
  echo ""
  echo -e "  3. 启动服务："
  echo -e "     ${CYAN}systemctl start linux-exam${NC}"
  echo -e "     ${CYAN}systemctl enable linux-exam  # 开机自启${NC}"
  echo ""
  echo -e "  4. 访问管理后台："
  echo -e "     ${CYAN}http://$(hostname -I | awk '{print $1}'):3000${NC}"
  echo ""
  echo -e "  5. 客户端 Agent 使用："
  echo -e "     ${CYAN}python3 ${SCRIPT_DIR}/client_agent/exam_agent.py --server http://服务器IP:3000${NC}"
  echo ""
  echo -e "  安装日志: ${CYAN}$LOG_FILE${NC}"
  echo ""
}

# ─── 主流程 ───────────────────────────────────────────────────────────────────
main() {
  # 初始化日志
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "=== Linux 考试系统安装日志 $(date) ===" > "$LOG_FILE"

  echo ""
  echo -e "${BOLD}${CYAN}"
  echo "  ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗"
  echo "  ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝"
  echo "  ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ "
  echo "  ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ "
  echo "  ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗"
  echo "  ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝"
  echo -e "${NC}"
  echo -e "${BOLD}  Linux 考试系统 — 一键安装脚本 v1.0${NC}"
  echo -e "  兼容：Ubuntu 18.04+ / 麒麟 V10 SP1+"
  echo ""

  expand_path
  check_root
  detect_os

  case "$MODE" in
    full)
      install_base_deps
      install_nodejs
      install_python
      install_server
      install_client_agent
      run_tests
      print_summary
      ;;
    server-only)
      install_base_deps
      install_nodejs
      install_server
      run_tests
      print_summary
      ;;
    client-only)
      install_base_deps
      install_python
      install_client_agent
      run_tests
      ;;
    test-only)
      run_tests
      ;;
  esac
}

main "$@"
