# 快速启动指南

## ✅ 数据库已初始化完成

### 当前状态

- ✅ 数据库：`linux_exam` 已创建
- ✅ 用户：`exam_user` 已创建
- ✅ 9 道考试题目已导入
- ✅ 考试场次已创建（ID: 16）
- ✅ 学生账号已创建（demo_student）
- ✅ 服务正在运行（http://localhost:3000）

### 登录信息

**管理后台**：
- URL: http://localhost:3000
- 账号：`demo-admin`
- 密码：`Admin123456`

**学生端**：
- 账号：`demo_student`

### 快速开始

#### 方式 1：运行快速测试脚本

```bash
bash /root/linux_exam_system/quick_demo_exam.sh
```

#### 方式 2：手动启动学生端

```bash
cd /root/linux_exam_system/client_agent
python3 exam_agent.py --auto --server http://localhost:3000
```

### 考试信息

- **考试名称**：达梦数据库操作考试
- **考试 ID**：16
- **题目数量**：9 道
- **总分**：100 分
- **时长**：120 分钟
- **状态**：active（进行中）

### 题目列表

| 题号 | 题目名称 | 分值 |
|------|---------|------|
| 1 | 数据库卸载 | 4 分 |
| 2 | 重新安装部署数据库 | 14 分 |
| 3 | 表空间及用户规划 | 8 分 |
| 4 | 表管理及数据导出 | 18 分 |
| 5 | 创建视图 | 8 分 |
| 6 | 数据库开发 | 20 分 |
| 7 | 定时作业 | 8 分 |
| 8 | 性能优化 | 10 分 |
| 9 | 数据库安全 | 10 分 |

### 服务管理

```bash
# 启动服务
cd /root/linux_exam_system
pnpm dev

# 停止服务
pkill -f "pnpm dev"

# 查看服务状态
curl http://localhost:3000/api/trpc/auth.me
```

### 数据库连接

```bash
MYSQL_PWD='Exam@Pass1234!' mysql -h localhost -u exam_user linux_exam
```

### 查看成绩

1. 访问 http://localhost:3000
2. 使用管理员账号登录
3. 进入"考试管理"
4. 选择"达梦数据库操作考试"
5. 查看学生成绩

### 常见问题

**Q: 服务无法启动？**
```bash
# 检查端口占用
lsof -i :3000

# 查看日志
tail /tmp/linux-exam-dev.log
```

**Q: 数据库连接失败？**
```bash
# 测试连接
MYSQL_PWD='Exam@Pass1234!' mysql -h localhost -u exam_user linux_exam -e "SELECT 1"
```

**Q: 学生端认证失败？**
```bash
# 清除设备绑定
rm ~/.exam_agent/token.json

# 重新运行
python3 exam_agent.py --auto
```
