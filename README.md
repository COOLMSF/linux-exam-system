# Linux 考试系统

基于 Web 的 Linux 操作实践考试系统，支持学生端自动评分、教师端实时监控和成绩管理。

---

## 目录

- [快速开始](#快速开始)
- [系统架构](#系统架构)
- [角色与功能](#角色与功能)
- [管理员使用指南](#管理员使用指南)
- [学生使用指南](#学生使用指南)
- [客户端 Agent 使用](#客户端-agent-使用)
- [评分系统](#评分系统)
- [install.sh 命令速查](#installsh-命令速查)
- [技术细节](#技术细节)
- [目录结构](#目录结构)
- [API 参考](#api-参考)

---

## 快速开始

```bash
# 一键安装并启动（推荐）
sudo bash install.sh --easy-install

# 开发模式（无需 root）
bash install.sh --dev

# 查看所有选项
bash install.sh --help
```

安装完成后访问 `http://服务器IP:3000`，首次访问会引导创建管理员账号。

---

## 系统架构

```
┌──────────────────────────────────────────────────────────────────┐
│                          服务端 (Node.js)                         │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌───────────────┐  │
│  │ Express  │  │  tRPC    │  │ Drizzle ORM│  │  评分脚本生成  │  │
│  │ 静态服务 │──│ API 路由 │──│ MySQL 操作 │  │ score_*.sh    │  │
│  └──────────┘  └──────────┘  └────────────┘  └───────────────┘  │
│       │              │              │                │            │
│       ▼              ▼              ▼                ▼            │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    MySQL 数据库                           │    │
│  │  users / students / exam_sessions / exam_records /       │    │
│  │  questions / exam_question_assignments / score_details   │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
        │                        │
        ▼                        ▼
┌───────────────┐      ┌──────────────────┐
│  管理员浏览器  │      │  学生浏览器/Agent │
│  React SPA    │      │  Web 端 + Python  │
│  /dashboard   │      │  /student         │
└───────────────┘      └──────────────────┘
```

| 组件 | 说明 |
|------|------|
| **服务端** | Node.js + Express + tRPC，管理题库/考试/成绩，生成个性化评分脚本 |
| **管理员前端** | React SPA，后台管理（题库、考试、学生、成绩报表） |
| **学生前端** | React SPA，查看考试题目、评分标准、成绩、个人信息 |
| **客户端 Agent** | Python 单文件可执行程序，在学生机上运行，负责认证/获题/评分/提交 |
| **评分脚本** | Bash 脚本（`score_a.sh` / `score_b.sh`），服务端按题目集生成，客户端本地执行 |

---

## 角色与功能

### 管理员

| 功能 | 说明 |
|------|------|
| 题库管理 | 添加/编辑/删除考试题目，按分类组织 |
| 考试管理 | 创建考试场次，设置时长、题目数、状态（草稿/进行中/已结束） |
| 学生管理 | 添加学生（学号+姓名+密码），设置/重置密码，设备绑定 |
| 成绩查看 | 查看每场考试的成绩统计、分数分布、各题得分明细 |
| 监控大屏 | 实时监控考试进度 |

### 学生

| 功能 | 说明 |
|------|------|
| Web 登录 | 用学号 + 密码登录学生中心 |
| 查看考试 | 浏览可用考试列表 |
| 查看题目 | 查看已分配的题目内容和评分标准（需先通过 Agent 抽题） |
| 查看成绩 | 查看历次考试得分及各题得分详情 |
| 修改密码 | 在学生中心修改自己的登录密码 |
| Agent 答题 | 在本机通过客户端 Agent 查看题目、完成操作、自动评分提交 |

---

## 管理员使用指南

### 1. 首次登录

访问 `http://服务器IP:3000`，首次会显示「创建管理员」表单，设置用户名和密码（≥6 位）。

### 2. 添加学生

进入「学生管理」页面 → 点击「添加学生」：

| 字段 | 必填 | 说明 |
|------|------|------|
| 学号 | ✅ | 唯一标识，如 `S20240001` |
| 姓名 | ✅ | 学生真实姓名 |
| Web 登录密码 | ✅ | 至少 6 位，学生用此密码登录 Web 端和客户端 Agent |
| 班级 | ❌ | 如 `2024级1班` |
| 院系 | ❌ | 如 `计算机学院` |
| 客户端用户名 | ❌ | 学生机的系统用户名，可由 Agent 自动采集 |

### 3. 重置学生密码

在学生列表中，点击学生行末尾的 🔑 图标，输入新密码即可。

### 4. 创建考试

进入「考试管理」页面 → 点击「创建考试」：
- 设置考试名称、时长（分钟）、题目数量
- 可选按题目分类筛选
- 状态设为 `active` 后学生 Agent 才能参加

### 5. 查看成绩

进入「成绩报表」页面，选择考试场次，可查看：
- 成绩统计（平均分、最高/最低分、通过率）
- 分数分布图
- 每个学生的各题得分明细

---

## 学生使用指南

### Web 端登录

1. 访问 `http://服务器IP:3000`
2. 点击顶部「学生」Tab
3. 输入学号和密码，点击登录
4. 进入学生中心，可以：
   - **考试列表**：查看可用考试，点击「查看题目」查看分配给自己的题目和评分标准
   - **我的成绩**：查看历次考试得分，点击查看各题详情
   - **个人信息**：查看个人资料
   - **修改密码**：点击右上角「修改密码」

### 客户端 Agent

学生在考试机上使用 Agent 完成考试，详见下一节。

---

## 客户端 Agent 使用

客户端 Agent 是运行在学生机上的 Python 程序，负责与服务器交互、展示题目、自动评分。

### 基本用法

```bash
# 查看帮助
./exam_agent -h

# 查看考试题目和评分标准（不评分，不提交）
./exam_agent --view --exam-id 11 --student-id <学号> --password <密码>

# 自动评分模式（默认）：显示题目 → 立即评分 → 提交成绩
./exam_agent --exam-id 11 --student-id <学号> --password <密码>

# 手动评分模式：显示题目 → 等待按 Enter → 评分 → 提交
./exam_agent --manual --exam-id 11 --student-id <学号> --password <密码>

# 指定服务器地址
./exam_agent --server http://192.168.1.100:3000 --exam-id 11

# 测试服务器连接
./exam_agent --test-connection --server http://192.168.1.100:3000

# 进入配置模式（保存服务器地址等）
./exam_agent --config
```

### 全部参数

| 参数 | 短写 | 说明 |
|------|------|------|
| `--server URL` | `-s` | 服务器地址（默认 `http://localhost:3000`） |
| `--exam-id N` | `-e` | 考试 ID（默认 1） |
| `--student-id ID` | `-i` | 学号（默认使用系统用户名） |
| `--password PWD` | `-p` | 密码（未指定则交互输入，不回显） |
| `--view` | | 仅查看题目和评分标准，不评分不提交 |
| `--auto` | `-a` | 自动评分模式（默认） |
| `--manual` | `-m` | 手动评分模式（完成操作后按 Enter 评分） |
| `--config` | `-c` | 进入配置向导 |
| `--test-connection` | `-t` | 测试服务器连接 |
| `--version` | `-v` | 显示版本号 |

### 考试流程

```
学生操作流程：

1. 查看题目       exam_agent --view --exam-id 11 -i <学号> -p <密码>
   ↓              阅读题目内容和评分标准
2. 在本机完成操作  按评分标准要求操作（建库、建表、配置等）
   ↓
3. 评分提交       exam_agent --exam-id 11 -i <学号> -p <密码>
   ↓              Agent 自动执行评分脚本，上传成绩
4. 查看成绩       登录 Web 端学生中心查看详细得分
```

### 认证机制

- Agent 使用 **学号 + 密码** 向服务器认证
- 认证成功后获取 API Token（有效期 8 小时），本地缓存于 `~/.exam_agent/token.json`
- Token 过期后自动重新认证（需再次输入密码）
- 首次认证会绑定设备 ID，后续只能在同一设备上使用

---

## 评分系统

### 工作原理

1. **题目分配**：每个学生首次获取题目时，服务器随机抽题并分配题目集（A 或 B）
2. **变量替换**：题目内容中的占位符被替换为个性化值（如数据库名、端口号、用户名等）
3. **评分脚本生成**：服务端根据题目集生成对应的 `score_*.sh` 评分脚本
4. **本地执行**：Agent 在学生机上执行评分脚本，脚本检查各项操作是否完成
5. **分数解析**：脚本输出格式为 `QUESTION_SCORES: Q1=5 Q2=8 Q3=10 ...`，Agent 解析后上传

### 评分脚本格式

评分脚本（`score_a.sh` / `score_b.sh`）采用统一格式：

```bash
#!/bin/bash
# 评分脚本 - 题目集 A

# 各题满分定义
Q1_MAX=10; Q2_MAX=8; Q3_MAX=10; ...
Q1=0; Q2=0; Q3=0; ...

# === 第 1 题评分 ===
# 检查某个条件是否满足
if mysql -u root -e "SHOW DATABASES" 2>/dev/null | grep -q "examdb"; then
    Q1=$((Q1 + 3))
fi
# ... 更多检查项 ...

# 输出标准格式（Agent 解析此行）
echo "QUESTION_SCORES: Q1=$Q1 Q2=$Q2 Q3=$Q3 ..."
```

### 评分标准

每道题的评分标准已写在题目内容中，学生可通过以下方式查看：

- **Agent `--view` 模式**：终端中用 `★` 高亮评分标准，`✓` 标记每项得分点
- **Web 学生中心**：考试列表 →「查看题目」按钮，评分标准金色高亮显示
- **考试时显示**：Agent 运行时会在终端打印完整题目内容

评分标准示例：
```
评分标准：
  - 数据库 examdb 存在 (3分)
  - 表 tab_emp 存在且有数据 (3分)
  - 索引 ix_emp_name 存在 (2分)
  - 视图 v_empinfo 查询结果正确 (2分)
```

---

## install.sh 命令速查

```bash
# 安装
sudo bash install.sh                    # 完整安装（服务端 + 系统服务）
sudo bash install.sh --easy-install     # 一键安装（推荐）

# 运维
sudo bash install.sh --reset-db         # 重置管理员密码（保留所有数据）
bash install.sh --start / --stop        # 启动/停止 systemd 服务
bash install.sh --status                # 查看服务状态

# 打包
bash install.sh --package-client        # 打包客户端 Agent 为可执行文件
bash install.sh --package-all           # 打包全部用于分发

# 开发 & 测试
bash install.sh --dev                   # 开发模式（热重载）
bash install.sh --demo-exam             # 端到端考试流程演示
bash install.sh --test-only             # 仅验证环境
```

---

## 技术细节

### 技术栈

| 层级 | 技术 |
|------|------|
| **运行时** | Node.js ≥ 18，Python 3.8+ |
| **数据库** | MySQL 8.0+，Drizzle ORM |
| **后端框架** | Express 4 + tRPC v11 |
| **前端框架** | React 19 + TypeScript 5.9 |
| **UI 库** | Tailwind CSS 4 + shadcn/ui + Lucide Icons |
| **图表** | Recharts |
| **构建工具** | Vite 6（前端）+ esbuild（后端） |
| **客户端** | Python + requests，PyInstaller 打包 |
| **兼容系统** | Ubuntu 18.04+，麒麟 V10 SP1+（x86_64） |

### 认证与会话

- **管理员认证**：用户名 + 密码 → JWT Session Token → HTTP-Only Cookie（`linux_exam_session`）
- **学生 Web 认证**：学号 + 密码 → 服务端创建临时 User 记录（`role='student'`）→ 同样的 JWT Cookie
- **Agent 认证**：学号 + 密码 → 验证后发放 API Token（nanoid 64 字符）→ 存于 HTTP Header
- **密码存储**：SHA256 + 随机 Salt，格式 `salt:hash`（`server/utils/auth.ts`）
- **Session 有效期**：Web 登录 1 年，Agent Token 8 小时

### 数据库表结构

```
users               管理员/学生 Web 登录用户
  ├─ openId         唯一标识（管理员 local-admin-xxx，学生 student-xxx）
  ├─ role           角色（admin / student）
  └─ passwordHash   密码哈希

students            学生信息
  ├─ studentId      学号（唯一）
  ├─ passwordHash   密码哈希（用于 Web 登录和 Agent 认证）
  ├─ apiToken       Agent API Token
  ├─ deviceId       设备绑定 ID
  └─ clientUsername 客户端系统用户名

exam_sessions       考试场次
  ├─ status         draft / active / paused / ended
  ├─ durationMinutes 考试时长
  └─ questionCount  题目数量

questions           题库
  ├─ title          题目标题
  ├─ content        题目内容（含评分标准）
  ├─ maxScore       满分
  └─ categoryId     分类

exam_question_assignments  学生题目分配
  ├─ examId / studentId / questionId
  ├─ personalizedContent  个性化后的题目内容
  └─ questionSet    题目集（a / b）

exam_records        考试记录
  ├─ status         in_progress / completed / graded
  ├─ totalScore     总分
  └─ scriptOutput   评分脚本原始输出

score_details       各题得分明细
  ├─ earnedScore    实际得分
  └─ maxScore       满分
```

### tRPC API 路由结构

```
appRouter
├── auth                    认证相关
│   ├── me                  获取当前用户信息
│   ├── localLogin          管理员登录（用户名+密码）
│   ├── studentLogin        学生登录（学号+密码）
│   ├── setupAdmin          首次创建管理员
│   ├── changePassword      管理员修改密码
│   ├── studentChangePassword 学生修改密码
│   └── logout              登出
│
├── students                学生管理（管理员）
│   ├── list / create / update / delete
│   └── setPassword         设置学生密码
│
├── questions               题库管理（管理员）
│   └── list / create / update / delete
│
├── exams                   考试管理（管理员）
│   ├── list / create / update
│   ├── records / recordDetails
│   ├── stats / scoreDistribution
│   └── getById
│
├── studentPortal           学生门户
│   ├── profile             个人信息
│   ├── exams               可见考试列表
│   ├── myRecords           我的考试记录
│   ├── myQuestions          我的题目（含评分标准）
│   └── scoreDetail         成绩详情
│
├── agentApi                客户端 Agent 接口
│   ├── authenticate        认证（学号+密码+设备ID）
│   ├── startExam           开始考试
│   ├── fetchQuestions      获取题目
│   ├── submitScore         提交成绩
│   ├── finishExam          结束考试
│   └── fetchScoringScript  获取评分脚本
│
├── categories              题目分类管理
├── scoringRules            评分规则管理
└── reports                 统计报表
```

### 前端路由

| 路径 | 页面 | 角色 |
|------|------|------|
| `/` | 登录页（管理员/学生切换） | 公开 |
| `/dashboard` | 管理员仪表盘 | 管理员 |
| `/questions` | 题库管理 | 管理员 |
| `/students` | 学生管理 | 管理员 |
| `/exams` | 考试管理 | 管理员 |
| `/scoring-rules` | 评分规则 | 管理员 |
| `/reports` | 成绩报表 | 管理员 |
| `/exam-ops` | 考试监控大屏 | 管理员 |
| `/student` | 学生中心 | 学生 |

### 构建与部署

```bash
# 构建前端 + 后端
pnpm build
# 产物：dist/public/（前端静态文件）+ dist/index.js（后端入口）

# 生产环境启动
NODE_ENV=production node dist/index.js

# systemd 服务
sudo systemctl start linux-exam
sudo systemctl status linux-exam
sudo journalctl -u linux-exam -f   # 查看日志

# 打包 Agent
bash install.sh --package-client
# 产物：dist/client_agent/exam_agent（单文件可执行）
```

---

## 目录结构

```
linux-exam-system/
├── server/                 # 服务端 TypeScript 源码
│   ├── _core/              # Express + tRPC 核心配置
│   │   ├── index.ts        # 服务入口（端口监听、中间件）
│   │   ├── trpc.ts         # tRPC 实例 + 权限中间件
│   │   ├── context.ts      # 请求上下文（认证）
│   │   └── sdk.ts          # JWT 会话管理
│   ├── db.ts               # 所有数据库操作函数
│   ├── routers.ts          # 所有 tRPC 路由定义
│   └── utils/
│       └── auth.ts         # 密码哈希/验证工具（SHA256+Salt）
│
├── client/                 # React 前端源码
│   └── src/
│       ├── pages/
│       │   ├── Home.tsx           # 登录页（管理员/学生切换）
│       │   ├── Dashboard.tsx      # 管理员仪表盘
│       │   ├── Students.tsx       # 学生管理（含设置密码）
│       │   ├── Questions.tsx      # 题库管理
│       │   ├── Exams.tsx          # 考试管理
│       │   ├── Reports.tsx        # 成绩报表
│       │   ├── ExamOpsCenter.tsx  # 监控大屏
│       │   └── StudentDashboard.tsx # 学生中心
│       ├── components/            # 通用 UI 组件（shadcn/ui）
│       └── lib/trpc.ts            # tRPC 客户端配置
│
├── drizzle/                # Drizzle ORM
│   ├── schema.ts           # 数据库表定义
│   └── migrations/         # SQL 迁移文件
│
├── client_agent/           # Python 客户端 Agent
│   ├── exam_agent.py       # Agent 主程序（认证/获题/评分/提交）
│   └── exam_agent.spec     # PyInstaller 打包配置
│
├── score_a.sh              # 题目集 A 评分脚本（MySQL）
├── score_b.sh              # 题目集 B 评分脚本（MySQL）
├── score.sh                # 题目集默认评分脚本（达梦）
│
├── seed_mysql_questions.js # 题库初始化脚本
├── install.sh              # 一键安装/管理脚本
├── exam_e2e_demo.sh        # 端到端演示测试
├── test_client_server.py   # 自动化对接测试
├── package.json            # Node.js 依赖配置
└── .env                    # 环境变量（DATABASE_URL 等）
```
