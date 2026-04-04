# 评分脚本编写指南

## 概述

评分脚本是 Bash Shell 脚本，由服务端存储、在学生机本地执行，负责检查学生的 Linux 操作结果并计算得分。

```
服务端 score_a.sh ──[fetchQuestions 下发]──► 学生机执行 ──[结果]──► submitScore 上传
```

## 文件命名与放置

| 文件名 | 用途 |
|--------|------|
| `/opt/linux-exam-system/score_a.sh` | 题目集 A（约 50% 学生） |
| `/opt/linux-exam-system/score_b.sh` | 题目集 B（约 50% 学生） |

服务端查找顺序：`score_a.sh` → `score-a.sh` → `score.sh`（兜底）

> 更新脚本后**无需重启服务**，下次 `fetchQuestions` 调用时自动读取新版本。

## 变量占位符

服务端在下发脚本前自动替换以下占位符：

| 占位符 | 说明 | 示例值 |
|--------|------|--------|
| `{{username}}` | 学生系统用户名 | `zhangsan` |
| `{{port_expected}}` | 随机端口 | `5236` 或 `5237` |
| `{{db_expected}}` | 随机数据库名 | `EXAMDB_A` |
| `{{instance_expected}}` | 随机实例名 | `EXAINS01` |

```bash
#!/bin/bash
# 占位符在下发时已被替换
USERNAME="{{username}}"
PORT="{{port_expected}}"
WORKDIR="/home/${USERNAME}/exam"
```

## 输出格式

客户端 Agent 支持解析以下三种输出格式（任选其一）：

### 格式 1：JSON（推荐，信息最完整）

```bash
cat <<JSON
{
  "totalScore": 85,
  "details": [
    {"questionId": 1, "earnedScore": 30, "maxScore": 30, "failedChecks": []},
    {"questionId": 2, "earnedScore": 40, "maxScore": 50, "failedChecks": ["端口号不匹配"]}
  ]
}
JSON
```

> ⚠️ `questionId` 需与 `fetchQuestions` 返回的值一致。若脚本不知道具体 ID，可输出位置分数（Q1/Q2/Q3），由客户端脚本二次映射。

### 格式 2：SCORE 关键字（简单场景）

```bash
echo "SCORE:85"
```

适用于单题或简单场景，Agent 解析 `SCORE:` 后的数字作为总分。

### 格式 3：KEY=VALUE

```bash
echo "Q1_SCORE=30"
echo "Q2_SCORE=40"
echo "Q3_SCORE=15"
echo "TOTAL_SCORE=85"
```

## 脚本模板

```bash
#!/bin/bash
# ══════════════════════════════════════════════
#  Linux 考试评分脚本 - 题目集 A
#  变量由服务端注入，请勿修改占位符格式
# ══════════════════════════════════════════════
USERNAME="{{username}}"
PORT_EXPECTED="{{port_expected}}"

echo "评分开始：用户=${USERNAME}  $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ── 题目1：检查 xxx（满分 30 分）─────────────────
q1=0; q1_max=30

if [[ 检查条件1 ]]; then
    echo "✓ 检查1 通过 (+10)"
    q1=$((q1 + 10))
else
    echo "✗ 检查1 失败"
fi

if [[ 检查条件2 ]]; then
    echo "✓ 检查2 通过 (+20)"
    q1=$((q1 + 20))
else
    echo "✗ 检查2 失败：错误原因描述"
fi

echo "第1题得分：${q1}/${q1_max}"
echo ""

# ── 题目2 … ──────────────────────────────────────
q2=0; q2_max=50
# ... 同上

# ── 汇总 ─────────────────────────────────────────
total=$((q1 + q2))

echo "════════════════════════"
echo "总分：${total}/100"
echo "════════════════════════"

# 机器可读输出（供 Agent 解析）
echo "Q1_SCORE=${q1}"
echo "Q2_SCORE=${q2}"
echo "TOTAL_SCORE=${total}"
```

## 常用检查技巧

### 文件/目录检查

```bash
# 文件存在
[[ -f "/path/to/file" ]] && score+=10

# 目录存在
[[ -d "/path/to/dir" ]] && score+=5

# 文件包含关键字
grep -q "keyword" "/path/to/file" 2>/dev/null && score+=10

# 文件权限
[[ $(stat -c "%a" "/path/file") == "644" ]] && score+=10

# 文件属主
[[ $(stat -c "%U" "/path/file") == "$USERNAME" ]] && score+=10
```

### 服务/进程检查

```bash
# systemd 服务运行中
systemctl is-active --quiet nginx && score+=15

# 服务开机自启
systemctl is-enabled --quiet nginx && score+=5

# 进程存在
pgrep -x "mysqld" > /dev/null && score+=10

# 端口监听
ss -tlnp | grep -q ":${PORT_EXPECTED}" && score+=15
# 或
netstat -tlnp 2>/dev/null | grep -q ":${PORT_EXPECTED}" && score+=15
```

### 用户/权限检查

```bash
# 用户存在
id "examuser" &>/dev/null && score+=10

# 用户属于某组
groups examuser | grep -q "sudo" && score+=5

# sudo 权限
sudo -l -U examuser 2>/dev/null | grep -q "NOPASSWD" && score+=10
```

### 网络/配置检查

```bash
# IP 地址配置
ip addr show eth0 | grep -q "192.168.1.100" && score+=10

# hosts 文件
grep -q "server.local" /etc/hosts && score+=10

# cron 任务
crontab -l -u "$USERNAME" 2>/dev/null | grep -q "backup.sh" && score+=15
```

### 数据库检查（MySQL）

```bash
MYSQL_CMD="mysql -u exam_user -p'password' exam_db"
# 表是否存在
$MYSQL_CMD -e "SHOW TABLES LIKE 'orders'" | grep -q "orders" && score+=10
# 记录数
COUNT=$($MYSQL_CMD -N -e "SELECT COUNT(*) FROM orders")
[[ "$COUNT" -ge 10 ]] && score+=5
```

## 脚本调试

```bash
# 本地测试（以当前用户身份）
USERNAME=$(whoami) bash score_a.sh

# 测试特定用户
USERNAME=zhangsan bash score_a.sh

# 开启 bash 调试输出
bash -x score_a.sh 2>&1 | head -50
```

## 常见问题

**Q: 脚本中某个命令不存在（如 `disql`）时，脚本崩溃退出**

```bash
# 检查命令是否存在再执行
if command -v disql &>/dev/null; then
    disql ...
else
    echo "⚠ disql 未安装，跳过检查"
fi
```

**Q: 学生完成了但脚本给分为 0**

1. 确认 `{{username}}` 占位符已由服务端替换（检查 `fetchQuestions` 返回的脚本内容）
2. 检查路径是否包含变量：`/home/{{username}}/` 替换后是否正确
3. 本地手动运行脚本调试

**Q: 两个题目集 score_a.sh / score_b.sh 如何差异化**

```bash
# score_a.sh：端口 5236
PORT_EXPECTED=5236
# score_b.sh：端口 5237  
PORT_EXPECTED=5237
```
检查逻辑完全一样，只有期望值不同。

**Q: 如何避免脚本超时**

- 每个命令设置超时：`timeout 5 some_command || true`
- Agent 默认脚本超时 300 秒
- 避免 `sleep` / 无限等待

## 评分脚本测试

```bash
# 使用项目自带的 E2E 演示测试
bash /home/ubuntu/linux-exam-system/exam_e2e_demo.sh

# 或使用自动化对接测试
python3 /home/ubuntu/linux-exam-system/test_client_server.py
```
