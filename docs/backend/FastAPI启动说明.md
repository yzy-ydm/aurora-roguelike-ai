# FastAPI 后端启动说明

> Aurora-Roguelike-AI 项目后端服务启动指南

## 📋 目录

- [环境要求](#环境要求)
- [安装步骤](#安装步骤)
- [配置说明](#配置说明)
- [启动服务](#启动服务)
- [API文档](#api文档)
- [健康检查](#健康检查)
- [常见问题](#常见问题)

---

## 环境要求

| 软件 | 版本 | 说明 |
|------|------|------|
| Python | 3.12+ | 推荐使用3.12.x |
| MySQL | 8.0 | 数据库服务 |
| pip | 最新 | Python包管理器 |

---

## 安装步骤

### 1. 创建虚拟环境

```bash
# 进入server目录
cd D:\GraduationProject\server

# 创建虚拟环境
python -m venv venv
```

### 2. 激活虚拟环境

**Windows (CMD/PowerShell):**
```bash
# CMD
venv\Scripts\activate.bat

# PowerShell
venv\Scripts\Activate.ps1
```

**Windows (Git Bash):**
```bash
source venv/Scripts/activate
```

**Linux/Mac:**
```bash
source venv/bin/activate
```

激活后命令行前缀会显示 `(venv)`。

### 3. 安装依赖

```bash
pip install -r requirements.txt
```

### 4. 配置环境变量

```bash
# 复制环境变量示例文件
cp .env.example .env

# 编辑 .env 文件，配置数据库连接信息
```

---

## 配置说明

### .env 文件配置

编辑 `server/.env` 文件，配置以下参数：

```env
# 数据库配置
MYSQL_HOST=localhost          # MySQL主机地址
MYSQL_PORT=3306               # MySQL端口
MYSQL_USER=root               # MySQL用户名
MYSQL_PASSWORD=your_password  # MySQL密码（修改为实际密码）
MYSQL_DATABASE=aurora_game    # 数据库名称

# 应用配置
APP_ENV=development           # 运行环境
DEBUG=True                    # 调试模式
APP_PORT=8000                 # 服务端口
```

### 重要提示

⚠️ **请确保：**

1. MySQL服务已启动
2. `aurora_game` 数据库已创建
3. 数据表已初始化（执行 `database/sql/create_tables.sql`）
4. `.env` 文件中的密码正确

---

## 启动服务

### 方式一：直接运行 main.py

```bash
# 确保在 server 目录下，且虚拟环境已激活
python main.py
```

### 方式二：使用 uvicorn 命令

```bash
# 基本启动
uvicorn main:app --host 0.0.0.0 --port 8000

# 开发模式（自动重载）
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 启动成功标志

```
==================================================
Roguelike游戏系统API服务启动中...
==================================================
API文档地址: http://localhost:8000/docs
ReDoc文档地址: http://localhost:8000/redoc
==================================================
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

---

## API文档

启动服务后，可以通过以下地址访问API文档：

| 文档类型 | 地址 | 说明 |
|----------|------|------|
| Swagger UI | http://localhost:8000/docs | 交互式API文档，支持在线测试 |
| ReDoc | http://localhost:8000/redoc | 更美观的API文档 |
| OpenAPI JSON | http://localhost:8000/openapi.json | OpenAPI规范文件 |

---

## 健康检查

### 接口信息

- **URL:** `GET /health`
- **功能:** 检查系统和数据库连接状态

### 响应示例

**连接成功:**
```json
{
    "status": "ok",
    "database": "connected",
    "database_info": {
        "name": "aurora_game",
        "version": "8.0.36"
    }
}
```

**连接失败:**
```json
{
    "status": "error",
    "database": "disconnected",
    "error": "(pymysql.err.OperationalError) (2003, \"Can't connect to MySQL server...\")"
}
```

### 测试方法

```bash
# 使用 curl
curl http://localhost:8000/health

# 使用 PowerShell
Invoke-WebRequest -Uri http://localhost:8000/health -Method GET

# 直接在浏览器访问
http://localhost:8000/health
```

---

## 项目结构

```
server/
├── main.py                    # 应用入口
├── requirements.txt           # Python依赖
├── .env                       # 环境变量（不提交Git）
├── .env.example               # 环境变量示例
└── app/
    ├── __init__.py
    ├── database/              # 数据库连接模块
    │   ├── __init__.py
    │   └── connection.py      # 数据库连接配置
    ├── api/                   # API路由（待开发）
    ├── models/                # 数据模型（待开发）
    ├── schemas/               # Pydantic模式（待开发）
    ├── services/              # 业务逻辑（待开发）
    ├── core/                  # 核心配置（待开发）
    └── utils/                 # 工具函数（待开发）
```

---

## 常见问题

### 1. 启动报错：ModuleNotFoundError

**错误信息:**
```
ModuleNotFoundError: No module named 'app'
```

**解决方案:**
确保在 `server` 目录下运行命令，且虚拟环境已激活。

---

### 2. 数据库连接失败

**错误信息:**
```
(pymysql.err.OperationalError) (2003, "Can't connect to MySQL server on 'localhost'")
```

**解决方案:**
1. 检查MySQL服务是否启动
2. 检查 `.env` 中的数据库配置是否正确
3. 检查MySQL端口是否为3306
4. 检查防火墙是否阻止连接

---

### 3. 认证失败

**错误信息:**
```
(pymysql.err.OperationalError) (1045, "Access denied for user 'root'@'localhost'")
```

**解决方案:**
1. 检查 `.env` 中的用户名和密码是否正确
2. 确认MySQL用户有访问 `aurora_game` 数据库的权限

---

### 4. 数据库不存在

**错误信息:**
```
(pymysql.err.ProgrammingError) (1049, "Unknown database 'aurora_game'")
```

**解决方案:**
```sql
-- 登录MySQL后执行
CREATE DATABASE aurora_game CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

### 5. 端口被占用

**错误信息:**
```
OSError: [Errno 98] Address already in use
```

**解决方案:**
```bash
# 查看占用端口的进程
netstat -ano | findstr :8000

# 终止进程或修改 .env 中的 APP_PORT
```

---

## 开发模式说明

当前阶段已完成：

- [x] FastAPI应用初始化
- [x] CORS跨域配置
- [x] 数据库连接模块
- [x] 健康检查接口

待开发模块：

- [ ] 用户认证模块 (api/auth)
- [ ] 用户管理模块 (api/user)
- [ ] 游戏数据模块 (api/game)
- [ ] AI生成模块 (api/ai)
- [ ] 数据模型 (models)
- [ ] Pydantic模式 (schemas)
- [ ] 业务逻辑层 (services)

---

## 📝 更新记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-07-13 | v1.0 | 初始版本，完成数据库连接层 |
