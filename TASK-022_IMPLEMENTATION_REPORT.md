# TASK-022_IMPLEMENTATION_REPORT — AI 数据模型解析适配修复报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 触发：真实 AI 调用 HTTP 200 后报错 `Invalid assignment of property or key 'choices' with value of type 'Array' on a base object of type 'RefCounted (AIEventData)'`（ai_event_data.gd:32）

---

## 1. 修改文件

| # | 文件 | 修复点 |
|---|---|---|
| 1 | [ai_event_data.gd](client/scripts/events/ai_event_data.gd) | `from_dict()`：`choices`（Array[Dictionary]）——**主报错位置** |
| 2 | [ai_room_content.gd](client/scripts/ai/ai_room_content.gd) | `from_dict()`：`event_choices`（Array[Dictionary]）、`npc_dialogue`（Array[String]） |
| 3 | [boss_data.gd](client/scripts/boss/boss_data.gd) | `from_dict()`：`skills`（Array[Dictionary]） |
| 4 | [room_content_data.gd](client/scripts/models/room_content_data.gd) | `from_dict()`：`monster_types`（Array[String]）、`reward_items`（Array[Dictionary]） |
| 5 | [npc_memory_manager.gd](client/scripts/ai/npc_memory_manager.gd) | `from_dict()`：`player_choices`（Array[Dictionary]）、`notes`（Array[String]） |
| 6 | [player_behavior_data.gd](client/scripts/ai/player_behavior_data.gd) | `from_dict()`：`upgrade_history`、`room_route`、`event_choices`（均 Array[Dictionary]） |
| 7 | [ai_response_parser.gd](client/scripts/ai/ai_response_parser.gd) | `_parse_reward_config()`：`content.reward_items`（Array[Dictionary]） |

## 2. 修改原因

- **根因**：Godot 4 运行时拒绝将 JSON 解析出的**未类型化 Array** 直接赋给类型化数组成员（`Array[Dictionary]`/`Array[String]`），报 `Invalid assignment of property or key`。AI 服务返回 200 后 JSON → 数据模型的转换层全部存在此隐患。
- **修复模式**（统一，不降低类型安全）：

```gdscript
var raw = data.get("xxx", [])
if raw is Array:
    for item in raw:
        if item is Dictionary:    # 或 String，按成员元素类型
            member.append(item)   # 逐项验证类型后追加
```

- **已确认安全的路径**（未改）：`ai_response_parser._parse_monster_config`（手动循环 + `is Dictionary` 验证，原本正确）、`NewRoomData.add_connection` 逐项添加、其余单对象模型（MonsterData/WeaponData）无数组成员。
- **检查结论**：用户要求排查的 AIRoomData/AIMonsterData/AIWeaponData/AIDifficultyData 中，房间内容（ai_room_content.gd）、怪物/武器模型（无类型化数组成员，安全）、难度数据（纯 Dictionary，安全）——同类隐患共发现 7 处，全部修复。

## 3. 保持不变（按指令）

- ✅ AI 服务接口设计零改动（仅客户端解析层）
- ✅ 类型安全未降低（逐项类型验证，非强制转换）
- ✅ 未新增玩法、未修改数据库、未重构 AI 架构

## 4. 测试结果

| 验证 | 结果 |
|---|---|
| Godot headless 启动（`--headless --quit`） | ✅ 0 脚本错误（SCRIPT ERROR / Parse Error / Invalid call / Invalid assignment 均为 0） |
| test_reward_system | 12/12 ✅ |
| test_reward_spawn_position | 11/11 ✅ |
| test_event_room | 16/16 ✅ |
| test_room_type_dispatch | 19/19 ✅ |
| test_room_lifecycle | 35/35 ✅ |
| test_floor_generation | 2001/2001 ✅ |
| test_monster_spawn_safety | 13/13 ✅ |
| test_monster_ai | 20/20 ✅ |
| 服务端 pytest（tests/ + ai/tests/） | ✅ 143 passed |

## 5. 剩余问题（延续自前序任务）

| # | 问题 | 等级 |
|---|---|---|
| 1 | 武器伤害双重计入（铁剑 18/19 伤害根因） | P1 |
| 2 | AI 难度调整生成后零消费者 | P1 |
| 3 | 暴击率硬编码 0.1 | P1 |
| 4 | 玩家双重减伤 | P2 |
| 5 | 存档加载 UI 入口缺失、楼层进度硬编码 1 | P0/P1 |
| 6 | 事件房自动选第一选项等观察项 | P3 |

---

**TASK-022 实施完成。按流程停止，等待人工验收后进入下一任务。**
