# Aurora-Roguelike-AI 项目审计报告

**日期**: 2026-09-22
**审计范围**: client (Godot 4.7) + server (FastAPI) + AI Service
**审计目标**: 系统稳定化重构

---

## 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                         GameScene                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │FloorMgr  │ │CombatMgr │ │Upgrade  │ │AIContent │          │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘          │
│       │            │            │            │                  │
│  ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐          │
│  │RoomSpwnr │ │RoomRendr │ │RoomCntr  │ │DamageSys │          │
│  └────┬─────┘ └──────────┘ └──────────┘ └────┬─────┘          │
│       │                                        │                │
│  ┌────▼────────────────────────────────────▼────┐              │
│  │                 GameWorld                      │              │
│  │  MonsterContainer  RewardContainer             │              │
│  │  Player (CharacterBody2D)                      │              │
│  └────────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
   ┌──────────┐              ┌──────────┐
   │  Server  │◄────────────►│AI Service│
   │  FastAPI │   HTTP 8000  │  FastAPI │
   │          │              │  8001    │
   └──────────┘              └──────────┘
```

---

## P0: 会导致崩溃或无法运行

### P0-1: MonsterData 无 max_health 字段，导致运行时错误

**位置**: `client/scripts/world/room_spawner.gd:175`

```gdscript
func _apply_monster_clamp(monster: MonsterData, level: int) -> void:
    monster.health = clampi(monster.health, 10, hp_max)
    monster.max_health = monster.health  # ← ERROR: MonsterData 无 max_health!
```

**根因**: `MonsterData` 类定义中只有 `health` 字段，没有 `max_health`。尝试赋值会导致:
```
Invalid assignment of property 'max_health' on 'RefCounted MonsterData'
```

**影响**: 进入游戏时怪物生成阶段崩溃，游戏无法运行。

**修复方案**: MonsterData 不需要 max_health——MonsterEntity 自己管理健康值。移除该赋值。

---

### P0-2: 奖励节点位置坐标系统错误

**位置**: `client/scripts/world/room_spawner.gd:328-412`

```gdscript
func spawn_rewards(content: RoomContentData, room_center: Vector2) -> void:
    var spawn_pos = WorldCoordinate.reward_spawn_pos(room_center)  # 返回世界坐标
    _spawn_single_reward(reward_data, spawn_pos)

func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
    reward_node.position = pos  # ← 错误: 将世界坐标赋给局部坐标
    _reward_container.add_child(reward_node)
```

**根因分析**:
- `WorldCoordinate.reward_spawn_pos()` 返回世界坐标 (room_center + offset)
- 但 `reward_node.position = pos` 将其作为 RewardContainer 的**局部坐标**设置
- RewardContainer 在 GameWorld 下，GameWorld 位置为 (0,0)
- 所以局部坐标 == 世界坐标，当前场景可以工作
- **但是**: 一旦 GameWorld 被移动或 RoomNode 有偏移，奖励会出现在错误位置

**修复方案**: 使用 `global_position` 而非 `position`，或计算相对坐标。

---

### P0-3: FloorManager AI 后台请求可能覆盖已生成内容

**位置**: `client/scripts/world/floor_manager.gd:327-348`

```gdscript
func _request_room_content_ai(room: NewRoomData) -> void:
    var content = await _ai_content_service.generate_room_content(...)
    if content:
        if room.content and room.content.is_finalized:  # 检查已存在
            return
        content.validate_for_room_type()
        room.content = content  # ← 可能覆盖已有内容
```

**根因**: AI 异步请求完成后覆盖 `room.content`，可能导致:
1. 用户已经进入战斗的房间内容被重新生成
2. 虽然检查了 `is_finalized`，但 AI 生成是后台进行的，时机不可控

---

## P1: 影响核心玩法

### P1-1: 碰撞层系统存在不匹配

**审计结果** (上次修复后):
```
Layer 0: Area/Portal/Reward   mask=2 (检测Player)
Layer 1: Wall                 mask=0
Layer 2: Player              mask=7 (检测Reward+Wall+Enemy)
Layer 4: Enemy               mask=11 (检测Reward+Wall+Player+PlayerBullet)
Layer 8: PlayerBullet        mask=5 (检测Wall+Enemy)
Layer 16: EnemyBullet        mask=3 (检测Wall+Player)
```

**问题**: 敌人子弹 (layer=0, mask=3) 无法被任何节点检测到，因为:
- Player mask=7 不包含 layer 16
- Enemy mask=11 不包含 layer 16

**影响**: 玩家无法被敌人子弹击中。

---

### P1-2: 存档槽位可能为 -1

**位置**: `client/scenes/game/game_scene.gd:952-966`

```gdscript
func _auto_save() -> void:
    var save_slot = GameStateManager.get_current_slot()
    if save_slot < 1:
        save_slot = 1  # fallback
```

**问题**: `GameFlowController.exit_game()` 中的保存:
```gdscript
var slot = GameStateManager.get_current_slot()
if slot >= 0:
    SaveService.save_game(slot, save_data)
else:
    # 没有存档槽位，直接返回 ← 不保存就退出！
```

当 slot=-1 时（新玩家未加载存档），直接退出而不保存。

---

### P1-3: 多个数据模型并行存在

| 模型 | 状态 | 问题 |
|------|------|------|
| `RoomNodeData` | 旧API | 仍在被 FloorGenerator 使用 |
| `RoomData` | 废弃 | 仍在被 RoomManager 使用 |
| `NewRoomData` | 新API | 被 FloorManager 使用 |
| `RoomContentData` | 混合 | 部分字段冗余 |

`FloorManager._convert_to_floor_data()` 进行转换，但如果源数据不一致会导致错误。

---

### P1-4: AI 生成内容无客户端钳制

**位置**: `client/scripts/ai/ai_content_service.gd`

AI 返回的怪物数据 (health, attack, defense) 直接被使用:
- 服务端 `MonsterBalanceConfig` 有钳制逻辑
- 但 `fake_ai_service.gd` 和 `ai_response_parser.gd` 中没有钳制
- AI 生成的怪物 HP 可能是任意值

---

## P2: 代码质量问题

### P2-1: FakeAI 创建节点未添加到场景树

**位置**: `client/scripts/ai/ai_content_service.gd:518-520`

```gdscript
func _generate_fallback_floor(floor_level: int) -> Array[RoomNodeData]:
    var floor_generator = Node.new()
    floor_generator.set_script(load("res://scripts/world/floor_generator.gd"))
    add_child(floor_generator)  # 添加到 AIContentService 子节点
```

每次 fallback 都创建一个新节点并添加到 AIContentService。如果 AI 失败多次，会积累大量节点。

---

### P2-2: HTTP 请求模式不一致

**位置**: `client/scripts/ai/ai_content_service.gd:337-433`

手动轮询 HTTPRequest 状态:
```gdscript
while timeout_counter < 50:
    if http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
        break
    await get_tree().process_frame
    timeout_counter += 1
```

而 `ApiClient.gd` 使用信号驱动的请求队列:
```gdscript
http_request.request_completed.connect(_on_request_completed.bind(http_request))
```

两种方式并存，容易混淆。

---

### P2-3: MonsterSpawner 已废弃但未清理

**位置**: `client/scripts/enemy/monster_spawner.gd`

这个文件仍然存在但已被 `RoomSpawner` 替代。两者共存导致混乱。

---

### P2-4: 旧 RoomManager 与新 FloorManager 并存

**位置**: `client/scripts/world/room_manager.gd` vs `client/scripts/world/floor_manager.gd`

两个管理器都存在，职责重叠。`room_manager.gd` 使用了过时的 `RoomData`，而 `floor_manager.gd` 使用 `NewRoomData`。

---

### P2-5: player_entity.gd 与 player_stats.gd 双重管理玩家状态

- `PlayerEntity` 管理生命值等
- `PlayerStats` 也管理生命值等
- `GameStateManager` 又有一份 `_player_data` 字典
- `PlayerController._player_data` 还有一份字典

四个地方管理相同的数据，同步困难。

---

### P2-6: Entity/EntityManger 体系与实际使用脱节

`Entity` 基类和 `EntityManager` 被设计为通用实体管理系统，但:
- `MonsterEntity` 继承 `Entity`，只用了部分功能
- `PlayerEntity` 也继承 `Entity`，但 `PlayerController` 不使用它
- `entity_manager.gd` 基本未被使用

---

## 服务器端问题

### S1: SaveService 不保存 current_map_data 和 explored_maps

**位置**: `server/app/services/save_service.py:251-277`

`_to_response()` 返回了 `current_map_data` 和 `explored_maps`，但创建存档时没有设置这些字段。

### S2: 怪物 API 无楼层差异化

**位置**: `server/app/api/monster/router.py`

`GET /api/monsters` 返回所有怪物，没有根据楼层过滤。客户端需要根据 `min_floor`/`max_floor` 自己过滤。

---

## 数据流审计

### 房间生成流程
```
FloorManager.generate_floor()
  → FloorGenerator.generate_floor() → Array[RoomNodeData]
  → _convert_to_floor_data() → FloorData (Array[NewRoomData])
  → enter_room(0)
    → _ensure_room_content()
      → RoomContentData.from_room_node() 或 AI 生成
      → content.validate_for_room_type()
  → RoomRenderer.render_room(room)
  → GameScene._on_fm_room_entered(room)
    → content.finalize()
    → RoomSpawner.spawn_monsters(content, room.position)
    → CombatManager.start_combat(content)
    → _create_room_exits()
```

### 战斗流程
```
CombatManager.start_combat()
  → RoomSpawner.spawn_monsters()
    → for each monster:
      → MonsterEntity.new() + monster.tscn.instantiate()
      → entity.bind_monster_node(monster_node)
      → monster_node.position = spawn_pos
      → monster_node.set_monster_entity(entity)
      → entity.activate()
  → CombatManager._state = COMBAT

每个物理帧:
  MonsterAI.update(delta)
    → distance check
    → chase/attack behavior
    → MonsterNode.attack_player(Player)
      → DamageSystem.on_monster_attack_player()
        → calculate_damage()
        → Player.take_damage()

玩家攻击:
  Weapon.try_attack()
    → Bullet.instantiate()
    → Bullet._process(delta) → move_and_slide()
    → Bullet._on_body_entered(MonsterNode)
      → DamageSystem.on_bullet_hit()
        → MonsterNode.take_damage()
          → MonsterEntity.take_damage()
            → if dead: MonsterNode.on_death()
              → RoomSpawner.on_monster_died()
                → CombatManager.on_monster_died()
                  → if all_dead: combat_cleared.emit()
```

### 奖励流程
```
CombatManager.combat_cleared
  → GameScene._on_combat_cleared()
    → RoomSpawner.spawn_rewards(content, room.position)
      → WorldCoordinate.reward_spawn_pos(room_center)
      → reward_item.tscn.instantiate()
      → reward_node.position = world_pos  (bug: should use global_position)
      → RewardContainer.add_child(reward_node)
      → reward_node.reward_collected.connect()

玩家进入奖励碰撞区:
  RewardItem._on_body_entered(player)
    → RewardItem._collect(player)
      → reward_data.apply_to_player(player)
      → reward_collected.emit()
      → parent.remove_reward(self)
        → DropManager.remove_reward()
          → if all collected: all_rewards_collected.emit()
            → GameScene._on_all_rewards_collected()
              → CombatManager.complete_reward_phase()
                → room_completed.emit()
```

### 存档流程
```
玩家选择存档槽位 N:
  SaveSelection._on_slot_pressed(N)
    → save_selected.emit(N)
  GameScene._on_save_selected(slot)
    → SaveService.load_save_by_slot(slot)
    → ApiClient.get_request("/api/game/save/" + slot)
    → SaveService._on_api_success(result)
      → save_loaded.emit(result)
    → GameFlowController._on_api_success(result)
      → GameStateManager.set_player_data(result)
      → GameStateManager.set_current_save(result, slot)
      → GameFlowController.enter_game(slot)
        → SceneManager.go_to_game()

游戏中自动保存:
  GameScene._auto_save()
    → GameStateManager.get_save_data()
    → SaveService.save_game(slot, data)
    → ApiClient.put_request("/api/game/save/" + slot, data)

退出游戏:
  GameFlowController.exit_game()
    → GameStateManager.get_save_data()
    → SaveService.save_game(slot, data)
```

---

## 修复优先级

| 优先级 | ID | 问题 | 状态 |
|--------|-----|------|------|
| P0 | 1 | MonsterData.max_health 赋值错误 | 待修复 |
| P0 | 2 | 奖励坐标系统 | 已修复(部分) |
| P1 | 3 | 敌人子弹碰撞层 | 待修复 |
| P1 | 4 | 存档 slot=-1 风险 | 待修复 |
| P1 | 5 | AI 内容无客户端钳制 | 待修复 |
| P2 | 6 | 废弃文件清理 | 待处理 |
| P2 | 7 | HTTP 请求模式统一 | 待处理 |
| P2 | 8 | 数据模型去重 | 待处理 |
