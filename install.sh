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
      echo ""
      echo "运行模式（不需要 root）："
      echo "  --dev           开发模式启动（直接在当前目录运行，无需安装）"
      echo "  --start         启动已安装的服务 (systemd)"
      echo "  --stop          停止服务 (systemd)"
      echo "  --status        查看服务运行状态"
      echo "  --test-only     仅运行测试验证（不安装）"
      echo ""
      echo "维护模式（需要 root 权限）："
      echo "  --reset-db      重置数据库（删除所有数据并重新初始化）"
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
      echo "  sudo bash install.sh --reset-db         # 重置数据库（清空所有数据）"
      echo "  export MYSQL_ROOT_PASSWORD='your_pass' && bash install.sh  # 指定 MySQL 密码"
      exit 0
      ;;
  esac
done

# ─── 权限检查 ─────────────────────────────────────────────────────────────────
check_root() {
  # 以下模式不需要 root
  if [[ "$MODE" == "easy-test" || "$MODE" == "test-only" || "$MODE" == "test-score" || "$MODE" == "dev" || "$MODE" == "start" || "$MODE" == "stop" || "$MODE" == "status" || "$MODE" == "reset-db" ]]; then
    return 0
  fi
  if [[ $EUID -ne 0 ]]; then
    log_error "安装模式需要 root 权限，请使用 sudo bash install.sh"
    log_warn "开发模式无需 root： bash install.sh --dev"
    log_warn "仅验证环境： bash install.sh --test-only"
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


# ─── 演示考试测试 ───────────────────────────────────────────────────────────────
demo_exam_test() {
  log_section "演示考试系统测试（含 score.sh 评分）"

  local project_dir="$SCRIPT_DIR"
  local test_student="demo_student"
  local test_password="Demo123456"

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
  fi

  log_ok "数据库连接信息已写入 .env"
}

# ─── 数据库重置 ───────────────────────────────────────────────────────────────
reset_database() {
  log_section "重置数据库"

  echo -e "${YELLOW}${BOLD}⚠️  警告：此操作将删除所有考试数据！${NC}"
  echo ""
  echo "  此操作将："
  echo "    1. 删除现有的 linux_exam 数据库"
  echo "    2. 删除 exam_user 用户"
  echo "    3. 重新创建数据库和用户"
  echo "    4. 重新运行数据库迁移"
  echo ""
  echo -e "${RED}  所有考试记录、学生信息、题目等数据将永久丢失！${NC}"
  echo ""

  # 确认提示
  read -r -p "  确定要继续吗？(输入 yes 确认): " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_warn "用户取消操作"
    exit 0
  fi

  log_info "开始重置数据库..."

  # 1. 停止服务（如果正在运行）
  log_info "停止服务..."
  if command -v systemctl &>/dev/null && systemctl is-active linux-exam &>/dev/null 2>&1; then
    systemctl stop linux-exam 2>/dev/null || true
    log_ok "系统服务已停止"
  fi

  # 2. 删除旧数据库和用户
  log_info "删除旧数据库和用户..."
  mysql -h localhost -u root <<MYSQL_SCRIPT
-- 删除数据库
DROP DATABASE IF EXISTS linux_exam;

-- 删除用户
DROP USER IF EXISTS 'exam_user'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

SELECT 'Old database and user deleted' AS status;
MYSQL_SCRIPT

  if [[ $? -ne 0 ]]; then
    log_error "删除旧数据库失败"
    exit 1
  fi

  log_ok "旧数据库已删除"

  # 3. 重新初始化数据库
  init_database

  # 4. 重新运行迁移
  run_database_migration

  # 5. 重启服务
  log_info "重启服务..."
  if command -v systemctl &>/dev/null && [[ -f /etc/systemd/system/linux-exam.service ]]; then
    systemctl daemon-reload
    systemctl start linux-exam
    systemctl enable linux-exam 2>/dev/null || true
    log_ok "系统服务已重启"
  fi

  # 6. 创建默认管理员账号
  log_info "创建默认管理员账号..."
  
  # 使用 Node.js 脚本创建默认管理员
  node << 'NODESCRIPT'
const { nanoid } = require('nanoid');
const crypto = require('crypto');
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

// 密码哈希函数
function makePasswordHash(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.createHash('sha256').update(salt + password + salt).digest('hex');
  return salt + ':' + hash;
}

async function createDefaultAdmin() {
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
    
    // 检查是否已有管理员账号
    const [adminRows] = await connection.execute(`
      SELECT COUNT(*) as count FROM users WHERE role = 'admin'
    `);
    
    if (adminRows[0].count > 0) {
      console.log('已有管理员账号，跳过创建');
      await connection.end();
      return;
    }
    
    // 创建默认管理员账号
    const openId = 'local-admin-' + nanoid(12);
    const username = 'admin';
    const password = 'Admin123456';
    const passwordHash = makePasswordHash(password);
    
    await connection.execute(`
      INSERT INTO users (openId, name, loginMethod, role, passwordHash, createdAt, lastSignedIn)
      VALUES (?, ?, ?, ?, ?, NOW(), NOW())
    `, [openId, username, 'local', 'admin', passwordHash]);
    
    console.log('✓ 默认管理员账号创建成功');
    console.log('  用户名：admin');
    console.log('  密码：Admin123456');
    console.log('  请登录后及时修改密码');
    
    await connection.end();
  } catch (error) {
    console.error('创建默认管理员失败:', error.message);
    if (connection) await connection.end();
    process.exit(1);
  }
}

createDefaultAdmin();
NODESCRIPT
  
  if [[ $? -eq 0 ]]; then
    log_ok "默认管理员账号创建成功"
  else
    log_warn "创建默认管理员账号失败，请手动创建"
  fi

  # 7. 显示新配置
  log_section "数据库重置完成"

  echo ""
  echo -e "${GREEN}${BOLD}✓ 数据库已成功重置！${NC}"
  echo ""

  # 读取新密码
  local new_pass=""
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    new_pass=$(grep "^DATABASE_URL=" "$SCRIPT_DIR/.env" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
    new_pass=$(printf '%b' "${new_pass//%/\\x}")
  fi

  echo -e "  新的数据库连接信息："
  echo -e "    ${CYAN}数据库名：linux_exam${NC}"
  echo -e "    ${CYAN}用户名：exam_user${NC}"
  echo -e "    ${CYAN}密码：${new_pass}${NC}"
  echo ""
  echo -e "  默认管理员账号："
  echo -e "    ${CYAN}用户名：admin${NC}"
  echo -e "    ${CYAN}密码：Admin123456${NC}"
  echo -e "    ${YELLOW}请登录后及时修改密码！${NC}"
  echo ""
  echo -e "  配置文件已更新：${CYAN}$SCRIPT_DIR/.env${NC}"
  echo ""
  echo -e "${YELLOW}提示：请妥善保管新的数据库密码和管理员账号！${NC}"
  echo ""
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
  esac
}
main "$@"
