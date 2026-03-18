#!/bin/bash
# =============================================================================
# Linux 考试系统 - 快速添加学生账号脚本
# 用法：bash add_student.sh <学生 ID> <学生姓名> [班级]
# 示例：bash add_student.sh root "Root User" "Default Class"
# =============================================================================

STUDENT_ID="${1:-root}"
STUDENT_NAME="${2:-Root User}"
CLASS_NAME="${3:-Default Class}"

echo "=== Linux 考试系统 - 添加学生账号 ==="
echo "学生 ID:   $STUDENT_ID"
echo "学生姓名：$STUDENT_NAME"
echo "班级：    $CLASS_NAME"
echo ""

# 检查数据库配置
if [[ ! -f ".env" ]]; then
    echo "[错误] .env 文件不存在，请在项目根目录运行此脚本"
    exit 1
fi

DATABASE_URL=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)

if [[ -z "$DATABASE_URL" ]]; then
    echo "[错误] DATABASE_URL 未配置"
    exit 1
fi

# 提取数据库信息
DB_USER=$(echo "$DATABASE_URL" | sed -E 's|mysql://([^:]+):.*|\1|')
DB_PASS=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^:]+:([^@]+)@.*|\1|')
DB_HOST=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^@]+@([^:]+):.*|\1|')
DB_PORT=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^@]+@[^:]+:([0-9]+)/.*|\1|')
DB_NAME=$(echo "$DATABASE_URL" | sed -E 's|mysql://[^@]+@[^/]+/([a-zA-Z0-9_]+).*|\1|')

# URL 解码密码
DB_PASS=$(printf '%b' "${DB_PASS//%/\\x}")

echo "[信息] 连接数据库：${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo ""

# 检查学生是否已存在
EXIST=$(MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -D "$DB_NAME" \
    -e "SELECT id FROM students WHERE studentId='$STUDENT_ID'" 2>/dev/null | tail -1)

if [[ -n "$EXIST" && "$EXIST" != "" ]]; then
    echo "[警告] 学生账号 '$STUDENT_ID' 已存在 (ID: $EXIST)"
    echo ""
    echo "如需更新，请执行以下 SQL:"
    echo "UPDATE students SET name='$STUDENT_NAME', className='$CLASS_NAME', isActive=1 WHERE studentId='$STUDENT_ID';"
    exit 0
fi

# 插入学生记录
MYSQL_PWD="$DB_PASS" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -D "$DB_NAME" \
    -e "INSERT INTO students (studentId, name, className, isActive, createdAt, updatedAt) 
        VALUES ('$STUDENT_ID', '$STUDENT_NAME', '$CLASS_NAME', 1, NOW(), NOW())" 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo "[成功] 学生账号创建成功！"
    echo ""
    echo "学生信息:"
    echo "  学生 ID:   $STUDENT_ID"
    echo "  学生姓名：$STUDENT_NAME"
    echo "  班级：    $CLASS_NAME"
    echo ""
    echo "现在可以使用客户端 Agent 进行认证："
    echo "  python3 client_agent/exam_agent.py"
else
    echo "[错误] 创建失败，请检查数据库连接"
    exit 1
fi
