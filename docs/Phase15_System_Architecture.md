# Phase 15 系统架构文档

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Godot Client                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  GameScene                            │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │FloorManager │  │CombatManager│  │UpgradeManager│  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │  │
│  │         │                │                │          │  │
│  │  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐  │  │
│  │  │RoomRenderer │  │RoomSpawner  │  │AIContentSvc │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                     HTTP REST API                            │
│                           │                                  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     FastAPI Server                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ AI Routes   │  │ Auth Module │  │Rate Limiter │        │
│  └──────┬──────┘  └─────────────┘  └─────────────┘        │
│         │                                                    │
│  ┌──────┴──────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ AI Service  │  │  Database   │  │    Cache    │        │
│  └──────┬──────┘  └─────────────┘  └─────────────┘        │
│         │                                                    │
│  ┌──────┴──────┐                                            │
│  │ MiMo Client │                                            │
│  └─────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

## 2. 客户端架构

### 2.1 核心系统

| 系统 | 职责 | 文件 |
|------|------|------|
| FloorManager | 楼层生成、房间切换、AI协调 | `world/floor_manager.gd` |
| CombatManager | 战斗状态机、怪物统计、Boss管理 | `combat/combat_manager.gd` |
| UpgradeManager | 升级系统、强化选择 | `progression/upgrade_manager.gd` |
| RoomRenderer | 房间视觉渲染 | `world/room_renderer.gd` |
| RoomSpawner | 怪物/奖励生成 | `world/room_spawner.gd` |

### 2.2 数据流

```
FloorManager.generate_floor()
    │
    ├─► FloorGenerator.generate_floor()  [本地生成]
    │
    ├─► FloorData (新数据模型)
    │
    ├─► RoomRenderer.render_room()  [视觉渲染]
    │
    └─► AIContentService.generate_*()  [后台AI增强]
```

### 2.3 状态管理

```gdscript
GameStateManager.GameState:
├── NOT_STARTED    # 未开始
├── LOGIN          # 登录中
├── LOADING        # 加载中
├── EXPLORATION    # 探索中
├── PLAYING        # 游戏中
├── PAUSED         # 暂停
├── COMBAT         # 战斗中
├── EVENT          # 事件选择中
├── LEVEL_UP       # 升级选择中
├── BOSS           # Boss战中
├── GAME_OVER      # 游戏结束
└── VICTORY        # 胜利
```

## 3. 服务器架构

### 3.1 API端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/api/auth/token` | GET | 获取Token |
| `/api/generate/floor` | POST | 生成楼层 |
| `/api/generate/room` | POST | 生成房间内容 |
| `/api/generate/event` | POST | 生成事件 |
| `/api/generate/dialogue` | POST | 生成NPC对话 |
| `/api/generate/upgrade` | POST | 生成升级选项 |
| `/api/generate/difficulty` | POST | 生成难度调整 |

### 3.2 中间件

- **认证**: Bearer Token验证
- **限流**: 60请求/分钟（普通），10请求/分钟（AI）
- **日志**: 请求/响应记录
- **缓存**: LRU缓存策略

## 4. AI调用流程

```
GameScene
    │
    ├─► FloorManager.enter_room()
    │       │
    │       ├─► RoomRenderer.render_room()  [同步]
    │       │
    │       └─► _request_ai_room_content()  [异步，不阻塞]
    │               │
    │               ├─► AIContentService.generate_context_event()
    │               │
    │               └─► AIContentService.generate_npc_dialogue()
    │
    └─► _request_difficulty_adjustment()  [异步，不阻塞]
            │
            └─► AIContentService.generate_difficulty_adjustment()
```

## 5. 网络通信流程

```
Client                          Server
  │                               │
  ├─ GET /api/auth/token ────────►│
  │◄── {token, expires_in} ───────┤
  │                               │
  ├─ POST /api/generate/floor ───►│
  │   Header: Authorization:      │
  │   Bearer <token>              │
  │                               │
  │   [Rate Limit Check]          │
  │   [Auth Check]                │
  │   [Cache Check]               │
  │                               │
  │   [AI Service]                │
  │       │                       │
  │       ├─ Mock Mode            │
  │       └─ MiMo API             │
  │                               │
  │◄── {floor_data} ─────────────┤
  │                               │
```

## 6. 数据模型

### 6.1 FloorData

```gdscript
class FloorData:
    var floor_level: int
    var rooms: Array[NewRoomData]
    var current_room_id: int
```

### 6.2 NewRoomData

```gdscript
class NewRoomData:
    var id: int
    var room_type: RoomType
    var connections: Array[int]
    var content: RoomContentData
    var visited: bool
    var completed: bool
    var position: Vector2
```

### 6.3 RoomContentData

```gdscript
class RoomContentData:
    var monster_count: int
    var monster_types: Array
    var reward_count: int
    var reward_quality: float
    var event_chance: float
```

## 7. 关键设计决策

1. **FloorManager统一管理**: 替代旧的RoomGraph + WorldManager + MapRenderer
2. **CombatManager独立**: 战斗状态机从RoomManager中剥离
3. **AI异步不阻塞**: 所有AI请求后台执行，不影响游戏流程
4. **状态机严格验证**: GameStateManager防止非法状态转换
5. **旧系统保留**: 旧文件标记@deprecated但不删除，保持兼容性

---

**Phase 15** | Aurora-Roguelike-AI Project
