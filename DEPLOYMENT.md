# Linux 考试系统部署文档

**版本**: 1.0.0  
**适配环境**: 麒麟操作系统 (KylinOS V10) + 达梦数据库 DM8  
**架构**: C/S（客户端/服务端）

---

## 目录

1. [系统架构概览](#1-系统架构概览)
2. [服务端部署（麒麟服务器版）](#2-服务端部署)
3. [达梦数据库 DM8 适配配置](#3-达梦数据库-dm8-适配配置)
4. [前端管理系统部署](#4-前端管理系统部署)
5. [客户端 Agent 部署（麒麟桌面版）](#5-客户端-agent-部署)
6. [自动化打包指南](#6-自动化打包指南)
7. [PyInstaller 手动打包指南](#7-pyinstaller-手动打包指南)
8. [评分规则配置指南](#8-评分规则配置指南)
9. [系统运维与故障排查](#9-系统运维与故障排查)

---

## 1. 系统架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    服务端（麒麟服务器版）                        │
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │  Node.js 后端    │    │     Vue 3 前端管理系统             │ │
│  │  (Express+tRPC) │    │  (题库管理/考试管理/成绩报表)        │ │
│  └────────┬────────┘    └──────────────────────────────────┘ │
│           │                                                   │
│  ┌────────▼────────────────────────────────────────────────┐ │
│  │              达梦数据库 DM8 / MySQL                       │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↕ HTTP/HTTPS (RESTful API)
┌─────────────────────────────────────────────────────────────┐
│                   客户端（麒麟桌面版）                          │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           考试 Agent (exam_agent)                        │ │
│  │  1. 采集系统用户名  2. 向服务端认证  3. 获取题目            │ │
│  │  4. 展示题目       5. 执行评分脚本  6. 上传成绩            │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 服务端部署

### 2.1 环境要求

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| 操作系统 | 麒麟服务器版 V10 SP2+ | 或 CentOS 7/8、Ubuntu 20.04+ |
| Node.js | 18.x 或 20.x LTS | 推荐使用 nvm 管理版本 |
| pnpm | 8.x+ | 包管理器 |
| 数据库 | MySQL 8.0 / 达梦 DM8 | 见第3节 DM8 适配 |
| 内存 | ≥ 4GB | 推荐 8GB |
| 磁盘 | ≥ 20GB | 用于数据库和日志 |

### 2.2 安装 Node.js（麒麟系统）

```bash
# 方法一：使用 nvm（推荐）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# 方法二：使用系统包管理器（麒麟 V10）
sudo apt update
sudo apt install -y nodejs npm
# 或通过 NodeSource 安装 Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
```

### 2.3 安装 pnpm

```bash
npm install -g pnpm
```

### 2.4 部署应用

```bash
# 克隆或上传项目到服务器
cd /opt
sudo mkdir -p linux_exam_system
sudo chown $USER:$USER linux_exam_system

# 上传项目文件（从开发机）
# scp -r ./linux_exam_system user@server:/opt/

cd /opt/linux_exam_system

# 安装依赖
pnpm install --frozen-lockfile

# 构建前端
pnpm build

# 配置环境变量（复制并修改）
cp .env.example .env
nano .env
```

### 2.5 环境变量配置

编辑 `.env` 文件：

```bash
# 数据库连接（MySQL 格式）
DATABASE_URL=mysql://root:password@localhost:3306/linux_exam

# 如使用达梦数据库，见第3节

# JWT 密钥（请修改为随机字符串）
JWT_SECRET=your-super-secret-jwt-key-change-this

# 服务端口
PORT=3000

# 应用标题
VITE_APP_TITLE=Linux考试系统
```

### 2.6 数据库初始化

```bash
# 运行数据库迁移
pnpm drizzle-kit generate
# 然后在管理界面执行生成的 SQL 文件

# 或直接连接数据库执行
mysql -u root -p linux_exam < drizzle/migrations/0001_initial.sql
```

### 2.7 配置系统服务（systemd）

```bash
# 创建 systemd 服务文件
sudo tee /etc/systemd/system/linux-exam.service << 'EOF'
[Unit]
Description=Linux Exam System Server
After=network.target mysql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/linux_exam_system
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
EnvironmentFile=/opt/linux_exam_system/.env

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable linux-exam
sudo systemctl start linux-exam
sudo systemctl status linux-exam
```

### 2.8 配置 Nginx 反向代理（可选）

```nginx
# /etc/nginx/conf.d/linux-exam.conf
server {
    listen 80;
    server_name exam.your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 3. 达梦数据库 DM8 适配配置

本系统默认使用 MySQL 协议。如需切换到达梦数据库 DM8，需要进行以下适配。

### 3.1 DM8 兼容性说明

达梦数据库 DM8 支持 MySQL 协议兼容模式，可通过以下两种方式接入：

**方式一：MySQL 兼容模式（推荐，改动最小）**

DM8 提供 MySQL 兼容层，直接使用现有 MySQL 连接字符串：

```bash
# .env 配置（DM8 MySQL 兼容端口，默认 5237）
DATABASE_URL=mysql://SYSDBA:SYSDBA001@localhost:5237/DAMENG
```

在 DM8 中启用 MySQL 兼容模式：

```sql
-- 以 SYSDBA 身份登录 DM8
-- 创建考试数据库
CREATE SCHEMA linux_exam;

-- 启用 MySQL 兼容模式（需要 DM8 SP2+）
SP_SET_PARA_VALUE(1, 'COMPATIBLE_MODE', 4);  -- 4 = MySQL 兼容模式
```

**方式二：原生 DM8 驱动（需修改代码）**

如需使用原生 DM8 驱动，需要安装 `dmdb` Node.js 驱动：

```bash
# 从达梦官网下载 Node.js 驱动
# 或联系达梦技术支持获取 npm 包
npm install dmdb

# 修改 server/db.ts 中的数据库连接
```

### 3.2 DM8 数据类型映射

| MySQL 类型 | DM8 类型 | 说明 |
|-----------|---------|------|
| `INT` | `INT` | 兼容 |
| `VARCHAR(n)` | `VARCHAR(n)` | 兼容 |
| `TEXT` | `TEXT` / `CLOB` | 大文本用 CLOB |
| `TIMESTAMP` | `TIMESTAMP` | 兼容 |
| `ENUM` | `VARCHAR(20)` | DM8 不支持 ENUM，需转换 |
| `BOOLEAN` | `TINYINT(1)` | 兼容 |
| `JSON` | `TEXT` | DM8 需手动解析 JSON |

### 3.3 DM8 Schema 适配脚本

```sql
-- 创建考试系统数据库用户
CREATE USER exam_admin IDENTIFIED BY "ExamAdmin@2024";
GRANT DBA TO exam_admin;

-- 创建表空间
CREATE TABLESPACE exam_ts DATAFILE '/dm8/data/exam_ts.dbf' SIZE 512;

-- 切换到考试用户
CONN exam_admin/ExamAdmin@2024;
```

### 3.4 DM8 服务配置

```bash
# 检查 DM8 服务状态
systemctl status DmServiceDMSERVER

# 启动 DM8 服务
systemctl start DmServiceDMSERVER

# 查看 DM8 监听端口
netstat -tlnp | grep 5236

# 使用 disql 连接测试
/home/dmdba/dmdbms/bin/disql SYSDBA/SYSDBA001@localhost:5236
```

---

## 4. 前端管理系统部署

前端已集成到 Node.js 后端服务中，通过 Vite 构建后由 Express 静态文件服务提供。

访问地址：`http://服务器IP:3000`

### 4.1 管理员账号设置

首次登录后，需要将账号设置为管理员：

```sql
-- 通过数据库直接设置管理员角色
UPDATE users SET role = 'admin' WHERE email = 'your-email@example.com';
```

或在系统管理界面 → 数据库面板中执行上述 SQL。

### 4.2 功能模块说明

| 模块 | 路径 | 功能 |
|------|------|------|
| 仪表盘 | `/dashboard` | 系统概览、实时统计 |
| 学生管理 | `/students` | 学生信息 CRUD、账号绑定 |
| 题库管理 | `/questions` | 题目增删改查、分类管理 |
| 考试管理 | `/exams` | 考试场次创建、启停控制、进度监控 |
| 评分规则 | `/scoring-rules` | 可视化配置评分标准、生成脚本预览 |
| 成绩报表 | `/reports` | 成绩统计、图表分析、CSV 导出 |

---

## 5. 客户端 Agent 部署

### 5.1 环境要求（麒麟桌面版）

| 组件 | 要求 |
|------|------|
| 操作系统 | 麒麟桌面版 V10 |
| Python | 3.8+ |
| 网络 | 能访问服务器 IP:3000 |

### 5.2 直接运行（开发/测试环境）

```bash
# 安装依赖
pip3 install requests

# 配置服务器地址
python3 exam_agent.py --config

# 运行考试
python3 exam_agent.py --server http://192.168.1.100:3000
```

### 5.3 使用打包后的可执行文件（生产环境）

```bash
# 将 exam_agent 可执行文件复制到客户端
cp exam_agent /usr/local/bin/
chmod +x /usr/local/bin/exam_agent

# 配置服务器地址（首次运行）
exam_agent --config

# 开始考试
exam_agent
```

### 5.4 客户端配置文件

配置文件位于 `~/.exam_agent/config.json`：

```json
{
  "server_url": "http://192.168.1.100:3000"
}
```

### 5.5 客户端日志

- 日志目录：`~/.exam_agent/logs/`
- 日志文件：`agent_YYYYMMDD.log`
- 成绩备份：`~/.exam_agent/logs/score_backup_*.json`（网络故障时自动保存）

---

## 6. 自动化打包指南

使用 `install.sh` 脚本自动打包客户端和服务端，用于分发部署。

### 6.1 打包客户端 Agent

```bash
# 打包客户端（生成可执行文件）
bash install.sh --package-client

# 打包产物
dist/
├── exam_agent          # Linux 可执行文件
└── README.txt          # 使用说明
```

### 8.2 打包服务端

```bash
# 打包服务端（生成部署包）
bash install.sh --package-server

# 打包产物
dist/
└── linux-exam-server/
    ├── deploy.sh       # 服务端部署脚本
    ├── README.txt      # 部署说明
    └── ...             # 服务端文件
```

### 8.3 打包全部（客户端 + 服务端）

```bash
# 打包全部用于分发
bash install.sh --package-all

# 打包产物
dist/
├── release/
│   ├── exam_agent              # 客户端可执行文件
│   ├── linux-exam-server/      # 服务端部署目录
│   └── RELEASE_NOTES.txt       # 分发说明
└── linux-exam-system_v1.0.0_YYYYMMDD_HHMMSS.tar.gz  # 最终分发包
```

### 8.4 制作分发包

```bash
# 客户端分发包
cd dist
tar -czf exam_agent_v1.0.0_kylin_x64.tar.gz exam_agent README.txt

# 服务端分发包
tar -czf linux-exam-server_v1.0.0.tar.gz linux-exam-server

# 完整分发包（使用 --package-all 后）
tar -czf linux-exam-system_v1.0.0_$(date +%Y%m%d_%H%M%S).tar.gz -C dist release
```

### 8.5 分发方式

**客户端 Agent 分发**：
- 共享网络目录
- USB 拷贝
- SSH 批量部署：
  ```bash
  for host in 192.168.1.{101..150}; do
    scp exam_agent.tar.gz user@$host:/tmp/
  done
  ```

**服务端分发**：
- 上传 `linux-exam-server` 目录到服务器
- 执行 `sudo bash deploy.sh` 完成部署

---

## 8. PyInstaller 手动打包指南

### 8.1 环境准备（在麒麟系统上打包）

```bash
# 安装 Python 依赖
pip3 install pyinstaller requests

# 进入 client_agent 目录
cd client_agent
```

### 8.2 执行打包

```bash
# 方法一：使用 spec 文件（推荐）
pyinstaller exam_agent.spec

# 方法二：命令行直接打包
pyinstaller \
    --onefile \
    --console \
    --name exam_agent \
    --hidden-import requests \
    --hidden-import urllib3 \
    exam_agent.py
```

### 8.3 打包产物

```
dist/
└── exam_agent          # Linux 可执行文件（约 8-15MB）
```

### 8.4 验证打包结果

```bash
# 测试可执行文件
./dist/exam_agent --version
./dist/exam_agent --test-connection

# 检查依赖（应无外部 .so 依赖）
ldd dist/exam_agent
```

### 8.5 分发方案

```bash
# 创建分发包
mkdir -p release
cp dist/exam_agent release/
cp README_CLIENT.md release/

# 打包
tar -czf exam_agent_v1.0.0_kylin_x64.tar.gz -C release .

# 分发到各客户端
# 方法1: 通过共享网络目录
# 方法2: 通过 USB 拷贝
# 方法3: 通过 SSH 批量部署
for host in 192.168.1.{101..150}; do
    scp exam_agent_v1.0.0_kylin_x64.tar.gz user@$host:/tmp/ &
done
wait
```

---

## 8. 评分规则配置指南

### 8.1 配置流程

```
管理员登录 → 评分规则页面 → 新建规则 → 添加检查项 → 查看生成脚本
```

### 8.2 检查项类型说明

| 类型 | 说明 | 示例 |
|------|------|------|
| `file_exists` | 检查文件/目录是否存在（存在则扣分） | 检查数据库软件目录是否已卸载 |
| `file_not_exists` | 检查文件/目录是否不存在（不存在则扣分） | 检查必要文件是否已创建 |
| `command_output` | 执行命令并检查输出 | 检查数据库名称、字符集配置 |
| `db_query` | 执行 SQL 文件并检查结果 | 检查表、视图、存储过程是否存在 |
| `custom_script` | 执行自定义 Shell 脚本 | 复杂的多步骤检查逻辑 |

### 8.3 SQL 检查文件规范

数据库查询检查依赖预置的 SQL 文件，存放在 `/var/local/sc/` 目录：

```bash
# 创建 SQL 文件目录
sudo mkdir -p /var/local/sc
sudo chmod 755 /var/local/sc

# 示例：检查数据库名称
cat > /var/local/sc/rw_dbname.sql << 'EOF'
SELECT NAME FROM V$DATABASE;
EOF

# 示例：检查表是否存在
cat > /var/local/sc/rw_table_exists.sql << 'EOF'
SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = 'EXAM_ADMIN';
EOF
```

### 8.4 用户名占位符

在检查目标中使用 `{{username}}` 占位符，系统会自动替换为当前学生的系统用户名：

```bash
# 示例：检查以用户名命名的用户是否在数据库中创建
SQL文件路径: /var/local/sc/rw_user_{{username}}.sql
```

---

## 9. 系统运维与故障排查

### 9.1 常见问题

**问题1：客户端认证失败**
```
原因：学生账号未在系统中注册，或设备ID不匹配
解决：管理员在"学生管理"页面添加学生信息，确保用户名与系统用户名一致
```

**问题2：评分脚本执行超时**
```
原因：数据库查询耗时过长，或脚本中存在死循环
解决：检查 DM8 服务状态，优化 SQL 查询，调整超时时间（默认300秒）
```

**问题3：成绩上传失败**
```
原因：网络中断或服务器异常
解决：成绩已自动备份到 ~/.exam_agent/logs/score_backup_*.json
      管理员可手动录入备份文件中的成绩
```

**问题4：DM8 连接失败**
```
原因：DM8 服务未启动，或端口被防火墙拦截
解决：
  systemctl start DmServiceDMSERVER
  firewall-cmd --add-port=5236/tcp --permanent
  firewall-cmd --reload
```

### 9.2 日志查看

```bash
# 服务端日志
journalctl -u linux-exam -f

# 客户端 Agent 日志
tail -f ~/.exam_agent/logs/agent_$(date +%Y%m%d).log

# 查看所有成绩备份
ls -la ~/.exam_agent/logs/score_backup_*.json
```

### 9.3 防火墙配置

```bash
# 麒麟系统（基于 firewalld）
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --add-port=5236/tcp --permanent  # DM8
sudo firewall-cmd --reload

# 验证
sudo firewall-cmd --list-ports
```

### 9.4 性能调优

```bash
# Node.js 内存限制（大型考试场景）
# 修改 /etc/systemd/system/linux-exam.service
ExecStart=/usr/bin/node --max-old-space-size=2048 dist/index.js

# DM8 连接池配置（server/db.ts）
# 修改 connectionLimit 参数
```

---

## 附录：快速部署检查清单

- [ ] 服务器 Node.js 18+ 已安装
- [ ] pnpm 已安装
- [ ] 数据库（MySQL/DM8）已启动并可连接
- [ ] `.env` 文件已正确配置
- [ ] `pnpm install && pnpm build` 执行成功
- [ ] systemd 服务已启动
- [ ] 防火墙端口 3000 已开放
- [ ] 管理员账号已设置
- [ ] 至少一名学生账号已创建
- [ ] 至少一道题目已添加
- [ ] 评分规则已配置
- [ ] 考试场次已创建
- [ ] 客户端 Agent 已分发到所有考试机
- [ ] 客户端服务器地址已配置
- [ ] 网络连通性测试通过（`exam_agent --test-connection`）
