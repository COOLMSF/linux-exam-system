# Linux 考试系统 - score.sh 评分集成指南

## 概述

本考试系统支持使用 Shell 评分脚本（如 `score.sh`）进行自动评分。系统架构如下：

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   服务端     │────▶│   客户端      │────▶│  评分脚本    │────▶│   服务端      │
│  (出题管理)  │     │  (做题环境)   │     │  (score.sh) │     │  (成绩记录)  │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
```

## 快速开始

### 1. 导入评分规则配置

系统已将 `score.sh` 的评分逻辑转换为数据库配置，运行以下脚本导入：

```bash
cd /root/linux_exam_system
python3 import_score_rules.py
```

或者使用 install.sh：

```bash
bash install.sh --demo-exam  # 自动导入评分规则并创建测试数据
```

这将创建：
- **1 个分类**：达梦数据库操作
- **9 道题目**：对应 score.sh 的 9 道考题
- **评分规则**：每题的检查项和扣分标准

### 2. 测试评分解析功能

使用新增的测试功能验证 score.sh 评分解析：

```bash
# 方式 1：直接运行测试脚本
python3 test_score_parser.py

# 方式 2：使用 install.sh
bash install.sh --test-score
```

### 3. 创建考试场次

访问管理后台：http://localhost:3000

1. 登录管理员账号
2. 进入"考试管理" → "创建考试"
3. 配置考试信息：
   - 名称：达梦数据库操作考试
   - 分类：达梦数据库操作
   - 题目数量：9
   - 时长：120 分钟
4. 启动考试（状态设为 `active`）

### 3. 客户端参加考试

在学生机上运行：

```bash
cd /root/linux_exam_system/client_agent
python3 exam_agent.py --server http://<服务器 IP>:3000
```

客户端会自动：
1. 认证学生身份
2. 获取考试题目
3. 显示题目要求
4. 等待学生完成操作
5. 执行评分脚本
6. 上传成绩到服务端

## 评分脚本格式说明

### score.sh 输出格式

`score.sh` 脚本输出格式如下：

```bash
第 1 题：数据库卸载
数据库软件未成功卸载:-4
***第 1 题数据库卸载得分***:0
***第 2 题重新安装部署数据库得分***:14
...
总得分：85
```

### 客户端解析逻辑

客户端 `ScriptExecutor._parse_output()` 支持解析以下格式：

| 格式类型 | 示例 | 说明 |
|---------|------|------|
| 题目得分 | `***第 1 题数据库卸载得分***:4` | 正则匹配提取 |
| 总得分 | `总得分：85` 或 `总得分:85` | 正则匹配提取 |
| 扣分信息 | `数据库软件未成功卸载:-4` | `:-` 分隔描述和分值 |

## 评分规则配置

### 检查项类型

系统支持 5 种检查类型：

| 类型 | 说明 | 示例 |
|------|------|------|
| `file_exists` | 检查文件/目录存在 | `[ -d "/dm" ]` |
| `file_not_exists` | 检查文件/目录不存在 | `[ ! -d "/home/dmdba/dmdbms/jar" ]` |
| `command_output` | 检查命令输出 | `find /dm/backup -name '*.meta' \| wc -l` |
| `db_query` | 执行 SQL 查询验证 | `disql ... rw_dbname.sql` |
| `custom_script` | 自定义脚本检查 | 复杂逻辑验证 |

### 9 道题目配置

| 题号 | 题目名称 | 分值 | 检查项数量 |
|------|---------|------|-----------|
| 1 | 数据库卸载 | 4 分 | 1 |
| 2 | 重新安装部署数据库 | 14 分 | 6 |
| 3 | 表空间及用户规划 | 8 分 | 7 |
| 4 | 表管理及数据导出 | 18 分 | 5 |
| 5 | 创建视图 | 8 分 | 4 |
| 6 | 数据库开发 | 20 分 | 3 |
| 7 | 定时作业 | 8 分 | 2 |
| 8 | 性能优化 | 10 分 | 4 |
| 9 | 数据库安全 | 10 分 | 7 |
| **总计** | | **100 分** | **39** |

## 服务端 API

### 客户端认证

```python
POST /api/trpc/agentApi.authenticate
{
  "studentId": "学生 ID",
  "deviceId": "设备唯一标识",
  "clientUsername": "客户端用户名"
}
```

返回：
```json
{
  "token": "认证令牌",
  "expiresAt": "2024-03-22T12:00:00Z",
  "name": "学生姓名"
}
```

### 获取考试题目

```python
POST /api/trpc/agentApi.fetchQuestions
{
  "token": "认证令牌",
  "examId": 1
}
```

返回：
```json
{
  "examName": "达梦数据库操作考试",
  "durationMinutes": 120,
  "questions": [
    {
      "id": 1,
      "title": "数据库卸载",
      "content": "题目内容...",
      "maxScore": 4,
      "scoringScript": "#!/bin/bash\n..."
    }
  ]
}
```

### 提交成绩

```python
POST /api/trpc/agentApi.submitScore
{
  "token": "认证令牌",
  "examId": 1,
  "totalScore": 85,
  "durationSeconds": 300,
  "scriptOutput": "评分脚本原始输出",
  "details": [
    {
      "questionId": 1,
      "earnedScore": 4,
      "maxScore": 4,
      "failedChecks": []
    }
  ]
}
```

## 测试流程

### 运行演示测试

```bash
# 一键测试（自动创建数据并模拟考试）
python3 demo_exam_test.py
```

### 手动测试单题评分

创建测试脚本：

```bash
cat > /tmp/test_score.sh << 'EOF'
#!/bin/bash
score=10

# 模拟检查
if [ -d "/dm" ]; then
  echo "✓ 安装路径正确"
else
  echo "✗ 安装路径不存在:-5"
  score=$((score - 5))
fi

echo "***第 1 题测试得分***:$score"
echo "总得分：$score"
EOF

chmod +x /tmp/test_score.sh
bash /tmp/test_score.sh
```

预期输出：
```
✓ 安装路径正确
***第 1 题测试得分***:10
总得分：10
```

## 成绩查看

### 管理后台

1. 访问 http://localhost:3000
2. 进入"考试管理"
3. 选择考试场次
4. 查看成绩报表：
   - 总分统计
   - 每题得分率
   - 错误分布分析

### 数据库查询

```sql
-- 查看所有考试记录
SELECT 
  s.name as student_name,
  es.name as exam_name,
  er.total_score,
  er.status,
  er.submitted_at
FROM exam_records er
JOIN students s ON er.student_id = s.id
JOIN exam_sessions es ON er.exam_id = es.id
ORDER BY er.submitted_at DESC;

-- 查看单题得分详情
SELECT 
  q.title as question_title,
  sd.earned_score,
  sd.max_score,
  sd.failed_checks
FROM score_details sd
JOIN questions q ON sd.question_id = q.id
WHERE sd.exam_record_id = 1;
```

## 故障排查

### 客户端认证失败

**错误**: "Device mismatch"

**解决**:
```bash
# 重置设备绑定
bash reset_device.sh
```

### 评分脚本执行超时

**错误**: "评分脚本执行超时"

**解决**:
1. 检查数据库服务是否正常
2. 增加超时时间：`ScriptExecutor(timeout=600)`
3. 优化评分脚本性能

### 成绩上传失败

**错误**: "无法连接到服务器"

**解决**:
1. 检查网络连接
2. 确认服务器地址正确
3. 查看本地备份：`~/.exam_agent/logs/score_backup_*.json`

## 扩展开发

### 添加新题目

1. 在管理后台创建题目
2. 配置评分规则和检查项
3. 系统自动生成评分脚本
4. 添加到考试场次

### 自定义评分逻辑

创建自定义检查项：

```python
{
  "description": "检查服务状态",
  "check_type": "custom_script",
  "check_target": "#!/bin/bash\nsystemctl status dmserver | grep active",
  "deduction_points": 5,
  "fail_message": "数据库服务未运行"
}
```

## 文件清单

| 文件 | 说明 |
|------|------|
| `score.sh` | 原始评分脚本（参考） |
| `import_score_rules.py` | 导入评分规则配置 |
| `client_agent/exam_agent.py` | 客户端 Agent（支持 score.sh 格式） |
| `demo_exam_test.py` | 演示考试测试脚本 |
| `DEMO_EXAM.md` | 演示考试使用说明 |

## 技术支持

- 部署文档：`DEPLOYMENT.md`
- 数据库安装：`DATABASE_INSTALL.md`
- 考试说明：`DEMO_EXAM.md`
