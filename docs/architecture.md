# 系统架构

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         教师 / 管理员                             │
│                    浏览器  http://server:3000                    │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP / tRPC
┌────────────────────────────▼────────────────────────────────────┐
│                       服务端（Node.js）                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Express     │  │  tRPC 路由   │  │  React 前端 (静态)   │  │
│  │  (HTTP)      │  │  /api/trpc/* │  │  /dist/client/       │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│              │                                                   │
│  ┌───────────▼───────────────────────────────────────────────┐  │
│  │               Drizzle ORM  (mysql2)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                   ┌─────────▼──────────┐
                   │  MySQL 8.0+        │
                   │  linux_exam 数据库  │
                   └────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      学生机（任意 Linux）                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  exam_agent（Python 单文件可执行）                        │   │
│  │                                                          │   │
│  │  1. authenticate  ──────────────────────────────►  服务端 │  │
│  │  2. fetchQuestions ─────────────────────────────►  服务端 │  │
│  │  3. startExam ──────────────────────────────────►  服务端 │  │
│  │  4. 学生在 Shell 完成 Linux 操作任务                      │   │
│  │  5. 执行本地 score.sh（服务端下发）                       │   │
│  │  6. submitScore ────────────────────────────────►  服务端 │  │
│  │  7. finishExam ─────────────────────────────────►  服务端 │  │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 考试完整数据流

```
教师操作                    系统内部                      学生端
────────────────────────────────────────────────────────────────────
1. 上传题目 & 评分脚本
   (score_a.sh / score_b.sh)

2. 创建考试场次
   设置题目数量、时长、
   题库分类过滤

3. 将状态改为 active ──────► 数据库写入 status='active'

                                                   4. exam_agent 启动
                                                      authenticate()
                                                      ◄── token (8h 有效)

                                                   5. fetchQuestions()
                                                      ◄── 个性化题目内容
                                                          + score.sh 脚本
                                                          （{{username}} 已替换）

                                                   6. startExam()
                                                      ◄── recordId

                                                   7. 学生完成 Linux 操作

                                                   8. 本地执行 score.sh
                                                      解析输出 → 得分明细

                                                   9. submitScore()
                                                      → totalScore
                                                      → details[]
                                                      → scriptOutput
                                                      → examMeta

                                                   10. finishExam()

11. 查看成绩报告 ◄────────── 数据库 exam_records
                              score_details 已写入
```

## 题目个性化（变量替换）

服务端在 `fetchQuestions` 时，对每道题内容中的占位符进行替换：

| 占位符 | 示例替换值 | 说明 |
|--------|-----------|------|
| `{{username}}` | `student01` | 学生系统用户名 |
| `{{port_expected}}` | `5236` | 随机端口（题目集决定） |
| `{{db_expected}}` | `EXAMDB` | 数据库名（随机） |
| `{{instance_expected}}` | `EXAMINS` | 实例名（随机） |

替换逻辑在 `server/routers.ts` 的 `generateVariableContext()` 中。

## 题目集（Question Set）

每次考试随机分配 **A** 或 **B** 题目集，同一场考试中不同学生可能使用不同题目集，对应 `score_a.sh` / `score_b.sh`。

- 题目集存入 `exam_question_assignments.questionSet`
- 评分脚本在下发前已完成变量替换
- `score_a.sh` 和 `score_b.sh` 功能相同，内容可配置差异化参数

## 数据库表关系

```
users                  students
  id                     id
  openId (UK)            studentId (UK)
  name                   name
  role                   className
  passwordHash           apiToken          ← 考试期间 token
  loginMethod            deviceId          ← 设备绑定

question_categories     questions
  id                     id
  name (UK)              title
                         categoryId ──────► question_categories.id
                         maxScore
                         difficulty

exam_sessions           exam_records
  id                     id
  name                   examId ──────────► exam_sessions.id
  status                 studentId ───────► students.id
  questionCount          totalScore
  durationMinutes        status
  categoryFilter         questionSet

exam_question_assignments   score_details
  id                          id
  examId                      examRecordId ────► exam_records.id
  studentId                   questionId ──────► questions.id
  questionId                  earnedScore
  personalizedContent         maxScore
  questionSet                 failedChecks

scoring_rules           scoring_check_items
  id                     id
  questionId             ruleId ──────────► scoring_rules.id
  name                   checkType
  initialScore           checkTarget
                         deductionPoints
```

## 部署架构（生产）

```
/opt/linux-exam-system/
├── dist/
│   └── index.js        ← 编译后的服务端（ESM bundle）
├── node_modules/       ← 运行时依赖
├── score_a.sh          ← 题目集 A 评分脚本（部署时替换）
├── score_b.sh          ← 题目集 B 评分脚本
└── .env                ← 生产环境变量

systemd 服务: linux-exam.service
  ExecStart: node /opt/linux-exam-system/dist/index.js
  EnvironmentFile: /opt/linux-exam-system/.env
  Restart: always
```
