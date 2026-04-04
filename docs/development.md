# 本地开发指南

## 环境准备

```bash
# 克隆项目
git clone <repo> linux-exam-system
cd linux-exam-system

# 安装 Node.js 依赖
pnpm install

# 复制环境变量（按需修改）
cp .env.example .env   # 若无，手动创建（见下方模板）
```

**.env 最小配置**

```ini
DATABASE_URL=mysql://exam_user:exam_password@localhost:3306/linux_exam
JWT_SECRET=dev-secret-key-change-in-production
PORT=3000
NODE_ENV=development
```

## 启动开发服务器

```bash
# 全栈开发模式（前端热重载 + 后端 tsx watch）
bash install.sh --dev
# 等价于：
pnpm dev
```

访问 `http://localhost:3000`

## 目录结构详解

```
linux-exam-system/
│
├── server/                     # 服务端 TypeScript
│   ├── _core/
│   │   ├── index.ts            # Express 入口（挂载 tRPC + 静态文件）
│   │   ├── trpc.ts             # tRPC context + procedure 定义
│   │   ├── cookies.ts          # JWT Cookie 工具
│   │   ├── logger.ts           # 结构化日志
│   │   └── systemRouter.ts     # 系统路由（health check 等）
│   ├── db.ts                   # 所有数据库操作函数
│   ├── routers.ts              # 所有 tRPC 路由（主文件）
│   ├── storage.ts              # 文件存储（S3 兼容）
│   └── utils/
│       └── auth.ts             # 密码哈希（SHA256 + salt）
│
├── client/                     # React 前端
│   ├── src/
│   │   ├── pages/              # 页面组件
│   │   │   ├── Dashboard.tsx   # 管理员首页
│   │   │   ├── Students.tsx    # 学生管理
│   │   │   ├── Questions.tsx   # 题库管理
│   │   │   ├── Exams.tsx       # 考试管理
│   │   │   └── Reports.tsx     # 成绩报告
│   │   ├── components/         # 可复用组件（shadcn/ui 为主）
│   │   ├── lib/trpc.ts         # tRPC 客户端配置
│   │   └── main.tsx            # 应用入口
│
├── drizzle/
│   └── schema.ts               # 数据库 Schema（Drizzle ORM 定义）
│
├── shared/                     # 前后端共享代码
│   └── const.ts                # 常量（COOKIE_NAME 等）
│
├── client_agent/
│   ├── exam_agent.py           # 学生端 Agent 主程序
│   ├── exam_agent.spec         # PyInstaller 打包配置
│   └── requirements.txt        # Python 依赖
│
├── tests/
│   ├── test_db_integration.test.ts  # 数据库集成测试
│   └── automatic_question.test.ts   # 题目自动化测试
│
├── score_a.sh                  # 题目集 A 评分脚本（开发用）
├── score_b.sh                  # 题目集 B 评分脚本
├── exam_e2e_demo.sh            # 端到端演示测试
├── test_client_server.py       # 客户端↔服务端自动化测试
├── install.sh                  # 安装/管理脚本
├── vite.config.ts              # Vite 构建配置（前端）
├── tsconfig.json               # TypeScript 配置
└── drizzle.config.json         # Drizzle ORM 配置
```

## 数据库操作

```bash
# 推送 schema 变更（开发用，等价于自动迁移）
DATABASE_URL="mysql://exam_user:exam_password@localhost:3306/linux_exam" pnpm db:push

# 运行数据库集成测试
pnpm test:db

# 直接连接数据库
mysql -u exam_user -p linux_exam
```

## 测试

```bash
# 运行所有单元测试
pnpm test

# 运行数据库集成测试
pnpm test:db

# 客户端↔服务端完整对接测试（需服务运行）
python3 test_client_server.py

# 端到端考试流程演示（需服务运行）
bash exam_e2e_demo.sh
```

## 构建

```bash
# 完整构建（前端 + 服务端）
pnpm build

# 构建产物：
# dist/          → 前端静态文件（Vite 构建）
# dist/index.js  → 服务端 ESM bundle（esbuild）
```

## 添加新的 tRPC 接口

在 `server/routers.ts` 中添加到对应 router：

```typescript
// 示例：添加一个新的管理员接口
const someRouter = router({
  myNewEndpoint: adminProcedure
    .input(z.object({ id: z.number() }))
    .query(async ({ input }) => {
      const db = await getDb();
      // ... 实现逻辑
      return { data: result };
    }),
});

// 在 appRouter 中注册
export const appRouter = router({
  // ...已有路由
  someFeature: someRouter,
});
```

前端调用：
```typescript
const { data } = trpc.someFeature.myNewEndpoint.useQuery({ id: 1 });
```

## 修改数据库 Schema

1. 编辑 `drizzle/schema.ts`
2. 运行 `pnpm db:push` 应用变更
3. 更新 `server/db.ts` 中对应的操作函数

**注意**：`db:push` 会直接修改数据库结构，仅用于开发。生产环境使用 `drizzle-kit generate` + `drizzle-kit migrate` 生成 SQL 迁移文件。

## 打包客户端 Agent

```bash
# 打包为单文件可执行（Ubuntu/麒麟）
bash install.sh --package-client

# 输出：dist/client_agent/exam_agent
# 分发到学生机直接运行即可
```

## 代码风格

```bash
# 格式化（Prettier）
pnpm format

# 类型检查
pnpm check
```

配置文件：`.prettierrc`（JSON），`tsconfig.json`（严格模式）。

## 环境变量说明

| 变量 | 开发默认值 | 说明 |
|------|-----------|------|
| `DATABASE_URL` | `mysql://exam_user:exam_password@localhost:3306/linux_exam` | MySQL 连接串 |
| `JWT_SECRET` | （任意字符串） | JWT 签名密钥 |
| `PORT` | `3000` | 监听端口 |
| `NODE_ENV` | `development` | 影响日志级别和错误输出 |

## 常见开发问题

**`pnpm dev` 报数据库连接失败**

```bash
# 确认 MySQL 服务运行
sudo systemctl status mysql
# 确认用户权限
mysql -u exam_user -p -e "USE linux_exam; SHOW TABLES;"
```

**修改了 `server/db.ts` 但 `limit(1)` 报错**

MySQL 不支持 LIMIT 参数绑定，不要使用 `.limit(1)`，改为：
```typescript
const r = await db.select().from(table).where(eq(table.col, val));
return r[0];  // 取第一条
```

**前端改动不生效**

开发模式下 Vite 会热重载，若不生效：
```bash
# 清除缓存重启
rm -rf node_modules/.vite
pnpm dev
```

**`buildScoringScript` 报 `require is not defined`**

服务端以 ESM 格式构建，不能用 `require()`。正确写法：
```typescript
import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
const __dirname = dirname(fileURLToPath(import.meta.url));
```
