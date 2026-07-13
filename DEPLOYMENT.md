# DEPLOYMENT.md

> Aurora-Roguelike-AI 部署说明文档

最后更新：2026-07-13

---

## 开发环境

### 系统要求

| 软件 | 版本 | 说明 |
|------|------|------|
| Windows | 10/11 | 操作系统 |
| Python | 3.12+ | 后端语言 |
| MySQL | 8.0 | 数据库 |
| Godot | 4.x | 游戏引擎 |
| Git | 最新 | 版本控制 |

### 工具推荐

| 工具 | 用途 |
|------|------|
| VS Code | 代码编辑器 |
| Navicat | 数据库管理 |
| Postman | API测试 |
| GitHub Desktop | Git图形界面 |

---

## 后端部署

### 1. 环境准备

**安装Python 3.12:**
1. 下载：https://www.python.org/downloads/
2. 安装时勾选 "Add Python to PATH"
3. 验证：`python --version`

**安装MySQL 8.0:**
1. 下载：https://dev.mysql.com/downloads/mysql/
2. 安装并设置root密码
3. 验证：`mysql --version`

### 2. 项目配置

```bash
# 克隆项目
git clone https://github.com/yzy-ydm/aurora-roguelike-ai.git
cd aurora-roguelike-ai

# 进入服务端目录
cd server

# 创建虚拟环境
python -m venv venv

# 激活虚拟环境
# Windows CMD:
venv\Scripts\activate.bat
# Windows PowerShell:
venv\Scripts\Activate.ps1
# Linux/Mac:
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

### 3. 数据库配置

```bash
# 登录MySQL
mysql -u root -p

# 创建数据库（如果需要）
CREATE DATABASE aurora_game CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 退出MySQL
exit

# 导入表结构
mysql -u root -p aurora_game < database/sql/create_tables.sql

# 导入测试数据（可选）
mysql -u root -p aurora_game < database/sql/insert_test_data.sql
```

### 4. 环境变量配置

```bash
# 复制环境变量示例
cp .env.example .env

# 编辑 .env 文件
# 修改数据库密码为你的实际密码
```

**.env 文件内容：**
```env
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=你的密码
MYSQL_DATABASE=aurora_game
JWT_SECRET_KEY=your-secret-key
```

### 5. 启动服务

```bash
# 确保虚拟环境已激活
python main.py
```

**启动成功标志：**
```
==================================================
Roguelike游戏系统API服务启动中...
==================================================
API文档地址: http://localhost:8000/docs
ReDoc文档地址: http://localhost:8000/redoc
==================================================
```

### 6. 验证服务

```bash
# 访问健康检查
curl http://localhost:8000/health

# 访问API文档
# 浏览器打开: http://localhost:8000/docs
```

---

## 客户端部署（待开发）

### Godot项目

1. 下载Godot 4.x：https://godotengine.org/download
2. 打开Godot，导入 `client/` 目录
3. 运行项目

---

## 常见问题

### 1. Python不是内部命令

**原因：** Python未添加到PATH

**解决：**
1. 重新安装Python，勾选 "Add Python to PATH"
2. 或手动添加Python到系统环境变量

### 2. MySQL连接失败

**原因：** 密码错误或MySQL未启动

**解决：**
1. 检查MySQL服务是否启动
2. 检查 `.env` 中的密码是否正确
3. 检查数据库是否存在

### 3. 依赖安装失败

**原因：** 网络问题

**解决：**
```bash
# 使用国内镜像
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 4. 端口被占用

**原因：** 8000端口已被其他程序使用

**解决：**
1. 关闭占用端口的程序
2. 或修改端口：`uvicorn main:app --port 8001`

---

## 生产环境部署（未来规划）

### Docker部署（计划）

```yaml
# docker-compose.yml
version: '3.8'

services:
  server:
    build: ./server
    ports:
      - "8000:8000"
    environment:
      - MYSQL_HOST=db
      - MYSQL_PASSWORD=password
    depends_on:
      - db

  db:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=password
      - MYSQL_DATABASE=aurora_game
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

### 云服务器部署（计划）

1. 购买云服务器（阿里云/腾讯云）
2. 安装Docker
3. 使用Docker Compose部署
4. 配置Nginx反向代理
5. 配置HTTPS证书

---

## 监控与日志

### 日志位置

- 应用日志：`server/logs/app.log`
- 错误日志：`server/logs/error.log`

### 健康检查

```bash
# 检查服务状态
curl http://localhost:8000/health
```

---

## 备份策略

### 数据库备份

```bash
# 备份数据库
mysqldump -u root -p aurora_game > backup_$(date +%Y%m%d).sql

# 恢复数据库
mysql -u root -p aurora_game < backup_20260713.sql
```

### 定期备份

建议：
- 每日自动备份数据库
- 每周备份完整项目
- 重要变更前手动备份
