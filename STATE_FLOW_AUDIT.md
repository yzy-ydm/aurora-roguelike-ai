# STATE_FLOW_AUDIT — 数据状态一致性审计报告（Phase 18.1）

> 日期：2026-09-24
> 触发：重新登录加载后 HUD 显示 profile 快照（level=1/exp=0/gold=0/hp=0/100/atk=10/def=5），
> 与数据库存档（level=5/exp=279/gold=160/hp=295/329/atk=81/weapon_id=3）不一致。
> 结论先行：**数据库存档数据完全正确；问题全部在客户端恢复链与 profile 字段形状。**

---

## 1. 完整数据流（运行时修改 → 缓存 → 保存 → 数据库 → 加载 → 恢复）

```
[运行时修改]                          [缓存]                    [保存]
PlayerStats 属性变化                   GameStateManager           get_save_data()
（伤害/金币/升级/奖励/武器）            ├ _runtime_stats ────────→ _player_data = _runtime_stats.to_dict()
     │                                └ _player_data（profile 或存档快照）
     ▼
player_controller._sync_stats_to_game_state()
     │  每次属性变化后调用
     ▼
GameStateManager.sync_from_runtime_stats()      → 合并 _extended_save_data（weapon_id/weapon_level/passive_items）
                                                     │
                                                     ▼
                                                SaveService.save_game(slot, data)
                                                     │  data.player_state = 合并结果
                                                     ▼
                                                服务端 PUT/POST → MySQL game_saves.player_state (JSON)

[加载]                               [恢复]
GameFlow.enter_game(slot)             GameStateManager.set_current_save(save, slot)
  ├ reset_run_state()（清 _runtime_stats，保留 _player_data=profile）
  ├ 内存列表为空 → 拉取服务端存档列表（Phase 18.1 加固）
  ├ get_save_by_slot(slot)
  └ set_current_save：
       ├ _current_floor = save.current_floor
       ├ _player_data = save.player_state        ← Phase 18.1: 一律写入（旧实现仅 _runtime_stats==null 时写）
       ├ _runtime_stats?.sync_from_dict(...)
       └ _extended_save_data ← player_state 嵌套内 weapon_id/weapon_level/passive_items
            （TASK-030: 嵌套优先 + 顶层兜底兼容旧档）
     │
     ▼
SceneManager.go_to_game() → player._ready → _link_stats_to_game_state()
  ├ get_stats()（新 PlayerStats，默认值）
  ├ sync_from_dict(GameStateManager.get_player_data())   ← 存档数据
  └ GameStateManager.set_runtime_stats(s)                ← 唯一运行时引用
     │
     ▼
player_controller._load_weapon_data() → extended weapon_id/level → 恢复武器（TASK-030 等级修复）
     │
     ▼
game_scene._update_game_display() → player.get_player_data() → HUD（单一来源）
```

## 2. PlayerStats 实例审计（Single Source of Truth）

| 位置 | 角色 | 结论 |
|---|---|---|
| `GameStateManager._runtime_stats` | autoload 持有的运行时唯一引用 | ✅ 唯一真相源 |
| `player_controller._stats` | 与 _runtime_stats **同一实例**（_link_stats_to_game_state 链接；reset_stats_to 重建后重新链接） | ✅ 无第二实例 |
| 其它 `PlayerStats.new()` 路径 | `get_stats()`（懒创建一次）、`set_player_data`（_stats 为空时 from_dict）、`reset_stats_to`（新 run 重建） | ✅ 全部立即链接回 GameStateManager |
| upgrade_manager / ai 系统 | 一律 `player.get_stats()` | ✅ 不持有独立实例 |

**结论：无重复实例。** 运行时唯一状态源 = `GameStateManager._runtime_stats`，HUD/保存/战斗/升级全部经由它。

## 3. 字段级完整路径核对

| 字段 | 运行时修改 | 保存 | 恢复 | 状态 |
|---|---|---|---|---|
| level | PlayerStats._level_up | to_dict ✓ | sync_from_dict ✓（实测 5 恢复） | ✅ |
| experience / experience_to_next | gain_exp | to_dict ✓ | sync ✓（实测 300 恢复） | ✅ |
| max_health | add_max_health/升级 | to_dict ✓ | sync ✓ | ✅ |
| current_health | take_damage/heal/升级 | to_dict ✓ | sync ✓（实测 295→恢复） | ✅ |
| attack | add_attack/升级/强化 | to_dict ✓ | sync ✓ | ✅ |
| defense | add_defense/强化 | to_dict ✓ | sync ✓ | ✅ |
| gold | add_gold | to_dict ✓ | sync ✓ | ✅ |
| move_speed / move_speed_bonus | 强化 | to_dict ✓ | sync ✓ | ✅（游戏内消费为已知 backlog） |
| weapon_id / weapon_level | equip_new_weapon/upgrade_weapon | 合并进 player_state ✓ | **嵌套读取**（TASK-030）+ 等级恢复（TASK-030） | ✅（实测冰霜法杖 Lv3 完整恢复） |
| passive_items | add_passive_item | 合并进 player_state ✓ | 嵌套读取 ✓ | ✅ |
| floor | GameStateManager.set_current_floor | get_save_data 取运行时值 ✓ | set_current_save._runtime_floor ✓ | ✅ |
| room | —— | **不保存**（房间级进度为已知限制） | —— | ⚠️ 设计限制（继续游戏当前楼层重新生成） |

## 4. 发现的问题（3 个，均已修复）

### 问题 1：profile 字段形状不匹配（HUD 显示 health=0/100 的直接根因）
- **现象**：profile API 返回 `{"health": 100, "experience_to_next_level": 100, ...}`，而运行时/HUD 统一读 `current_health` / `experience_to_next` → 键缺失 → `get("current_health", 0)` 返回 **0**。
- **修复**：`GameStateManager.set_player_data` 字段名规整（health→current_health、experience_to_next_level→experience_to_next），缺失时再走默认值兜底。

### 问题 2：set_current_save 缓存分支不对称
- **现象**：旧实现仅当 `_runtime_stats == null` 时才把存档写入 `_player_data`；若残留旧运行时引用（异常退出路径），缓存停留在 **profile 快照** → 新场景 player 链接前 `get_player_data()` 返回 profile → HUD 显示登录快照（level=1/atk=10/def=5 的来源）。
- **修复**：`_player_data = player_state` **无条件先行写入**，再按需同步运行时引用。

### 问题 3：自动进入路径依赖内存存档列表
- **现象**：登录后自动进入游戏（enter_game 无参）直接读内存列表；若列表因任何瞬态原因为空 → 判定"无存档"→ 以 profile 数据开新局（玩家视角=存档丢失）。
- **修复**：enter_game 在内存列表为空时**先拉取服务端最新存档列表再决定**（最长 5 秒，成功后正常恢复）。

## 5. 保存 JSON 结构约定（固化规则）

```
存档记录（SaveResponse）:
{
  save_name, slot_number,
  current_floor: int,          ← 进度字段顶层（服务端 schema 定义）
  play_time, kill_count, gold_collected,
  player_state: {              ← 玩家全部状态字段嵌套于此
     level, experience, experience_to_next, max_health, current_health,
     attack, defense, gold, move_speed, ...,
     weapon_id, weapon_level, passive_items   ← 扩展数据合并写入
  }
}
```

- **读取规则**：玩家字段一律 `player_state.xxx`；`current_floor` 等进度字段读顶层（服务端 schema 如此定义）；武器字段**嵌套优先、顶层兜底**（兼容旧档）。
- **禁止**：从顶层读玩家字段（旧实现的 weapon_id 顶层读取是 TASK-030 修复的历史 bug）。

## 6. 剩余风险

| # | 风险 | 说明 |
|---|---|---|
| R1 | room 级进度不存档 | 继续游戏后当前楼层重新生成（房间完成状态重置）——既有设计限制，论文如实表述 |
| R2 | 旧档字段缺失 | 旧档 player_state 若缺字段 → sync_from_dict 增量语义保留默认值 + set_player_data 兜底默认值，已覆盖 |
| R3 | move_speed 等加成字段 | 存档/恢复完整，但游戏内消费（移动速度/暴击/击杀回血）为已知 backlog，不影响数据一致性 |

---

**审计结论：运行时状态与持久化状态的一致性链已修复并全字段实测（test_full_progress_save_restore 17/17）。**
