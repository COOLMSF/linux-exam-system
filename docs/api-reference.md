# 客户端 Agent API 参考

所有接口均通过 tRPC，基础路径：`POST /api/trpc/agentApi.<方法名>`

请求体固定格式：
```json
{ "json": { ...参数 } }
```

响应固定格式：
```json
{ "result": { "data": { "json": { ...返回值 } } } }
```

---

## 考试流程顺序

```
authenticate → fetchQuestions → startExam → submitScore → finishExam
```

---

## 1. agentApi.authenticate

学生认证，获取 8 小时有效 token。首次认证绑定 deviceId，后续认证强制校验设备。

**请求**

```json
{
  "json": {
    "studentId": "stu2024001",
    "deviceId": "sha256-based-device-id",
    "clientUsername": "zhangsan"
  }
}
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `studentId` | string | 学生学号（需在后台录入） |
| `deviceId` | string | 设备唯一标识（推荐：hostname + MAC 的 SHA256 前32位） |
| `clientUsername` | string | 学生机系统登录用户名（用于评分脚本变量替换） |

**响应**

```json
{
  "token": "64位随机字符串",
  "expiresAt": "2026-04-04T20:00:00.000Z",
  "studentId": 1,
  "name": "张三"
}
```

**错误码**

| code | 原因 |
|------|------|
| `UNAUTHORIZED` | 学号不存在或账号已停用 |
| `FORBIDDEN` | deviceId 与首次绑定的设备不符 |

---

## 2. agentApi.fetchQuestions

获取分配给该学生的个性化题目及评分脚本。若该学生在本场考试中尚无题目分配，自动从题库随机抽取并持久化。

**请求**

```json
{
  "json": {
    "token": "...",
    "examId": 1
  }
}
```

**响应**

```json
{
  "examName": "Linux 运维实践考试",
  "durationMinutes": 120,
  "questions": [
    {
      "id": 42,
      "examId": 1,
      "studentId": 7,
      "questionId": 5,
      "personalizedContent": "安装 DM8 数据库，端口号设置为 5237...",
      "sortOrder": 0,
      "questionSet": "a",
      "scoringScript": "#!/bin/bash\nUSERNAME=\"zhangsan\"\n..."
    }
  ]
}
```

**关键字段说明**

| 字段 | 说明 |
|------|------|
| `questionId` | 题目在 questions 表中的 ID，提交成绩时使用 |
| `personalizedContent` | 已替换变量的题目内容 |
| `questionSet` | 题目集标识（`a` 或 `b`） |
| `scoringScript` | 评分脚本内容（所有 `{{username}}` 等占位符已替换） |

**错误码**

| code | 原因 |
|------|------|
| `NOT_FOUND` | 考试不存在或状态不为 `active` |
| `INTERNAL_SERVER_ERROR` | 题库中无可用题目，或评分脚本文件缺失 |

---

## 3. agentApi.startExam

记录考试开始时间，将记录状态设为 `in_progress`。

**请求**

```json
{
  "json": {
    "token": "...",
    "examId": 1
  }
}
```

**响应**

```json
{
  "success": true,
  "recordId": 88,
  "questionSet": "a"
}
```

> `recordId` 后续 `finishExam` 需要。

**错误码**

| code | 原因 |
|------|------|
| `NOT_FOUND` | 考试未处于 active，或尚未调用 fetchQuestions |

---

## 4. agentApi.submitScore

提交评分脚本执行结果，写入 `exam_records` 和 `score_details`。可重复调用，已 graded 的记录直接返回成功。

**请求**

```json
{
  "json": {
    "token": "...",
    "examId": 1,
    "totalScore": 85,
    "durationSeconds": 3720,
    "scriptOutput": "评分脚本的完整 stdout 输出...",
    "examMeta": {
      "hostname": "kylin-pc-001",
      "os": "Linux",
      "osVersion": "5.10.0-153",
      "arch": "x86_64",
      "username": "zhangsan",
      "questionCount": 9,
      "questionSet": "a"
    },
    "details": [
      {
        "questionId": 5,
        "earnedScore": 14,
        "maxScore": 14,
        "failedChecks": []
      },
      {
        "questionId": 6,
        "earnedScore": 8,
        "maxScore": 18,
        "failedChecks": ["数据库名不匹配", "端口号错误"]
      }
    ]
  }
}
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `totalScore` | number | ✓ | 总分（应等于 details 各项之和） |
| `durationSeconds` | number | ✓ | 考试用时（秒） |
| `scriptOutput` | string | — | 评分脚本完整输出（用于日志审计） |
| `examMeta` | object | — | 学生机环境信息 |
| `details[].questionId` | number | ✓ | 与 `fetchQuestions` 返回的 `questionId` 对应 |
| `details[].earnedScore` | number | ✓ | 该题实际得分 |
| `details[].failedChecks` | string[] | — | 失败检查点描述列表 |

**响应**

```json
{ "success": true }
```

---

## 5. agentApi.finishExam

标记考试结束，写入 `completedAt`。

**请求**

```json
{
  "json": {
    "token": "...",
    "recordId": 88
  }
}
```

**响应**

```json
{
  "success": true,
  "recordId": 88
}
```

---

## 错误处理通用规则

- Token 无效 → HTTP 401 `UNAUTHORIZED`
- Token 过期（8h）→ HTTP 401，需重新 `authenticate`
- 设备不匹配 → HTTP 403 `FORBIDDEN`
- 资源不存在 → HTTP 404 `NOT_FOUND`
- 所有 tRPC 错误均以标准格式返回：

```json
{
  "error": {
    "json": {
      "message": "错误描述",
      "code": -32600,
      "data": { "code": "UNAUTHORIZED", "httpStatus": 401 }
    }
  }
}
```

---

## 管理员 API（需登录）

> 以下接口需要管理员 JWT Cookie，通过 `auth.localLogin` 登录后自动设置。

| 接口 | 方法 | 说明 |
|------|------|------|
| `auth.localLogin` | mutation | 管理员账号密码登录 |
| `auth.me` | query | 获取当前登录用户信息 |
| `students.list` | query | 列出所有学生 |
| `students.create` | mutation | 新增学生 |
| `students.update` | mutation | 修改学生信息 |
| `students.resetDevice` | mutation | 解绑学生设备（允许换机登录） |
| `questions.list` | query | 列出题库 |
| `questions.create` | mutation | 新增题目 |
| `exams.list` | query | 列出考试场次 |
| `exams.create` | mutation | 创建考试场次 |
| `exams.setStatus` | mutation | 修改考试状态（draft→active→ended） |
| `reports.examRecords` | query | 查询成绩记录 |
| `reports.scoreDistribution` | query | 成绩分布统计 |

---

## Python 调用示例

```python
import requests

SERVER = "http://192.168.1.100:3000"

def trpc(proc, data):
    r = requests.post(f"{SERVER}/api/trpc/{proc}",
                      json={"json": data}, timeout=15)
    body = r.json()
    if "error" in body:
        raise Exception(body["error"]["json"]["message"])
    return body["result"]["data"].get("json", body["result"]["data"])

# 1. 认证
auth = trpc("agentApi.authenticate", {
    "studentId": "stu001",
    "deviceId": "abc123",
    "clientUsername": "zhangsan"
})
token = auth["token"]

# 2. 获题
data = trpc("agentApi.fetchQuestions", {"token": token, "examId": 1})
questions = data["questions"]
scoring_script = questions[0]["scoringScript"]

# ... 运行脚本，解析得分

# 3. 提交
trpc("agentApi.submitScore", {
    "token": token, "examId": 1,
    "totalScore": 85, "durationSeconds": 3600,
    "details": [{"questionId": q["questionId"], "earnedScore": 10, "maxScore": 10} for q in questions]
})
```

---

## curl 调用示例

```bash
# 认证
curl -s -X POST http://localhost:3000/api/trpc/agentApi.authenticate \
  -H "Content-Type: application/json" \
  -d '{"json":{"studentId":"stu001","deviceId":"dev001","clientUsername":"student"}}'

# 获取题目
curl -s -X POST http://localhost:3000/api/trpc/agentApi.fetchQuestions \
  -H "Content-Type: application/json" \
  -d '{"json":{"token":"YOUR_TOKEN","examId":1}}'
```
