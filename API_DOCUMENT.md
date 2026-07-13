# API_DOCUMENT.md

> Aurora-Roguelike-AI API接口文档

最后更新：2026-07-13

---

## API总览

| 模块 | 接口数量 | 状态 |
|------|----------|------|
| 系统接口 | 2 | ✅ 已完成 |
| 认证接口 | 2 | ✅ 已完成 |
| 玩家接口 | 0 | ⬜ 待开发 |
| 武器接口 | 0 | ⬜ 待开发 |
| 怪物接口 | 0 | ⬜ 待开发 |

**Base URL:** `http://localhost:8000`

---

## 系统接口

### 1. 健康检查

**接口:** `GET /health`

**功能:** 检查系统和数据库连接状态

**认证:** 不需要

**请求参数:** 无

**响应示例:**

成功：
```json
{
    "status": "ok",
    "database": "connected",
    "database_info": {
        "name": "aurora_game",
        "version": "8.0.45"
    }
}
```

失败：
```json
{
    "status": "error",
    "database": "disconnected",
    "error": "连接失败原因"
}
```

**状态码:**
- 200: 成功

---

### 2. 根路径

**接口:** `GET /`

**功能:** 系统信息

**认证:** 不需要

**响应示例:**
```json
{
    "code": 200,
    "message": "Roguelike游戏系统API服务运行中",
    "version": "1.0.0"
}
```

---

## 认证接口

### 3. 用户注册

**接口:** `POST /api/auth/register`

**功能:** 创建新用户账号

**认证:** 不需要

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名（3-50字符，字母数字下划线） |
| password | string | 是 | 密码（8-100字符） |
| email | string | 否 | 邮箱地址 |

**请求示例:**
```json
{
    "username": "player1",
    "password": "password123",
    "email": "player1@example.com"
}
```

**响应示例:**

成功（201）：
```json
{
    "code": 201,
    "message": "注册成功"
}
```

失败（400）：
```json
{
    "detail": "用户名已存在"
}
```

**状态码:**
- 201: 注册成功
- 400: 用户名或邮箱已存在
- 422: 请求数据验证失败

---

### 4. 用户登录

**接口:** `POST /api/auth/login`

**功能:** 用户登录，获取JWT Token

**认证:** 不需要

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名 |
| password | string | 是 | 密码 |

**请求示例:**
```json
{
    "username": "player1",
    "password": "password123"
}
```

**响应示例:**

成功（200）：
```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "user": {
        "id": 1,
        "username": "player1",
        "email": "player1@example.com",
        "is_active": true,
        "created_at": "2026-07-13T00:00:00"
    }
}
```

失败（401）：
```json
{
    "detail": "用户名或密码错误"
}
```

**状态码:**
- 200: 登录成功
- 401: 用户名或密码错误
- 403: 账号已被禁用
- 422: 请求数据验证失败

---

## 待开发接口

### 玩家接口（Phase 4.3）

| 接口 | 方法 | 功能 |
|------|------|------|
| /api/player/profile | POST | 创建角色 |
| /api/player/profile | GET | 查询角色 |
| /api/player/profile | PUT | 更新角色 |

### 武器接口（Phase 4.4）

| 接口 | 方法 | 功能 |
|------|------|------|
| /api/weapons | GET | 武器列表 |
| /api/weapons/{id} | GET | 武器详情 |

### 怪物接口（Phase 4.5）

| 接口 | 方法 | 功能 |
|------|------|------|
| /api/monsters | GET | 怪物列表 |
| /api/monsters/{id} | GET | 怪物详情 |

---

## 认证说明

### JWT Token使用

登录成功后获取Token，后续请求需要在Header中携带：

```
Authorization: Bearer <token>
```

### Token信息

- 算法：HS256
- 有效期：24小时
- 载荷：用户ID、用户名

---

## 错误码说明

| 错误码 | 说明 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 未认证或Token无效 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 422 | 数据验证失败 |
| 500 | 服务器内部错误 |

---

## 测试说明

### Swagger文档

启动服务后访问：`http://localhost:8000/docs`

可在Swagger界面中直接测试所有接口。

### curl测试示例

```bash
# 健康检查
curl http://localhost:8000/health

# 用户注册
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123456"}'

# 用户登录
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123456"}'
```
