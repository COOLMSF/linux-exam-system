# 生产环境部署指南

## 前置条件

| 要求 | 最低版本 | 推荐 |
|------|---------|------|
| 操作系统 | Ubuntu 18.04 / 麒麟 V10 SP1 | Ubuntu 22.04 |
| CPU | 2 核 | 4 核 |
| 内存 | 2 GB | 4 GB |
| 磁盘 | 20 GB | 50 GB |
| Node.js | 18.x | 20.x LTS |
| MySQL | 8.0 | 8.0 |
| Python | 3.8 | 3.12 |

---

## 一键安装（推荐）

```bash
# 克隆或上传项目到服务器
git clone <repo> /home/ubuntu/linux-exam-system
cd /home/ubuntu/linux-exam-system

# 一键安装（自动处理依赖、数据库、systemd 服务）
sudo bash install.sh --easy-install
```

安装完成后终端会输出：
- 管理员账号和初始密码
- 服务访问地址
- 日志文件路径

---

## 手动部署步骤

### 1. 安装系统依赖

```bash
# Ubuntu / 麒麟（apt）
sudo apt update
sudo apt install -y nodejs npm mysql-server python3 python3-venv python3-pip

# 安装 pnpm
npm install -g pnpm

# 验证
node --version   # >= 18
mysql --version  # >= 8.0
python3 --version  # >= 3.8
```

### 2. 初始化数据库

```bash
# 使用 root 登录 MySQL
sudo mysql

-- 创建数据库和用户
CREATE DATABASE linux_exam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'exam_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';
GRANT ALL PRIVILEGES ON linux_exam.* TO 'exam_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. 配置环境变量

```bash
cp /home/ubuntu/linux-exam-system/.env.example /opt/linux-exam-system/.env
# 编辑 .env：
```

```ini
# /opt/linux-exam-system/.env
DATABASE_URL=mysql://exam_user:StrongPassword123!@localhost:3306/linux_exam
JWT_SECRET=随机生成的64字节字符串
PORT=3000
NODE_ENV=production
```

生成随机 JWT_SECRET：
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### 4. 编译项目

```bash
cd /home/ubuntu/linux-exam-system
pnpm install
pnpm build
```

### 5. 数据库迁移

```bash
DATABASE_URL="mysql://exam_user:密码@localhost:3306/linux_exam" pnpm db:push
```

### 6. 部署服务端文件

```bash
sudo mkdir -p /opt/linux-exam-system
sudo cp -r dist node_modules package.json /opt/linux-exam-system/
sudo cp score_a.sh score_b.sh /opt/linux-exam-system/
sudo cp .env /opt/linux-exam-system/.env
sudo chmod 600 /opt/linux-exam-system/.env
```

### 7. 配置 systemd 服务

```bash
sudo cat > /etc/systemd/system/linux-exam.service << 'EOF'
[Unit]
Description=Linux Exam System
After=network.target mysql.service
Requires=mysql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/linux-exam-system
EnvironmentFile=/opt/linux-exam-system/.env
ExecStart=/usr/bin/node /opt/linux-exam-system/dist/index.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable linux-exam
sudo systemctl start linux-exam
```

### 8. 创建管理员账号

```bash
# 使用安装脚本重置管理员密码
sudo bash /home/ubuntu/linux-exam-system/install.sh --reset-db
```

---

## 验证部署

```bash
# 检查服务状态
systemctl status linux-exam

# 检查端口
ss -tlnp | grep 3000

# 测试 API
curl -s http://localhost:3000/api/trpc/auth.me

# 运行对接测试
python3 /home/ubuntu/linux-exam-system/test_client_server.py
```

---

## 更新部署

```bash
cd /home/ubuntu/linux-exam-system

# 拉取新版本
git pull

# 重新编译
pnpm install
pnpm build

# 更新服务端文件
sudo cp dist/index.js /opt/linux-exam-system/dist/
sudo cp score_a.sh score_b.sh /opt/linux-exam-system/

# 重启服务
sudo systemctl restart linux-exam

# 验证
systemctl status linux-exam
curl -s http://localhost:3000/api/trpc/auth.me
```

---

## 环境变量参考

| 变量 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `DATABASE_URL` | ✓ | MySQL 连接字符串（密码需 URL 编码） | `mysql://user:pass@localhost:3306/linux_exam` |
| `JWT_SECRET` | ✓ | JWT 签名密钥（≥ 32 字节随机字符串） | `abc123...` |
| `PORT` | — | 服务监听端口（默认 3000） | `3000` |
| `NODE_ENV` | — | 运行环境（`production` 关闭调试日志） | `production` |

> **密码 URL 编码**：若密码含特殊字符（如 `@#!`），需编码后写入：
> ```bash
> python3 -c "from urllib.parse import quote; print(quote('P@ss!word', safe=''))"
> # 输出：P%40ss%21word
> ```

---

## 反向代理（Nginx，可选）

```nginx
# /etc/nginx/sites-available/linux-exam
server {
    listen 80;
    server_name exam.example.com;

    # 强制 HTTPS（推荐）
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name exam.example.com;

    ssl_certificate     /etc/ssl/certs/exam.crt;
    ssl_certificate_key /etc/ssl/private/exam.key;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/linux-exam /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## 防火墙

```bash
# 仅开放 Web 端口（若不使用 Nginx，开放 3000）
sudo ufw allow 3000/tcp    # 直接访问
sudo ufw allow 80/tcp      # HTTP（Nginx）
sudo ufw allow 443/tcp     # HTTPS（Nginx）
sudo ufw enable
```

---

## 日志管理

```bash
# 查看实时日志
journalctl -u linux-exam -f

# 查看最近 100 条
journalctl -u linux-exam -n 100

# 安装日志（install.sh 输出）
tail -f /var/log/linux-exam-install.log
```

---

## 常见问题

**服务启动失败：`DATABASE_URL` 相关错误**

```bash
# 检查 .env 文件权限和内容
sudo cat /opt/linux-exam-system/.env
# 测试数据库连接
mysql -u exam_user -p linux_exam -e "SELECT 1"
```

**管理员无法登录**

```bash
# 重置管理员密码
sudo bash /home/ubuntu/linux-exam-system/install.sh --reset-db
```

**客户端 Agent 连接服务端失败**

```bash
# 检查防火墙
sudo ufw status
# 检查服务是否运行
systemctl status linux-exam
# 直接测试
curl http://服务器IP:3000/api/trpc/auth.me
```

**端口 3000 被占用**

```bash
# 找出占用进程
sudo ss -tlnp | grep 3000
# 修改端口（在 .env 中设置）
echo "PORT=3001" >> /opt/linux-exam-system/.env
sudo systemctl restart linux-exam
```
