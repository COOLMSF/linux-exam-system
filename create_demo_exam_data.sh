#!/bin/bash
# =============================================================================
# Linux 考试系统 - 快速创建演示考试数据
# 用法：bash create_demo_exam_data.sh
# =============================================================================

cd "$(dirname "$0")"

# 读取数据库配置
DATABASE_URL=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)
DB_PASS=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
DB_PASS=$(printf '%b' "${DB_PASS//%/\\x}")

echo "=== 创建演示考试数据 ==="
echo ""

# 创建测试数据
MYSQL_PWD="$DB_PASS" mysql -h localhost -u root linux_exam << 'SQL'
-- 1. 创建管理员
INSERT INTO users (openId, name, loginMethod, role, createdAt, lastSignedIn)
VALUES ('demo-admin', 'Demo Admin', 'local', 'admin', NOW(), NOW())
ON DUPLICATE KEY UPDATE name='Demo Admin';

UPDATE users SET passwordHash = CONCAT(SUBSTRING(MD(RAND()), 1, 32), ':', SUBSTRING(MD(RAND()), 1, 64)) 
WHERE openId = 'demo-admin';

-- 2. 创建学生
INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt)
VALUES ('demo_student', '演示学生', 'Demo Class', 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE name='演示学生';

-- 3. 创建分类
INSERT INTO question_categories (name, description)
VALUES ('DM8 数据库', '达梦数据库操作题目')
ON DUPLICATE KEY UPDATE description='达梦数据库操作题目';

-- 4. 创建题目（不带评分脚本）
DELETE FROM questions WHERE categoryId IN (SELECT id FROM question_categories WHERE name = 'DM8 数据库');

INSERT INTO questions (title, content, categoryId, difficulty, maxScore, isActive, sortOrder)
VALUES 
('Linux 基础操作', '请在终端完成以下操作：\n1. 创建一个名为 exam 的用户\n2. 创建目录 /tmp/exam\n3. 设置目录权限为 755', 
 (SELECT id FROM question_categories WHERE name = 'DM8 数据库'), 1, 10, 1, 0),
('数据库服务检查', '请检查数据库服务状态并报告：\n1. 数据库是否运行\n2. 数据库端口是否监听', 
 (SELECT id FROM question_categories WHERE name = 'DM8 数据库'), 2, 10, 1, 1);

-- 5. 创建考试场次
DELETE FROM exam_sessions WHERE name = 'DM8 数据库操作考试';

INSERT INTO exam_sessions (name, description, durationMinutes, questionCount, status, categoryFilter, createdAt)
VALUES (
  'DM8 数据库操作考试',
  '达梦数据库安装与配置实操考试',
  60,
  2,
  'active',
  NULL,
  NOW()
);

-- 显示结果
SELECT '=== 测试数据创建完成 ===' as status;
SELECT openId, name, role FROM users WHERE openId = 'demo-admin';
SELECT studentId, name, className FROM students WHERE studentId = 'demo_student';
SELECT id, title, maxScore FROM questions WHERE categoryId IN (SELECT id FROM question_categories WHERE name = 'DM8 数据库');
SELECT id, name, status, questionCount FROM exam_sessions WHERE name = 'DM8 数据库操作考试';
SQL

echo ""
echo "========================================"
echo "  管理员账号：demo-admin / (随机密码)"
echo "  学生账号：demo_student"
echo "  考试名称：DM8 数据库操作考试"
echo "========================================"
echo ""
echo "访问管理后台：http://localhost:3000"
echo ""
