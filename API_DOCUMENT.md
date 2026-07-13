# API_DOCUMENT.md

> Aurora-Roguelike-AI API接口文档

最后更新：2026-07-13

---

## API总览

| 模块 | 接口数量 | 状态 |
|------|----------|------|
| 系统接口 | 2 | ✅ 已完成 |
| 认证接口 | 2 | ✅ 已完成 |
| 玩家接口 | 3 | ✅ 已完成 |
| 武器接口 | 4 | ✅ 已完成 |
| 怪物接口 | 2 | ✅ 已完成 |
| 存档接口 | 4 | ✅ 已完成 |

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

## 玩家接口

### 5. 创建玩家角色

**接口:** `POST /api/player/profile`

**功能:** 为当前登录用户创建游戏角色

**认证:** 需要JWT Token

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| nickname | string | 是 | 角色昵称（2-50字符） |

**请求示例:**
```json
{
    "nickname": "勇敢的冒险者"
}
```

**响应示例:**

成功（201）：
```json
{
    "id": 1,
    "user_id": 1,
    "nickname": "勇敢的冒险者",
    "level": 1,
    "experience": 0,
    "health": 100,
    "max_health": 100,
    "attack": 10,
    "defense": 5,
    "gold": 0
}
```

失败（409）：
```json
{
    "detail": "该用户已有角色档案"
}
```

**状态码:**
- 201: 创建成功
- 401: 未认证或Token无效
- 409: 角色已存在
- 422: 请求数据验证失败

---

### 6. 查询玩家角色信息

**接口:** `GET /api/player/profile`

**功能:** 获取当前登录用户的角色信息

**认证:** 需要JWT Token

**请求参数:** 无

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "user_id": 1,
    "nickname": "勇敢的冒险者",
    "level": 1,
    "experience": 0,
    "health": 100,
    "max_health": 100,
    "attack": 10,
    "defense": 5,
    "gold": 0
}
```

失败（404）：
```json
{
    "detail": "玩家角色不存在"
}
```

**状态码:**
- 200: 查询成功
- 401: 未认证或Token无效
- 404: 玩家角色不存在

---

### 7. 更新玩家角色信息

**接口:** `PUT /api/player/profile`

**功能:** 更新当前登录用户的角色信息（目前只允许修改昵称）

**认证:** 需要JWT Token

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| nickname | string | 否 | 新的角色昵称（2-50字符） |

**请求示例:**
```json
{
    "nickname": "传奇英雄"
}
```

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "user_id": 1,
    "nickname": "传奇英雄",
    "level": 1,
    "experience": 0,
    "health": 100,
    "max_health": 100,
    "attack": 10,
    "defense": 5,
    "gold": 0
}
```

**状态码:**
- 200: 更新成功
- 401: 未认证或Token无效
- 404: 玩家角色不存在
- 422: 请求数据验证失败

---

## 武器接口

### 8. 获取武器列表

**接口:** `GET /api/weapons`

**功能:** 获取所有基础武器数据

**认证:** 不需要

**请求参数:** 无

**响应示例:**

成功（200）：
```json
[
    {
        "id": 1,
        "name": "铁剑",
        "description": "一把普通的铁制长剑",
        "type": "sword",
        "rarity": "common",
        "damage": 5,
        "crit_rate_bonus": 0.0,
        "special_effect": null,
        "attributes": null,
        "icon_path": null,
        "price": 50
    }
]
```

**状态码:**
- 200: 成功

---

### 9. 获取武器详情

**接口:** `GET /api/weapons/{weapon_id}`

**功能:** 根据武器ID获取单个武器的详细信息

**认证:** 不需要

**路径参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| weapon_id | int | 是 | 武器ID |

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "name": "铁剑",
    "description": "一把普通的铁制长剑",
    "type": "sword",
    "rarity": "common",
    "damage": 5,
    "crit_rate_bonus": 0.0,
    "special_effect": null,
    "attributes": null,
    "icon_path": null,
    "price": 50
}
```

失败（404）：
```json
{
    "detail": "武器不存在"
}
```

**状态码:**
- 200: 成功
- 404: 武器不存在

---

### 10. 获取玩家武器

**接口:** `GET /api/player/weapons`

**功能:** 获取当前登录用户拥有的所有武器

**认证:** 需要JWT Token

**请求参数:** 无

**响应示例:**

成功（200）：
```json
[
    {
        "id": 1,
        "player_id": 1,
        "weapon_id": 1,
        "is_equipped": 0,
        "created_at": "2026-07-13T00:00:00",
        "weapon": {
            "id": 1,
            "name": "铁剑",
            "description": "一把普通的铁制长剑",
            "type": "sword",
            "rarity": "common",
            "damage": 5,
            "crit_rate_bonus": 0.0,
            "special_effect": null,
            "attributes": null,
            "icon_path": null,
            "price": 50
        }
    }
]
```

**状态码:**
- 200: 成功
- 401: 未认证或Token无效
- 404: 玩家角色不存在

---

### 11. 添加玩家武器

**接口:** `POST /api/player/weapons`

**功能:** 为当前登录用户添加一把武器

**认证:** 需要JWT Token

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| weapon_id | int | 是 | 武器ID |

**请求示例:**
```json
{
    "weapon_id": 1
}
```

**响应示例:**

成功（201）：
```json
{
    "id": 1,
    "player_id": 1,
    "weapon_id": 1,
    "is_equipped": 0,
    "created_at": "2026-07-13T00:00:00",
    "weapon": {
        "id": 1,
        "name": "铁剑",
        "description": "一把普通的铁制长剑",
        "type": "sword",
        "rarity": "common",
        "damage": 5,
        "crit_rate_bonus": 0.0,
        "special_effect": null,
        "attributes": null,
        "icon_path": null,
        "price": 50
    }
}
```

失败（404）：
```json
{
    "detail": "武器不存在"
}
```

**状态码:**
- 201: 添加成功
- 401: 未认证或Token无效
- 404: 玩家角色不存在或武器不存在
- 422: 请求数据验证失败

---

## 怪物接口

### 12. 获取怪物列表

**接口:** `GET /api/monsters`

**功能:** 获取所有怪物基础数据

**认证:** 不需要

**请求参数:** 无

**响应示例:**

成功（200）：
```json
[
    {
        "id": 1,
        "name": "史莱姆",
        "description": "最基础的怪物，由粘液构成，行动缓慢。",
        "type": "normal",
        "level": 1,
        "health": 20,
        "attack": 5,
        "defense": 2,
        "speed": 3,
        "experience_reward": 10,
        "gold_reward": 5,
        "special_ability": null,
        "attributes": null,
        "icon_path": null,
        "min_floor": 1,
        "max_floor": 10
    }
]
```

**状态码:**
- 200: 成功

---

### 13. 获取怪物详情

**接口:** `GET /api/monsters/{monster_id}`

**功能:** 根据怪物ID获取单个怪物的详细信息

**认证:** 不需要

**路径参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| monster_id | int | 是 | 怪物ID |

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "name": "史莱姆",
    "description": "最基础的怪物，由粘液构成，行动缓慢。",
    "type": "normal",
    "level": 1,
    "health": 20,
    "attack": 5,
    "defense": 2,
    "speed": 3,
    "experience_reward": 10,
    "gold_reward": 5,
    "special_ability": null,
    "attributes": null,
    "icon_path": null,
    "min_floor": 1,
    "max_floor": 10
}
```

失败（404）：
```json
{
    "detail": "怪物不存在"
}
```

**状态码:**
- 200: 成功
- 404: 怪物不存在

---

## 游戏存档接口

### 14. 创建游戏存档

**接口:** `POST /api/game/save`

**功能:** 为当前登录用户创建游戏存档

**认证:** 需要JWT Token

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| save_name | string | 是 | 存档名称（1-100字符） |
| slot_number | int | 是 | 存档槽位（1-3） |
| player_state | object | 是 | 玩家状态数据（JSON） |

**请求示例:**
```json
{
    "save_name": "第一次冒险",
    "slot_number": 1,
    "player_state": {
        "health": 100,
        "max_health": 100,
        "attack": 10,
        "defense": 5,
        "level": 1,
        "experience": 0,
        "gold": 0
    }
}
```

**响应示例:**

成功（201）：
```json
{
    "id": 1,
    "user_id": 1,
    "save_name": "第一次冒险",
    "current_floor": 1,
    "player_state": {...},
    "inventory_data": null,
    "current_map_data": null,
    "explored_maps": null,
    "play_time": 0,
    "kill_count": 0,
    "gold_collected": 0,
    "slot_number": 1,
    "is_active": 1,
    "created_at": "2026-07-13T00:00:00",
    "updated_at": "2026-07-13T00:00:00"
}
```

失败（409）：
```json
{
    "detail": "槽位1已有存档"
}
```

**状态码:**
- 201: 创建成功
- 401: 未认证或Token无效
- 409: 该槽位已有存档
- 422: 请求数据验证失败

---

### 15. 查询用户所有存档

**接口:** `GET /api/game/save`

**功能:** 获取当前登录用户的所有游戏存档

**认证:** 需要JWT Token

**请求参数:** 无

**响应示例:**

成功（200）：
```json
[
    {
        "id": 1,
        "user_id": 1,
        "save_name": "第一次冒险",
        "current_floor": 1,
        "player_state": {...},
        "slot_number": 1,
        "is_active": 1,
        "created_at": "2026-07-13T00:00:00",
        "updated_at": "2026-07-13T00:00:00"
    }
]
```

**状态码:**
- 200: 成功
- 401: 未认证或Token无效

---

### 16. 查询指定槽位存档

**接口:** `GET /api/game/save/{slot_number}`

**功能:** 获取当前登录用户指定槽位的游戏存档

**认证:** 需要JWT Token

**路径参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| slot_number | int | 是 | 存档槽位（1-3） |

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "user_id": 1,
    "save_name": "第一次冒险",
    "current_floor": 1,
    "player_state": {...},
    "slot_number": 1,
    "is_active": 1,
    "created_at": "2026-07-13T00:00:00",
    "updated_at": "2026-07-13T00:00:00"
}
```

失败（404）：
```json
{
    "detail": "槽位1没有存档"
}
```

**状态码:**
- 200: 成功
- 401: 未认证或Token无效
- 404: 该槽位没有存档

---

### 17. 更新游戏存档

**接口:** `PUT /api/game/save/{slot_number}`

**功能:** 更新当前登录用户指定槽位的游戏存档

**认证:** 需要JWT Token

**路径参数:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| slot_number | int | 是 | 存档槽位（1-3） |

**请求参数（可选）:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| save_name | string | 否 | 存档名称 |
| current_floor | int | 否 | 当前层数 |
| player_state | object | 否 | 玩家状态数据 |
| inventory_data | object | 否 | 背包数据 |
| current_map_data | object | 否 | 当前地图数据 |
| play_time | int | 否 | 游戏时长（秒） |
| kill_count | int | 否 | 击杀数 |
| gold_collected | int | 否 | 收集金币 |

**请求示例:**
```json
{
    "current_floor": 5,
    "player_state": {
        "health": 80,
        "max_health": 100,
        "attack": 15,
        "defense": 8,
        "level": 3,
        "experience": 250,
        "gold": 150
    },
    "play_time": 3600,
    "kill_count": 50
}
```

**响应示例:**

成功（200）：
```json
{
    "id": 1,
    "user_id": 1,
    "save_name": "第一次冒险",
    "current_floor": 5,
    "player_state": {...},
    "play_time": 3600,
    "kill_count": 50,
    "slot_number": 1,
    "is_active": 1,
    "created_at": "2026-07-13T00:00:00",
    "updated_at": "2026-07-13T01:00:00"
}
```

**状态码:**
- 200: 更新成功
- 401: 未认证或Token无效
- 404: 该槽位没有存档
- 422: 请求数据验证失败

---

## 待开发接口

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
