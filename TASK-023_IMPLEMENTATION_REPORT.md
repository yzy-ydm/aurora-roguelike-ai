# TASK-023_IMPLEMENTATION_REPORT — AI 数据稳定性修复实施报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 触发：真实 AI 调用（dialogue 返回 200）后报错 `Trying to return a value of type "Array" from a function whose return type is "Array[String]"`（generate_npc_dialogue）
> 第一阶段产物：[AI_DATA_FLOW_AUDIT.md](AI_DATA_FLOW_AUDIT.md)

---

## 1. 修改文件

| # | 文件 | 改动 |
|---|---|---|
| 1 | [ai_response_adapter.gd](client/scripts/ai/ai_response_adapter.gd) | **新增**统一解析层（class_name `AIResponseAdapter`，纯静态工具）：`to_string_array()` / `to_dictionary_array()` / `to_safe_dictionary()` / `to_float()` / `to_int()`——全部逐项类型验证，无强制 cast、不降类型声明 |
| 2 | [ai_content_service.gd](client/scripts/ai/ai_content_service.gd) | 6 处 AI 返回处理迁移到适配层：① generate_npc_dialogue（**崩溃点**：dialogue → Array[String]）② generate_upgrade_options（**同类必炸点**：upgrades → Array[Dictionary]）③ generate_room_event / generate_context_event（from_dict 前 to_safe_dictionary 防御）④ _parse_difficulty_response（4 个数值字段 to_float 规整）⑤ generate_room_strategy / generate_npc_memory_response（返回前 to_safe_dictionary 防御） |
| 3 | [AI_DATA_FLOW_AUDIT.md](AI_DATA_FLOW_AUDIT.md) | 第一阶段审计报告（链路总览 + 风险清单） |

**未修改**：AI 接口设计、数据库、游戏流程、无新玩法；from_dict 层 7 处已在 TASK-022 修复，本次复核无新遗漏。

## 2. 修改原因

- **根因**：AI 服务返回 JSON 经 `JSON.parse` 后全部为未类型化 Variant；`response.get("dialogue")` 得到的未类型化 Array 被直接 `return` 到 `-> Array[String]` 声明 → Godot 4 运行时拒绝（"Trying to return a value of type..."）。`generate_upgrade_options` 的 `upgrades` 是同一模式的潜伏点。
- **方案**：按任务要求新增统一适配层，所有 AI 响应字段转换收敛到一处；逐项类型验证（非强制 cast），保持强类型安全。

## 3. 测试结果

| 验证 | 结果 |
|---|---|
| Godot headless 启动（`--headless --quit`） | ✅ 0 脚本错误（SCRIPT ERROR / Parse Error / Invalid call / Invalid assignment / Trying to return 均为 0） |
| test_reward_system | 12/12 ✅ |
| test_reward_spawn_position | 11/11 ✅ |
| test_event_room | 16/16 ✅ |
| test_room_type_dispatch | 19/19 ✅ |
| test_room_lifecycle | 35/35 ✅ |
| test_floor_generation | 2001/2001 ✅ |
| test_monster_spawn_safety | 13/13 ✅ |
| test_monster_ai | 20/20 ✅ |
| 服务端 pytest（tests/ + ai/tests/） | ✅ 143 passed |

## 4. 剩余风险

| # | 风险 | 等级 | 说明 |
|---|---|---|---|
| 1 | AI 返回字段类型怪异（如 dialogue 字段直接是字符串而非数组） | 低 | `to_string_array` 返回空数组 → 走 fallback 模拟对话，行为安全 |
| 2 | AI 数值字段为超范围浮点（难度倍率 >3 等） | 低 | `to_float` 只做类型规整不做范围钳制；难度消费点（F6，零消费者）接入时可另行钳制 |
| 3 | 其他未发现的 AI 字段（未来新增 endpoint） | 低 | 适配层已存在，新代码遵循"统一经 adapter"约定即可 |
| 4 | 遗留问题清单（与本次无关） | — | 武器伤害双计（P1）、难度消费点（P1）、暴击硬编码（P1）、双重减伤（P2）、存档加载入口（P0/P1） |

---

**TASK-023 实施完成。按流程停止，等待人工验收后进入下一任务。**
