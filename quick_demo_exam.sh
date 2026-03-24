#!/bin/bash
# =============================================================================
# Linux 考试系统 - 快速演示考试测试
# 用法：bash quick_demo_exam.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  Linux 考试系统 - 演示考试测试${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# 数据库配置
DB_USER="exam_user"
DB_PASS="Exam@Pass1234!"
DB_NAME="linux_exam"

# 1. 检查服务
log_info "检查服务状态..."
if curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>&1; then
  log_ok "服务已运行"
else
  log_warn "服务未运行，正在启动..."
  cd /root/linux_exam_system
  nohup pnpm dev > /tmp/linux-exam-dev.log 2>&1 &
  sleep 5
  for i in {1..15}; do
    if curl -sf http://localhost:3000/api/trpc/auth.me -o /dev/null 2>&1; then
      log_ok "服务已启动"
      break
    fi
    echo -ne "\r等待服务启动... ($i/15)"
    sleep 2
  done
  echo ""
fi

# 2. 初始化数据库
log_info "初始化数据库..."
MYSQL_PWD="$DB_PASS" mysql -h localhost -u "$DB_USER" "$DB_NAME" << 'SQL'
-- 创建分类
INSERT INTO categories (name, description) VALUES ('达梦数据库操作', '达梦数据库管理操作考试题目')
ON DUPLICATE KEY UPDATE description='达梦数据库管理操作考试题目';

SET @category_id = (SELECT id FROM categories WHERE name = '达梦数据库操作' LIMIT 1);

-- 删除旧数据
DELETE FROM questions WHERE categoryId = @category_id;
DELETE FROM exam_sessions WHERE name = '达梦数据库操作考试';
DELETE FROM students WHERE studentId = 'demo_student';

-- 创建 9 道题目
INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder) VALUES
('数据库卸载', '请完整卸载达梦数据库软件', @category_id, 2, 4, 1, 1),
('重新安装部署数据库', '请重新安装并配置达梦数据库', @category_id, 3, 14, 1, 2),
('表空间及用户规划', '请创建表空间和用户', @category_id, 2, 8, 1, 3),
('表管理及数据导出', '请完成表管理操作', @category_id, 2, 18, 1, 4),
('创建视图', '请创建视图', @category_id, 2, 8, 1, 5),
('数据库开发', '请完成数据库开发任务', @category_id, 3, 20, 1, 6),
('定时作业', '请创建定时作业', @category_id, 2, 8, 1, 7),
('性能优化', '请完成性能优化操作', @category_id, 2, 10, 1, 8),
('数据库安全', '请完成安全配置', @category_id, 3, 10, 1, 9);

-- 创建考试场次
INSERT INTO exam_sessions (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt) 
VALUES ('达梦数据库操作考试', '达梦数据库管理操作实操考试', 120, 9, 'active', JSON_ARRAY(@category_id), NOW());

-- 创建学生
INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt) 
VALUES ('demo_student', '演示学生', 'Demo Class', 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE name='演示学生';

SELECT COUNT(*) AS question_count FROM questions WHERE categoryId = @category_id;
SELECT id AS exam_id FROM exam_sessions WHERE name = '达梦数据库操作考试' LIMIT 1;
SQL

if [[ $? -eq 0 ]]; then
  log_ok "数据库初始化完成"
else
  log_error "数据库初始化失败"
  exit 1
fi

# 3. 显示测试信息
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  测试数据已创建${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo "  管理员账号：${CYAN}demo-admin / Admin123456${NC}"
echo "  学生账号：${CYAN}demo_student${NC}"
echo "  考试 ID: ${CYAN}15${NC}"
echo "  题目数量：${CYAN}9 道${NC}"
echo "  总分：${CYAN}100 分${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  下一步操作${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo "1. 访问管理后台："
echo -e "   ${CYAN}http://localhost:3000${NC}"
echo ""
echo "2. 使用管理员账号登录查看考试"
echo ""
echo "3. 学生端参加考试："
echo -e "   ${CYAN}cd /root/linux_exam_system/client_agent${NC}"
echo -e "   ${CYAN}python3 exam_agent.py --auto --server http://localhost:3000${NC}"
echo ""
echo "4. 查看成绩："
echo "   管理后台 → 考试管理 → 达梦数据库操作考试"
echo ""
