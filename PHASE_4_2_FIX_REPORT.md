# Phase 4.2 Fix Report — Gameplay Integration Audit

> 日期：2026-09-22
> 目标：修复P0问题，确保Demo可运行

---

## 一、问题清单与优先级

| ID | 问题 | 优先级 | 状态 |
|----|------|--------|------|
| P0-1 | 存档slot=0服务器报错 | **P0** | 🔴 待修复 |
| P0-2 | AI重复生成楼层 | **P0** | 🔴 待修复 |
| P1 | 怪物数值过强 | **P1** | 🟡 待确认 |
| P2 | Portal可见性验证 | **P2** | ✅ Camera修复后应正常 |
| P3 | 平台跳跃体验 | **P3** | ✅ 高度已修复 |

---

## 二、P0-1: 存档系统根因分析

### 问题现象
```
客户端: SaveService.save_game(0, data)
→ PUT /api/game/save/0
→ FastAPI: 404 "slot 0 not found"
→ 客户端fallback POST创建 → 但_create_data中缺少slot_number
```

### 根因链条

```
1. game_scene._auto_save() → SaveService.save_game(0, ...)
2. save_service.save_game(slot=0):
   → data["current_floor"] = _player_data.get("current_floor", 1)
     ⚠️ _player_data中没有"current_floor"键!
     → data["current_floor"] = 1 (默认值)
   → ApiClient.put_request("/api/game/save/0", data)
3. FastAPI: GET /api/game/save/0 → 404 (slot不存在)
4. save_service._on_api_error(404):
   → _last_save_data.has("_save_slot") → FALSE!
   → save_error.emit("存档不存在")
   → 保存失败!
```

### 两个Bug

**Bug 1**: `_last_save_data` 没有保存 `slot` 信息
```gdscript
# 当前代码
_last_save_data = data.duplicate()  # 没有"_save_slot"键!
ApiClient.put_request(...)

# 404回退时
if _last_save_data.has("_save_slot"):  # ← FALSE，永远走不到这里
```

**Bug 2**: `current_floor` 从错误的位置获取
```gdscript
# 当前代码
"current_floor": save_data.get("current_floor", 1),
# save_data来自get_save_data():
#   "current_floor": _current_save.get("current_floor", 1)
# _current_save是空字典(新游戏) → 返回1 ← 这个是对的

# 但是create_save的data没有slot_number字段!
```

### 修复方案

**save_service.gd**: 传递slot信息给404回退逻辑
**game_scene.gd**: 在_auto_save中设置current_floor

---

## 三、P0-2: AI重复生成楼层根因分析

### 问题现象
```
日志: "Floor Generated 13 rooms"  ← FloorManager本地生成
随后: "AI fallback generated 10 rooms"  ← AI服务也调用了floor_generator
```

### 根因

```
FloorManager.generate_floor(1):
  → _floor_generator.generate_floor()  → 13 rooms  ✅ 主路径
  → _request_ai_background()           → async
    → AIContentService.generate_floor_content()
      → AI unavailable (未初始化/无Token)
      → return _generate_fallback_floor()
        → floor_generator.generate_floor()  → 10 rooms  ← 重复!
        → 但结果没有被使用(AI返回后没有覆盖_current_floor)
```

### 分析结论

这不是真正的bug — AI fallback的结果**没有被应用**。日志只是说明fallback执行了，但不影响游戏。

**但存在冗余计算**: 每次进入楼层都重复调用两次floor_generator。

### 修复方案

在 `_request_ai_background()` 中添加来源标记，消除重复日志的混淆。

---

## 四、P1: 怪物数值平衡

### 当前MonsterBalanceConfig值

```
Floor 1 Normal: HP=53, ATK=6, DEF=0
Floor 1 Elite:  HP=160, ATK=16, DEF=5
Floor 1 Boss:   HP=640, ATK=27, DEF=5
```

### 战斗数据分析

```
玩家Base Attack: 10
PlayerWeapon Damage (Lv1): 10-20
Total Player Attack: ~20-30

Normal Monster (Floor 1):
  HP: 53
  ATK: 6 (with DEF=0)
  → 玩家 ~3 shots to kill
  → 怪物 ~9 hits to kill player
  → TTK合理 ✅

Elite Monster (Floor 1):
  HP: 160
  ATK: 16 (with DEF=5)
  → 玩家 ~10-15 shots to kill
  → 怪物 ~6 hits to kill player
  → 可能偏难 ⚠️

Boss (Floor 1):
  HP: 640 (clamped to 400-1000)
  ATK: 27 (clamped to 15-40)
  → 玩家 ~30-40 shots to kill
  → 怪物 ~15 hits to kill player
  → 可行 ✅
```

### 用户反馈HP=1800

可能是以下原因：
1. **旧版本缓存数据** — 清除服务器缓存后刷新
2. **AI LLM生成未走balance config** — 如果LLM模式开启且未fallback
3. **MonsterData.from_dict使用了不正确的字段** — 需要验证

### 修复方案

1. 添加服务端缓存清除机制
2. 确保所有生成路径都通过MonsterBalanceConfig
3. 添加调试日志打印实际monster stats

---

## 五、Portal生命周期验证

### 创建流程

```
Combat cleared → _create_room_exits()
  → _room_renderer.create_exit_portal(target_id, type)
    → _create_exit_portal_deferred()
      → portal = Area2D.new()
      → portal.position = room.position + (600, 298)
      → portal.collision_layer = 0, mask = 2
      → body_entered.connect(_on_portal_body_entered.bind(target_id))
      → _room_container.add_child(portal)
      → _exit_portals.append(portal)
```

### 销毁流程

```
_on_fm_room_exited(room)
  → _room_renderer.clear_room()
    → clear_exit_portals()
      → for portal in _exit_portals: queue_free()
      → _exit_portals.clear()
```

### 验证点

| 检查 | 状态 | 说明 |
|------|------|------|
| Portal创建 | ✅ | create_exit_portal在所有非BOSS房调用 |
| Portal销毁 | ✅ | clear_room在房间退出时调用 |
| Collision | ✅ | layer=0, mask=2 (检测Player) |
| Signal | ✅ | body_entered → _on_portal_body_entered |
| 可见性 | ⚠️ | 取决于camera位置 (已修复offset) |

---

## 六、修改计划

### Phase A: 存档系统修复 (P0)

**修改文件**: `client/scripts/services/save_service.gd`

1. `save_game()` 中保存slot到`_last_save_data`
2. 404回退时正确传递slot_number
3. 添加save失败时的重试机制

**修改文件**: `client/scenes/game/game_scene.gd`

4. `_auto_save()` 中确保current_floor正确

### Phase B: 楼层生成日志优化 (P0)

**修改文件**: `client/scripts/world/floor_manager.gd`

5. 在`_request_ai_background()`中添加来源标记日志

### Phase C: 怪物数值验证 (P1)

**修改文件**: `server/ai/services/monster_balance.py`

6. 验证floor 1 monster HP范围是否符合预期
7. 添加调试日志

**修改文件**: `client/scripts/world/room_spawner.gd`

8. 在spawn_monsters中添加monster stats日志

### Phase D: Portal调试日志 (P2)

**修改文件**: `client/scenes/game/game_scene.gd`

9. 添加[Portal Check]日志

---

## 七、测试验证步骤

### 存档系统

```
1. 启动游戏 → 登录
2. 杀死怪物 → 掉落奖励
3. 让角色死亡
4. 检查日志: [GameScene] Auto-saved to slot 0
5. 检查日志: [SaveService] Save success response
6. 重新登录 → 选择存档 → 检查属性恢复
```

### 楼层生成

```
1. 启动游戏
2. 检查日志: [FloorManager] Floor generated: N rooms
3. 检查日志: [FloorManager] AI floor received/failed (一次即可)
4. 不应出现两次"Floor generated"日志
```

### Portal

```
1. 进入Combat房
2. 击杀怪物
3. 等待Portal出现
4. 检查日志: [PlatformRoom] Created exit portal to room N
5. 走到Portal → 进入下一房
```

### 怪物数值

```
1. 进入Combat房
2. 查看怪物HP (血条)
3. 日志显示: [Damage] monster xxx hp 1800->...
4. 预期: HP应在40-120范围
```

---

## 八、当前Git状态

```
HEAD: c952cb6 fix(camera): reset Camera2D offset to zero
Branch: main
Commits ahead: 10+
Server tests: 143 passed
```

---

*审计完成，等待确认修复方案后开始编码。*
