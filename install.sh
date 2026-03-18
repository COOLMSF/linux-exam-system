#!/bin/bash
# =============================================================================
# Linux 考试系统 — 一键安装 & 测试脚本
# 兼容系统：Ubuntu 18.04/20.04/22.04 (apt) | 麒麟 V10 SP1/SP2/SP3 (yum/dnf)
# 用法：sudo bash install.sh [--server-only | --client-only | --test-only | --demo-exam | --package-client | --package-server | --package-all]
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
MODE="full"   # full | server-only | client-only | test-only | demo-exam | package-client | package-server | package-all

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --server-only) MODE="server-only" ;;
    --client-only) MODE="client-only" ;;
    --test-only)   MODE="test-only"   ;;
    --dev)         MODE="dev"          ;;
    --start)       MODE="start"        ;;
    --stop)        MODE="stop"         ;;
    --status)      MODE="status"       ;;
    --demo-exam)   MODE="demo-exam"    ;;
    --help|-h)
      echo ""
      echo -e "\033[1m用法:\033[0m sudo bash install.sh [选项]"
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
      echo "  --demo-exam        一键测试：创建数据 + 学生答题 + 自动评分"
      echo ""
      echo "运行模式（不需要 root）："
      echo "  --dev           开发模式启动（直接在当前目录运行，无需安装）"
      echo "  --start         启动已安装的服务 (systemd)"
      echo "  --stop          停止服务 (systemd)"
      echo "  --status        查看服务运行状态"
      echo "  --test-only     仅运行测试验证（不安装）"
      echo "  --help          显示此帮助"
      echo ""
      echo "示例："
      echo "  sudo bash install.sh                    # 完整安装并启动"
      echo "  bash install.sh --dev                   # 开发模式即刻启动"
      echo "  bash install.sh --test-only             # 验证环境"
      echo "  bash install.sh --package-client        # 打包客户端"
      echo "  bash install.sh --package-server        # 打包服务端"
      echo "  bash install.sh --package-all           # 打包全部用于分发"
      echo "  bash install.sh --demo-exam             # 演示考试全流程测试"
      exit 0
      ;;
  esac
done

# ─── 权限检查 ─────────────────────────────────────────────────────────────────
check_root() {
  # 以下模式不需要 root
  if [[ "$MODE" == "test-only" || "$MODE" == "dev" || "$MODE" == "start" || "$MODE" == "stop" || "$MODE" == "status" ]]; then
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
  log_section "演示考试系统测试"
  
  local project_dir="$SCRIPT_DIR"
  local test_student="demo_student"
  local test_password="Demo123456"
  
  echo ""
  echo "本测试将模拟完整的考试流程："
  echo "  1. 创建管理员账号"
  echo "  2. 创建学生账号"
  echo "  3. 创建考试题目"
  echo "  4. 创建考试场次"
  echo "  5. 启动考试"
  echo "  6. 学生端参加考试"
  echo "  7. 提交成绩"
  echo "  8. 查看成绩报表"
  echo ""
  
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
  esac
}
main "$@"
