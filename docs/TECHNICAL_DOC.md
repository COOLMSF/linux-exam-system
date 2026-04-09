# Linux 考试系统 — 技术文档

---

## 目录

1. [系统整体介绍](#1-系统整体介绍)
2. [自动评分与统计技术](#2-自动评分与统计技术)
3. [自动出题与个性化技术](#3-自动出题与个性化技术)
4. [重要功能介绍](#4-重要功能介绍)

---

## 1. 系统整体介绍

### 1.1 系统定位

Linux 考试系统是一套面向高校和培训机构的 **Linux 数据库运维实操考试平台**。与传统选择题考试不同，本系统要求学生在真实操作系统环境中完成数据库安装、配置、优化、备份等操作，系统通过 **客户端 Agent** 在学生机器上执行评分脚本，自动检测操作结果并评分，实现全流程无人值守的考试与阅卷。

系统同时支持 **MySQL** 和 **达梦（DM8）** 两种数据库的考试场景，评分脚本内置自动检测逻辑，可在同一套题目下适配不同的数据库环境。

### 1.2 系统架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        管理员 Web 端 (浏览器)                       │
│   React + TailwindCSS + shadcn/ui + Recharts                    │
│   路由: Dashboard / Questions / Students / Exams / Reports       │
└─────────────────────────────┬────────────────────────────────────┘
                              │ HTTP (tRPC over Express)
┌─────────────────────────────▼────────────────────────────────────┐
│                       服务端 (Node.js)                            │
│   Express + tRPC v11 + Drizzle ORM + SuperJSON                  │
│   API 路由: auth / students / questions / exams / agentApi       │
│   数据库连接: MySQL (mysql2 驱动)                                  │
└─────────────────────────────┬────────────────────────────────────┘
                              │ MySQL Protocol
┌─────────────────────────────▼────────────────────────────────────┐
│                    MySQL 数据库 (系统数据库)                        │
│   表: users, students, questions, exam_sessions,                 │
│       exam_question_assignments, exam_records, score_details,    │
│       question_categories, scoring_rules, scoring_check_items    │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    学生机 (Linux / 麒麟 OS)                        │
│   Python 客户端 Agent (exam_agent.py)                            │
│   ① 认证 → ② 获取题目 → ③ 开始考试 → ④ 执行评分脚本              │
│   → ⑤ 上传成绩 → ⑥ 结束考试                                     │
│                                                                  │
│   评分脚本在学生机本地执行，检查:                                    │
│   MySQL 状态 / 达梦 DmService / 表结构 / 数据 / 索引 / 备份 ...   │
└──────────────────────────────────────────────────────────────────┘
```

### 1.3 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| **前端** | React 19 + TypeScript 5.9 | SPA 单页应用 |
| **UI 框架** | TailwindCSS 4 + shadcn/ui (Radix) | 现代组件库，暗色主题支持 |
| **图表** | Recharts | 成绩分布、趋势、错误率可视化 |
| **路由** | wouter | 轻量级前端路由 |
| **状态管理** | TanStack React Query | 服务端状态缓存与自动刷新 |
| **API 层** | tRPC v11 + SuperJSON | 端到端类型安全的 RPC 调用 |
| **服务端** | Express 4 + Node.js | HTTP 服务器 |
| **ORM** | Drizzle ORM | 类型安全的 SQL 查询构建 |
| **系统数据库** | MySQL 8.0+ (mysql2) | 存储题目、学生、考试、成绩数据 |
| **客户端 Agent** | Python 3 (requests) | 运行在学生机上的评分代理 |
| **构建工具** | Vite 6 + esbuild | 前端构建 + 服务端打包 |
| **包管理** | pnpm | 依赖管理 |
| **认证** | JWT (jose) + Cookie Session | 管理员/学生双角色认证 |

### 1.4 数据库 Schema（ER 模型）

```
users (管理员/教师账号)
  ├── id, openId, name, email, role, passwordHash

students (学生账号)
  ├── id, studentId, name, className, department
  ├── clientUsername, passwordHash
  ├── apiToken, tokenExpiresAt, deviceId    ← Agent 认证相关
  
question_categories (题目分类)
  ├── id, name, description

questions (题库)
  ├── id, title, content, categoryId
  ├── difficulty, maxScore, sortOrder
  ├── scoringScript                         ← 每题独立评分脚本 (Bash)
  
exam_sessions (考试场次)
  ├── id, name, durationMinutes, questionCount
  ├── status (draft/active/paused/ended)
  ├── categoryFilter                        ← JSON 数组，指定抽题分类

exam_question_assignments (考试题目分配)
  ├── examId, studentId, questionId
  ├── personalizedContent                   ← 变量替换后的个性化题目内容
  ├── questionSet (a/b)                     ← 题组标识

exam_records (考试记录)
  ├── examId, studentId, questionSet
  ├── status, totalScore, maxPossibleScore
  ├── durationSeconds, scriptOutput
  ├── startedAt, submittedAt, gradedAt

score_details (每题得分明细)
  ├── examRecordId, questionId
  ├── earnedScore, maxScore, failedChecks
```

### 1.5 项目目录结构

```
linux-exam-system/
├── server/                    # 服务端代码
│   ├── _core/                 # Express 启动、tRPC 上下文、OAuth、SDK
│   │   ├── index.ts           # 服务入口
│   │   ├── trpc.ts            # tRPC 初始化 (publicProcedure / protectedProcedure)
│   │   └── context.ts         # 请求上下文 (认证注入)
│   ├── routers.ts             # 所有 tRPC 路由定义
│   ├── db.ts                  # 数据库操作层 (Drizzle)
│   └── utils/auth.ts          # 密码哈希 (salt + SHA256)
├── client/                    # 前端代码
│   └── src/
│       ├── App.tsx            # 路由入口
│       ├── pages/             # 页面组件
│       │   ├── Dashboard.tsx       # 管理控制台
│       │   ├── Questions.tsx       # 题库管理
│       │   ├── Students.tsx        # 学生管理
│       │   ├── Exams.tsx           # 考试场次管理
│       │   ├── ExamOpsCenter.tsx   # 考试监控中心
│       │   ├── Reports.tsx         # 成绩报表与统计
│       │   ├── ScoringRules.tsx    # 评分规则管理
│       │   └── StudentDashboard.tsx # 学生门户
│       └── lib/trpc.ts        # tRPC 客户端
├── client_agent/              # Python 客户端 Agent
│   └── exam_agent.py          # Agent 主程序
├── scoring_scripts/           # 预置评分脚本 (10 道题)
│   ├── 01_mysql_service.sh    # Q1: 数据库服务管理 (4分)
│   ├── 02_mysql_install_config.sh  # Q2: 安装与配置 (14分)
│   ├── ...
│   └── 10_mysql_uninstall.sh  # Q10: 数据库卸载 (4分)
├── drizzle/
│   └── schema.ts              # 数据库 Schema 定义
├── install.sh                 # 一键安装/部署/E2E测试脚本
└── package.json
```

---

## 2. 自动评分与统计技术

### 2.1 评分架构概述

系统采用 **"服务端出题 + 客户端评分"** 的分布式评分架构：

```
┌────────────┐    tRPC API     ┌────────────┐    本地执行    ┌─────────────┐
│  服务端     │ ──────────────> │  Agent     │ ────────────> │  评分脚本    │
│  (题目+脚本) │ <────────────── │  (Python)  │ <──────────── │  (Bash)     │
│            │    上传成绩      │            │    SCORE:N    │  在学生机运行 │
└────────────┘                 └────────────┘               └─────────────┘
```

**核心流程**：

1. **Agent 认证**：学生通过 `studentId + password` 向服务端获取 API Token（有效期 8 小时）
2. **抽题与分配**：服务端从题库随机抽取指定数量的题目，进行变量替换后生成个性化内容，连同评分脚本一起下发
3. **本地评分**：Agent 将每题的评分脚本保存到学生机临时目录，以 `bash` 执行，解析 `SCORE:N` 格式的输出
4. **成绩上报**：Agent 将每题得分（`earnedScore / maxScore`）及失败检查项上传到服务端
5. **持久化**：服务端将成绩写入 `exam_records` 和 `score_details` 表

### 2.2 评分脚本设计

每道题对应一个独立的 Bash 评分脚本。脚本采用 **"满分扣分制"**：初始为满分，每个检查项失败则扣除相应分数。

**脚本结构示例**（以 Q1 数据库服务管理为例）：

```bash
#!/bin/bash
# 数据库服务管理检查（满分 4 分）
SCORE=4

# 自动检测数据库类型（MySQL / 达梦）
if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    DB_TYPE="dameng"
else
    DB_TYPE="mysql"
fi

if [ "$DB_TYPE" = "mysql" ]; then
    # 检查 MySQL 服务运行状态
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo "✓ MySQL 服务正在运行 (+2)"
    else
        echo "✗ MySQL 服务未运行 (-2)"
        SCORE=$((SCORE-2))
    fi
    # ... 更多检查项
else
    # 达梦模式检查
    DM_SVC=$(systemctl list-units --type=service --all | grep -i "DmService" | head -1)
    # ... 达梦特有检查
fi

echo "SCORE:$SCORE"    # 最终得分输出
```

**关键设计点**：

- **双数据库自动适配**：每个脚本内部通过检测 `/dm/bin` 目录或 `disql` 命令自动判断 MySQL 或达梦环境
- **扣分制**：满分起步，逐项检查，失败即扣分，比加分制更直观
- **标准输出协议**：脚本最后一行输出 `SCORE:N`，Agent 通过正则解析得分
- **检查类型丰富**：支持 `systemctl` 服务状态、SQL 查询结果、文件存在性、配置参数值、进程状态等多种检查

### 2.3 双模式评分引擎

Agent 支持两种评分模式，在运行时自动选择：

| 模式 | 条件 | 行为 |
|------|------|------|
| **逐题独立评分** | 每道题有不同的 `scoringScript` | 依次执行每题的脚本，分别解析 `SCORE:N` |
| **全局脚本评分** | 所有题目共享同一个脚本 | 执行一次全局脚本，解析 `Qn_SCORE=N` 格式 |

判断逻辑（`exam_agent.py`）：

```python
per_question = all(q.get("scoringScript") for q in questions)
unique_scripts = set(q.get("scoringScript", "") for q in questions)
per_question = per_question and len(unique_scripts) > 1

if per_question:
    return self._run_per_question_scoring(questions, username)
else:
    return self._run_legacy_scoring(questions, username)
```

### 2.4 评分脚本检查项类型

系统支持以下检查维度（以 10 道默认题目为例）：

| 题号 | 检查维度 | 满分 | 典型检查项 |
|------|----------|------|-----------|
| Q1 | 服务管理 | 4 | 服务运行状态、开机自启、旧目录清理 |
| Q2 | 安装配置 | 14 | 数据库存在、字符集、端口、实例名、数据恢复 |
| Q3 | 用户权限 | 8 | 用户存在、密码策略、表空间、权限检查 |
| Q4 | 表与数据 | 18 | 表记录数、列存在性、默认值、CSV 导出 |
| Q5 | 视图 | 8 | 视图存在、查询结果验证 |
| Q6 | 存储过程 | 20 | 过程存在、调用验证、日志表、触发器触发 |
| Q7 | 定时任务 | 8 | 事件调度器/定时作业状态 |
| Q8 | 性能优化 | 10 | 索引、统计信息、缓冲区配置 |
| Q9 | 备份安全 | 10 | 归档模式、备份目录、物理/逻辑备份文件 |
| Q10 | 卸载 | 4 | 服务停止、软件包卸载、进程清理 |

### 2.5 成绩统计与可视化

服务端提供多维度的成绩统计 API，前端通过 Recharts 进行可视化展示：

**统计 API**：

| API | 功能 | SQL 聚合 |
|-----|------|----------|
| `exams.stats` | 考试整体统计 | `AVG/MAX/MIN(totalScore)`, `COUNT(*)`, 及格人数 |
| `exams.scoreDistribution` | 分数段分布 | `FLOOR(totalScore/10)` 分组统计 |
| `exams.questionErrorRates` | 每题错误率 | `1 - AVG(earnedScore / maxScore)` |
| `exams.recordDetails` | 单次考试明细 | 逐题 `earnedScore / maxScore` + `failedChecks` |

**可视化图表**（Reports 页面）：

- **分数段柱状图**：0-59、60-69、70-79、80-89、90-100 五个区间
- **及格率饼图**：及格 / 不及格比例（≥60% 为及格）
- **成绩趋势面积图**：按提交时间排序的分数走势
- **每题错误率排名**：帮助教师识别难点题目

**考试监控中心**（ExamOpsCenter）：

- 实时刷新（5 秒轮询）的在线考试人数、已交卷人数
- 实时平均分、最高分统计
- 支持一键导出 CSV 成绩单

---

## 3. 自动出题与个性化技术

### 3.1 题目个性化机制

为防止学生之间互相抄袭，系统实现了 **基于变量替换的题目个性化**。每个学生拿到的题目参数不同，从而使得操作结果也不同。

**工作原理**：

```
题库中的模板内容                    学生 A 看到的题目
─────────────────                  ─────────────────
创建数据库 {{a_dbname}}      →     创建数据库 examdb_a
端口设置为 {{a_port}}        →     端口设置为 3306
创建用户 {{user_expected}}   →     创建用户 exam_dba
```

### 3.2 变量上下文生成

变量替换由服务端 `generateVariableContext()` 函数集中管理：

```typescript
// server/db.ts
export function generateVariableContext(
  questionSet: string,    // 题组: 'a' 或 'b'
  questionIndex: number,  // 题目序号
  studentUsername: string  // 学生用户名
): Record<string, string> {
  const context: Record<string, string> = {
    '{{username}}': studentUsername,
  };
  
  switch (questionSet) {
    case 'a':
      context['{{a_dbname}}'] = 'examdb_a';
      context['{{a_port}}'] = '3306';
      context['{{db_expected}}'] = 'examdb_a';
      context['{{user_expected}}'] = 'exam_dba';
      context['{{server_id_expected}}'] = '101';
      break;
    case 'b':
      context['{{b_dbname}}'] = 'examdb_b';
      context['{{b_port}}'] = '3307';
      context['{{db_expected}}'] = 'examdb_b';
      context['{{user_expected}}'] = 'exam_dbb';
      context['{{server_id_expected}}'] = '102';
      break;
  }
  return context;
}
```

### 3.3 题组（Question Set）分配

每个学生在首次获取题目时，系统随机分配 A 卷或 B 卷：

```typescript
// server/routers.ts — fetchQuestions 端点
const questionSet = Math.random() < 0.5 ? 'a' : 'b';

// 对每道题进行变量替换
const variableContexts = drawn.map((q, index) =>
  generateVariableContext(questionSet, index, student.clientUsername)
);

// 替换题目内容中的占位符
Object.entries(variables).forEach(([placeholder, value]) => {
  personalizedContent = personalizedContent.replace(
    new RegExp(placeholder, 'g'), value
  );
});
```

**A/B 卷差异对照**：

| 变量 | A 卷 | B 卷 |
|------|------|------|
| `{{db_expected}}` | `examdb_a` | `examdb_b` |
| `{{instance_expected}}` | `PROD` | `TEST` |
| `{{port_expected}}` | `3306` | `3307` |
| `{{user_expected}}` | `exam_dba` | `exam_dbb` |
| `{{server_id_expected}}` | `101` | `102` |

### 3.4 评分脚本的变量注入

评分脚本同样需要知道学生应该使用的参数值。服务端在下发评分脚本时，也会进行同样的变量替换：

```typescript
function buildScoringScript(questionSet: string, username: string): string {
  let scriptContent = readFileSync(scoreScriptPath, "utf8");
  const variables = generateVariableContext(questionSet, 0, username);
  
  // 将 {{db_expected}} 等占位符替换为实际值
  Object.entries(variables).forEach(([placeholder, value]) => {
    scriptContent = scriptContent.replace(new RegExp(placeholder, 'g'), value);
  });
  
  return scriptContent;
}
```

这确保了评分脚本检查的参数与学生题目中要求的参数一致。

### 3.5 随机抽题

考试创建时可指定 `categoryFilter`（题目分类 ID 数组）和 `questionCount`（抽题数量）。服务端在学生首次获取题目时执行随机抽取：

```typescript
// 使用 MySQL RAND() 函数随机抽题
const drawn = await db.select().from(questions)
  .where(and(
    eq(questions.isActive, true),
    inArray(questions.categoryId, categoryIds)
  ))
  .orderBy(sql`RAND()`)
  .limit(count);
```

### 3.6 预置评分脚本管理

系统在 `scoring_scripts/` 目录提供了 10 个预置脚本。管理员可以在 Web 界面上：

- **浏览预置脚本**：`questions.listPresets` API 读取目录下所有 `.sh` 文件
- **语法检查**：`questions.validateScript` API 调用 `bash -n` 做语法验证
- **自定义脚本**：每道题可以直接编辑独立的 `scoringScript` 字段

---

## 4. 重要功能介绍

### 4.1 双数据库支持（MySQL / 达梦）

系统从评分脚本到 E2E 测试均实现了 **MySQL 和达梦数据库的双轨支持**。

**自动检测逻辑**（统一用于所有评分脚本和 E2E 测试）：

```bash
if [ -d "/dm/bin" ] || command -v disql &>/dev/null; then
    DB_TYPE="dameng"
else
    DB_TYPE="mysql"
fi
```

**达梦模式下的关键差异**：

| 操作 | MySQL | 达梦 |
|------|-------|------|
| 客户端工具 | `mysql -u root` | `disql sysdba/Dameng123@localhost:5236` |
| 自增主键 | `AUTO_INCREMENT` | `IDENTITY(1,1)` |
| 时间默认值 | `CURRENT_TIMESTAMP` | `SYSDATE` |
| 列名风格 | 小写 (`create_time`) | 大写 (`CREATETIME`) |
| 表空间 | 无需手动创建 | `CREATE TABLESPACE TBS` |
| 定时任务 | `EVENT SCHEDULER` | `SP_CREATE_JOB / SYSJOB` |
| 备份 | `mysqldump` | `BACKUP DATABASE` + `dexp` |
| 归档模式 | `binlog` | `ALTER DATABASE ARCHIVELOG` |
| 统计信息 | `ANALYZE TABLE` | `DBMS_STATS.GATHER_TABLE_STATS` |

### 4.2 端到端（E2E）自动化测试

`install.sh --e2e-full` 提供了完整的端到端测试，模拟一个学生完成全部 10 道题的考试流程：

**测试流程**：

```
步骤 1: 环境检查 (服务运行、DB连接、.env解析)
步骤 2: 创建测试数据 (学生账号、题目分类、10道题、考试场次)
步骤 3: 模拟 Q1 — 数据库服务管理
步骤 4: 模拟 Q2 — 安装与初始化配置
步骤 5: 模拟 Q3 — 用户与权限管理
步骤 6: 模拟 Q4 — 表管理与数据导入导出
步骤 7: 模拟 Q5-Q7 — 视图/存储过程/定时任务
步骤 8: 模拟 Q8-Q9 — 性能优化/备份安全
步骤 9: 运行 Agent 自动评分 (调用 exam_agent.py)
```

**预期结果**：100/104 分（Q10 卸载题与 Q1 服务管理互斥，预期 0 分）

测试自动检测当前环境的数据库类型，MySQL 环境执行 MySQL 模拟操作，达梦环境执行 disql 模拟操作。

### 4.3 客户端 Agent

`client_agent/exam_agent.py` 是运行在学生机上的 Python 程序，支持麒麟操作系统（KylinOS）。

**完整生命周期**：

```
认证 → 获取题目 → 开始考试 → 显示题目 → 执行评分 → 上传成绩 → 结束考试
```

**关键特性**：

- **设备绑定**：首次认证记录 `deviceId`，防止换机作弊
- **Token 缓存**：认证 Token 缓存到 `~/.exam_agent/token.json`，8 小时有效
- **自动/手动模式**：`--auto`（默认）自动评分，`--manual` 需手动确认
- **查看模式**：`--view` 仅显示题目和评分标准，不执行评分
- **断线重传**：成绩上传失败时最多重试 5 次，指数退避
- **本地备份**：上传彻底失败时，成绩 JSON 备份到本地日志目录
- **元数据采集**：自动采集主机名、OS 版本、架构等考试环境信息

**命令行示例**：

```bash
# 自动评分模式
python3 exam_agent.py --exam-id 1 --student-id S001 --password mypass

# 查看题目
python3 exam_agent.py --view --exam-id 1 --student-id S001 --password mypass

# 手动模式（完成操作后按 Enter 评分）
python3 exam_agent.py --manual --exam-id 1 --student-id S001 --password mypass
```

### 4.4 管理员 Web 控制台

管理员通过浏览器访问 Web 界面，功能模块包括：

| 页面 | 路径 | 功能 |
|------|------|------|
| **控制台** | `/dashboard` | 总览统计（题库量、学生数、考试场次、平均分）、近期考试、最近提交 |
| **题库管理** | `/questions` | 题目 CRUD、分类筛选、评分脚本编辑、预置脚本选择、语法检查 |
| **学生管理** | `/students` | 学生 CRUD、密码重置、批量导入、设备解绑 |
| **考试管理** | `/exams` | 考试场次创建、状态管理（草稿→进行中→暂停→结束）、分类抽题配置 |
| **考试监控** | `/exam-ops` | 实时监控在线人数、成绩流水、CSV 导出 |
| **评分规则** | `/scoring-rules` | 可视化规则编辑器、检查项配置、脚本自动生成 |
| **成绩报表** | `/reports` | 分数分布、及格率、趋势、每题错误率排行、按考试/班级筛选 |

### 4.5 学生 Web 门户

学生通过学号登录后，可在 `/student` 页面查看：

- 个人信息（学号、姓名、班级）
- 可参加的考试列表（active/ended）
- 历史考试成绩记录
- 每题得分明细和失败检查项

### 4.6 认证与安全

系统实现了双角色认证体系：

**管理员认证**：
- 首次运行时通过 `auth.setupAdmin` 创建初始管理员
- 后续通过 `auth.localLogin` 用户名密码登录
- Session 使用 JWT Cookie 存储

**学生认证**（Web 端）：
- 通过 `auth.studentLogin` 学号密码登录
- 创建 `student-{studentId}` 格式的 session

**Agent 认证**（API）：
- 通过 `agentApi.authenticate` 获取 API Token
- Token 有效期 8 小时，绑定设备 ID
- 后续 API 调用通过 `validateToken()` 验证

**密码安全**：
- 使用 `salt + SHA256(salt + password + salt)` 哈希存储
- 盐值为 16 字节随机字符串
- 存储格式：`salt:hash`

### 4.7 一键部署脚本

`install.sh` 提供了完整的系统安装和管理功能：

```bash
sudo bash install.sh                  # 完整安装 (Node.js + MySQL + 系统)
sudo bash install.sh --install-mysql   # 仅安装 MySQL
sudo bash install.sh --install-dameng  # 仅安装达梦
sudo bash install.sh --e2e-full        # E2E 全流程测试
sudo bash install.sh --help            # 查看所有选项
```

### 4.8 评分规则可视化编辑器

管理员可以通过 Web 界面创建结构化评分规则，无需手写 Bash 脚本：

**规则结构**：
```
评分规则 (scoring_rules)
  └── 检查项 (scoring_check_items)
       ├── checkType: file_exists / file_not_exists / command_output / db_query / custom_script
       ├── checkTarget: 检查目标 (文件路径 / 命令 / SQL)
       ├── expectedValue: 期望值
       ├── compareOperator: eq / ne / contains / gt / lt
       └── deductionPoints: 扣分分值
```

系统支持从规则配置自动生成 Shell 评分脚本（`scoringRules.generateScript` API）。

---

## 附录：系统 API 一览

### 管理端 API（需 admin 权限）

| 路由 | 方法 | 说明 |
|------|------|------|
| `students.list` | Query | 学生列表 |
| `students.create` | Mutation | 创建学生 |
| `students.setPassword` | Mutation | 重置学生密码 |
| `questions.list` | Query | 题目列表 |
| `questions.create` | Mutation | 创建题目 |
| `questions.validateScript` | Mutation | 脚本语法检查 |
| `questions.listPresets` | Query | 预置脚本列表 |
| `exams.create` | Mutation | 创建考试 |
| `exams.update` | Mutation | 更新考试状态 |
| `exams.stats` | Query | 考试统计 |
| `exams.scoreDistribution` | Query | 分数分布 |
| `exams.questionErrorRates` | Query | 每题错误率 |

### Agent API（需 Token 认证）

| 路由 | 方法 | 说明 |
|------|------|------|
| `agentApi.authenticate` | Mutation | Agent 认证获取 Token |
| `agentApi.fetchQuestions` | Mutation | 获取个性化题目 + 评分脚本 |
| `agentApi.startExam` | Mutation | 开始考试计时 |
| `agentApi.submitScore` | Mutation | 提交评分结果 |
| `agentApi.finishExam` | Mutation | 结束考试 |

### 学生门户 API（需学生 Session）

| 路由 | 方法 | 说明 |
|------|------|------|
| `studentPortal.profile` | Query | 个人信息 |
| `studentPortal.exams` | Query | 可参加考试列表 |
| `studentPortal.myRecords` | Query | 历史成绩 |
| `studentPortal.myQuestions` | Query | 考试题目 |
| `studentPortal.scoreDetail` | Query | 每题得分明细 |
