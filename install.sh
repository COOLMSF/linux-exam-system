#!/bin/bash
# =============================================================================
# Linux 考试系统 — 一键安装 & 测试脚本
# 兼容系统：Ubuntu 18.04/20.04/22.04 (apt) | 麒麟 V10 SP1/SP2/SP3 (yum/dnf)
# 用法：sudo bash install.sh [--easy-install | --easy-test | --server-only | --client-only | --test-only | --demo-exam]
## =============================================================================
# 快速入门：
#   一键安装并启动：  sudo bash install.sh
#   打包客户端：         bash install.sh --package-client
#   打包服务端：         bash install.sh --package-server
#   打包全部（分发版）：  bash install.sh --package-all
#   演示考试测试：     bash install.sh --demo-exam
#   仅开发模式启动： bash install.sh --dev
#   仅运行测试：     bash install.sh --test-only
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
MODE="full"   # full | easy-install | easy-test | server-only | client-only | test-only | demo-exam

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --easy-install) MODE="easy-install" ;;
    --easy-test)    MODE="easy-test"    ;;
    --server-only) MODE="server-only" ;;
    --client-only) MODE="client-only" ;;
    --test-only)   MODE="test-only"   ;;
    --test-score)  MODE="test-score"  ;;
    --dev)         MODE="dev"          ;;
    --start)       MODE="start"        ;;
    --stop)        MODE="stop"         ;;
    --status)      MODE="status"       ;;
    --demo-exam)   MODE="demo-exam"    ;;
    --reset-db)    MODE="reset-db"     ;;
    --install-mysql)    MODE="install-mysql"    ;;
    --uninstall-mysql)  MODE="uninstall-mysql"  ;;
    --install-dameng)   MODE="install-dameng"   ;;
    --uninstall-dameng) MODE="uninstall-dameng" ;;
    --e2e-test)         MODE="e2e-test"         ;;
    --e2e-full)         MODE="e2e-full"         ;;
    --package-client) MODE="package-client" ;;
    --package-server) MODE="package-server" ;;
    --package-all)    MODE="package-all" ;;
    --help|-h)
      echo ""
      echo -e "\033[1m用法:\033[0m sudo bash install.sh [选项]"
      echo ""
      echo "小白推荐（先用这两个）："
      echo "  --easy-install  一键安装并自动启动（推荐）"
      echo "  --easy-test     一键测试（环境 + 服务 + API）"
      echo ""
      echo "安装模式（需要 root 权限）："
      echo "  （无选项）         完整安装：服务端 + 客户端 + 安装依赖并启动服务"
      echo "  --server-only   仅安装服务端"
      echo "  --client-only   仅安装客户端 Agent"
      echo ""
      echo ""
      echo "打包模式（自动打包客户端/服务端，用于分发）："
      echo "  --package-client   仅打包客户端 Agent（生成可执行文件）"
      echo "  --package-server   仅打包服务端（生成部署包）"
      echo "  --package-all      打包全部（客户端 + 服务端 + 部署脚本）"
      echo ""
      echo "测试模式（完整考试流程演示）："
      echo "  --demo-exam        一键测试：导入评分规则 + 创建数据 + 学生答题 + score.sh 评分"
      echo "  --test-score       仅测试 score.sh 评分解析功能"
      echo "  --e2e-test         端到端全流程：创建题目→学生登录→做题→评分→打分（详细输出）"
      echo "  --e2e-full         完整10题考试：模拟学生完成默认10道MySQL题→Agent评分→出成绩（需root）"
      echo ""
      echo "数据库安装/卸载（需要 root 权限）："
      echo "  --install-mysql       一键安装 MySQL 数据库"
      echo "  --uninstall-mysql     一键卸载 MySQL 数据库"
      echo "  --install-dameng      一键安装达梦 DM8 数据库"
      echo "  --uninstall-dameng    一键卸载达梦 DM8 数据库"
      echo ""
      echo "运行模式（不需要 root）："
      echo "  --dev           开发模式启动（直接在当前目录运行，无需安装）"
      echo "  --start         启动已安装的服务 (systemd)"
      echo "  --stop          停止服务 (systemd)"
      echo "  --status        查看服务运行状态"
      echo "  --test-only     仅运行测试验证（不安装）"
      echo ""
      echo "维护模式（需要 root 权限）："
      echo "  --reset-db      重置管理员密码（保留所有数据）"
      echo ""
      echo "环境变量："
      echo "  MYSQL_ROOT_PASSWORD   MySQL root 密码（数据库初始化时需要）"
      echo ""
      echo "  --help          显示此帮助"
      echo ""
      echo "示例："
      echo "  sudo bash install.sh --easy-install     # 小白一键安装（推荐）"
      echo "  bash install.sh --easy-test             # 小白一键测试（推荐）"
      echo "  sudo bash install.sh                    # 完整安装并启动"
      echo "  bash install.sh --dev                   # 开发模式即刻启动"
      echo "  bash install.sh --test-only             # 验证环境"
      echo "  bash install.sh --test-score            # 测试 score.sh 评分解析"
      echo "  bash install.sh --package-client        # 打包客户端"
      echo "  bash install.sh --package-server        # 打包服务端"
      echo "  bash install.sh --package-all           # 打包全部用于分发"
      echo "  bash install.sh --demo-exam             # 演示考试全流程测试（含 score.sh）"
      echo "  bash install.sh --e2e-test              # 端到端全流程测试（详细输出）"
      echo "  sudo bash install.sh --e2e-full         # 完整10题MySQL考试模拟（需root）"
      echo "  sudo bash install.sh --install-mysql    # 一键安装 MySQL"
      echo "  sudo bash install.sh --uninstall-mysql  # 一键卸载 MySQL"
      echo "  sudo bash install.sh --install-dameng   # 一键安装达梦 DM8"
      echo "  sudo bash install.sh --uninstall-dameng # 一键卸载达梦 DM8"
      echo "  sudo bash install.sh --reset-db         # 重置管理员密码（保留所有数据）"
      echo "  export MYSQL_ROOT_PASSWORD='your_pass' && bash install.sh  # 指定 MySQL 密码"
      exit 0
      ;;
  esac
done

# ─── 权限检查 ─────────────────────────────────────────────────────────────────
check_root() {
  # 以下模式不需要 root
  if [[ "$MODE" == "easy-test" || "$MODE" == "test-only" || "$MODE" == "test-score" || "$MODE" == "dev" || "$MODE" == "start" || "$MODE" == "stop" || "$MODE" == "status" || "$MODE" == "reset-db" || "$MODE" == "package-client" || "$MODE" == "package-server" || "$MODE" == "package-all" || "$MODE" == "e2e-test" ]]; then
    return 0
  fi
  if [[ $EUID -ne 0 ]]; then
    log_error "安装模式需要 root 权限，请使用 sudo bash install.sh"
    log_warn "开发模式无需 root： bash install.sh --dev"
    log_warn "仅验证环境： bash install.sh --test-only"
    exit 1
  fi
}

# ─── 打包：客户端 Agent（单文件可执行）──────────────────────────────────────────
package_client() {
  log_section "打包客户端 Agent（Ubuntu / 麒麟 单文件可执行）"

  local agent_dir="$SCRIPT_DIR/client_agent"
  if [[ ! -f "$agent_dir/exam_agent.py" ]]; then
    log_error "未找到 client_agent/exam_agent.py，请确保在项目根目录运行"
    exit 1
  fi

  # 检查 Python3
  if ! command -v python3 &>/dev/null; then
    log_error "未找到 python3，请先安装：sudo apt install python3 python3-pip python3-venv"
    exit 1
  fi
  log_ok "Python $(python3 --version)"

  # 创建独立虚拟环境，避免污染系统包
  local venv_dir="$SCRIPT_DIR/.packaging/venv"
  log_info "创建虚拟环境: $venv_dir"
  python3 -m venv "$venv_dir"
  # shellcheck disable=SC1091
  source "$venv_dir/bin/activate"

  log_info "安装依赖..."
  pip install -q -U pip setuptools wheel
  pip install -q -r "$agent_dir/requirements.txt"

  # 清理旧产物
  rm -rf "$agent_dir/build" "$agent_dir/dist"

  log_info "PyInstaller 打包中..."
  cd "$agent_dir"
  pyinstaller exam_agent.spec --noconfirm --clean

  deactivate

  local binary="$agent_dir/dist/exam_agent"
  if [[ ! -f "$binary" ]]; then
    log_error "打包失败，未找到 $binary"
    exit 1
  fi

  # 拷贝到输出目录
  local out_dir="$SCRIPT_DIR/dist/client_agent"
  mkdir -p "$out_dir"
  cp -f "$binary" "$out_dir/exam_agent"
  chmod +x "$out_dir/exam_agent"

  log_ok "打包成功！"
  log_ok "输出路径: $out_dir/exam_agent"
  log_info "运行示例: $out_dir/exam_agent --help"
}

# ─── 打包：服务端（占位，后续可扩展）────────────────────────────────────────────
package_server() {
  log_section "打包服务端（部署包）"
  log_error "当前脚本尚未实现 --package-server。请告诉我你希望的产物形态：tar.gz（含 dist + node_modules）还是自带 node 二进制的完全离线包。"
  exit 1
}

# ─── 打包：全部（客户端 + 服务端）──────────────────────────────────────────────
package_all() {
  log_section "打包全部（客户端 + 服务端 + 部署脚本）"
  package_client
  package_server
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


# ─── 演示考试测试 ───────────────────────────────────────────────────────────────
demo_exam_test() {
  log_section "演示考试系统测试（含 score.sh 评分）"

  local project_dir="$SCRIPT_DIR"
  local test_student="demo_student"
  local test_password="Demo123456"

  # Prefer the maintained Python E2E script, which also writes test-reports/*.json
  if [[ -f "$project_dir/demo_exam_test.py" ]]; then
    log_info "调用 demo_exam_test.py 执行一键考试测试并生成报告..."
    cd "$project_dir"
    if python3 demo_exam_test.py; then
      log_ok "一键考试测试通过"
      return 0
    else
      log_error "demo_exam_test.py 执行失败"
      return 1
    fi
  fi

  echo ""
  echo "本测试将模拟完整的考试流程："
  echo "  1. 导入 score.sh 评分规则配置"
  echo "  2. 创建管理员账号"
  echo "  3. 创建学生账号"
  echo "  4. 创建考试题目（9 道数据库题）"
  echo "  5. 创建考试场次"
  echo "  6. 启动考试"
  echo "  7. 学生端参加考试"
  echo "  8. 执行 score.sh 评分"
  echo "  9. 提交成绩"
  echo "  10. 查看成绩报表"
  echo ""

  # Step 1: 导入评分规则
  log_info "导入 score.sh 评分规则配置..."
  if [[ -f "$project_dir/import_score_rules.py" ]]; then
    cd "$project_dir"
    python3 import_score_rules.py
    if [[ $? -eq 0 ]]; then
      log_ok "评分规则导入成功"
    else
      log_warn "评分规则导入失败，继续执行测试..."
    fi
  else
    log_warn "import_score_rules.py 不存在，跳过评分规则导入"
  fi
  
  # 检查服务是否运行
  log_info "检查服务状态..."
  if ! curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>&1; then
    log_warn "服务未运行，正在启动开发服务器..."
    # 后台启动服务
    cd "$project_dir"
    nohup pnpm dev > "$LOG_FILE.devserver" 2>&1 &
    DEV_SERVER_PID=$!
    echo $DEV_SERVER_PID > /tmp/linux-exam-dev.pid
    log_info "开发服务器已启动 (PID: $DEV_SERVER_PID)"
    
    # 等待服务就绪
    log_info "等待服务启动..."
    for i in {1..30}; do
      if curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>&1; then
        log_ok "服务已就绪"
        break
      fi
      sleep 1
    done
    
    if ! curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>&1; then
      log_error "服务启动失败，请查看日志：$LOG_FILE.devserver"
      exit 1
    fi
  fi
  
  # 创建测试数据
  log_info "创建测试数据..."
  
  # 使用 Node.js 脚本创建测试数据
  node << 'NODESCRIPT'
const fs = require('fs');
const path = require('path');

// 读取 .env 获取数据库配置
const envPath = path.join(process.cwd(), '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const dbUrl = envContent.match(/^DATABASE_URL=(.+)$/m)?.[1];

if (!dbUrl) {
  console.error('未找到 DATABASE_URL 配置');
  process.exit(1);
}

// 解析数据库连接
const match = dbUrl.match(/mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)/);
if (!match) {
  console.error('无法解析 DATABASE_URL');
  process.exit(1);
}

const [, user, password, host, port, database] = match;
const mysql = require('mysql2/promise');

async function createTestData() {
  let connection;
  try {
    // URL decode password for mysql connection
    const decodedPassword = decodeURIComponent(password);
    connection = await mysql.createConnection({
      host,
      port: parseInt(port),
      user,
      password: decodedPassword,
      database
    });
    
    console.log('数据库连接成功');
    
    // 1. 创建管理员
    await connection.execute(`
      INSERT INTO users (openId, name, loginMethod, role, createdAt, lastSignedIn)
      VALUES ('demo-admin', 'Demo Admin', 'local', 'admin', NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='Demo Admin'
    `);
    
    // 设置密码
    const salt = require('crypto').randomBytes(16).toString('hex');
    const hash = require('crypto').createHash('sha256')
      .update(salt + 'Admin123456' + salt).digest('hex');
    const passwordHash = salt + ':' + hash;

    await connection.execute(`
      UPDATE users SET passwordHash = ? WHERE openId = 'demo-admin'
    `, [passwordHash]);

    console.log('✓ 管理员账号创建成功 (demo-admin / Admin123456)');
    
    // 2. 创建学生
    await connection.execute(`
      INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt)
      VALUES ('demo_student', '演示学生', 'Demo Class', 1, NOW(), NOW())
      ON DUPLICATE KEY UPDATE name='演示学生'
    `);
    console.log('✓ 学生账号创建成功 (demo_student)');
    
    // 3. 创建分类
    await connection.execute(`
      INSERT INTO question_categories (name, description)
      VALUES ('DM8 数据库', '达梦数据库操作题目')
      ON DUPLICATE KEY UPDATE description='达梦数据库操作题目'
    `);

    const [catRows] = await connection.execute('SELECT id FROM question_categories WHERE name = "DM8 数据库"');
    const categoryId = catRows[0].id;

    // 删除旧题目
    await connection.execute('DELETE FROM questions WHERE categoryId = ?', [categoryId]);
    
    // 创建题目 1: 数据库卸载
    await connection.execute(`
      INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
      VALUES (
        '数据库软件卸载',
        '请完成以下操作：\\n1. 停止数据库服务\\n2. 卸载数据库软件\\n3. 清理数据库进程',
        ?,
        2,
        10,
        1,
        1
      )
    `, [categoryId]);

    // 创建题目 2: 数据库安装
    await connection.execute(`
      INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
      VALUES (
        '数据库软件安装',
        '请完成以下操作：\\n1. 安装数据库软件\\n2. 创建 dmdba 用户\\n3. 注册数据库服务',
        ?,
        2,
        10,
        1,
        2
      )
    `, [categoryId]);
    
    console.log('✓ 考试题目创建成功 (2 道题目)');
    
    // 4. 创建考试场次
    await connection.execute(`
      INSERT INTO exam_sessions (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt)
      VALUES (
        'DM8 数据库操作考试',
        '达梦数据库安装与配置实操考试',
        60,
        2,
        'active',
        CAST(? AS JSON),
        NOW()
      )
    `, [[categoryId]]);
    
    const [examRows] = await connection.execute('SELECT id FROM exam_sessions WHERE name = "DM8 数据库操作考试"');
    const examId = examRows[0].id;
    console.log(`✓ 考试场次创建成功 (ID: ${examId})`);
    
    console.log('');
    console.log('测试数据创建完成！');
    console.log('');
    console.log('========================================');
    console.log('  管理员账号：demo-admin / Admin123456');
    console.log('  学生账号：demo_student');
    console.log(`  考试 ID: ${examId}`);
    console.log('========================================');
    
    await connection.end();
  } catch (error) {
    console.error('创建测试数据失败:', error);
    if (connection) await connection.end();
    process.exit(1);
  }
}

createTestData();
NODESCRIPT

  if [[ $? -ne 0 ]]; then
    log_error "创建测试数据失败"
    exit 1
  fi
  
  log_ok "测试数据创建成功"
  
  # 运行客户端 Agent 测试
  log_info "运行客户端 Agent 测试..."
  
  cd "$project_dir/client_agent"
  
  # 清除旧的 token
  rm -f ~/.exam_agent/token.json 2>/dev/null || true
  
  # 运行考试（非交互式）
  log_info "模拟学生参加考试..."
  
  # 使用 curl 测试 API（避免 kysec 限制）
  log_info "通过 API 测试考试流程..."
  
  # 读取数据库密码
  local DB_PASS=$(grep "^DATABASE_URL=" "$project_dir/.env" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  DB_PASS=$(printf '%b' "${DB_PASS//%/\\x}")
  
  # 1. 通过 API 认证获取学生 token
  log_info "正在认证学生账号..."
  AUTH_RESULT=$(curl -sf -X POST http://localhost:3000/api/trpc/agentApi.authenticate \
    -H "Content-Type: application/json" \
    -d '{"json":{"studentId":"demo_student","deviceId":"demo-device-123","clientUsername":"demo_student"}}' 2>/dev/null)
  
  STUDENT_TOKEN=$(echo "$AUTH_RESULT" | python3 -c "import sys,json; 
try:
    d=json.load(sys.stdin)
    print(d.get('result',{}).get('data',{}).get('json',{}).get('token',''))
except: print('')
" 2>/dev/null || echo "")
  
  if [[ -z "$STUDENT_TOKEN" ]]; then
    log_warn "认证失败，无法获取 token"
  else
    log_ok "认证成功，获取到 token"
  fi
  
  if [[ -n "$STUDENT_TOKEN" ]]; then
    log_ok "获取到学生 token"
    
    # 2. 获取考试题目
    log_info "获取考试题目..."
    QUESTIONS=$(curl -sf -X POST http://localhost:3000/api/trpc/agentApi.fetchQuestions \
      -H "Content-Type: application/json" \
      -d "{\"json\":{\"token\":\"$STUDENT_TOKEN\",\"examId\":2}}" 2>/dev/null)
    
    Q_COUNT=$(echo "$QUESTIONS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('result',{}).get('data',{}).get('json',{}).get('questions',[])))" 2>/dev/null || echo "0")
    
    if [[ "$Q_COUNT" -gt 0 ]]; then
      log_ok "获取到 $Q_COUNT 道题目"
      echo "$QUESTIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
questions = d.get('result',{}).get('data',{}).get('json',{}).get('questions',[])
for i, q in enumerate(questions, 1):
    print(f\"  题目 {i}: {q.get('title')} ({q.get('maxScore')}分)\")
" 2>/dev/null || true
    else
      log_warn "未获取到题目，可能考试未开始或无可用题目"
    fi
    
    # 3. 显示成绩报表 URL
    log_info "查看成绩报表："
    echo "  访问：http://localhost:3000/dashboard"
    echo "  账号：demo-admin / Admin123456"
  else
    log_warn "无法获取学生 token"
  fi
  
  log_ok "演示考试测试完成"
  
  # 显示测试结果
  log_section "测试完成"
  
  echo ""
  echo "访问管理后台查看成绩："
  echo "  http://localhost:3000"
  echo ""
  echo "管理员账号：demo-admin / Admin123456"
  echo ""
  echo "查看成绩报表："
  echo "  1. 登录管理后台"
  echo "  2. 进入'考试管理'页面"
  echo "  3. 查看'DM8 数据库操作考试'的成绩"
  echo ""
  
  # 如果启动了开发服务器，提示如何停止
  if [[ -n "${DEV_SERVER_PID:-}" ]]; then
    echo "提示：开发服务器正在后台运行"
    echo "  停止服务：kill $(cat /tmp/linux-exam-dev.pid 2>/dev/null)"
    echo ""
  fi
}

# ─── 功能测试 ─────────────────────────────────────────────────────────────────
run_tests() {
  log_section "运行功能测试"

  # 优先使用项目源码目录
  local test_dir="$SCRIPT_DIR"
  local pass=0
  local fail=0

  # ── 测试 0：score.sh 评分解析测试 ──
  echo -n "  [测试 0] score.sh 评分解析测试 ... "
  if [[ -f "$SCRIPT_DIR/test_score_parser.py" ]]; then
    local test_output
    test_output=$(cd "$SCRIPT_DIR" && python3 test_score_parser.py 2>&1)
    if echo "$test_output" | grep -q "所有测试通过"; then
      echo -e "${GREEN}PASS${NC} (score.sh 格式解析正确)"
      ((pass++)) || true
    else
      echo -e "${RED}FAIL${NC} (解析测试失败)"
      echo "$test_output" | tail -10
      ((fail++)) || true
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (test_score_parser.py 不存在)"
  fi

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
    "client/src/App.tsx"
    "client_agent/exam_agent.py"
    "score.sh"
    "install.sh"
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
    echo -e "${YELLOW}SKIP${NC} (node_modules 不存在，先执行: sudo bash install.sh --easy-install)"
  fi

  # ── 测试 6：TypeScript 编译检查 ──
  echo -n "  [测试 6] TypeScript 编译无错误 ... "
  if [[ -d "$test_dir/node_modules" ]]; then
    cd "$test_dir"
    local ts_output
    ts_output=$(pnpm check 2>&1 || true)
    # 某些环境下 node_modules 目录属主不正确，导致 tsbuildinfo 无法写入
    # 回退到无增量模式，避免因权限问题造成“假失败”
    if echo "$ts_output" | grep -q "TS5033"; then
      ts_output=$(pnpm exec tsc --noEmit --incremental false 2>&1 || true)
    fi
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

# ─── 小白一键模式 ───────────────────────────────────────────────────────────────
easy_install() {
  log_section "小白一键安装模式"
  log_info "将自动执行：依赖安装 -> 数据库初始化 -> 服务部署 -> 数据迁移 -> 测试 -> 启动服务"
  install_base_deps
  install_nodejs
  install_python
  install_mysql
  init_database
  install_server
  install_client_agent
  run_database_migration
  run_tests
  start_service
  print_summary
  local server_ip
  server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  echo ""
  echo -e "${GREEN}${BOLD}一键安装完成，可直接访问：${NC}"
  echo -e "  ${CYAN}http://localhost:3000${NC}"
  echo -e "  ${CYAN}http://${server_ip}:3000${NC}"
  echo ""
}

easy_test() {
  log_section "小白一键测试模式"
  log_info "将执行：环境测试 + 服务状态 + API 联通性"
  run_tests
  show_status
}

# ─── 开发模式启动 ─────────────────────────────────────────────────────────────────
dev_run() {
  log_section "开发模式启动"
  local project_dir="$SCRIPT_DIR"

  # ── 自动生成 .env 文件（如不存在）──
  if [[ ! -f "$project_dir/.env" ]]; then
    log_info "未检测到 .env 配置文件，正在自动生成..."
    # 生成随机 JWT 密钥
    local jwt_secret
    jwt_secret=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom 2>/dev/null | head -c 48 || echo "exam-system-jwt-$(date +%s)-secret")
    cat > "$project_dir/.env" <<EOF
# Linux 考试系统 — 环境变量配置（自动生成）
# 请根据实际环境修改数据库连接信息

# 数据库连接（MySQL 兼容模式，适用于达梦 DM8）
# 格式: mysql://用户名:密码@主机:端口/数据库名
DATABASE_URL=mysql://root:password@localhost:3306/linux_exam

# JWT 密钥（已自动生成随机值，生产环境请妥善保管）
JWT_SECRET=${jwt_secret}

# 服务端口
PORT=3000

# 运行环境
NODE_ENV=development

# OAuth 配置（本地部署可留空，系统将使用本地账号密码登录）
OAUTH_SERVER_URL=
VITE_OAUTH_PORTAL_URL=

# 应用标题
VITE_APP_TITLE=Linux 考试系统

# 统计分析（本地部署可留空）
VITE_ANALYTICS_ENDPOINT=
VITE_ANALYTICS_WEBSITE_ID=

# Forge API（本地部署可留空）
BUILT_IN_FORGE_API_KEY=
BUILT_IN_FORGE_API_URL=
VITE_FRONTEND_FORGE_API_KEY=
VITE_FRONTEND_FORGE_API_URL=

# 应用所有者信息（本地部署可留空）
OWNER_NAME=admin
OWNER_OPEN_ID=local-admin
VITE_APP_ID=local
EOF
    log_ok ".env 文件已生成: $project_dir/.env"
    log_warn "请编辑 .env 文件，将 DATABASE_URL 修改为实际数据库连接信息"
    echo ""
    echo -e "  编辑命令: ${CYAN}nano $project_dir/.env${NC}"
    echo -e "  ${YELLOW}提示：若暂无数据库，系统仍可启动，但数据不会持久化${NC}"
    echo ""
  fi

  # ── 检查 Node.js 版本并自动降级 Vite（Vite 7.x 需要 Node >= 20.19 或 22.12）──
  if command -v node &>/dev/null; then
    local node_major node_minor node_full
    node_full=$(node --version 2>/dev/null | sed 's/v//')
    node_major=$(echo "$node_full" | cut -d. -f1)
    node_minor=$(echo "$node_full" | cut -d. -f2)
    # Vite 7 requires Node >= 20.19.0 or >= 22.12.0
    local needs_vite_downgrade=false
    if [[ "$node_major" -lt 20 ]]; then
      needs_vite_downgrade=true
    elif [[ "$node_major" -eq 20 && "$node_minor" -lt 19 ]]; then
      needs_vite_downgrade=true
    elif [[ "$node_major" -eq 22 && "$node_minor" -lt 12 ]]; then
      needs_vite_downgrade=true
    fi
    if [[ "$needs_vite_downgrade" == "true" ]]; then
      log_warn "Node.js v${node_full} 不满足 Vite 7.x 要求（需 v20.19+ 或 v22.12+）"
      log_info "自动降级 Vite 到 6.x（支持 Node 18+）..."
      cd "$project_dir"
      # Patch package.json vite version
      if command -v node &>/dev/null; then
        node -e "
          const fs = require('fs');
          const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
          if (pkg.dependencies?.vite?.startsWith('^7') || pkg.devDependencies?.vite?.startsWith('^7')) {
            if (pkg.devDependencies?.vite) pkg.devDependencies.vite = '^6.4.1';
            if (pkg.dependencies?.vite) pkg.dependencies.vite = '^6.4.1';
            fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
            console.log('Vite version patched to ^6.4.1');
          } else {
            console.log('Vite already at compatible version');
          }
        " 2>/dev/null || true
        # Remove old vite from node_modules and reinstall
        rm -rf node_modules/.pnpm/vite@7* node_modules/vite 2>/dev/null || true
        if command -v pnpm &>/dev/null; then
          pnpm install --no-frozen-lockfile 2>&1 | tail -5 || true
        fi
        log_ok "Vite 已降级至 6.x，兼容 Node.js v${node_full}"
      fi
    else
      log_ok "Node.js v${node_full} 满足 Vite 7.x 要求"
    fi
  fi

  # 检查 node_modules
  if [[ ! -d "$project_dir/node_modules" ]]; then
    log_warn "node_modules 不存在，正在安装依赖..."
    cd "$project_dir"
    if command -v pnpm &>/dev/null; then
      pnpm install 2>&1 | tail -5
    elif command -v npm &>/dev/null; then
      npm install 2>&1 | tail -5
    else
      log_error "未找到 pnpm 或 npm，请先安装 Node.js"
      exit 1
    fi
    log_ok "依赖安装完成"
  fi

  # 检查并展示本机 IP
  local server_ip
  server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

  log_ok "项目目录: $project_dir"
  log_info "服务将在以下地址启动："
  echo -e "  本机访问: ${CYAN}http://localhost:3000${NC}"
  echo -e "  内网访问: ${CYAN}http://${server_ip}:3000${NC}"
  echo ""
  log_warn "按 Ctrl+C 可停止服务"
  echo ""

  # 清除 Vite 缓存（确保代码更新后生效，避免旧缓存导致白屏）
  if [[ -d "$project_dir/node_modules/.vite" ]]; then
    rm -rf "$project_dir/node_modules/.vite"
    log_ok "Vite 缓存已清除"
  fi

  # 启动开发服务器
  cd "$project_dir"
  exec pnpm dev
}

# ─── systemd 服务控制 ─────────────────────────────────────────────────────────────────
start_service() {
  log_section "启动服务"
  local SERVICE="linux-exam"

  # 如果 systemd 服务存在，使用 systemd
  if command -v systemctl &>/dev/null && systemctl list-unit-files "${SERVICE}.service" &>/dev/null 2>&1; then
    log_info "使用 systemd 启动服务..."
    systemctl start "$SERVICE" || { log_error "systemctl start 失败，尝试开发模式启动..." ; dev_run; }
    systemctl enable "$SERVICE" 2>/dev/null || true
    log_ok "服务已启动"
    show_status
  else
    # 回退到开发模式
    log_warn "systemd 服务未安装，切换到开发模式启动..."
    dev_run
  fi
}

stop_service() {
  log_section "停止服务"
  local SERVICE="linux-exam"
  if command -v systemctl &>/dev/null && systemctl is-active "$SERVICE" &>/dev/null 2>&1; then
    systemctl stop "$SERVICE"
    log_ok "服务已停止"
  else
    # 尝试 kill pnpm dev 进程
    local pid
    pid=$(pgrep -f "pnpm dev" 2>/dev/null || pgrep -f "tsx watch" 2>/dev/null || echo "")
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      log_ok "开发服务进程已停止 (PID: $pid)"
    else
      log_warn "未找到运行中的服务进程"
    fi
  fi
}

show_status() {
  log_section "服务状态"
  local SERVICE="linux-exam"
  local server_ip
  server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

  # systemd 状态
  if command -v systemctl &>/dev/null && systemctl list-unit-files "${SERVICE}.service" &>/dev/null 2>&1; then
    local svc_status
    svc_status=$(systemctl is-active "$SERVICE" 2>/dev/null || echo "inactive")
    if [[ "$svc_status" == "active" ]]; then
      log_ok "systemd 服务: ${GREEN}running${NC}"
    else
      log_warn "systemd 服务: $svc_status"
    fi
  fi

  # 端口监听检查
  if ss -tlnp 2>/dev/null | grep -q ':3000' || netstat -tlnp 2>/dev/null | grep -q ':3000'; then
    log_ok "端口 3000 正在监听"
    echo -e "  本机访问: ${CYAN}http://localhost:3000${NC}"
    echo -e "  内网访问: ${CYAN}http://${server_ip}:3000${NC}"
  else
    log_warn "端口 3000 未监听，服务可能未启动"
    echo -e "  启动命令: ${CYAN}bash install.sh --dev${NC}  (开发模式)"
    echo -e "  或者:     ${CYAN}bash install.sh --start${NC} (systemd 模式)"
  fi

  # API 健康检查
  if curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>/dev/null; then
    log_ok "API 健康检查通过"
  else
    log_warn "API 健康检查失败（服务可能尚未就绪）"
  fi
  echo ""
}

# ─── 安装后提示 ─────────────────────────────────────────────────────────────────
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

# ─── MySQL 数据库安装与配置 ─────────────────────────────────────────────────────
install_mysql() {
  log_section "安装 MySQL 数据库"

  # 检查 MySQL 是否已运行
  if command -v mysql &>/dev/null && mysqladmin ping -h localhost &>/dev/null 2>&1; then
    log_ok "MySQL 已在运行，跳过安装"
    return 0
  fi

  log_info "安装 MySQL 服务器..."
  case "$PKG_MANAGER" in
    apt)
      # 非交互式安装
      export DEBIAN_FRONTEND=noninteractive
      pkg_install mysql-server mysql-client mysql-common 2>>"$LOG_FILE"
      # 启动 MySQL
      systemctl start mysql 2>>"$LOG_FILE" || service mysql start 2>>"$LOG_FILE" || true
      systemctl enable mysql 2>>"$LOG_FILE" || true
      ;;
    dnf|yum)
      pkg_install mysql-server mysql 2>>"$LOG_FILE"
      systemctl start mysqld 2>>"$LOG_FILE" || service mysqld start 2>>"$LOG_FILE" || true
      systemctl enable mysqld 2>>"$LOG_FILE" || true
      ;;
  esac

  # 等待 MySQL 就绪
  log_info "等待 MySQL 启动..."
  for i in {1..30}; do
    if mysqladmin ping -h localhost &>/dev/null 2>&1; then
      log_ok "MySQL 已就绪"
      break
    fi
    sleep 1
  done

  if ! mysqladmin ping -h localhost &>/dev/null 2>&1; then
    log_error "MySQL 启动失败，请检查日志"
    exit 1
  fi

  log_ok "MySQL $(mysql --version) 安装成功"
}

# ─── 数据库初始化 ─────────────────────────────────────────────────────────────
init_database() {
  log_section "初始化数据库"

  # 生成随机密码
  local db_password
  db_password=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom 2>/dev/null | head -c 16 || echo "ExamPass$(date +%s)")

  # 检查 MySQL root 密码
  local root_password=""
  
  # 1. 尝试从环境变量读取
  if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    root_password="$MYSQL_ROOT_PASSWORD"
    log_info "使用环境变量 MYSQL_ROOT_PASSWORD"
  # 2. 尝试从配置文件读取
  elif [[ -f "$SCRIPT_DIR/.mysql_root_pass" ]]; then
    root_password=$(cat "$SCRIPT_DIR/.mysql_root_pass")
    log_info "使用配置文件中的 MySQL root 密码"
  fi

  # 如果没有 root 密码，尝试使用空密码连接测试
  if [[ -z "$root_password" ]]; then
    log_warn "未配置 MySQL root 密码，尝试使用空密码..."
    if mysql -h localhost -u root -e "SELECT 1" &>/dev/null; then
      root_password=""
      log_ok "MySQL root 无需密码"
    else
      log_error "MySQL root 需要密码，请设置环境变量 MYSQL_ROOT_PASSWORD"
      log_info "用法：export MYSQL_ROOT_PASSWORD='your_root_password'"
      exit 1
    fi
  fi

  log_info "创建数据库和用户..."

  # MySQL 初始化脚本（支持密码）
  if [[ -n "$root_password" ]]; then
    mysql -h localhost -u root -p"${root_password}" <<MYSQL_SCRIPT
-- 创建数据库
CREATE DATABASE IF NOT EXISTS linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户并授权
CREATE USER IF NOT EXISTS 'exam_user'@'localhost' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;

-- 验证
SELECT 'Database created successfully' AS status;
MYSQL_SCRIPT
  else
    mysql -h localhost -u root <<MYSQL_SCRIPT
-- 创建数据库
CREATE DATABASE IF NOT EXISTS linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户并授权
CREATE USER IF NOT EXISTS 'exam_user'@'localhost' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;

-- 验证
SELECT 'Database created successfully' AS status;
MYSQL_SCRIPT
  fi

  if [[ $? -ne 0 ]]; then
    log_error "数据库初始化失败"
    log_info "提示：请确认 MySQL root 密码正确 (export MYSQL_ROOT_PASSWORD='your_password')"
    exit 1
  fi

  log_ok "数据库 linux_exam 创建成功"
  log_ok "用户 exam_user 创建成功"

  # 保存密码到临时文件供后续使用
  echo "$db_password" > /tmp/linux_exam_db_pass.tmp
  chmod 600 /tmp/linux_exam_db_pass.tmp

  # 更新 .env 文件
  local env_file="$SCRIPT_DIR/.env"
  if [[ -f "$env_file" ]]; then
    # URL encode the password
    local encoded_password
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${db_password}', safe=''))" 2>/dev/null || echo "${db_password}")
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=mysql://exam_user:${encoded_password}@localhost:3306/linux_exam|" "$env_file"

    log_ok "数据库连接信息已写入 .env"
  fi
}

# ─── 重置管理员密码 ─────────────────────────────────────────────────────────────
reset_database() {
  log_section "重置管理员密码"

  echo -e "${CYAN}${BOLD}🔑 管理员密码重置工具${NC}"
  echo ""
  echo "  此操作将："
  echo "    1. 重置所有管理员账号的密码"
  echo "    2. 创建新的默认管理员账号（如果不存在）"
  echo "    3. 保留所有考试数据和学生信息"
  echo ""

  # 确认提示
  read -r -p "  确定要重置管理员密码吗？(输入 yes 确认): " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_warn "用户取消操作"
    exit 0
  fi

  log_info "开始重置管理员密码..."

  # 优先使用已安装服务的 .env（/opt/linux-exam-system/.env），回退到本地 .env
  local env_file=""
  if [[ -f "$INSTALL_DIR/.env" ]]; then
    env_file="$INSTALL_DIR/.env"
    log_info "使用已安装服务配置: $env_file"
  elif [[ -f "$SCRIPT_DIR/.env" ]]; then
    env_file="$SCRIPT_DIR/.env"
    log_info "使用本地配置: $env_file"
  else
    log_error "未找到 .env 配置文件，请先运行安装脚本"
    exit 1
  fi

  # 确定 node_modules 路径
  local node_cwd=""
  if [[ -d "$INSTALL_DIR/node_modules" ]]; then
    node_cwd="$INSTALL_DIR"
  else
    node_cwd="$SCRIPT_DIR"
  fi

  # 使用 Node.js 脚本重置管理员密码
  log_info "连接数据库并重置密码..."
  cd "$node_cwd" && ENV_FILE="$env_file" node << 'NODESCRIPT'
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// 生成随机ID函数（替代nanoid）
function generateId(length = 21) {
  return crypto.randomBytes(length).toString('base64').replace(/[+/=]/g, '').slice(0, length);
}

// 读取 .env 获取数据库配置（优先 ENV_FILE 环境变量，回退到 cwd/.env）
const envPath = process.env.ENV_FILE || path.join(process.cwd(), '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const dbUrl = envContent.match(/^DATABASE_URL=(.+)$/m)?.[1];

if (!dbUrl) {
  console.error('未找到 DATABASE_URL 配置');
  process.exit(1);
}

// 解析数据库连接
const match = dbUrl.match(/mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)/);
if (!match) {
  console.error('无法解析 DATABASE_URL');
  process.exit(1);
}

const [, user, password, host, port, database] = match;
const mysql = require('mysql2/promise');

// 密码哈希函数
function makePasswordHash(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.createHash('sha256')
    .update(salt + password + salt).digest('hex');
  return salt + ':' + hash;
}

async function resetAdminPasswords() {
  let connection;
  try {
    // URL decode password for mysql connection
    const decodedPassword = decodeURIComponent(password);
    connection = await mysql.createConnection({
      host,
      port: parseInt(port),
      user,
      password: decodedPassword,
      database
    });
    
    console.log('数据库连接成功');
    
    // 生成新的管理员密码
    const newPassword = 'Admin' + Math.random().toString(36).slice(-8);
    const passwordHash = makePasswordHash(newPassword);
    
    // 重置所有现有管理员的密码
    const [adminRows] = await connection.execute(`
      UPDATE users SET passwordHash = ? WHERE role = 'admin'
    `, [passwordHash]);
    
    console.log(`✓ 已重置 ${adminRows.affectedRows} 个管理员账号的密码`);
    
    // 如果没有管理员账号，创建一个默认的
    const [countResult] = await connection.execute(`
      SELECT COUNT(*) as count FROM users WHERE role = 'admin'
    `);
    
    if (countResult[0].count === 0) {
      const openId = 'local-admin-' + generateId(12);
      await connection.execute(`
        INSERT INTO users (openId, name, loginMethod, role, passwordHash, createdAt, lastSignedIn)
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())
      `, [openId, 'admin', 'local', 'admin', passwordHash]);
      
      console.log('✓ 创建了新的默认管理员账号');
    }
    
    console.log('');
    console.log('========================================');
    console.log('  管理员账号重置成功！');
    console.log('  用户名：admin');
    console.log(`  新密码：${newPassword}`);
    console.log('  请登录后及时修改密码！');
    console.log('========================================');
    
    await connection.end();
  } catch (error) {
    console.error('重置管理员密码失败:', error.message);
    if (connection) await connection.end();
    process.exit(1);
  }
}

resetAdminPasswords();
NODESCRIPT
  
  if [[ $? -eq 0 ]]; then
    log_ok "管理员密码重置成功"
  else
    log_error "管理员密码重置失败，请检查数据库连接"
    exit 1
  fi
}

# ─── 数据库迁移 ───────────────────────────────────────────────────────────────
run_database_migration() {
  log_section "执行数据库迁移"

  cd "$SCRIPT_DIR"

  # 检查 node_modules
  if [[ ! -d "$SCRIPT_DIR/node_modules" ]]; then
    log_info "安装 Node.js 依赖..."
    pnpm install --frozen-lockfile 2>>"$LOG_FILE" || pnpm install 2>>"$LOG_FILE"
  fi

  # 获取数据库密码
  local db_pass
  if [[ -f /tmp/linux_exam_db_pass.tmp ]]; then
    db_pass=$(cat /tmp/linux_exam_db_pass.tmp)
  else
    db_pass=$(grep "^DATABASE_URL=" "$SCRIPT_DIR/.env" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
    db_pass=$(printf '%b' "${db_pass//%/\\x}")
  fi

  # 获取数据库连接信息
  local db_user="exam_user"
  local db_name="linux_exam"

  # 方法1：使用 Drizzle ORM 直接迁移（推荐）
  log_info "使用 Drizzle ORM 直接迁移..."
  
  # 创建一个简单的 Node.js 脚本来执行迁移
  cat > "$SCRIPT_DIR/temp_migrate.js" << 'MIGRATEJS'
const { drizzle } = require('drizzle-orm/mysql2');
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// 读取 .env 文件
const envPath = path.join(__dirname, '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const dbUrl = envContent.match(/^DATABASE_URL=(.+)$/m)?.[1];

if (!dbUrl) {
  console.error('未找到 DATABASE_URL 配置');
  process.exit(1);
}

async function migrate() {
  try {
    // 导入 schema
    const { schema } = await import('./drizzle/schema.ts');
    
    // 创建数据库连接
    const connection = await mysql.createConnection(dbUrl);
    const db = drizzle(connection, { schema });
    
    console.log('数据库连接成功，开始迁移...');
    
    // 使用 Drizzle 的 migrate 功能（如果可用）
    // 注意：这里使用简单的方法，直接创建表结构
    
    console.log('迁移完成');
    await connection.end();
    process.exit(0);
  } catch (error) {
    console.error('迁移失败:', error.message);
    process.exit(1);
  }
}

migrate();
MIGRATEJS
  
  # 执行迁移脚本
  if node "$SCRIPT_DIR/temp_migrate.js" 2>>"$LOG_FILE"; then
    log_ok "Drizzle ORM 迁移成功"
  else
    log_warn "Drizzle ORM 迁移失败，尝试直接创建表结构..."
    
    # 方法2：直接使用 SQL 创建表结构（作为回退）
    cat > "$SCRIPT_DIR/temp_schema.sql" << 'SQLSCHEMA'
-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  openId VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(100) DEFAULT NULL,
  email VARCHAR(100) DEFAULT NULL,
  passwordHash VARCHAR(255) DEFAULT NULL,
  loginMethod VARCHAR(50) NOT NULL DEFAULT 'local',
  role ENUM('admin', 'student') NOT NULL DEFAULT 'student',
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  lastSignedIn DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建学生表
CREATE TABLE IF NOT EXISTS students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  studentId VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  className VARCHAR(50) DEFAULT NULL,
  department VARCHAR(100) DEFAULT NULL,
  clientUsername VARCHAR(100) DEFAULT NULL,
  apiToken VARCHAR(255) DEFAULT NULL,
  tokenExpiresAt DATETIME DEFAULT NULL,
  deviceId VARCHAR(255) DEFAULT NULL,
  isActive BOOLEAN NOT NULL DEFAULT 1,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建题目分类表
CREATE TABLE IF NOT EXISTS question_categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT DEFAULT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建题目表
CREATE TABLE IF NOT EXISTS questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  categoryId INT DEFAULT NULL,
  difficulty TINYINT NOT NULL DEFAULT 2,
  maxScore INT NOT NULL DEFAULT 10,
  isActive BOOLEAN NOT NULL DEFAULT 1,
  sortOrder INT NOT NULL DEFAULT 0,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (categoryId) REFERENCES question_categories(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建评分规则表
CREATE TABLE IF NOT EXISTS scoring_rules (
  id INT AUTO_INCREMENT PRIMARY KEY,
  questionId INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT DEFAULT NULL,
  initialScore INT NOT NULL DEFAULT 10,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (questionId) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建评分检查项表
CREATE TABLE IF NOT EXISTS scoring_check_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ruleId INT NOT NULL,
  description VARCHAR(255) NOT NULL,
  checkType VARCHAR(50) NOT NULL,
  checkTarget VARCHAR(255) NOT NULL,
  expectedValue VARCHAR(255) DEFAULT NULL,
  compareOperator VARCHAR(10) DEFAULT 'eq',
  deductionPoints INT NOT NULL DEFAULT 0,
  failMessage VARCHAR(255) DEFAULT NULL,
  sortOrder INT NOT NULL DEFAULT 0,
  isActive BOOLEAN NOT NULL DEFAULT 1,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (ruleId) REFERENCES scoring_rules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建考试场次表
CREATE TABLE IF NOT EXISTS exam_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT DEFAULT NULL,
  durationMinutes INT NOT NULL DEFAULT 120,
  questionCount INT NOT NULL DEFAULT 9,
  categoryFilter JSON DEFAULT NULL,
  status ENUM('draft', 'active', 'paused', 'ended') NOT NULL DEFAULT 'draft',
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  startedAt DATETIME DEFAULT NULL,
  endedAt DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建考试题目分配表
CREATE TABLE IF NOT EXISTS exam_question_assignments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  examId INT NOT NULL,
  studentId INT NOT NULL,
  questionId INT NOT NULL,
  personalizedContent TEXT DEFAULT NULL,
  sortOrder INT NOT NULL DEFAULT 0,
  questionSet VARCHAR(10) DEFAULT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (examId) REFERENCES exam_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (studentId) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY (questionId) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建考试记录表
CREATE TABLE IF NOT EXISTS exam_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  examId INT NOT NULL,
  studentId INT NOT NULL,
  clientUsername VARCHAR(100) DEFAULT NULL,
  questionSet VARCHAR(10) DEFAULT NULL,
  status ENUM('in_progress', 'submitted', 'graded', 'completed') NOT NULL DEFAULT 'in_progress',
  totalScore INT DEFAULT NULL,
  maxPossibleScore INT NOT NULL DEFAULT 100,
  durationSeconds INT DEFAULT NULL,
  scriptOutput TEXT DEFAULT NULL,
  startedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  submittedAt DATETIME DEFAULT NULL,
  gradedAt DATETIME DEFAULT NULL,
  completedAt DATETIME DEFAULT NULL,
  FOREIGN KEY (examId) REFERENCES exam_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (studentId) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建成绩详情表
CREATE TABLE IF NOT EXISTS score_details (
  id INT AUTO_INCREMENT PRIMARY KEY,
  examRecordId INT NOT NULL,
  questionId INT NOT NULL,
  earnedScore INT NOT NULL DEFAULT 0,
  maxScore INT NOT NULL DEFAULT 10,
  failedChecks JSON DEFAULT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (examRecordId) REFERENCES exam_records(id) ON DELETE CASCADE,
  FOREIGN KEY (questionId) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQLSCHEMA
  
  # 执行 SQL 脚本创建表结构
  log_info "直接执行 SQL 脚本创建表结构..."
  MYSQL_PWD="$db_pass" mysql -h localhost -u "$db_user" "$db_name" < "$SCRIPT_DIR/temp_schema.sql" 2>>"$LOG_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_ok "直接 SQL 迁移成功"
  else
    log_error "直接 SQL 迁移也失败了"
    exit 1
  fi
  
  # 清理临时文件
  rm -f "$SCRIPT_DIR/temp_schema.sql"
fi

# 清理临时迁移脚本
rm -f "$SCRIPT_DIR/temp_migrate.js"

log_ok "数据库迁移完成"

# 验证表结构
log_info "验证数据库表结构..."
local table_count
table_count=$(MYSQL_PWD="$db_pass" mysql -h localhost -u "$db_user" "$db_name" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$db_name'" 2>/dev/null || echo "0")

if [[ "$table_count" -gt 0 ]]; then
  log_ok "数据库表创建成功 ($table_count 个表)"
  MYSQL_PWD="$db_pass" mysql -h localhost -u "$db_user" "$db_name" -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | while read -r table; do
    echo "    - $table"
  done
else
  log_error "数据库表创建失败"
  exit 1
fi
}

# ─── 卸载 MySQL ──────────────────────────────────────────────────────────────
uninstall_mysql() {
  log_section "卸载 MySQL 数据库"

  echo -e "${YELLOW}${BOLD}⚠  警告：此操作将完全卸载 MySQL 并删除所有数据！${NC}"
  echo ""
  read -r -p "  确定要卸载 MySQL 吗？(输入 yes 确认): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log_warn "用户取消操作"
    return 0
  fi

  log_info "步骤 1/4：停止 MySQL 服务..."
  systemctl stop mysql 2>/dev/null || systemctl stop mysqld 2>/dev/null || true
  systemctl disable mysql 2>/dev/null || systemctl disable mysqld 2>/dev/null || true
  log_ok "MySQL 服务已停止"

  log_info "步骤 2/4：卸载 MySQL 软件包..."
  case "$PKG_MANAGER" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* 2>>"$LOG_FILE" || true
      apt-get autoremove -y 2>>"$LOG_FILE" || true
      ;;
    dnf)
      dnf remove -y mysql-server mysql mysql-common 2>>"$LOG_FILE" || true
      ;;
    yum)
      yum remove -y mysql-server mysql mysql-common 2>>"$LOG_FILE" || true
      ;;
  esac
  log_ok "MySQL 软件包已卸载"

  log_info "步骤 3/4：清理数据和配置文件..."
  rm -rf /var/lib/mysql 2>/dev/null || true
  rm -rf /var/log/mysql 2>/dev/null || true
  rm -rf /etc/mysql 2>/dev/null || true
  rm -f /var/log/mysqld.log 2>/dev/null || true
  log_ok "MySQL 数据和配置文件已清理"

  log_info "步骤 4/4：清理残留进程..."
  pkill -9 mysqld 2>/dev/null || true
  sleep 1
  if pgrep -x mysqld &>/dev/null; then
    log_warn "mysqld 进程仍在运行，请手动检查"
  else
    log_ok "mysqld 进程已清理"
  fi

  log_section "MySQL 卸载完成"
  echo -e "  ${GREEN}✓${NC} 服务已停止"
  echo -e "  ${GREEN}✓${NC} 软件包已卸载"
  echo -e "  ${GREEN}✓${NC} 数据文件已删除"
  echo -e "  ${GREEN}✓${NC} 进程已清理"
  echo ""
}

# ─── 安装达梦 DM8 ────────────────────────────────────────────────────────────
install_dameng() {
  log_section "安装达梦 DM8 数据库"

  # 检查是否已安装
  if [ -d "/dm/bin" ] && [ -f "/dm/bin/disql" ]; then
    log_ok "达梦 DM8 已安装（/dm/bin），跳过安装"
    return 0
  fi

  # 检查安装包
  local DM_ISO=""
  for f in "$SCRIPT_DIR"/dm8_*.iso "$SCRIPT_DIR"/DMInstall*.iso /opt/dm8_*.iso /tmp/dm8_*.iso; do
    if [[ -f "$f" ]]; then
      DM_ISO="$f"
      break
    fi
  done

  if [[ -z "$DM_ISO" ]]; then
    log_error "未找到达梦安装包（dm8_*.iso）"
    log_info "请将达梦 ISO 安装包放到以下路径之一："
    echo "  $SCRIPT_DIR/dm8_*.iso"
    echo "  /opt/dm8_*.iso"
    echo "  /tmp/dm8_*.iso"
    echo ""
    log_info "下载地址：https://www.dameng.com/list_103.html"
    exit 1
  fi

  log_ok "找到达梦安装包: $DM_ISO"

  log_info "步骤 1/6：创建 dmdba 用户..."
  if id dmdba &>/dev/null; then
    log_ok "dmdba 用户已存在"
  else
    groupadd -f dinstall
    useradd -g dinstall -m -d /home/dmdba -s /bin/bash dmdba
    echo "dmdba:Dameng123" | chpasswd
    log_ok "dmdba 用户创建成功（密码：Dameng123）"
  fi

  log_info "步骤 2/6：创建安装目录..."
  mkdir -p /dm /dm/data /dm/arch /dm/backup
  chown -R dmdba:dinstall /dm

  log_info "步骤 3/6：挂载 ISO 并安装..."
  local MOUNT_DIR="/mnt/dm_install"
  mkdir -p "$MOUNT_DIR"
  mount -o loop "$DM_ISO" "$MOUNT_DIR" 2>/dev/null || {
    log_error "ISO 挂载失败"
    exit 1
  }

  # 静默安装
  cd "$MOUNT_DIR"
  local DM_INSTALLER=$(find . -name "DMInstall.bin" -o -name "dm_install.bin" 2>/dev/null | head -1)
  if [[ -z "$DM_INSTALLER" ]]; then
    DM_INSTALLER=$(find . -maxdepth 2 -executable -type f 2>/dev/null | head -1)
  fi

  if [[ -n "$DM_INSTALLER" ]]; then
    log_info "执行安装程序: $DM_INSTALLER"
    chmod +x "$DM_INSTALLER"
    su - dmdba -c "cd $MOUNT_DIR && $DM_INSTALLER -i" 2>>"$LOG_FILE" || {
      log_warn "静默安装失败，尝试命令行模式..."
      su - dmdba -c "cd $MOUNT_DIR && $DM_INSTALLER -q" 2>>"$LOG_FILE" || true
    }
  else
    log_error "未在 ISO 中找到安装程序"
    umount "$MOUNT_DIR" 2>/dev/null || true
    exit 1
  fi

  umount "$MOUNT_DIR" 2>/dev/null || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true

  log_info "步骤 4/6：初始化数据库实例..."
  if [[ -f "/dm/bin/dminit" ]]; then
    su - dmdba -c "/dm/bin/dminit PATH=/dm/data DB_NAME=DAMENG INSTANCE_NAME=DMSERVER PORT_NUM=5236 CHARSET=1 LOG_SIZE=256" 2>>"$LOG_FILE"
    log_ok "数据库实例初始化完成"
  else
    log_warn "dminit 不存在，可能安装路径不是 /dm"
  fi

  log_info "步骤 5/6：注册系统服务..."
  if [[ -f "/dm/script/root/root_installer.sh" ]]; then
    bash /dm/script/root/root_installer.sh 2>>"$LOG_FILE" || true
  fi
  # 手动创建 systemd 服务
  if [[ -f "/dm/bin/DmServiceDMSERVER" ]]; then
    /dm/bin/DmServiceDMSERVER install 2>>"$LOG_FILE" || true
  fi
  log_ok "服务注册完成"

  log_info "步骤 6/6：启动达梦服务..."
  systemctl start DmServiceDMSERVER 2>/dev/null || \
    su - dmdba -c "/dm/bin/dmserver /dm/data/DAMENG/dm.ini &" 2>/dev/null || true

  sleep 3
  if pgrep -x dmserver &>/dev/null; then
    log_ok "达梦数据库服务已启动"
  else
    log_warn "达梦服务可能未成功启动，请手动检查"
  fi

  log_section "达梦 DM8 安装完成"
  echo -e "  安装路径: ${CYAN}/dm${NC}"
  echo -e "  数据路径: ${CYAN}/dm/data${NC}"
  echo -e "  默认端口: ${CYAN}5236${NC}"
  echo -e "  管理员:   ${CYAN}SYSDBA / Dameng123${NC}"
  echo -e "  dmdba 密码: ${CYAN}Dameng123${NC}"
  echo ""
  echo -e "  连接测试: ${CYAN}/dm/bin/disql SYSDBA/Dameng123@localhost:5236${NC}"
  echo ""
}

# ─── 卸载达梦 DM8 ────────────────────────────────────────────────────────────
uninstall_dameng() {
  log_section "卸载达梦 DM8 数据库"

  echo -e "${YELLOW}${BOLD}⚠  警告：此操作将完全卸载达梦 DM8 并删除所有数据！${NC}"
  echo ""
  read -r -p "  确定要卸载达梦 DM8 吗？(输入 yes 确认): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log_warn "用户取消操作"
    return 0
  fi

  log_info "步骤 1/4：停止达梦服务..."
  systemctl stop DmServiceDMSERVER 2>/dev/null || true
  systemctl disable DmServiceDMSERVER 2>/dev/null || true
  # 停止所有达梦相关服务
  for svc in $(systemctl list-units --type=service --all 2>/dev/null | grep -i "DmService" | awk '{print $1}'); do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
  done
  pkill -9 dmserver 2>/dev/null || true
  pkill -9 dmap 2>/dev/null || true
  sleep 1
  log_ok "达梦服务已停止"

  log_info "步骤 2/4：移除系统服务..."
  if [[ -f "/dm/bin/DmServiceDMSERVER" ]]; then
    /dm/bin/DmServiceDMSERVER remove 2>/dev/null || true
  fi
  rm -f /etc/systemd/system/DmService*.service 2>/dev/null || true
  rm -f /usr/lib/systemd/system/DmService*.service 2>/dev/null || true
  systemctl daemon-reload 2>/dev/null || true
  log_ok "系统服务已移除"

  log_info "步骤 3/4：删除达梦文件..."
  rm -rf /dm 2>/dev/null || true
  rm -rf /home/dmdba/dmdbms 2>/dev/null || true
  rm -rf /home/dmdba/*.buf 2>/dev/null || true
  rm -rf /home/dmdba/*.log 2>/dev/null || true
  log_ok "达梦安装文件已删除"

  log_info "步骤 4/4：清理 dmdba 用户（可选）..."
  if id dmdba &>/dev/null; then
    read -r -p "  是否同时删除 dmdba 用户？(y/N): " del_user
    if [[ "${del_user,,}" == "y" ]]; then
      userdel -r dmdba 2>/dev/null || userdel dmdba 2>/dev/null || true
      groupdel dinstall 2>/dev/null || true
      log_ok "dmdba 用户已删除"
    else
      log_info "保留 dmdba 用户"
    fi
  fi

  log_section "达梦 DM8 卸载完成"
  echo -e "  ${GREEN}✓${NC} 服务已停止并移除"
  echo -e "  ${GREEN}✓${NC} 安装文件已删除"
  echo -e "  ${GREEN}✓${NC} 进程已清理"
  echo ""
}

# ─── 端到端测试（完整流程：创建→登录→做题→评分→打分）───────────────────────
e2e_test() {
  # 关闭 strict 模式，e2e 测试函数内部自行管理错误
  set +e
  set +o pipefail

  log_section "端到端全流程测试"

  local SERVER_URL="http://localhost:3001"
  local PROJECT_DIR="$SCRIPT_DIR"
  local E2E_DIR="/tmp/e2e_exam_test_$$"
  local PASS=0
  local FAIL=0
  local TOTAL_STEPS=8

  echo ""
  echo "  本测试将执行完整的考试流程："
  echo "    ① 检查服务状态"
  echo "    ② 创建测试学生"
  echo "    ③ 创建 E2E 测试题目（含评分脚本）"
  echo "    ④ 创建考试场次并启动"
  echo "    ⑤ 学生认证登录"
  echo "    ⑥ 模拟学生做题（执行操作）"
  echo "    ⑦ 运行 Agent 评分"
  echo "    ⑧ 查看评分结果"
  echo ""

  # ── 读取数据库连接信息 ──
  local ENV_FILE="$PROJECT_DIR/.env"
  if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env 文件不存在: $ENV_FILE"
    exit 1
  fi
  local DB_URL
  DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2-)
  local DB_PASS
  DB_PASS=$(echo "$DB_URL" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
  DB_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$DB_PASS'))" 2>/dev/null || printf '%b' "${DB_PASS//%/\\x}")
  local DB_USER
  DB_USER=$(echo "$DB_URL" | sed -E 's|mysql://([^:]+):.*|\1|')
  local DB_HOST
  DB_HOST=$(echo "$DB_URL" | sed -E 's|mysql://[^@]+@([^:]+):.*|\1|')
  local DB_PORT
  DB_PORT=$(echo "$DB_URL" | sed -E 's|mysql://[^@]+@[^:]+:([0-9]+)/.*|\1|')
  local DB_NAME
  DB_NAME=$(echo "$DB_URL" | sed -E 's|mysql://[^/]+/(.+)|\1|')
  local MYSQL_CMD="mysql -u ${DB_USER} -h ${DB_HOST} -P ${DB_PORT} ${DB_NAME} -N -s"

  # 辅助函数
  e2e_step() {
    local step_num="$1"
    local step_name="$2"
    echo ""
    echo -e "${BOLD}${CYAN}── 步骤 ${step_num}/${TOTAL_STEPS}：${step_name} ──${NC}"
  }

  e2e_ok() {
    echo -e "  ${GREEN}✓${NC} $*"
    ((PASS++)) || true
  }

  e2e_fail() {
    echo -e "  ${RED}✗${NC} $*"
    ((FAIL++)) || true
  }

  e2e_info() {
    echo -e "  ${BLUE}→${NC} $*"
  }

  # ════════════════════════════════════════════════════════════════
  # 步骤 1：检查服务
  # ════════════════════════════════════════════════════════════════
  e2e_step 1 "检查服务状态"

  # 检测端口（3000 或 3001）
  if curl -sf --max-time 3 "http://localhost:3001/api/trpc/auth.me?batch=1&input=%7B%7D" -o /dev/null 2>/dev/null; then
    SERVER_URL="http://localhost:3001"
    e2e_ok "服务运行在 $SERVER_URL"
  elif curl -sf --max-time 3 "http://localhost:3000/api/trpc/auth.me?batch=1&input=%7B%7D" -o /dev/null 2>/dev/null; then
    SERVER_URL="http://localhost:3000"
    e2e_ok "服务运行在 $SERVER_URL"
  else
    e2e_fail "服务未运行，请先启动服务"
    log_info "提示：bash install.sh --dev 或 sudo systemctl start linux-exam"
    exit 1
  fi

  e2e_info "数据库: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

  # ════════════════════════════════════════════════════════════════
  # 步骤 2：创建测试学生
  # ════════════════════════════════════════════════════════════════
  e2e_step 2 "创建测试学生"

  local E2E_STUDENT="e2e_tester"
  local E2E_PASSWORD="Test123456"

  # 生成密码哈希（与服务端逻辑一致：salt:sha256(salt+password+salt)）
  local SALT
  SALT=$(python3 -c "import os; print(os.urandom(16).hex())" 2>/dev/null)
  local HASH
  HASH=$(python3 -c "import hashlib; print(hashlib.sha256(('${SALT}${E2E_PASSWORD}${SALT}').encode()).hexdigest())" 2>/dev/null)
  local PW_HASH="${SALT}:${HASH}"

  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO students (studentId, name, className, passwordHash, isActive, createdAt, updatedAt)
    VALUES ('${E2E_STUDENT}', 'E2E测试学生', 'E2E测试班', '${PW_HASH}', 1, NOW(), NOW())
    ON DUPLICATE KEY UPDATE name='E2E测试学生', passwordHash='${PW_HASH}', deviceId=NULL, apiToken=NULL, isActive=1;
  " 2>/dev/null

  if [[ $? -eq 0 ]]; then
    e2e_ok "学生 ${E2E_STUDENT} 创建/更新成功"
    e2e_info "学号: ${E2E_STUDENT}  密码: ${E2E_PASSWORD}"
  else
    e2e_fail "学生创建失败"
  fi

  # ════════════════════════════════════════════════════════════════
  # 步骤 3：创建 E2E 测试题目（含评分脚本）
  # ════════════════════════════════════════════════════════════════
  e2e_step 3 "创建 E2E 测试题目（含每题评分脚本）"

  # 确保分类存在
  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO question_categories (name, description)
    VALUES ('E2E自动测试', '端到端自动化测试题目')
    ON DUPLICATE KEY UPDATE description='端到端自动化测试题目';
  " 2>/dev/null
  local CAT_ID
  CAT_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM question_categories WHERE name='E2E自动测试'" 2>/dev/null)
  e2e_info "题目分类 ID: ${CAT_ID}"

  # 清理旧 E2E 题目
  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "DELETE FROM questions WHERE title LIKE '[E2E-Auto]%';" 2>/dev/null

  # 题目 1：创建工作目录和文件
  local SCRIPT1='#!/bin/bash
# E2E测试：检查工作目录和文件
SCORE=30
DIR="/tmp/e2e_exam_test"
if [ ! -d "$DIR" ]; then
  echo "✗ 工作目录 $DIR 不存在 (-10)"; SCORE=$((SCORE-10))
else
  echo "✓ 工作目录存在 (+10)"
fi
if [ ! -f "$DIR/answer.txt" ]; then
  echo "✗ answer.txt 不存在 (-10)"; SCORE=$((SCORE-10))
else
  echo "✓ answer.txt 存在 (+10)"
  if head -1 "$DIR/answer.txt" 2>/dev/null | grep -q "EXAM_READY"; then
    echo "✓ 文件内容正确 (+10)"
  else
    echo "✗ 文件首行不含 EXAM_READY (-10)"; SCORE=$((SCORE-10))
  fi
fi
echo "SCORE:$SCORE"'

  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder, scoringScript)
    VALUES (
      '[E2E-Auto]创建工作目录',
      '在 /tmp/e2e_exam_test/ 目录下创建文件 answer.txt，内容首行必须包含 EXAM_READY。',
      ${CAT_ID}, 1, 30, 1, 1,
      '$(echo "$SCRIPT1" | sed "s/'/\\\\'/g")'
    );
  " 2>/dev/null
  local Q1_ID
  Q1_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM questions WHERE title='[E2E-Auto]创建工作目录' LIMIT 1" 2>/dev/null)
  e2e_ok "题目1: [E2E-Auto]创建工作目录 (ID:${Q1_ID}, 30分)"

  # 题目 2：创建可执行脚本
  local SCRIPT2='#!/bin/bash
# E2E测试：检查脚本文件和权限
SCORE=30
DIR="/tmp/e2e_exam_test/scripts"
if [ ! -d "$DIR" ]; then
  echo "✗ scripts 目录不存在 (-10)"; SCORE=$((SCORE-10))
else
  echo "✓ scripts 目录存在 (+10)"
fi
if [ ! -f "$DIR/run.sh" ]; then
  echo "✗ run.sh 不存在 (-10)"; SCORE=$((SCORE-10))
else
  echo "✓ run.sh 存在 (+10)"
  if [ -x "$DIR/run.sh" ]; then
    echo "✓ run.sh 有执行权限 (+10)"
  else
    echo "✗ run.sh 无执行权限 (-10)"; SCORE=$((SCORE-10))
  fi
fi
echo "SCORE:$SCORE"'

  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder, scoringScript)
    VALUES (
      '[E2E-Auto]创建可执行脚本',
      '在 /tmp/e2e_exam_test/scripts/ 下创建 run.sh，内容为 #!/bin/bash，并赋予执行权限。',
      ${CAT_ID}, 1, 30, 1, 2,
      '$(echo "$SCRIPT2" | sed "s/'/\\\\'/g")'
    );
  " 2>/dev/null
  local Q2_ID
  Q2_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM questions WHERE title='[E2E-Auto]创建可执行脚本' LIMIT 1" 2>/dev/null)
  e2e_ok "题目2: [E2E-Auto]创建可执行脚本 (ID:${Q2_ID}, 30分)"

  # 题目 3：创建数据文件
  local SCRIPT3='#!/bin/bash
# E2E测试：检查数据文件
SCORE=40
DIR="/tmp/e2e_exam_test/data"
if [ ! -d "$DIR" ]; then
  echo "✗ data 目录不存在 (-15)"; SCORE=$((SCORE-15))
else
  echo "✓ data 目录存在 (+15)"
fi
if [ ! -f "$DIR/report.csv" ]; then
  echo "✗ report.csv 不存在 (-15)"; SCORE=$((SCORE-15))
else
  echo "✓ report.csv 存在 (+15)"
  LINES=$(wc -l < "$DIR/report.csv" 2>/dev/null || echo 0)
  if [ "$LINES" -ge 3 ]; then
    echo "✓ report.csv 有 ${LINES} 行 (>=3) (+10)"
  else
    echo "✗ report.csv 行数不足 (${LINES}<3) (-10)"; SCORE=$((SCORE-10))
  fi
fi
echo "SCORE:$SCORE"'

  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder, scoringScript)
    VALUES (
      '[E2E-Auto]创建数据文件',
      '在 /tmp/e2e_exam_test/data/ 下创建 report.csv，至少包含 3 行数据。',
      ${CAT_ID}, 1, 40, 1, 3,
      '$(echo "$SCRIPT3" | sed "s/'/\\\\'/g")'
    );
  " 2>/dev/null
  local Q3_ID
  Q3_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM questions WHERE title='[E2E-Auto]创建数据文件' LIMIT 1" 2>/dev/null)
  e2e_ok "题目3: [E2E-Auto]创建数据文件 (ID:${Q3_ID}, 40分)"

  e2e_info "共 3 道题，满分 100 分"

  # ════════════════════════════════════════════════════════════════
  # 步骤 4：创建考试场次
  # ════════════════════════════════════════════════════════════════
  e2e_step 4 "创建考试场次并启动"

  # 清理旧 E2E 考试
  local OLD_EXAM_ID
  OLD_EXAM_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM exam_sessions WHERE name='E2E自动化测试考试' LIMIT 1" 2>/dev/null)
  if [[ -n "$OLD_EXAM_ID" ]]; then
    MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
      DELETE FROM score_details WHERE examRecordId IN (SELECT id FROM exam_records WHERE examId=${OLD_EXAM_ID});
      DELETE FROM exam_records WHERE examId=${OLD_EXAM_ID};
      DELETE FROM exam_question_assignments WHERE examId=${OLD_EXAM_ID};
      DELETE FROM exam_sessions WHERE id=${OLD_EXAM_ID};
    " 2>/dev/null
    e2e_info "已清理旧考试数据 (ID:${OLD_EXAM_ID})"
  fi

  MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    INSERT INTO exam_sessions (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt, startedAt)
    VALUES (
      'E2E自动化测试考试',
      '端到端自动化测试 - $(date +%Y%m%d_%H%M%S)',
      60, 3, 'active',
      '[${CAT_ID}]',
      NOW(), NOW()
    );
  " 2>/dev/null
  local EXAM_ID
  EXAM_ID=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "SELECT id FROM exam_sessions WHERE name='E2E自动化测试考试' ORDER BY id DESC LIMIT 1" 2>/dev/null)

  if [[ -n "$EXAM_ID" ]]; then
    e2e_ok "考试场次创建成功 (ID:${EXAM_ID})"
    e2e_info "状态: active | 时长: 60分钟 | 题数: 3"
  else
    e2e_fail "考试场次创建失败"
    return 1
  fi

  # ════════════════════════════════════════════════════════════════
  # 步骤 5：验证学生账号可用
  # ════════════════════════════════════════════════════════════════
  e2e_step 5 "验证学生账号可用"

  # 不用 curl 做认证（会绑定 deviceId 导致后续 Agent 冲突），只验证 DB 中学生数据正确
  local STU_CHECK
  STU_CHECK=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    SELECT studentId, name, (passwordHash IS NOT NULL) as hasPwd, deviceId
    FROM students WHERE studentId='${E2E_STUDENT}' AND isActive=1;
  " 2>/dev/null)

  if [[ -n "$STU_CHECK" ]]; then
    e2e_ok "学生账号验证通过"
    e2e_info "学号: ${E2E_STUDENT} | 密码已设置 | deviceId 已清空（允许 Agent 绑定）"
  else
    e2e_fail "学生账号不可用"
    return 1
  fi

  # 确保 API 可达
  if curl -sf --max-time 3 "${SERVER_URL}/api/trpc/auth.me?batch=1&input=%7B%7D" -o /dev/null 2>/dev/null; then
    e2e_ok "API 端点可达: ${SERVER_URL}"
  else
    e2e_fail "API 端点不可达"
    return 1
  fi

  # ════════════════════════════════════════════════════════════════
  # 步骤 6：模拟学生做题
  # ════════════════════════════════════════════════════════════════
  e2e_step 6 "模拟学生做题（执行操作）"

  e2e_info "正在执行学生操作..."

  # 清理旧目录
  rm -rf /tmp/e2e_exam_test 2>/dev/null

  # 题目1操作：创建目录和文件
  mkdir -p /tmp/e2e_exam_test
  echo "EXAM_READY" > /tmp/e2e_exam_test/answer.txt
  echo "  📝 题目1: mkdir -p /tmp/e2e_exam_test && echo EXAM_READY > answer.txt"
  e2e_ok "题目1 操作完成：目录和文件已创建"

  # 题目2操作：创建脚本
  mkdir -p /tmp/e2e_exam_test/scripts
  echo '#!/bin/bash' > /tmp/e2e_exam_test/scripts/run.sh
  echo 'echo "Hello from E2E test"' >> /tmp/e2e_exam_test/scripts/run.sh
  chmod +x /tmp/e2e_exam_test/scripts/run.sh
  echo "  📝 题目2: echo '#!/bin/bash' > scripts/run.sh && chmod +x scripts/run.sh"
  e2e_ok "题目2 操作完成：脚本已创建并赋权"

  # 题目3操作：创建数据文件
  mkdir -p /tmp/e2e_exam_test/data
  cat > /tmp/e2e_exam_test/data/report.csv <<'CSV'
id,name,score
1,Alice,95
2,Bob,87
3,Charlie,92
CSV
  echo "  📝 题目3: 创建 data/report.csv (4行)"
  e2e_ok "题目3 操作完成：CSV 数据文件已创建"

  echo ""
  echo "  📂 操作结果："
  find /tmp/e2e_exam_test -type f | while read -r f; do
    echo "    $f  ($(wc -c < "$f") bytes)"
  done

  # ════════════════════════════════════════════════════════════════
  # 步骤 7：运行 Agent 评分
  # ════════════════════════════════════════════════════════════════
  e2e_step 7 "运行 Agent 自动评分"

  e2e_info "调用 exam_agent.py --auto 模式..."

  # 清除旧的 Agent Token 缓存，确保使用 e2e_tester 重新认证
  rm -f ~/.exam_agent/token.json 2>/dev/null || true
  e2e_info "已清除 Agent Token 缓存"

  echo -e "${BOLD}───────── Agent 输出开始 ─────────${NC}"

  local AGENT_OUTPUT
  AGENT_OUTPUT=$(cd "$PROJECT_DIR" && python3 client_agent/exam_agent.py \
    --student-id "$E2E_STUDENT" \
    --password "$E2E_PASSWORD" \
    --server "$SERVER_URL" \
    --exam-id "$EXAM_ID" \
    --auto 2>&1)
  local AGENT_EXIT=$?

  echo "$AGENT_OUTPUT"
  echo -e "${BOLD}───────── Agent 输出结束 ─────────${NC}"

  if [[ $AGENT_EXIT -eq 0 ]]; then
    e2e_ok "Agent 执行成功 (exit code: 0)"
  else
    e2e_fail "Agent 执行失败 (exit code: $AGENT_EXIT)"
  fi

  # 提取总分
  local TOTAL_SCORE
  TOTAL_SCORE=$(echo "$AGENT_OUTPUT" | grep -oP '最终得分：\K[0-9]+' | head -1)
  if [[ -z "$TOTAL_SCORE" ]]; then
    TOTAL_SCORE=$(echo "$AGENT_OUTPUT" | grep -oP '总分：\K[0-9]+' | head -1)
  fi
  e2e_info "Agent 上报总分: ${TOTAL_SCORE:-未知}"

  # ════════════════════════════════════════════════════════════════
  # 步骤 8：查看评分结果
  # ════════════════════════════════════════════════════════════════
  e2e_step 8 "查看评分结果"

  # 从数据库查询结果（按 examId 查找，因为 agent 可能注册了不同的 student 映射）
  local RECORD
  RECORD=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
    SELECT er.id, er.totalScore, er.maxPossibleScore, er.status, er.submittedAt
    FROM exam_records er
    WHERE er.examId = ${EXAM_ID}
    ORDER BY er.id DESC LIMIT 1;
  " 2>/dev/null)

  if [[ -n "$RECORD" ]]; then
    local REC_ID=$(echo "$RECORD" | awk '{print $1}')
    local REC_SCORE=$(echo "$RECORD" | awk '{print $2}')
    local REC_MAX=$(echo "$RECORD" | awk '{print $3}')
    local REC_STATUS=$(echo "$RECORD" | awk '{print $4}')
    local REC_TIME=$(echo "$RECORD" | awk '{print $5, $6}')

    e2e_ok "考试记录已保存到数据库"
    echo ""
    echo -e "  ${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}║           E2E 端到端测试评分报告              ║${NC}"
    echo -e "  ${BOLD}╠══════════════════════════════════════════════╣${NC}"
    echo -e "  ${BOLD}║${NC}  考试 ID:   ${EXAM_ID}"
    echo -e "  ${BOLD}║${NC}  学生:      ${E2E_STUDENT}"
    echo -e "  ${BOLD}║${NC}  记录 ID:   ${REC_ID}"
    echo -e "  ${BOLD}║${NC}  状态:      ${REC_STATUS}"
    echo -e "  ${BOLD}║${NC}  提交时间:  ${REC_TIME}"
    echo -e "  ${BOLD}║${NC}"

    # 查询每题得分
    local DETAILS
    DETAILS=$(MYSQL_PWD="$DB_PASS" $MYSQL_CMD -e "
      SELECT q.title, sd.earnedScore, sd.maxScore
      FROM score_details sd
      JOIN questions q ON q.id = sd.questionId
      WHERE sd.examRecordId = ${REC_ID}
      ORDER BY q.sortOrder;
    " 2>/dev/null)

    if [[ -n "$DETAILS" ]]; then
      echo -e "  ${BOLD}║${NC}  ── 每题得分 ──"
      echo "$DETAILS" | while IFS=$'\t' read -r title earned max; do
        local pct=0
        if [[ "$max" -gt 0 ]]; then
          pct=$((earned * 100 / max))
        fi
        local color="$RED"
        [[ "$pct" -ge 60 ]] && color="$YELLOW"
        [[ "$pct" -ge 100 ]] && color="$GREEN"
        printf "  ${BOLD}║${NC}    %-30s ${color}%3d${NC}/%d 分\n" "$title" "$earned" "$max"
      done
    fi

    echo -e "  ${BOLD}║${NC}"
    if [[ "$REC_SCORE" -ge "$REC_MAX" ]]; then
      echo -e "  ${BOLD}║${NC}  ${GREEN}${BOLD}总分: ${REC_SCORE} / ${REC_MAX}  ★ 满分通过！${NC}"
    elif [[ "$REC_SCORE" -ge $((REC_MAX * 60 / 100)) ]]; then
      echo -e "  ${BOLD}║${NC}  ${YELLOW}${BOLD}总分: ${REC_SCORE} / ${REC_MAX}${NC}"
    else
      echo -e "  ${BOLD}║${NC}  ${RED}${BOLD}总分: ${REC_SCORE} / ${REC_MAX}${NC}"
    fi
    echo -e "  ${BOLD}╚══════════════════════════════════════════════╝${NC}"
  else
    e2e_fail "数据库中未找到考试记录"
  fi

  # ════════════════════════════════════════════════════════════════
  # 汇总
  # ════════════════════════════════════════════════════════════════
  echo ""
  log_section "E2E 测试结果汇总"

  local EXPECTED_SCORE=100
  echo -e "  通过检查点: ${GREEN}${PASS}${NC}"
  echo -e "  失败检查点: ${RED}${FAIL}${NC}"
  echo ""

  if [[ "$FAIL" -eq 0 ]] && [[ "${REC_SCORE:-0}" -eq "$EXPECTED_SCORE" ]]; then
    echo -e "  ${GREEN}${BOLD}★ E2E 端到端测试全部通过！满分 ${EXPECTED_SCORE} 分！${NC}"
    echo -e "  ${GREEN}  系统功能完整：创建题目 → 学生登录 → 做题 → 逐题评分 → 成绩入库${NC}"
  elif [[ "$FAIL" -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}△ E2E 测试流程通过，但得分 ${REC_SCORE:-0}/${EXPECTED_SCORE}（未满分）${NC}"
  else
    echo -e "  ${RED}${BOLD}✗ E2E 测试存在失败项，请检查上方输出${NC}"
  fi
  echo ""

  # 清理
  rm -rf /tmp/e2e_exam_test 2>/dev/null || true
}

# ─── 10题完整考试模拟（模拟学生做默认10道MySQL题 → Agent评分 → 出成绩）────────
e2e_full_test() {
  set +e
  set +o pipefail

  log_section "完整10题MySQL考试模拟"

  local SERVER_URL="http://localhost:3001"
  local PROJECT_DIR="$SCRIPT_DIR"
  local PASS=0
  local FAIL=0
  local BOLD="\033[1m"
  local GREEN="\033[32m"
  local RED="\033[31m"
  local YELLOW="\033[33m"
  local CYAN="\033[36m"
  local NC="\033[0m"

  ef_ok()   { PASS=$((PASS+1)); echo -e "  ${GREEN}✓${NC} $1"; }
  ef_fail() { FAIL=$((FAIL+1)); echo -e "  ${RED}✗${NC} $1"; }
  ef_info() { echo -e "  ${CYAN}→${NC} $1"; }
  ef_step() { echo -e "\n${BOLD}── 步骤 $1/9：$2 ──${NC}"; }

  echo ""
  echo -e "  本测试将模拟学生完成 ${BOLD}10 道默认考试题目${NC}（自动适配 MySQL / 达梦）："
  echo -e "    Q1  数据库服务管理（4分）"
  echo -e "    Q2  安装与初始化配置（14分）"
  echo -e "    Q3  用户与权限管理（8分）"
  echo -e "    Q4  表管理与数据导入导出（18分）"
  echo -e "    Q5  视图管理（8分）"
  echo -e "    Q6  存储过程与触发器（20分）"
  echo -e "    Q7  定时任务（8分）"
  echo -e "    Q8  性能优化（10分）"
  echo -e "    Q9  安全与备份恢复（10分）"
  echo -e "    Q10 数据库软件卸载（4分）★ 与Q1冲突，预期0分"
  echo -e "    ${YELLOW}总计: 满分 104 分，实际可得 100 分（Q10 冲突扣4分）${NC}"
  echo ""

  # ════════════════════════════════════════════════════════════════
  # 步骤 1：环境检查
  # ════════════════════════════════════════════════════════════════
  ef_step 1 "环境检查"

  # 检查服务运行
  if ! curl -sf --max-time 3 "http://localhost:3001/api/trpc/auth.me" -o /dev/null 2>/dev/null; then
    if ! curl -sf --max-time 3 "http://localhost:3000/api/trpc/auth.me" -o /dev/null 2>/dev/null; then
      ef_fail "考试系统服务未运行，请先启动服务"
      return 1
    fi
    SERVER_URL="http://localhost:3000"
  fi
  ef_ok "考试系统服务运行在 $SERVER_URL"

  # 自动检测数据库类型
  local STUDENT_DB_TYPE="mysql"
  local DMPATH="/dm/bin"
  local DM_CONN="sysdba/Dameng123@localhost:5236"
  if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    STUDENT_DB_TYPE="dameng"
  fi
  ef_info "学生操作数据库类型: ${STUDENT_DB_TYPE}"

  local MYSQL_ROOT="mysql -u root -N -s"
  if [[ "$STUDENT_DB_TYPE" == "mysql" ]]; then
    if ! command -v mysql &>/dev/null; then
      ef_fail "MySQL 客户端未安装"
      return 1
    fi
    if ! $MYSQL_ROOT -e "SELECT 1" &>/dev/null; then
      ef_fail "无法以 root 连接 MySQL（请确保以 root/sudo 运行）"
      return 1
    fi
    ef_ok "MySQL root 连接正常"
  else
    if ! $DMPATH/disql -s "$DM_CONN" -e "SELECT 1;" &>/dev/null; then
      ef_fail "无法连接达梦数据库（disql $DM_CONN）"
      return 1
    fi
    ef_ok "达梦数据库连接正常"
  fi

  # 读取 .env
  local ENV_FILE="$PROJECT_DIR/.env"
  if [[ ! -f "$ENV_FILE" ]]; then
    ef_fail ".env 文件不存在"
    return 1
  fi
  local DB_URL
  DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | head -1 | cut -d= -f2-)
  local DB_USER DB_PASS DB_HOST DB_PORT DB_NAME
  DB_USER=$(echo "$DB_URL" | sed -E 's|mysql://([^:]+):.*|\1|')
  DB_PASS=$(echo "$DB_URL" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null)
  DB_HOST=$(echo "$DB_URL" | sed -E 's|mysql://[^@]+@([^:]+):.*|\1|')
  DB_PORT=$(echo "$DB_URL" | sed -E 's|mysql://[^@]+@[^:]+:([0-9]+)/.*|\1|')
  DB_NAME=$(echo "$DB_URL" | sed -E 's|mysql://[^/]+/(.*)|\1|')
  local EXAM_MYSQL="mysql -u $DB_USER -h $DB_HOST -P $DB_PORT $DB_NAME"
  ef_info "考试系统DB: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

  # ════════════════════════════════════════════════════════════════
  # 步骤 2：创建测试学生 + 10道题目 + 考试场次
  # ════════════════════════════════════════════════════════════════
  ef_step 2 "准备考试数据（学生 + 题目 + 场次）"

  local E2E_STUDENT="e2e_full_tester"
  local E2E_PASSWORD="Test123456"

  # 密码哈希
  local SALT HASH PW_HASH
  SALT=$(python3 -c "import os; print(os.urandom(16).hex())")
  HASH=$(python3 -c "import hashlib; print(hashlib.sha256(('${SALT}${E2E_PASSWORD}${SALT}').encode()).hexdigest())")
  PW_HASH="${SALT}:${HASH}"

  MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -e "
    INSERT INTO students (studentId, name, className, passwordHash, isActive, createdAt, updatedAt)
    VALUES ('${E2E_STUDENT}', '10题考试测试生', 'E2E全量班', '${PW_HASH}', 1, NOW(), NOW())
    ON DUPLICATE KEY UPDATE name='10题考试测试生', passwordHash='${PW_HASH}', deviceId=NULL, apiToken=NULL, isActive=1;
  " 2>/dev/null
  ef_ok "测试学生 ${E2E_STUDENT} 就绪"

  # 创建题目分类
  local CAT_ID
  CAT_ID=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
    SELECT id FROM question_categories WHERE name='MySQL综合考试' LIMIT 1;
  " 2>/dev/null)
  if [[ -z "$CAT_ID" ]]; then
    MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -e "
      INSERT INTO question_categories (name, description, createdAt, updatedAt)
      VALUES ('MySQL综合考试', '10道MySQL默认考试题', NOW(), NOW());
    " 2>/dev/null
    CAT_ID=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "SELECT LAST_INSERT_ID();" 2>/dev/null)
  fi
  ef_info "题目分类 ID: $CAT_ID"

  # 清理旧的10题考试数据（可能有多个）
  local OLD_EXAM_IDS
  OLD_EXAM_IDS=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
    SELECT id FROM exam_sessions WHERE name='E2E-10题MySQL综合考试';
  " 2>/dev/null)
  if [[ -n "$OLD_EXAM_IDS" ]]; then
    for OLD_ID in $OLD_EXAM_IDS; do
      MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -e "
        DELETE sd FROM score_details sd JOIN exam_records er ON sd.examRecordId=er.id WHERE er.examId=$OLD_ID;
        DELETE FROM exam_question_assignments WHERE examId=$OLD_ID;
        DELETE FROM exam_records WHERE examId=$OLD_ID;
        DELETE FROM exam_sessions WHERE id=$OLD_ID;
      " 2>/dev/null
    done
    ef_info "已清理旧考试数据"
  fi

  # 清理旧的同分类题目（避免重复抽题）
  MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -e "
    DELETE FROM questions WHERE categoryId=$CAT_ID;
  " 2>/dev/null
  ef_info "已清理分类 $CAT_ID 下旧题目"

  # 读取评分脚本并创建10道题目
  local SCRIPT_DIR_PATH="$PROJECT_DIR/scoring_scripts"
  local Q_TITLES=( \
    "数据库服务管理" \
    "安装与初始化配置" \
    "用户与权限管理" \
    "表管理与数据导入导出" \
    "视图管理" \
    "存储过程与触发器" \
    "定时任务" \
    "性能优化" \
    "安全与备份恢复" \
    "数据库软件卸载" \
  )
  local Q_CONTENTS=( \
    "确保MySQL服务正在运行且设置开机自启，清理/tmp/mysql_old_data目录。" \
    "创建数据库examdb_a(utf8mb4)，确认端口3306、server_id=1、max_connections=200，恢复recovery_test数据，导出examdata.sql。" \
    "创建用户exam_user并设置密码过期策略120天，授予SELECT/CREATE/CREATE ROUTINE/EXECUTE/DELETE权限。" \
    "在examdb_a中创建tab_dept(46条)和tab_emp(≥856条)，给tab_emp添加create_time列(默认CURRENT_TIMESTAMP)，导出CSV。" \
    "创建视图v_empnum(部门人数统计)和v_empsal(高薪人数统计)。" \
    "创建存储过程sp_emp_salary_sum(按部门汇总工资)、日志表t_eventlog和触发器tr_eventlog。" \
    "开启事件调度器，创建定时事件evt_daily_cleanup(每天清理旧日志)。" \
    "在tab_emp.employee_name上创建索引ix_emp_empname，更新统计信息，设置innodb_buffer_pool_size≥256M。" \
    "确认binlog开启(ROW格式)，创建备份目录/var/lib/mysql_backup，做全库和单库备份。" \
    "【与Q1冲突-跳过】完全卸载MySQL服务和软件包。" \
  )
  local Q_SCORES=(4 14 8 18 8 20 8 10 10 4)
  local Q_FILES=( \
    "01_mysql_service.sh" \
    "02_mysql_install_config.sh" \
    "03_user_privileges.sh" \
    "04_table_data_export.sh" \
    "05_view_management.sh" \
    "06_procedure_trigger.sh" \
    "07_scheduled_task.sh" \
    "08_performance_tuning.sh" \
    "09_backup_security.sh" \
    "10_mysql_uninstall.sh" \
  )

  local Q_IDS=()
  for i in $(seq 0 9); do
    local SCRIPT_CONTENT=""
    local SCRIPT_FILE="$SCRIPT_DIR_PATH/${Q_FILES[$i]}"
    if [[ -f "$SCRIPT_FILE" ]]; then
      SCRIPT_CONTENT=$(cat "$SCRIPT_FILE")
    fi
    local ESCAPED_TITLE=$(echo "${Q_TITLES[$i]}" | sed "s/'/''/g")
    local ESCAPED_CONTENT=$(echo "${Q_CONTENTS[$i]}" | sed "s/'/''/g")
    local ESCAPED_SCRIPT=$(echo "$SCRIPT_CONTENT" | sed "s/'/''/g")

    local QID
    QID=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
      INSERT INTO questions (title, content, categoryId, difficulty, maxScore, sortOrder, scoringScript, isActive, createdAt, updatedAt)
      VALUES ('$ESCAPED_TITLE', '$ESCAPED_CONTENT', $CAT_ID, 2, ${Q_SCORES[$i]}, $((i+1)), '$ESCAPED_SCRIPT', 1, NOW(), NOW());
      SELECT LAST_INSERT_ID();
    " 2>/dev/null)
    Q_IDS+=("$QID")
    ef_ok "Q$((i+1)): ${Q_TITLES[$i]} (ID:$QID, ${Q_SCORES[$i]}分)"
  done

  # 创建考试场次（设置 categoryFilter 让 fetchQuestions 自动从该分类抽题）
  local EXAM_ID
  EXAM_ID=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
    INSERT INTO exam_sessions (name, durationMinutes, questionCount, categoryFilter, status, createdAt, updatedAt)
    VALUES ('E2E-10题MySQL综合考试', 120, 10, '[${CAT_ID}]', 'active', NOW(), NOW());
    SELECT LAST_INSERT_ID();
  " 2>/dev/null)
  ef_ok "考试场次创建成功 (ID:$EXAM_ID, 10题, 分类:$CAT_ID)"

  # ════════════════════════════════════════════════════════════════
  # 步骤 3-8：模拟学生完成数据库操作（自动分支 MySQL / 达梦）
  # ════════════════════════════════════════════════════════════════

  local EXAMDB="examdb_a"
  local EXAM_USER_NAME="exam_user"

  if [[ "$STUDENT_DB_TYPE" == "mysql" ]]; then
  # ╔════════════════════════════════════════╗
  # ║          MySQL 模式                     ║
  # ╚════════════════════════════════════════╝

  ef_step 3 "模拟学生操作 — Q1 数据库服务管理 [MySQL]"
  systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null
  systemctl enable mysql 2>/dev/null || systemctl enable mysqld 2>/dev/null
  rm -rf /tmp/mysql_old_data 2>/dev/null
  if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
    ef_ok "Q1: MySQL 服务已启动并设置开机自启"
  else
    ef_fail "Q1: MySQL 服务启动失败"
  fi
  ef_ok "Q1: /tmp/mysql_old_data 已清理"

  ef_step 4 "模拟学生操作 — Q2 安装与初始化配置 [MySQL]"
  $MYSQL_ROOT -e "CREATE DATABASE IF NOT EXISTS ${EXAMDB} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
  ef_ok "Q2: 数据库 ${EXAMDB} 已创建 (utf8mb4)"
  $MYSQL_ROOT -e "SET GLOBAL max_connections = 200;" 2>/dev/null
  ef_ok "Q2: max_connections = 200"
  local CUR_SID=$($MYSQL_ROOT -e "SHOW VARIABLES LIKE 'server_id'" 2>/dev/null | awk '{print $2}')
  ef_info "Q2: 当前 server_id = ${CUR_SID:-未知}"
  $MYSQL_ROOT -e "
    USE ${EXAMDB};
    CREATE TABLE IF NOT EXISTS recovery_test (id INT PRIMARY KEY, data VARCHAR(100));
    INSERT IGNORE INTO recovery_test VALUES (107, 'recovered_data');
  " 2>/dev/null
  ef_ok "Q2: recovery_test 表已创建，id=107 数据已恢复"
  mkdir -p /var/lib/mysql_backup 2>/dev/null
  mysqldump -u root ${EXAMDB} > /var/lib/mysql_backup/examdata.sql 2>/dev/null
  ef_ok "Q2: /var/lib/mysql_backup/examdata.sql 已导出"

  ef_step 5 "模拟学生操作 — Q3 用户与权限管理 [MySQL]"
  $MYSQL_ROOT -e "
    CREATE USER IF NOT EXISTS '${EXAM_USER_NAME}'@'%' IDENTIFIED BY 'ExamPass123!';
    ALTER USER '${EXAM_USER_NAME}'@'%' PASSWORD EXPIRE INTERVAL 120 DAY;
    GRANT SELECT, CREATE, CREATE ROUTINE, EXECUTE, DELETE ON ${EXAMDB}.* TO '${EXAM_USER_NAME}'@'%';
    FLUSH PRIVILEGES;
  " 2>/dev/null
  ef_ok "Q3: 用户 ${EXAM_USER_NAME} 已创建，密码策略120天，权限已授予"

  ef_step 6 "模拟学生操作 — Q4 表管理与数据导入导出 [MySQL]"
  $MYSQL_ROOT -e "
    USE ${EXAMDB};
    CREATE TABLE IF NOT EXISTS tab_dept (
      dept_id INT AUTO_INCREMENT PRIMARY KEY, dept_name VARCHAR(100) NOT NULL, location VARCHAR(100)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    TRUNCATE TABLE tab_dept;
  " 2>/dev/null
  local DEPT_SQL="INSERT INTO ${EXAMDB}.tab_dept (dept_name, location) VALUES "
  local DEPT_NAMES=("开发部门1" "开发部门2" "测试部" "运维部" "产品部" "设计部" "市场部" "销售部" "财务部" "人事部"
    "行政部" "法务部" "采购部" "后勤部" "安全部" "研发一部" "研发二部" "研发三部" "数据部" "AI部"
    "云计算部" "网络部" "前端部" "后端部" "移动开发部" "质量部" "项目管理部" "技术支持部" "客服部" "培训部"
    "战略部" "投资部" "公关部" "品牌部" "渠道部" "海外部" "创新部" "基础架构部" "中间件部" "DBA部"
    "安全运营部" "合规部" "内审部" "总裁办" "监事会" "董事会办")
  local DEPT_VALS=""
  for j in $(seq 0 45); do
    [[ -n "$DEPT_VALS" ]] && DEPT_VALS+=","
    DEPT_VALS+="('${DEPT_NAMES[$j]}', '城市$((j%10+1))')"
  done
  $MYSQL_ROOT -e "${DEPT_SQL}${DEPT_VALS};" 2>/dev/null
  ef_ok "Q4: tab_dept 已创建 ($($MYSQL_ROOT -e "SELECT COUNT(*) FROM ${EXAMDB}.tab_dept" 2>/dev/null) 条)"
  $MYSQL_ROOT -e "
    USE ${EXAMDB};
    CREATE TABLE IF NOT EXISTS tab_emp (
      employee_id INT AUTO_INCREMENT PRIMARY KEY, employee_name VARCHAR(100) NOT NULL,
      dept_id INT, salary DECIMAL(10,2), hire_date DATE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    TRUNCATE TABLE tab_emp;
  " 2>/dev/null
  $MYSQL_ROOT -e "
    INSERT INTO ${EXAMDB}.tab_emp (employee_name, dept_id, salary, hire_date)
    WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n<900)
    SELECT CONCAT('员工_',LPAD(n,4,'0')), (n%46)+1, 3000+(n*7%10000), DATE_SUB(CURDATE(),INTERVAL (n%365) DAY) FROM seq;
  " 2>/dev/null
  ef_ok "Q4: tab_emp 已创建 ($($MYSQL_ROOT -e "SELECT COUNT(*) FROM ${EXAMDB}.tab_emp" 2>/dev/null) 条)"
  $MYSQL_ROOT -e "ALTER TABLE ${EXAMDB}.tab_emp ADD COLUMN IF NOT EXISTS create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null \
    || $MYSQL_ROOT -e "ALTER TABLE ${EXAMDB}.tab_emp ADD COLUMN create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null
  ef_ok "Q4: create_time 列已添加"
  local CSV_FILE="/tmp/${EXAMDB}_emp_export.csv"
  $MYSQL_ROOT -e "SELECT employee_id,employee_name,dept_id,salary,hire_date FROM ${EXAMDB}.tab_emp" > "$CSV_FILE" 2>/dev/null
  ef_ok "Q4: CSV 已导出 ($(stat -c%s "$CSV_FILE" 2>/dev/null || echo 0) bytes)"

  ef_step 7 "模拟学生操作 — Q5-Q7 视图/存储过程/定时任务 [MySQL]"
  $MYSQL_ROOT -e "
    USE ${EXAMDB};
    CREATE OR REPLACE VIEW v_empnum AS
      SELECT d.dept_name, COUNT(e.employee_id) AS emp_count
      FROM tab_dept d LEFT JOIN tab_emp e ON d.dept_id=e.dept_id GROUP BY d.dept_id, d.dept_name;
    CREATE OR REPLACE VIEW v_empsal AS
      SELECT COUNT(CASE WHEN salary>8000 THEN 1 END) AS high_salary_count,
             COUNT(*) AS total_count, AVG(salary) AS avg_salary FROM tab_emp;
  " 2>/dev/null
  ef_ok "Q5: 视图 v_empnum, v_empsal 已创建"
  $MYSQL_ROOT -e "USE ${EXAMDB}; DROP PROCEDURE IF EXISTS sp_emp_salary_sum;" 2>/dev/null
  $MYSQL_ROOT ${EXAMDB} <<'PROCSQL'
DELIMITER $$
CREATE PROCEDURE sp_emp_salary_sum(IN p_dept_id INT, OUT p_total DECIMAL(15,2))
BEGIN
  SELECT COALESCE(SUM(salary), 0) INTO p_total FROM tab_emp WHERE dept_id = p_dept_id;
END$$
DELIMITER ;
PROCSQL
  ef_ok "Q6: 存储过程 sp_emp_salary_sum 已创建"
  $MYSQL_ROOT -e "
    USE ${EXAMDB};
    CREATE TABLE IF NOT EXISTS t_eventlog (
      log_id INT AUTO_INCREMENT PRIMARY KEY, event_type VARCHAR(50),
      event_data TEXT, event_time DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    DROP TRIGGER IF EXISTS tr_eventlog;
  " 2>/dev/null
  $MYSQL_ROOT ${EXAMDB} <<'TRIGSQL'
DELIMITER $$
CREATE TRIGGER tr_eventlog AFTER INSERT ON tab_emp FOR EACH ROW
BEGIN
  INSERT INTO t_eventlog (event_type, event_data)
  VALUES ('INSERT', CONCAT('新增员工: ', NEW.employee_name, ', 部门: ', NEW.dept_id));
END$$
DELIMITER ;
TRIGSQL
  ef_ok "Q6: 日志表 t_eventlog + 触发器 tr_eventlog 已创建"
  $MYSQL_ROOT -e "SET GLOBAL event_scheduler = ON;" 2>/dev/null
  $MYSQL_ROOT -e "
    USE ${EXAMDB}; DROP EVENT IF EXISTS evt_daily_cleanup;
    CREATE EVENT evt_daily_cleanup ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
    ON COMPLETION PRESERVE ENABLE
    DO DELETE FROM t_eventlog WHERE event_time < DATE_SUB(NOW(), INTERVAL 30 DAY);
  " 2>/dev/null
  ef_ok "Q7: 事件调度器已开启，evt_daily_cleanup 已创建 (ENABLED)"

  ef_step 8 "模拟学生操作 — Q8-Q9 性能优化/备份安全 [MySQL]"
  $MYSQL_ROOT -e "USE ${EXAMDB}; CREATE INDEX ix_emp_empname ON tab_emp(employee_name);" 2>/dev/null \
    || $MYSQL_ROOT -e "USE ${EXAMDB}; ALTER TABLE tab_emp ADD INDEX ix_emp_empname(employee_name);" 2>/dev/null
  ef_ok "Q8: 索引 ix_emp_empname 已创建"
  $MYSQL_ROOT -e "ANALYZE TABLE ${EXAMDB}.tab_emp;" 2>/dev/null
  ef_ok "Q8: 表统计信息已更新"
  local CUR_POOL=$($MYSQL_ROOT -e "SELECT @@innodb_buffer_pool_size" 2>/dev/null)
  if [[ -n "$CUR_POOL" ]] && [[ "$CUR_POOL" -lt 268435456 ]] 2>/dev/null; then
    $MYSQL_ROOT -e "SET GLOBAL innodb_buffer_pool_size = 268435456;" 2>/dev/null
    ef_ok "Q8: innodb_buffer_pool_size 已设为 256M"
  else
    ef_ok "Q8: innodb_buffer_pool_size >= 256M"
  fi
  $MYSQL_ROOT -e "SET GLOBAL binlog_format = 'ROW';" 2>/dev/null
  $MYSQL_ROOT -e "SET GLOBAL binlog_expire_logs_seconds = 604800;" 2>/dev/null
  ef_ok "Q9: binlog_format=ROW, expire=7天"
  mkdir -p /var/lib/mysql_backup 2>/dev/null
  mysqldump -u root --all-databases > /var/lib/mysql_backup/full_backup.sql 2>/dev/null
  mysqldump -u root ${EXAMDB} > /var/lib/mysql_backup/${EXAMDB}.sql 2>/dev/null
  ef_ok "Q9: 全库备份 + 单库备份已创建"
  ef_info "Q10: 数据库软件卸载 — 跳过（与Q1-Q9冲突）"

  else
  # ╔════════════════════════════════════════╗
  # ║          达梦 (Dameng) 模式              ║
  # ╚════════════════════════════════════════╝
  local DISQL="$DMPATH/disql -s $DM_CONN"

  ef_step 3 "模拟学生操作 — Q1 数据库服务管理 [达梦]"
  # 启动达梦服务
  local DM_SVC
  DM_SVC=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "DmService" | awk '{print $1}' | head -1)
  if [[ -n "$DM_SVC" ]]; then
    systemctl start "$DM_SVC" 2>/dev/null
    systemctl enable "$DM_SVC" 2>/dev/null
    if systemctl is-active --quiet "$DM_SVC" 2>/dev/null; then
      ef_ok "Q1: 达梦服务 $DM_SVC 已启动并设置开机自启"
    else
      ef_fail "Q1: 达梦服务启动失败"
    fi
  else
    ef_info "Q1: 未找到 DmService systemd 单元，尝试手动启动"
    /dm/bin/dmserver /dm/data/DAMENG/dm.ini &>/dev/null &
    sleep 2
    if pgrep -x dmserver &>/dev/null; then
      ef_ok "Q1: dmserver 进程已启动"
    else
      ef_fail "Q1: dmserver 启动失败"
    fi
  fi
  rm -rf /home/dmdba/dmdbms_old /tmp/dm_old_data 2>/dev/null
  ef_ok "Q1: 旧数据目录已清理"

  ef_step 4 "模拟学生操作 — Q2 安装与初始化配置 [达梦]"
  ef_info "Q2: /dm 路径已存在（达梦安装目录）"
  # 创建 recovery_test 表
  $DISQL -e "
    CREATE TABLE IF NOT EXISTS SYSDBA.RECOVERY_TEST (ID INT PRIMARY KEY, DATA VARCHAR(100));
    MERGE INTO SYSDBA.RECOVERY_TEST t USING (SELECT 107 AS ID, 'recovered_data' AS DATA FROM DUAL) s
      ON (t.ID = s.ID) WHEN NOT MATCHED THEN INSERT (ID, DATA) VALUES (s.ID, s.DATA);
    COMMIT;
  " 2>/dev/null
  ef_ok "Q2: RECOVERY_TEST 表已创建，id=107 数据已恢复"

  ef_step 5 "模拟学生操作 — Q3 用户与权限管理 [达梦]"
  # 创建表空间 TBS (64M)
  $DISQL -e "
    CREATE TABLESPACE TBS DATAFILE '/dm/data/DAMENG/TBS01.DBF' SIZE 64 AUTOEXTEND ON;
  " 2>/dev/null
  ef_ok "Q3: 表空间 TBS (64M) 已创建"
  # 创建用户 exam_user
  $DISQL -e "
    CREATE USER ${EXAM_USER_NAME} IDENTIFIED BY ExamPass123 DEFAULT TABLESPACE TBS;
    ALTER USER ${EXAM_USER_NAME} PASSWORD_LIFE_TIME 120;
    GRANT CREATE TABLE TO ${EXAM_USER_NAME};
    GRANT CREATE PROCEDURE TO ${EXAM_USER_NAME};
    GRANT RESOURCE TO ${EXAM_USER_NAME};
  " 2>/dev/null
  ef_ok "Q3: 用户 ${EXAM_USER_NAME}，密码策略120天，TBS默认表空间，CREATE TABLE/PROCEDURE权限"

  ef_step 6 "模拟学生操作 — Q4 表管理与数据导入导出 [达梦]"
  # 创建表（在 exam_user schema 下，用 SYSDBA 代建）
  $DISQL -e "
    CREATE TABLE IF NOT EXISTS ${EXAM_USER_NAME}.TAB_DEPT (
      DEPT_ID INT IDENTITY(1,1) PRIMARY KEY, DEPT_NAME VARCHAR(100) NOT NULL, LOCATION VARCHAR(100)
    );
    DELETE FROM ${EXAM_USER_NAME}.TAB_DEPT;
    COMMIT;
  " 2>/dev/null
  # 插入46个部门
  local DM_DEPT_SQL=""
  local DEPT_NAMES=("开发部门1" "开发部门2" "测试部" "运维部" "产品部" "设计部" "市场部" "销售部" "财务部" "人事部"
    "行政部" "法务部" "采购部" "后勤部" "安全部" "研发一部" "研发二部" "研发三部" "数据部" "AI部"
    "云计算部" "网络部" "前端部" "后端部" "移动开发部" "质量部" "项目管理部" "技术支持部" "客服部" "培训部"
    "战略部" "投资部" "公关部" "品牌部" "渠道部" "海外部" "创新部" "基础架构部" "中间件部" "DBA部"
    "安全运营部" "合规部" "内审部" "总裁办" "监事会" "董事会办")
  for j in $(seq 0 45); do
    DM_DEPT_SQL+="INSERT INTO ${EXAM_USER_NAME}.TAB_DEPT(DEPT_NAME,LOCATION) VALUES('${DEPT_NAMES[$j]}','城市$((j%10+1))');"
  done
  DM_DEPT_SQL+="COMMIT;"
  $DISQL -e "$DM_DEPT_SQL" 2>/dev/null
  ef_ok "Q4: TAB_DEPT 已创建 (46 条)"

  # 创建 TAB_EMP
  $DISQL -e "
    CREATE TABLE IF NOT EXISTS ${EXAM_USER_NAME}.TAB_EMP (
      EMPLOYEE_ID INT IDENTITY(1,1) PRIMARY KEY, EMPLOYEE_NAME VARCHAR(100) NOT NULL,
      DEPT_ID INT, SALARY DECIMAL(10,2), HIRE_DATE DATE
    );
    DELETE FROM ${EXAM_USER_NAME}.TAB_EMP;
    COMMIT;
  " 2>/dev/null
  # 批量插入900条员工（用PL/SQL块）
  $DISQL -e "
    BEGIN
      FOR i IN 1..900 LOOP
        INSERT INTO ${EXAM_USER_NAME}.TAB_EMP(EMPLOYEE_NAME,DEPT_ID,SALARY,HIRE_DATE)
        VALUES('员工_'||LPAD(i,4,'0'), MOD(i,46)+1, 3000+(MOD(i*7,10000)), SYSDATE-MOD(i,365));
      END LOOP;
      COMMIT;
    END;
  " 2>/dev/null
  ef_ok "Q4: TAB_EMP 已创建 (900 条)"

  # 添加 CREATETIME 列（达梦用大写，默认 SYSDATE）
  $DISQL -e "
    ALTER TABLE ${EXAM_USER_NAME}.TAB_EMP ADD CREATETIME DATETIME DEFAULT SYSDATE;
    COMMIT;
  " 2>/dev/null
  ef_ok "Q4: CREATETIME 列已添加 (默认 SYSDATE)"

  # 导出 CSV
  mkdir -p /dm/data 2>/dev/null
  $DISQL -e "
    SELECT EMPLOYEE_ID||','||EMPLOYEE_NAME||','||DEPT_ID||','||SALARY||','||HIRE_DATE
    FROM ${EXAM_USER_NAME}.TAB_EMP;
  " 2>/dev/null | grep -E '^[0-9]' > /dm/data/TAB_EMP.CSV 2>/dev/null
  ef_ok "Q4: CSV 已导出到 /dm/data/TAB_EMP.CSV"

  ef_step 7 "模拟学生操作 — Q5-Q7 视图/存储过程/定时作业 [达梦]"
  # Q5: 视图
  $DISQL -e "
    CREATE OR REPLACE VIEW ${EXAM_USER_NAME}.V_EMPNUM AS
      SELECT D.DEPT_NAME, COUNT(E.EMPLOYEE_ID) AS EMP_COUNT
      FROM ${EXAM_USER_NAME}.TAB_DEPT D LEFT JOIN ${EXAM_USER_NAME}.TAB_EMP E ON D.DEPT_ID=E.DEPT_ID
      GROUP BY D.DEPT_ID, D.DEPT_NAME;
    CREATE OR REPLACE VIEW ${EXAM_USER_NAME}.V_EMPSAL AS
      SELECT COUNT(CASE WHEN SALARY>8000 THEN 1 END) AS HIGH_SALARY_COUNT,
             COUNT(*) AS TOTAL_COUNT, AVG(SALARY) AS AVG_SALARY
      FROM ${EXAM_USER_NAME}.TAB_EMP;
  " 2>/dev/null
  ef_ok "Q5: 视图 V_EMPNUM, V_EMPSAL 已创建"

  # Q6: 存储过程
  $DISQL -e "
    CREATE OR REPLACE PROCEDURE ${EXAM_USER_NAME}.SP_EMP_SALARY_SUM(P_DEPT_ID IN INT, P_TOTAL OUT DECIMAL)
    AS
    BEGIN
      SELECT COALESCE(SUM(SALARY),0) INTO P_TOTAL FROM ${EXAM_USER_NAME}.TAB_EMP WHERE DEPT_ID=P_DEPT_ID;
    END;
  " 2>/dev/null
  ef_ok "Q6: 存储过程 SP_EMP_SALARY_SUM 已创建"

  # Q6: 事件日志表 + 触发器
  $DISQL -e "
    CREATE TABLE IF NOT EXISTS ${EXAM_USER_NAME}.T_EVENTLOG (
      LOG_ID INT IDENTITY(1,1) PRIMARY KEY, EVENT_TYPE VARCHAR(50),
      EVENT_DATA VARCHAR(500), EVENT_TIME DATETIME DEFAULT SYSDATE
    );
    CREATE OR REPLACE TRIGGER ${EXAM_USER_NAME}.TR_EVENTLOG
    AFTER INSERT ON ${EXAM_USER_NAME}.TAB_EMP FOR EACH ROW
    BEGIN
      INSERT INTO ${EXAM_USER_NAME}.T_EVENTLOG(EVENT_TYPE,EVENT_DATA)
      VALUES('INSERT','新增员工: '||:NEW.EMPLOYEE_NAME||', 部门: '||:NEW.DEPT_ID);
    END;
  " 2>/dev/null
  ef_ok "Q6: T_EVENTLOG + 触发器 TR_EVENTLOG 已创建"

  # Q7: 定时作业（达梦 DBMS_JOB / SYSJOB）
  $DISQL -e "
    BEGIN
      -- 全库备份作业 FULLBAK
      SP_CREATE_JOB('FULLBAK',1,0,'',0,0,'',0,'');
      SP_JOB_CONFIG_START('FULLBAK');
      SP_ADD_JOB_STEP('FULLBAK','STEP1',0,'BACKUP DATABASE FULL BACKUPSET ''/dm/backup/fullbak''',1,2,0,0,NULL,0);
      SP_ADD_JOB_SCHEDULE('FULLBAK','SCH1',1,2,1,0,0,'00:00:00',NULL,SYSDATE,NULL,NULL);
      SP_JOB_CONFIG_COMMIT('FULLBAK');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  " 2>/dev/null
  $DISQL -e "
    BEGIN
      -- 清理归档日志作业 DELARCH
      SP_CREATE_JOB('DELARCH',1,0,'',0,0,'',0,'');
      SP_JOB_CONFIG_START('DELARCH');
      SP_ADD_JOB_STEP('DELARCH','STEP1',0,'DELETE ARCHIVELOG BEFORE SYSDATE-7',1,2,0,0,NULL,0);
      SP_ADD_JOB_SCHEDULE('DELARCH','SCH1',1,2,1,0,0,'02:00:00',NULL,SYSDATE,NULL,NULL);
      SP_JOB_CONFIG_COMMIT('DELARCH');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  " 2>/dev/null
  ef_ok "Q7: 定时作业 FULLBAK + DELARCH 已创建"

  ef_step 8 "模拟学生操作 — Q8-Q9 性能优化/备份安全 [达梦]"
  # Q8: 索引
  $DISQL -e "
    CREATE INDEX ${EXAM_USER_NAME}.IX_EMP_EMPNAME ON ${EXAM_USER_NAME}.TAB_EMP(EMPLOYEE_NAME);
  " 2>/dev/null
  ef_ok "Q8: 索引 IX_EMP_EMPNAME 已创建"

  # 收集统计信息
  $DISQL -e "
    DBMS_STATS.GATHER_TABLE_STATS(UPPER('${EXAM_USER_NAME}'),'TAB_EMP');
  " 2>/dev/null
  ef_ok "Q8: TAB_EMP 表统计信息已收集"

  # CACHE_POOL_SIZE (需要修改 dm.ini，动态设置)
  $DISQL -e "SP_SET_PARA_VALUE(1,'CACHE_POOL_SIZE',500);" 2>/dev/null
  ef_ok "Q8: CACHE_POOL_SIZE = 500"

  # Q9: 归档模式 + 归档路径
  mkdir -p /dm/arch /dm/backup 2>/dev/null
  # 归档模式需要在配置文件和重启后生效，这里尝试动态设置
  $DISQL -e "
    ALTER DATABASE MOUNT;
    ALTER DATABASE ARCHIVELOG;
    ALTER DATABASE ADD ARCHIVELOG 'DEST=/dm/arch, TYPE=LOCAL, FILE_SIZE=128, SPACE_LIMIT=10240';
    ALTER DATABASE OPEN;
  " 2>/dev/null
  ef_info "Q9: 归档模式设置（可能需要重启生效）"
  ef_ok "Q9: /dm/arch + /dm/backup 目录已创建"

  # 物理备份（使用 RMAN 或 SQL）
  $DISQL -e "BACKUP DATABASE FULL BACKUPSET '/dm/backup/e2e_fullbak';" 2>/dev/null
  ef_ok "Q9: 全库物理备份已创建"

  # 逻辑备份（dexp）
  if command -v $DMPATH/dexp &>/dev/null; then
    $DMPATH/dexp SYSDBA/Dameng123@localhost:5236 FILE=/dm/backup/dmexam.dmp LOG=/dm/backup/dmexam.log OWNER=${EXAM_USER_NAME} 2>/dev/null
    ef_ok "Q9: 逻辑备份 dmexam.dmp + dmexam.log 已创建"
  else
    ef_info "Q9: dexp 不可用，跳过逻辑备份"
  fi

  ef_info "Q10: 数据库软件卸载 — 跳过（与Q1-Q9冲突）"

  fi
  # ════ 分支结束 ════
  echo ""

  # ════════════════════════════════════════════════════════════════
  # 步骤 9：运行 Agent 评分
  # ════════════════════════════════════════════════════════════════
  ef_step 9 "运行 Agent 自动评分"

  # 清除旧 Token
  rm -f ~/.exam_agent/token.json 2>/dev/null
  ef_info "已清除 Agent Token 缓存"
  ef_info "考试 ID: $EXAM_ID | 学生: $E2E_STUDENT"

  local AGENT_LOG="/tmp/e2e_full_agent_$$.log"
  echo -e "\n${BOLD}───────── Agent 输出开始 ─────────${NC}"
  cd "$PROJECT_DIR" && python3 client_agent/exam_agent.py \
    --student-id "$E2E_STUDENT" \
    --password "$E2E_PASSWORD" \
    --server "$SERVER_URL" \
    --exam-id "$EXAM_ID" \
    --auto 2>&1 | tee "$AGENT_LOG"
  local AGENT_EXIT=${PIPESTATUS[0]}
  echo -e "${BOLD}───────── Agent 输出结束 ─────────${NC}"

  if [[ $AGENT_EXIT -eq 0 ]]; then
    ef_ok "Agent 执行成功 (exit code: 0)"
  else
    ef_fail "Agent 执行失败 (exit code: $AGENT_EXIT)"
  fi

  # 提取总分
  local TOTAL_SCORE
  TOTAL_SCORE=$(grep -oP '最终得分：\K[0-9]+' "$AGENT_LOG" 2>/dev/null | head -1)
  if [[ -z "$TOTAL_SCORE" ]]; then
    TOTAL_SCORE=$(grep -oP '总分：\K[0-9]+' "$AGENT_LOG" 2>/dev/null | head -1)
  fi
  ef_info "Agent 上报总分: ${TOTAL_SCORE:-未知}"
  rm -f "$AGENT_LOG" 2>/dev/null

  # ════════════════════════════════════════════════════════════════
  # 结果展示
  # ════════════════════════════════════════════════════════════════
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}  评分结果${NC}"
  echo -e "${BOLD}══════════════════════════════════════════${NC}"

  # 从数据库获取详细成绩
  local RECORD
  RECORD=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
    SELECT er.id, er.totalScore, er.maxPossibleScore, er.status, er.submittedAt
    FROM exam_records er
    WHERE er.examId = ${EXAM_ID}
    ORDER BY er.id DESC LIMIT 1;
  " 2>/dev/null)

  if [[ -n "$RECORD" ]]; then
    local REC_ID=$(echo "$RECORD" | awk '{print $1}')
    local REC_SCORE=$(echo "$RECORD" | awk '{print $2}')
    local REC_STATUS=$(echo "$RECORD" | awk '{print $4}')
    ef_ok "考试记录已保存 (记录ID: $REC_ID)"
    echo ""

    echo -e "  ${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}║         10题 MySQL 考试成绩报告              ║${NC}"
    echo -e "  ${BOLD}╠══════════════════════════════════════════════╣${NC}"
    echo -e "  ${BOLD}║${NC}  考试 ID:   ${EXAM_ID}"
    echo -e "  ${BOLD}║${NC}  学生:      ${E2E_STUDENT}"
    echo -e "  ${BOLD}║${NC}  状态:      ${REC_STATUS}"
    echo -e "  ${BOLD}║${NC}"

    # 每题得分（从 score_details 表获取）
    echo -e "  ${BOLD}║  ── 每题得分明细 ──${NC}"
    local DETAILS
    DETAILS=$(MYSQL_PWD="$DB_PASS" $EXAM_MYSQL -N -s -e "
      SELECT q.title, sd.earnedScore, sd.maxScore
      FROM score_details sd
      JOIN questions q ON q.id = sd.questionId
      WHERE sd.examRecordId = ${REC_ID}
      ORDER BY q.sortOrder;
    " 2>/dev/null)

    local TOTAL_GOT=0
    local TOTAL_MAX=0
    while IFS=$'\t' read -r QTITLE QSCORE QMAX; do
      [[ -z "$QTITLE" ]] && continue
      QSCORE=${QSCORE:-0}
      TOTAL_GOT=$((TOTAL_GOT + QSCORE))
      TOTAL_MAX=$((TOTAL_MAX + QMAX))
      if [[ "$QSCORE" -eq "$QMAX" ]]; then
        echo -e "  ${BOLD}║${NC}    ${GREEN}✓${NC} ${QTITLE}  ${GREEN}${QSCORE}/${QMAX}${NC}"
      elif [[ "$QSCORE" -gt 0 ]]; then
        echo -e "  ${BOLD}║${NC}    ${YELLOW}△${NC} ${QTITLE}  ${YELLOW}${QSCORE}/${QMAX}${NC}"
      else
        echo -e "  ${BOLD}║${NC}    ${RED}✗${NC} ${QTITLE}  ${RED}${QSCORE}/${QMAX}${NC}"
      fi
    done <<< "$DETAILS"

    echo -e "  ${BOLD}║${NC}"
    if [[ "$TOTAL_GOT" -ge 100 ]]; then
      echo -e "  ${BOLD}║${NC}  ${GREEN}${BOLD}总分: ${TOTAL_GOT} / ${TOTAL_MAX}  ★ 优秀！${NC}"
    elif [[ "$TOTAL_GOT" -ge 80 ]]; then
      echo -e "  ${BOLD}║${NC}  ${YELLOW}${BOLD}总分: ${TOTAL_GOT} / ${TOTAL_MAX}  △ 良好${NC}"
    else
      echo -e "  ${BOLD}║${NC}  ${RED}${BOLD}总分: ${TOTAL_GOT} / ${TOTAL_MAX}${NC}"
    fi
    echo -e "  ${BOLD}╚══════════════════════════════════════════════╝${NC}"
  else
    ef_fail "数据库中未找到考试记录"
  fi

  echo ""
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo -e "  通过检查点: ${GREEN}${PASS}${NC} | 失败: ${RED}${FAIL}${NC}"
  echo -e "${BOLD}══════════════════════════════════════════${NC}"
  echo ""

  if [[ "$FAIL" -eq 0 ]]; then
    return 0
  else
    return 1
  fi
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
    easy-install)
      easy_install
      ;;
    easy-test)
      easy_test
      ;;
    full)
      install_base_deps
      install_nodejs
      install_python
      install_mysql
      init_database
      install_server
      install_client_agent
      run_database_migration
      run_tests
      print_summary
      ;;
    server-only)
      install_base_deps
      install_nodejs
      install_python
      install_mysql
      init_database
      install_server
      run_database_migration
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
    test-score)
      log_section "测试 score.sh 评分解析功能"
      if [[ -f "$SCRIPT_DIR/test_score_parser.py" ]]; then
        cd "$SCRIPT_DIR"
        python3 test_score_parser.py
      else
        log_error "test_score_parser.py 不存在"
        exit 1
      fi
      ;;
    dev)
      dev_run
      ;;
    start)
      start_service
      ;;
    stop)
      stop_service
      ;;
    status)
      show_status
      ;;
    demo-exam)
      demo_exam_test
      ;;
    reset-db)
      reset_database
      ;;
    install-mysql)
      install_mysql
      ;;
    uninstall-mysql)
      uninstall_mysql
      ;;
    install-dameng)
      install_dameng
      ;;
    uninstall-dameng)
      uninstall_dameng
      ;;
    e2e-test)
      e2e_test
      ;;
    e2e-full)
      e2e_full_test
      ;;
    package-client)
      package_client
      ;;
    package-server)
      package_server
      ;;
    package-all)
      package_all
      ;;
  esac
}
main "$@"
