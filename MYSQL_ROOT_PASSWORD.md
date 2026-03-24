# MySQL Root 密码配置说明

## 问题原因

`install.sh` 在初始化数据库时需要 MySQL root 权限，但默认情况下无法获取 root 密码。

## 解决方案

### 方式 1：使用配置文件（推荐）

将 MySQL root 密码保存到项目根目录的 `.mysql_root_pass` 文件：

```bash
echo "YourRootPassword" > /root/linux_exam_system/.mysql_root_pass
chmod 600 /root/linux_exam_system/.mysql_root_pass
```

**优点**：
- 一次配置，永久使用
- 不影响其他脚本
- 权限设置为 600，保证安全

### 方式 2：使用环境变量

```bash
export MYSQL_ROOT_PASSWORD="YourRootPassword"
bash install.sh --demo-exam
```

**优点**：
- 不保存密码到文件
- 适合临时使用

**缺点**：
- 每次运行都需要设置

### 方式 3：命令行指定

```bash
MYSQL_ROOT_PASSWORD="YourRootPassword" bash install.sh --demo-exam
```

## 当前配置

已创建配置文件：
```
文件：/root/linux_exam_system/.mysql_root_pass
密码：Exam#Pass1234
权限：600（仅 root 可读）
```

## 验证配置

```bash
# 测试数据库连接
mysql -u root -p'Exam#Pass1234' -e "SELECT '连接成功' AS status;"

# 或测试 install.sh
bash install.sh --test-score
```

## 安全提示

1. **保护密码文件**
   ```bash
   chmod 600 /root/linux_exam_system/.mysql_root_pass
   ```

2. **不要提交到版本控制**
   ```bash
   # .gitignore 已包含
   .mysql_root_pass
   ```

3. **定期更换密码**
   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'NewPassword123!';
   ```

4. **限制访问权限**
   ```bash
   # 仅 root 用户可访问
   chown root:root /root/linux_exam_system/.mysql_root_pass
   ```

## 故障排查

### Q1: Access denied for user 'root'@'localhost'

**解决**：
```bash
# 检查密码文件
cat /root/linux_exam_system/.mysql_root_pass

# 或设置环境变量
export MYSQL_ROOT_PASSWORD="YourPassword"
```

### Q2: KYSEC: Permission denied

**解决**：
```bash
# 使用 root 权限运行
sudo bash install.sh

# 或临时禁用 KYSEC（不推荐）
```

### Q3: 密码文件不存在

**解决**：
```bash
# 创建密码文件
echo "YourPassword" > /root/linux_exam_system/.mysql_root_pass
chmod 600 /root/linux_exam_system/.mysql_root_pass
```

## 完整安装流程

```bash
# 1. 配置 MySQL root 密码
echo "YourPassword" > /root/linux_exam_system/.mysql_root_pass
chmod 600 /root/linux_exam_system/.mysql_root_pass

# 2. 运行安装脚本
bash install.sh --demo-exam

# 3. 验证安装
bash install.sh --test-score
```

## 相关文件

| 文件 | 说明 | 权限 |
|------|------|------|
| `.mysql_root_pass` | MySQL root 密码 | 600 |
| `.env` | 应用配置（数据库连接） | 644 |
| `install.sh` | 安装脚本 | 755 |

## 更新日志

### v1.1 (2026-03-22)
- ✅ 新增 `.mysql_root_pass` 配置文件支持
- ✅ 新增 `MYSQL_ROOT_PASSWORD` 环境变量支持
- ✅ 优化错误提示信息
- ✅ 添加安全权限设置
