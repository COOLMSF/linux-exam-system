# Linux 考试系统 - 一键测试使用说明

## 快速开始

### 方式一：通过 install.sh 脚本

```bash
# 一键运行演示考试测试
bash install.sh --demo-exam
```

### 方式二：直接运行 Python 脚本

```bash
# 在项目根目录
python3 demo_exam_test.py
```

---

## 测试流程

执行测试后，脚本会自动完成以下操作：

### 1. 服务检查与启动
- 检查服务端是否运行
- 如未运行，自动启动开发服务器
- 等待服务就绪

### 2. 创建测试数据
- **管理员账号**: `demo-admin` / `Admin123456`
- **学生账号**: `demo_student`
- **考试题目**: 2 道数据库操作题
  - 数据库软件卸载 (10 分)
  - 数据库软件安装 (10 分)
- **考试场次**: DM8 数据库操作考试 (60 分钟)

### 3. 模拟考试流程
- 学生端自动认证
- 获取考试题目
- 执行评分脚本
- 提交成绩

### 4. 显示测试结果
```
============================================================
  考试完成！
  最终得分：20 / 20
============================================================
```

---

## 查看成绩

### 访问管理后台
1. 打开浏览器访问：http://localhost:3000
2. 使用管理员账号登录：`demo-admin` / `Admin123456`
3. 进入"考试管理"页面
4. 查看"DM8 数据库操作考试"的成绩报表

### 查看内容
- 学生姓名：演示学生 (demo_student)
- 总分：20/20
- 各题得分详情
- 评分脚本执行输出

---

## 测试输出示例

```
════════════════════════════════════════════
  Linux 考试系统 - 演示考试测试
════════════════════════════════════════════

本测试将模拟完整的考试流程：
  1. 检查/启动服务
  2. 创建管理员账号
  3. 创建学生账号
  4. 创建考试题目
  5. 创建考试场次
  6. 学生端参加考试
  7. 提交成绩
  8. 查看成绩报表

[INFO]  检查服务状态...
[OK]    服务已运行

════════════════════════════════════════════
  创建测试数据
════════════════════════════════════════════

数据库连接成功
✓ 管理员账号创建成功 (demo-admin / Admin123456)
✓ 学生账号创建成功 (demo_student)
✓ 考试题目创建成功 (2 道题目)
✓ 考试场次创建成功 (ID: 1)

测试数据创建完成！
========================================
  管理员账号：demo-admin / Admin123456
  学生账号：demo_student
  考试 ID: 1
========================================

════════════════════════════════════════════
  运行演示考试
════════════════════════════════════════════

[演示] 开始考试流程测试

  当前用户：root
  设备 ID: a79bced6c52b9add...

[演示] 正在认证...
[OK]    认证成功

[演示] 获取考试题目 (examId=1)...
[OK]    获取到 2 道题目
    题目 1: 数据库软件卸载 (10 分)
    题目 2: 数据库软件安装 (10 分)

[演示] 开始考试...
[OK]    考试记录已创建 (recordId=1)

[演示] 执行评分...
  评分题目 1: 数据库软件卸载...
    得分：10 / 10
  评分题目 2: 数据库软件安装...
    得分：10 / 10

[演示] 评分完成！总分：20 / 20

[演示] 提交成绩...
[OK]    成绩已提交

============================================================
  考试完成！
  最终得分：20 / 20
============================================================

════════════════════════════════════════════
  测试完成
════════════════════════════════════════════

访问管理后台查看成绩：
  http://localhost:3000

管理员账号：demo-admin / Admin123456

查看成绩报表：
  1. 登录管理后台
  2. 进入'考试管理'页面
  3. 查看'DM8 数据库操作考试'的成绩
```

---

## 常见问题

### Q1: 服务启动失败
**解决**: 检查端口 3000 是否被占用
```bash
lsof -i :3000
kill -9 <PID>
```

### Q2: 数据库连接失败
**解决**: 检查 `.env` 文件中的 `DATABASE_URL` 配置
```bash
# 确保数据库服务已启动
systemctl status mysqld
```

### Q3: 认证失败 "Device mismatch"
**解决**: 清除学生的设备绑定
```bash
bash reset_device.sh
```

### Q4: 获取题目失败
**解决**: 确保考试场次状态为 `active`
```sql
UPDATE exam_sessions SET status='active' WHERE id=1;
```

---

## 清理测试数据

如需重新测试，可先清理测试数据：

```bash
# 连接数据库
mysql -u root -p linux_exam

# 删除测试数据
DELETE FROM exam_records WHERE student_id IN (SELECT id FROM students WHERE student_id='demo_student');
DELETE FROM exam_question_assignments WHERE student_id IN (SELECT id FROM students WHERE student_id='demo_student');
DELETE FROM exam_sessions WHERE name='DM8 数据库操作考试';
DELETE FROM questions WHERE category_id IN (SELECT id FROM categories WHERE name='DM8 数据库');
DELETE FROM categories WHERE name='DM8 数据库';
DELETE FROM students WHERE student_id='demo_student';
DELETE FROM users WHERE open_id='demo-admin';
```

---

## 脚本位置

| 文件 | 说明 |
|------|------|
| `install.sh` | 主安装脚本，包含 `--demo-exam` 参数 |
| `demo_exam_test.py` | 独立的演示考试测试脚本 |
| `add_student.sh` | 快速添加学生账号脚本 |
| `reset_device.sh` | 重置设备绑定脚本 |

---

## 扩展测试

### 修改题目数量
编辑 `demo_exam_test.py` 中的 `create_test_data()` 函数，添加更多题目：

```python
# 创建题目 3
await connection.execute(`
  INSERT INTO questions (...)
  VALUES (...)
`, [categoryId]);
```

### 修改考试时长
```python
await connection.execute(`
  INSERT INTO exam_sessions (..., duration_minutes, ...)
  VALUES (..., 120, ...)
`);
```

### 使用不同学生账号
运行测试前设置环境变量：
```bash
export DEMO_STUDENT_ID=test_student
python3 demo_exam_test.py
```

---

## 技术支持

- 部署文档：`DEPLOYMENT.md`
- 安装日志：`/var/log/linux-exam-install.log`
- 服务端日志：`journalctl -u linux-exam -f`
- 客户端日志：`~/.exam_agent/logs/`
