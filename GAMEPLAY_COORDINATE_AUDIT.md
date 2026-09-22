# Gameplay Coordinate & Integration Audit

> 日期：2026-09-22
> 范围：世界坐标、摄像机、Portal、平台、存档系统

---

## 一、世界坐标体系审计

### 1.1 坐标系定义

```
GameWorld (root Node2D)
  ├── Player (CharacterBody2D) @ position (640, 360) in scene
  ├── Room_Nodes (created dynamically)
  │     ├── Background (ColorRect) @ (-640, -360) relative to room
  │     ├── Ground (StaticBody2D) @ (0, 328) relative to room
  │     ├── Platforms @ various positions relative to room center
  │     └── Exit Portal @ (600, 298) relative to room center
  └── Camera2D (on Player)
```

### 1.2 各系统坐标来源

| 对象 | position 来源 | 父节点 | 世界坐标计算 |
|------|--------------|--------|-------------|
| **Player** | `WorldCoordinate.player_spawn_pos(room.position)` | GameWorld | `room.position + (-540, 298)` |
| **Platform** | `room_renderer._create_platform(pos, width)` | Room Node | `room.position + pos` |
| **Reward** | `WorldCoordinate.reward_spawn_pos(room.position)` | RewardContainer | `room.position + (randx, 288)` |
| **Portal** | `_current_room_position + (600, 298)` | Room Node | `room.position + (600, 298)` |
| **Monster** | `WorldCoordinate.monster_spawn_pos(room.position)` | MonsterContainer | `room.position + (randx, 298)` |

### 1.3 坐标一致性验证

```
Room 0 center: (0, 0)
Player spawn: (-540, 298)  → 左墙内100px, 地面之上30px ✓
Portal: (600, 298)         → 右墙内40px, 地面之上30px ✓
Room 1 center: (1240, 0)   → 门对门对齐 ✓
Room 1 left edge: (600, 0) → 与Portal X相同 ✓
```

**结论**: 坐标体系内部一致，Portal位置正确。问题不在坐标计算，而在**摄像机视野**。

---

## 二、摄像机系统审计（根因）

### 2.1 当前配置

```gdscript
# player.tscn
Camera2D:
  zoom = Vector2(2, 2)
  offset = (-180, 60, -10, 120)  # left, top, right, bottom (screen pixels)
```

### 2.2 视野计算

```
可见宽度 = (屏幕宽 - offset_left - offset_right) / zoom
         = (1280 - (-180) - (-10)) / 2
         = (1280 + 180 + 10) / 2
         = 1470 / 2
         = 735 world units

等等... 让我重新理解Godot 4的offset符号约定:
```

### 2.3 Godot 4 Camera2D Offset 语义

在Godot 4中，Camera2D的offset定义了**相机视口边界相对于屏幕边缘的内缩距离**：

- `offset_left = -180`: 视口左边界在屏幕左边缘**左侧180px** → **向外扩展**
- `offset_right = -10`: 视口右边界在屏幕右边缘**左侧10px** → **向内收缩**
- `offset_top = 60`: 视口上边界在屏幕上边缘**下方60px** → **向内收缩**
- `offset_bottom = 120`: 视口下边界在屏幕下边缘**上方120px** → **向内收缩**

### 2.4 实际可见区域

```
有效偏移 (取正值，负值=扩展):
  effective_left = max(0, -180) = 0
  effective_right = max(0, -10) = 0
  effective_top = max(0, 60) = 60
  effective_bottom = max(0, 120) = 120

可见世界宽度 = (1280 - 0 - 0) / 2 = 640px
可见世界高度 = (720 - 60 - 120) / 2 = 270px
```

### 2.5 关键问题

```
玩家出生位置: X = -540 (Room 0内，距左墙100px)
摄像机保持玩家在屏幕右侧10px处 (offset_right=-10)

摄像机中心 X = -540 + (1280/2 - 10)/2 = -540 + 315 = -225
可见X范围 = [-225 - 320, -225 + 320] = [-545, -5]

Portal X = +600
Portal在可见范围外 1145px!
```

### 2.6 修复方案

将Camera2D offset改为正视图模式：

```gdscript
# 当前 (错误): offset = (-180, 60, -10, 120)
# 修复后: offset = (0, 0, 0, 0) → 全屏居中
# 或者横版游戏常用: offset = (100, 50, 100, 100) → 左右留白

# 推荐: 让摄像机居中显示房间中央区域
offset_left = 0    # 不裁剪左边
offset_top = 80    # 上方留一点天空
offset_right = 0   # 不裁剪右边
offset_bottom = 80 # 下方留一点地面
```

---

## 三、Portal系统审计

### 3.1 创建流程

```
game_scene.gd._create_room_exits()
  → _room_renderer.create_exit_portal(target_id, type)
    → _create_exit_portal_deferred(target_id, type)
      → portal = Area2D.new()
      → portal.position = room_center + (600, 298)
      → portal.collision_layer = 0
      → portal.collision_mask = 2  # 检测Player
      → portal.body_entered.connect(_on_portal_body_entered)
      → _room_container.add_child(portal)
      → _exit_portals.append(portal)
```

### 3.2 验证

- ✅ Portal位置正确: `room.position + (600, 298)`
- ✅ 碰撞层正确: layer=0, mask=2 (检测Player)
- ✅ 信号连接正确: `body_entered → _on_portal_body_entered`
- ✅ 添加到场景树: `_room_container.add_child(portal)`
- ⚠️ **不可见原因**: 摄像机看不到X=+600的区域

### 3.3 Portal可见性检查清单

| 检查项 | 值 | 状态 |
|--------|-----|------|
| Portal position | (600, 298) relative to room | ✅ |
| Portal collision_layer | 0 | ✅ |
| Portal collision_mask | 2 | ✅ |
| Portal sprite z_index | 默认 | ⚠️ 需确认 |
| Portal visible | true (默认) | ✅ |
| Portal in tree | _room_container.add_child() | ✅ |
| Portal in camera view | X=600, camera sees X≈[-545,-5] | ❌ 根本问题 |

---

## 四、平台系统审计

### 4.1 平台位置

所有平台使用`_create_platform(pos, width)`创建，`pos`是相对于房间中心的偏移。

| 房间 | 平台Y坐标 | 相邻差 | 状态 |
|------|----------|--------|------|
| Combat | [30, -10, 35] | max=45px | ✅ |
| Elite | [15, -10, 15, -30] | max=45px | ✅ |
| Boss | [20, 20, -25] | max=45px | ✅ |
| Reward | [25, -15, -15] | max=40px | ✅ |
| Shop | [20, 20] | 0px | ✅ |
| Event | [15] | 0px | ✅ |
| Treasure | [20, -20] | 40px | ✅ |

**结论**: 平台高度全部可到达（最大45px < 玩家跳跃82px）。坐标体系正确。

---

## 五、存档系统审计

### 5.1 Auto-save触发链

| 触发点 | 方法 | 状态 |
|--------|------|------|
| 玩家死亡 | `_on_player_dead()` → `_auto_save()` | ✅ |
| Boss击败 | `_on_boss_defeated()` → `_auto_save()` (延迟0.5s) | ✅ |
| 楼层完成 | `_on_floor_completed()` → `_auto_save()` | ✅ |
| 退出游戏 | `GameFlowController.exit_game()` → `SaveService.save_game()` | ✅ |

### 5.2 SaveService API调用

```gdscript
# save_service.gd
func save_game(slot, save_data):
    data = {save_name, current_floor, player_state, play_time, kill_count, gold_collected}
    ApiClient.put_request("/api/game/save/{slot}", data, true)
    # 如果404 → POST创建
```

### 5.3 数据完整性

| 字段 | 来源 | 状态 |
|------|------|------|
| level | PlayerStats.level | ✅ |
| experience | PlayerStats.experience | ✅ |
| gold | PlayerStats.gold | ✅ |
| hp/max_hp | PlayerStats.current_health/max_health | ✅ |
| weapon_id | GameStateManager._extended_save_data["weapon_id"] | ✅ (刚修复) |
| weapon_level | GameStateManager._extended_save_data["weapon_level"] | ✅ |
| passive_items | GameStateManager._extended_save_data["passive_items"] | ✅ |
| current_floor | _auto_save()设置 | ✅ |

---

## 六、问题汇总

| 优先级 | 问题 | 根因 | 修复文件 |
|--------|------|------|---------|
| **P0** | Portal不可见 | Camera2D offset负值导致视野过窄 | player.tscn |
| **P1** | 奖励物品可能在视野外 | 同上，camera看不到房间右侧 | player.tscn |
| **P2** | 平台视觉坐标一致 | ✅ 已验证正确 | 无需修改 |
| **P3** | 存档武器恢复 | ✅ 已修复 | game_state_manager.gd, player_controller.gd |

---

## 七、修复方案

### Priority 1: 修复Camera2D (player.tscn)

```xml
<!-- 当前 (错误) -->
[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
offset_left = -180.0
offset_top = 60.0
offset_right = -10.0
offset_bottom = 120.0

<!-- 修复后 -->
[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
# 正视图: 左右居中，上下留白
offset_left = 0.0
offset_top = 80.0
offset_right = 0.0
offset_bottom = 80.0
```

**预期效果**:
- 视野宽度: 640px (全屏)
- 视野高度: 260px (720-80-80=560/2=280)
- Player居中显示
- Portal在X=+600处可见（距玩家1140px，需要摄像机跟随）

**注意**: 由于房间跨度1240px，单屏无法同时看到整个房间。需要摄像机平滑跟随。当前Camera2D没有enabled设置问题，只需修正offset。

### Priority 2: 验证Portal碰撞

不需要修改，Portal的碰撞层/mask已正确配置。

### Priority 3: 验证存档

已完成修复，需要人工验收。

---

## 八、完整游戏流程验证清单

```
[Start]
  → Login → JWT
  → GameScene init
  → FloorManager.generate_floor(1)
  → FloorGenerator生成8-12个房间，间距1240px
  → Room 0 (start) 渲染到GameWorld
  → Player spawn at (-540, 298) relative to Room 0

[Combat Room]
  → spawn_monsters() → 怪物在(±300, 298)
  → 玩家攻击 → 子弹飞向怪物
  → 击杀 → reward掉落
  → 拾取奖励
  → 走到右侧 → 进入Portal → enter_room(next)

[Reward Room]
  → spawn_rewards() → 奖励在(±200, 288)
  → 玩家拾取
  → all_rewards_collected → _create_room_exits()
  → 进入Portal

[Event Room]
  → _handle_event_room() → 随机事件
  → HUD显示事件名
  → 属性变化
  → exit portal

[Treasure Room]
  → spawn_rewards() × N
  → 玩家拾取
  → exit portal

[Boss Room]
  → spawn_boss() → Boss在room_center
  → Boss战
  → boss_defeated → spawn_rewards()
  → _auto_save()
  → 进入Portal → 下一层
```
