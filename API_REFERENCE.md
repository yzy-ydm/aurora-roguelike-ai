# API_REFERENCE.md

> Aurora-Roguelike-AI API参考文档

最后更新：2026-07-13

---

## 概述

**AI服务端地址**：`http://localhost:8001`

**认证方式**：Bearer Token

**数据格式**：JSON

---

## 认证接口

### 获取Token

```http
GET /api/auth/token?client_id=godot_client
```

**参数**：
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| client_id | string | 否 | 客户端ID，默认godot_client |

**响应**：
```json
{
    "token": "abc123...",
    "client_id": "godot_client",
    "expires_in": 86400
}
```

**说明**：
- Token有效期24小时
- 后续请求需携带 `Authorization: Bearer <token>`

---

## 内容生成接口

### 生成楼层

```http
POST /api/generate/floor
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**：
```json
{
    "floor_level": 1,
    "player_level": 1,
    "player_stats": {
        "health": 100,
        "attack": 10,
        "defense": 5
    }
}
```

**响应**：
```json
{
    "floor": 1,
    "player_level": 1,
    "room_count": 10,
    "rooms": [
        {
            "id": 0,
            "type": "start",
            "connections": [1],
            "monsters": [],
            "rewards": {},
            "chests": 0
        }
    ],
    "ai_mode": "mock",
    "from_cache": false
}
```

**房间类型**：
- `start` - 起始房间
- `combat` - 战斗房间
- `elite` - 精英房间
- `boss` - Boss房间
- `reward` - 奖励房间
- `treasure` - 宝箱房间
- `shop` - 商店房间
- `event` - 事件房间

---

### 生成房间内容

```http
POST /api/generate/room
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**：
```json
{
    "room_id": 1,
    "room_type": "combat",
    "floor_level": 1,
    "player_level": 1
}
```

**响应**：
```json
{
    "room_id": 1,
    "room_type": "combat",
    "floor_level": 1,
    "player_level": 1,
    "difficulty": 1,
    "monsters": [
        {"id": "goblin", "count": 3, "level": 1}
    ],
    "rewards": {
        "count": 2,
        "quality": 1.5,
        "strategy": "power_growth",
        "items": [
            {"type": "weapon", "rarity": "rare", "value": 10}
        ]
    },
    "chests": 0,
    "ai_mode": "mock",
    "from_cache": false
}
```

**奖励策略**：
- `power_growth` - 力量成长（更多攻击奖励）
- `survival` - 生存策略（更多生命奖励）
- `balanced` - 平衡策略

**奖励类型**：
- `gold` - 金币
- `attack_up` - 攻击提升
- `health_up` - 生命提升
- `heal` - 治疗
- `weapon` - 武器

---

### 生成怪物

```http
POST /api/generate/monster
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**：
```json
{
    "room_type": "combat",
    "floor_level": 1,
    "player_level": 1,
    "monster_count": 3
}
```

**响应**：
```json
{
    "monsters": [
        {"id": "goblin", "count": 1, "level": 1},
        {"id": "skeleton", "count": 2, "level": 1}
    ],
    "total_count": 3,
    "ai_mode": "mock"
}
```

**怪物类型**：
- `goblin` - 哥布林
- `skeleton` - 骷髅
- `bat` - 蝙蝠
- `slime` - 史莱姆
- `spider` - 蜘蛛
- `elite_goblin` - 精英哥布林
- `boss_goblin_king` - 哥布林王

---

### 生成武器

```http
POST /api/generate/weapon
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**：
```json
{
    "player_level": 1,
    "rarity": "common",
    "weapon_type": "sword"
}
```

**响应**：
```json
{
    "weapon": {
        "id": "common_sword",
        "name": "Basic Sword",
        "description": "A common sword",
        "type": "sword",
        "rarity": "common",
        "damage": 12,
        "crit_rate_bonus": 0.06,
        "special_effect": "",
        "fire_rate": 0.3,
        "bullet_speed": 400.0,
        "price": 120
    },
    "ai_mode": "mock"
}
```

**武器类型**：
- `sword` - 剑（平衡型）
- `axe` - 斧（高伤害，慢速度）
- `bow` - 弓（远程，中等伤害）
- `staff` - 法杖（魔法伤害）
- `dagger` - 匕首（快速，低伤害）

**稀有度**：
- `common` - 普通
- `uncommon` - 优秀
- `rare` - 稀有
- `epic` - 史诗
- `legendary` - 传说

---

## 系统接口

### 健康检查

```http
GET /health
```

**响应**：
```json
{
    "status": "ok",
    "service": "ai_content_generator",
    "mode": "mock"
}
```

### 服务信息

```http
GET /api/info
```

**响应**：
```json
{
    "service": "Aurora-Roguelike-AI Content Generator",
    "version": "1.0.0",
    "endpoints": [...],
    "ai_mode": "mock"
}
```

### 统计信息

```http
GET /api/stats
Authorization: Bearer <token>
```

**响应**：
```json
{
    "auth": {
        "auth_enabled": true,
        "active_tokens": 1,
        "registered_clients": ["godot_client", "admin"]
    },
    "database": {
        "total_requests": 100,
        "success_requests": 95,
        "failed_requests": 5,
        "type_counts": {"floor": 30, "room": 50, "monster": 15, "weapon": 5},
        "average_quality_score": 0.85,
        "average_processing_time": 0.125
    },
    "cache": {
        "floor": {"size": 10, "hits": 25, "misses": 5, "hit_rate": 0.83},
        "room": {"size": 50, "hits": 100, "misses": 20, "hit_rate": 0.83}
    }
}
```

### 生成历史

```http
GET /api/history?request_type=floor&limit=50
Authorization: Bearer <token>
```

**参数**：
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| request_type | string | 否 | 请求类型过滤 |
| limit | int | 否 | 返回数量，默认50 |

**响应**：
```json
{
    "records": [
        {
            "id": 1,
            "request_type": "floor",
            "request_data": {...},
            "response_data": {...},
            "quality_score": 0.85,
            "client_id": "godot_client",
            "processing_time": 0.125,
            "status": "success",
            "create_time": "2026-07-13T10:30:45"
        }
    ],
    "total": 1
}
```

### 测试接口

```http
GET /api/generate/test
```

**说明**：无需认证，快速测试AI生成功能

**响应**：
```json
{
    "status": "ok",
    "message": "AI生成测试成功",
    "floor_sample": {...},
    "room_sample": {...},
    "ai_mode": "mock"
}
```

---

## 错误响应

**401 Unauthorized**：
```json
{
    "detail": "Invalid or expired token"
}
```

**500 Internal Server Error**：
```json
{
    "detail": "Internal server error"
}
```

---

## 当前状态

- **接口数量**：7个
- **认证方式**：Bearer Token
- **AI模式**：Mock（随机生成）
- **缓存**：内存LRU缓存
- **数据库**：SQLite记录
