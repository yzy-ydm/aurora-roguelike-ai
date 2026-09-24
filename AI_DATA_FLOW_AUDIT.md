# AI_DATA_FLOW_AUDIT — AI JSON → Godot 类型转换链路审计报告

> 日期：2026-09-24（TASK-023 第一阶段产物）
> 触发错误：`Trying to return a value of type "Array" from a function whose return type is "Array[String]"`（ai_content_service.gd generate_npc_dialogue）

---

## 1. 链路总览

```
AI服务(HTTP 200, JSON)
  → _do_ai_request: JSON.parse → Variant Dictionary（内部所有值均为未类型化 Variant）
  → 各 generate_*() 函数: response.get("字段") → 直接 return / 直接赋给类型化成员
  → ❌ Godot 4 运行时拒绝: 未类型化 Array 不能作为 Array[String]/Array[Dictionary] 返回或赋值
```

**结论**：链路缺少统一的"JSON Variant → 强类型"适配层，风险点分散在各 generate 函数与 from_dict 中。

---

## 2. 风险清单（文件 / 函数 / 输入JSON字段 / 目标类型 / 风险等级）

### A. ai_content_service.gd（generate 函数返回路径）

| 函数 | 输入 JSON 字段 | 目标类型 | 当前处理 | 风险 |
|---|---|---|---|---|
| generate_npc_dialogue | `dialogue` | `Array[String]` | `return dialogue`（Variant Array 直接返回） | **P0 运行时崩溃（当前报错点）** |
| generate_upgrade_options | `upgrades` | `Array[Dictionary]` | `return upgrades`（同上） | **P0 运行时崩溃（同类必炸点）** |
| generate_room_event | `title/description/choices` | AIEventData | from_dict（TASK-022 已修 choices） | ✅ 已安全 |
| generate_context_event | `title/description/choices` | AIEventData | from_dict（TASK-022 已修） | ✅ 已安全 |
| generate_floor_content | `rooms` | `Array[NewRoomData]` | ai_response_parser 手动循环（`is Dictionary` 验证） | ✅ 已安全 |
| generate_room_content(_from_new) | `monsters/rewards` | RoomContentData | ai_response_parser 手动循环 + TASK-022 修 reward_items | ✅ 已安全 |
| generate_difficulty_adjustment | `enemy_hp_multiplier` 等 | Dictionary | `_parse_difficulty_response` 直接 get | ⚠️ P2（数值可能为 String/int，无转换） |
| generate_room_strategy | strategy 字段 | Dictionary | 直接 get | ⚠️ P3（Dictionary 无类型约束，安全但未规整） |
| generate_npc_memory_response | memory 字段 | Dictionary | 直接 get | ⚠️ P3 |

### B. 数据模型 from_dict（TASK-022 已全部修复，本次复核）

| 文件 | 字段 | 状态 |
|---|---|---|
| ai_event_data.gd | choices: Array[Dictionary] | ✅ TASK-022 已逐项验证 |
| ai_room_content.gd | event_choices / npc_dialogue | ✅ TASK-022 |
| boss_data.gd | skills | ✅ TASK-022 |
| room_content_data.gd | monster_types / reward_items | ✅ TASK-022 |
| npc_memory_manager.gd | player_choices / notes | ✅ TASK-022 |
| player_behavior_data.gd | upgrade_history / room_route / event_choices | ✅ TASK-022 |
| ai_response_parser.gd | reward_items | ✅ TASK-022 |

**结论：from_dict 层已无"直接接收 JSON Array"的路径；本次只需修 generate 函数返回路径 + 数值规整。**

---

## 3. 修复设计（第二阶段起）

新增 [ai_response_adapter.gd](client/scripts/ai/ai_response_adapter.gd)（class_name `AIResponseAdapter`，纯静态工具）：

| 函数 | 用途 |
|---|---|
| `to_string_array(raw) -> Array[String]` | JSON Array → 类型化数组（逐项 `is String` 验证，非法项跳过） |
| `to_dictionary_array(raw) -> Array[Dictionary]` | 同上（逐项 `is Dictionary`） |
| `to_safe_dictionary(raw) -> Dictionary` | Variant → Dictionary（非字典返回空字典） |
| `to_float(raw, default) -> float` | int/float/数字字符串 → float（失败返回默认值） |
| `to_int(raw, default) -> int` | int/float/数字字符串 → int（失败返回默认值） |

原则：**保持强类型声明、无强制 cast（全部逐项类型验证）、不降类型安全**。

迁移范围（第三阶段）：ai_content_service.gd 中全部 generate_* 的 AI 返回处理（dialogue/upgrades 两处必修；event/context_event/difficulty 走规整；strategy/npc_memory 防御性 to_safe_dictionary）。
