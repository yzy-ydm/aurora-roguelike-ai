# ARCHITECTURE.md

> Aurora-Roguelike-AI 系统架构文档

最后更新：2026-07-13

---

## 系统总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      Godot 4.7 客户端                            │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │ Player  │ │ Combat  │ │ Monster │ │  Room   │               │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘               │
│       └───────────┴───────────┴───────────┘                     │
│                           │                                      │
│                    AIContentService                              │
└───────────────────────────┼──────────────────────────────────────┘
                            │ HTTP REST
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI AI服务端 (port 8001)                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │  Auth   │ │  Cache  │ │   DB    │ │  Logger │               │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘               │
│       └───────────┴───────────┴───────────┘                     │
│                           │                                      │
│                     MockAIService                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Godot客户端架构

### 核心模块

```
client/scripts/
├── ai/                          # AI内容服务
│   ├── ai_content_service.gd    # 统一AI接口
│   ├── fake_ai_service.gd       # 本地模拟AI
│   ├── ai_validator.gd          # 数据验证
│   ├── ai_quality_checker.gd    # 质量检查
│   ├── ai_cache_manager.gd      # 客户端缓存
│   └── ai_response_parser.gd    # JSON解析
│
├── combat/                      # 战斗系统
│   ├── weapon.gd                # 武器逻辑
│   ├── bullet.gd                # 子弹逻辑
│   └── damage_system.gd         # 伤害计算
│
├── enemy/                       # 怪物系统
│   ├── monster_entity.gd        # 怪物实体
│   ├── monster_ai.gd            # 怪物AI
│   ├── monster_spawner.gd       # 怪物生成器
│   └── monster_node.gd          # 怪物节点
│
├── world/                       # 世界系统
│   ├── room_graph.gd            # 房间图（接入AI楼层生成）
│   ├── room_manager.gd          # 房间状态管理
│   ├── room_content_manager.gd  # 房间内容管理
│   ├── floor_generator.gd       # 本地楼层生成（降级用）
│   └── map_renderer.gd          # 地图渲染
│
├── drop/                        # 掉落系统
│   ├── drop_manager.gd          # 掉落管理（支持AI策略）
│   └── reward_item.gd           # 奖励物品
│
└── models/                      # 数据模型
    ├── room_content_data.gd     # 房间内容数据
    ├── room_node_data.gd        # 房间节点数据
    ├── monster_data.gd          # 怪物数据
    ├── weapon_data.gd           # 武器数据
    └── reward_data.gd           # 奖励数据
```

### 数据流

```
GameScene._ready()
    ↓
RoomGraph.generate_new_floor()
    ↓
AIContentService.generate_floor_content()
    ↓ (HTTP)
FastAPI /api/generate/floor
    ↓
返回JSON → AIParser → RoomNodeData[]
    ↓
进入房间
    ↓
RoomContentManager.generate_content_for_room()
    ↓
AIContentService.generate_room_content()
    ↓ (HTTP)
FastAPI /api/generate/room
    ↓
返回JSON → AIParser → RoomContentData
    ↓
MonsterSpawner.spawn_monsters_from_content()
    ↓
DropManager.spawn_rewards_from_content()
```

---

## FastAPI AI服务架构

### 目录结构

```
server/ai/
├── main.py                      # 入口
├── api/
│   └── ai_routes.py             # 路由定义
├── services/
│   ├── ai_service.py            # MockAI服务
│   └── prompt_builder.py        # 提示词构建（未来用）
├── security/
│   └── auth.py                  # Token认证
├── database/
│   └── db_manager.py            # SQLite管理
├── cache/
│   └── cache_manager.py         # 内存缓存
└── logger/
    └── logger.py                # 日志系统
```

### 请求处理流程

```
客户端请求
    ↓
中间件（日志、CORS）
    ↓
路由处理（ai_routes.py）
    ↓
Token验证（auth.py）
    ↓
缓存检查（cache_manager.py）
    ↓ (未命中)
AI服务调用（ai_service.py）
    ↓
数据验证
    ↓
数据库记录（db_manager.py）
    ↓
返回响应
```

---

## HTTP通信流程

### 请求格式

```http
POST /api/generate/floor
Content-Type: application/json
Authorization: Bearer <token>

{
    "floor_level": 1,
    "player_level": 1
}
```

### 响应格式

```json
{
    "floor": 1,
    "player_level": 1,
    "room_count": 10,
    "rooms": [...],
    "ai_mode": "mock"
}
```

### Token获取

```http
GET /api/auth/token?client_id=godot_client

Response:
{
    "token": "xxx",
    "client_id": "godot_client",
    "expires_in": 86400
}
```

---

## 数据流图

### 楼层生成数据流

```
Godot                          FastAPI
  │                               │
  │ POST /api/generate/floor      │
  │ ─────────────────────────────►│
  │                               │
  │                    ┌──────────┴──────────┐
  │                    │   ai_service.py     │
  │                    │   generate_floor()  │
  │                    └──────────┬──────────┘
  │                               │
  │      { floor, rooms[] }       │
  │ ◄─────────────────────────────│
  │                               │
  ▼                               ▼
RoomGraph                    SQLite记录
```

### 房间内容数据流

```
Godot                          FastAPI
  │                               │
  │ POST /api/generate/room       │
  │ ─────────────────────────────►│
  │                               │
  │                    ┌──────────┴──────────┐
  │                    │   ai_service.py     │
  │                    │ generate_room()     │
  │                    └──────────┬──────────┘
  │                               │
  │ { monsters[], rewards{} }     │
  │ ◄─────────────────────────────│
  │                               │
  ▼                               ▼
RoomContentData            MonsterSpawner
                           DropManager
```

---

## 降级策略

```
AI服务可用
    ↓
调用云端AI
    ↓
返回数据
    ↓
验证+质量检查
    ↓ (通过)
使用AI数据

AI服务不可用
    ↓
HTTP失败/超时
    ↓
返回空数据
    ↓
使用本地FakeAIService
    ↓
使用本地FloorGenerator
```

---

## 当前状态

- **客户端**：已完成AI接入，支持云端和本地降级
- **服务端**：已完成MockAI服务，支持认证、缓存、日志
- **通信**：HTTP REST，Bearer Token认证
- **数据格式**：JSON
