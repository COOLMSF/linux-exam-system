# 数据库快速初始化指南

## 问题原因

MySQL 需要密码认证，但 `install.sh` 默认使用空密码连接。

## 解决方案

### 方式 1：手动初始化（推荐）

```bash
# 1. 使用 root 密码登录 MySQL
mysql -u root -p'YourRootPassword'

# 2. 执行以下 SQL
CREATE DATABASE IF NOT EXISTS linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'exam_user'@'localhost' IDENTIFIED BY 'YourStrongPassword123!';
GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# 3. 更新 .env 文件中的 DATABASE_URL
# 将密码进行 URL 编码（@ → %40, ! → %21）
# 例如：Exam@Pass1234! → Exam%40Pass1234%21

# 4. 执行数据库迁移
cd /root/linux_exam_system
pnpm db:push
```

### 方式 2：使用默认密码（已配置）

如果 MySQL 密码是 `Exam#Pass1234`，可以直接运行：

```bash
cd /root/linux_exam_system

# 数据库已初始化，直接运行迁移
pnpm db:push

# 启动服务
pnpm dev
```

## 当前配置

**数据库连接信息**：
- 主机：localhost
- 端口：3306
- 数据库：linux_exam
- 用户名：exam_user
- 密码：Exam@Pass1234!
- 连接字符串：`mysql://exam_user:Exam%40Pass1234%21@localhost:3306/linux_exam`

## 验证连接

```bash
# 测试数据库连接
MYSQL_PWD='Exam@Pass1234!' mysql -h localhost -u exam_user linux_exam -e "SHOW TABLES;"
```

## 启动服务

```bash
cd /root/linux_exam_system

# 开发模式
pnpm dev

# 或生产模式
pnpm build && pnpm start
```

访问：http://localhost:3000

## 常见问题

### Q1: Access denied for user 'root'@'localhost'

**解决**：MySQL 需要密码，使用 `-p` 参数：
```bash
mysql -u root -p'YourPassword'
```

### Q2: Your password does not satisfy the current policy requirements

**解决**：使用更复杂的密码（包含大小写字母、数字、特殊字符）：
```sql
CREATE USER 'exam_user'@'localhost' IDENTIFIED BY 'Strong@Pass1234!';
```

### Q3: pnpm: command not found

**解决**：安装 pnpm：
```bash
npm install -g pnpm
```

### Q4: Cannot read properties of null (reading 'matches')

**解决**：清理 npm 缓存并重新安装：
```bash
cd /root/linux_exam_system
rm -rf node_modules package-lock.json
npm install -g pnpm
pnpm install --frozen-lockfile
```

## 完整初始化流程

```bash
# 1. 初始化数据库
mysql -u root -p'Exam#Pass1234' <<'SQL'
CREATE DATABASE IF NOT EXISTS linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'exam_user'@'localhost' IDENTIFIED BY 'Exam@Pass1234!';
GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;
SQL

# 2. 更新 .env 文件
sed -i 's|^DATABASE_URL=.*|DATABASE_URL=mysql://exam_user:Exam%40Pass1234%21@localhost:3306/linux_exam|' .env

# 3. 安装依赖
pnpm install --frozen-lockfile

# 4. 执行迁移
pnpm db:push

# 5. 启动服务
pnpm dev
```

## 数据库表结构

共 10 个表：
- `users` - 用户表
- `students` - 学生表
- `categories` - 题目分类
- `questions` - 考试题目
- `scoring_rules` - 评分规则
- `scoring_check_items` - 评分检查项
- `exam_sessions` - 考试场次
- `exam_question_assignments` - 考试题目分配
- `exam_records` - 考试记录
- `score_details` - 成绩详情

## 下一步

数据库初始化完成后：

1. **启动服务**：`pnpm dev`
2. **访问管理后台**：http://localhost:3000
3. **首次设置管理员账号**
4. **创建考试题目和场次**
5. **学生端参加考试**
