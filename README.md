# Linux 考试系统

基于 Web 的 Linux 操作实践考试系统，支持学生端自动评分、教师端实时监控和成绩管理。

## 快速开始

```bash
# 一键安装并启动（推荐）
sudo bash install.sh --easy-install

# 开发模式（无需 root）
bash install.sh --dev

# 查看所有选项
bash install.sh --help
```

安装完成后访问 `http://服务器IP:3000`，默认管理员账号由安装脚本输出。

## 系统构成

| 组件 | 说明 |
|------|------|
| **服务端** | Node.js + Express + tRPC，管理题库/考试/成绩，提供 REST/tRPC API |
| **前端** | React + Tailwind CSS，管理员后台 + 监考大屏 |
| **客户端 Agent** | Python 单文件可执行程序，在学生机上运行，负责认证/获题/评分/提交 |
| **评分脚本** | Bash shell 脚本（`score_a.sh` / `score_b.sh`），服务端下发，客户端本地执行 |

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

## 文档

| 文件 | 内容 |
|------|------|
| [docs/architecture.md](docs/architecture.md) | 系统架构与数据流 |
| [docs/api-reference.md](docs/api-reference.md) | 客户端 Agent API 参考 |
| [docs/scoring-system.md](docs/scoring-system.md) | 评分脚本编写指南 |
| [docs/deployment.md](docs/deployment.md) | 生产环境部署指南 |
| [docs/development.md](docs/development.md) | 本地开发指南 |

## 技术栈

- **运行时**：Node.js ≥ 18，Python 3.8+
- **数据库**：MySQL 8.0+（Drizzle ORM）
- **前端**：React 19，Tailwind CSS 4，shadcn/ui，Recharts
- **API**：tRPC v11，Express
- **客户端**：Python + requests，PyInstaller 打包为单文件
- **兼容系统**：Ubuntu 18.04+，麒麟 V10 SP1+（x86_64）

## 目录结构

```
linux-exam-system/
├── server/           # 服务端 TypeScript 源码
│   ├── _core/        # Express + tRPC 核心配置
│   ├── db.ts         # 数据库操作函数
│   ├── routers.ts    # 所有 tRPC 路由
│   └── utils/auth.ts # 密码哈希工具
├── client/           # React 前端源码
├── drizzle/          # ORM schema 定义 + 迁移
├── client_agent/     # Python 客户端 Agent
│   ├── exam_agent.py # Agent 主程序
│   └── exam_agent.spec # PyInstaller 打包配置
├── score_a.sh        # 题目集 A 评分脚本
├── score_b.sh        # 题目集 B 评分脚本
├── install.sh        # 一键安装/管理脚本
├── exam_e2e_demo.sh  # 端到端演示测试脚本
└── test_client_server.py  # 自动化对接测试
```
