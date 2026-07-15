# Aurora-Roguelike-AI 云端部署文档

## 1. 服务器环境要求

### 1.1 硬件要求
- **CPU**: 2核心以上
- **内存**: 4GB以上
- **存储**: 20GB以上
- **网络**: 公网IP，开放8001端口

### 1.2 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / Windows Server 2019+
- **Python**: 3.9+
- **pip**: 最新版本

## 2. 依赖安装

### 2.1 创建虚拟环境

```bash
cd server/ai
python -m venv venv

# Linux/Mac
source venv/bin/activate

# Windows
venv\Scripts\activate
```

### 2.2 安装依赖

```bash
pip install -r requirements.txt
```

### 2.3 requirements.txt 内容

```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
python-multipart==0.0.6
aiohttp==3.9.1
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
```

## 3. 数据库初始化

### 3.1 SQLite数据库

数据库会在首次启动时自动创建，无需手动初始化。

数据库文件位置：`server/ai/data/aurora.db`

### 3.2 数据库表结构

| 表名 | 说明 |
|------|------|
| users | 用户表 |
| ai_requests | AI请求记录表 |
| player_profiles | 玩家数据表 |
| ai_generation_history | AI生成历史表 |

## 4. 配置说明

### 4.1 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| AI_API_KEY | API密钥 | aurora-roguelike-ai-key-2024 |
| AI_ADMIN_KEY | 管理员密钥 | admin-secret-key-2024 |
| AI_AUTH_ENABLED | 是否启用认证 | true |
| LLM_PROVIDER | AI提供者 | mock |

### 4.2 配置文件

配置文件位于 `server/ai/config/` 目录下。

## 5. 启动流程

### 5.1 开发环境启动

```bash
cd server/ai
python main.py
```

### 5.2 生产环境启动

```bash
cd server/ai
uvicorn main:app --host 0.0.0.0 --port 8001 --workers 4
```

### 5.3 使用systemd服务（Linux）

创建服务文件 `/etc/systemd/system/aurora-ai.service`:

```ini
[Unit]
Description=Aurora-Roguelike-AI Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/server/ai
Environment="PATH=/path/to/server/ai/venv/bin"
ExecStart=/path/to/server/ai/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable aurora-ai
sudo systemctl start aurora-ai
sudo systemctl status aurora-ai
```

## 6. API说明

### 6.1 认证接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/auth/token | 获取API Token |

### 6.2 AI生成接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/generate/floor | 生成楼层内容 |
| POST | /api/generate/room | 生成房间内容 |
| POST | /api/generate/monster | 生成怪物配置 |
| POST | /api/generate/weapon | 生成武器配置 |
| POST | /api/generate/event | 生成房间事件 |
| POST | /api/generate/dialogue | 生成NPC对话 |
| POST | /api/generate/upgrade | 生成升级强化选项 |
| POST | /api/generate/difficulty | 生成难度调整建议 |
| POST | /api/generate/room_strategy | 生成房间策略建议 |
| POST | /api/generate/npc_memory | 生成NPC记忆响应 |
| POST | /api/generate/context_event | 生成上下文事件 |

### 6.3 系统接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /health | 健康检查 |
| GET | /api/info | API信息 |
| GET | /api/stats | 服务统计 |
| GET | /api/rate-limit/status | 限流状态 |
| GET | /api/requests/recent | 最近请求记录 |

### 6.4 认证方式

所有AI生成接口需要在请求头中携带Token：

```
Authorization: Bearer <token>
```

### 6.5 限流说明

| 接口类型 | 限制 |
|----------|------|
| 普通接口 | 60 requests/min |
| AI接口 | 10 requests/min |

## 7. 监控和日志

### 7.1 日志文件

日志文件位于 `server/ai/logs/` 目录下：

- `ai_service_YYYY-MM-DD.log` - 普通日志
- `ai_service_error_YYYY-MM-DD.log` - 错误日志

### 7.2 性能测试

使用性能测试工具：

```bash
cd server/tools
pip install aiohttp
python ai_benchmark.py
```

测试报告将保存在 `server/reports/` 目录下。

## 8. 安全建议

### 8.1 生产环境配置

1. 修改默认API密钥
2. 启用HTTPS
3. 配置防火墙
4. 限制CORS源
5. 定期备份数据库

### 8.2 HTTPS配置

使用Nginx反向代理：

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 9. 故障排除

### 9.1 常见问题

| 问题 | 解决方案 |
|------|----------|
| 端口被占用 | 修改main.py中的端口号 |
| 数据库锁定 | 检查是否有其他进程占用数据库文件 |
| 内存不足 | 减少缓存大小或增加服务器内存 |

### 9.2 日志查看

```bash
# 查看实时日志
tail -f server/ai/logs/ai_service_$(date +%Y-%m-%d).log

# 查看错误日志
tail -f server/ai/logs/ai_service_error_$(date +%Y-%m-%d).log
```

## 10. 更新和维护

### 10.1 更新代码

```bash
cd /path/to/project
git pull origin main

cd server/ai
pip install -r requirements.txt

sudo systemctl restart aurora-ai
```

### 10.2 数据库维护

```bash
# 清理30天前的旧记录
python -c "from database.db_manager import db_manager; print(db_manager.cleanup_old_records(30))"
```
