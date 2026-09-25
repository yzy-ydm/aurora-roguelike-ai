# Phase 18.1_IMPLEMENTATION_REPORT — 数据状态一致性审计与修复

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**（按要求未提交 git）
> 交付物：STATE_FLOW_AUDIT.md（完整数据流审计）+ 本报告
> 触发：重新登录加载后 HUD 显示 profile 快照（level=1/exp=0/gold=0/health=0/100/attack=10/defense=5）
> 与数据库存档（level=5/exp=279/gold=160/hp=295/329/attack=81/weapon_id=3）不一致。

---

## 1. 修改文件列表

| # | 文件 | 改动 |
|---|---|---|
| 1 | client/scripts/managers/game_state_manager.gd | ① set_player_data 字段名规整（health→current_health、experience_to_next_level→experience_to_next）；② set_current_save **无条件先写缓存**（旧实现仅 _runtime_stats==null 时写） |
| 2 | client/scripts/managers/game_flow_controller.gd | enter_game 内存存档列表为空时**先拉取服务端最新列表再决定**（杜绝有档却以 profile 开新局） |
| 3 | STATE_FLOW_AUDIT.md | **新增**：完整数据流/实例审计/字段核对/JSON 结构约定/剩余风险 |
| 4 | client/tests/test_full_progress_save_restore.gd | **新增**：用户指定全流程测试（真实 HTTP，17 检查项） |

## 2. 发现的问题（3 个）

### 问题 1（HUD health=0/100 的直接根因）：profile 字段形状不匹配

- **证据**：profile API 实际返回 `{"health":100, "experience_to_next_level":100, "level":1, "attack":10, "defense":5, "gold":0, ...}` —— 而运行时/HUD 统一读 `current_health` / `experience_to_next`。
- **后果**：HUD `get("current_health", 0)` 键缺失 → 返回 0 → 显示 **0/100**；其余字段与用户报告逐一吻合（level=1/exp=0/gold=0/atk=10/def=5 = 注册时的 profile 快照，游戏从不回写 player_profiles）。
- **修复**：`set_player_data` 入口统一字段名规整 + 默认值兜底。

### 问题 2（level/gold 被 profile 覆盖）：set_current_save 缓存分支不对称

- **旧实现**：仅当 `_runtime_stats == null` 时才 `_player_data = player_state`；若残留旧运行时引用 → 缓存停留在 profile → 新场景玩家链接前 `get_player_data()` 返回 profile → 整局以登录快照开局。
- **修复**：`_player_data = player_state` **无条件先行写入**，再按需同步运行时引用。

### 问题 3（有档却开新局）：自动进入依赖内存列表

- 登录后自动进入游戏直接读内存存档列表；列表为空（任何瞬态原因）→ 判定"无存档" → profile 开局。
- **修复**：enter_game 列表为空时先拉取服务端最新存档（最长 5 秒）再决定。

## 3. 为什么产生（根因链）

1. **双字段名体系并存**：服务端 profile 响应沿用旧命名（health/experience_to_next_level），客户端运行时体系用新命名（current_health/experience_to_next），只有 HUD 读缺失键时才暴露（运行时 sync_from_dict 是增量语义，缺键静默跳过）。
2. **缓存覆盖条件不对称**：`set_current_save` 的两个分支只有一半写缓存——防御性写法针对"运行时已链接"场景，但未考虑"缓存必须始终反映存档"的契约。
3. **信任内存快照**：自动进入路径未做"列表为空 → 服务端确认"的兜底。

> 说明：数据本身（运行时→保存→数据库）经 DB 直查完全正确（level=5/gold=160/hp=295/attack=81/weapon_id=3 均在库），问题全部在**恢复链的读取侧**。

## 4. 测试结果（全部真实运行）

| 套件 | 结果 |
|---|---|
| **test_full_progress_save_restore（新，用户指定全流程，真实 HTTP）** | ✅ **17/17** —— 金币100/等级5/经验300/生命300/攻击50/冰霜法杖Lv3 → 保存 → 重新登录（含 profile 步骤）→ 全字段一致；含 HUD 数据源完整性断言 |
| 其余 20 套客户端测试 | ✅ 全绿（16/2001/20/13/11/12/35/19/11/8/6/8/11/8/4/7/11/12/15/10） |
| test_save_integration | ✅ 12/12 |
| 服务端 pytest app/tests + ai/tests | ✅ 5 + 143 |
| Godot headless 启动 | ✅ 0 脚本错误 |

## 5. 剩余风险

| # | 风险 | 说明 |
|---|---|---|
| R1 | room 级进度不存档 | 继续游戏后当前楼层重新生成（设计限制，论文如实表述） |
| R2 | profile 快照永不更新 | 游戏进度只写 game_saves 不回写 player_profiles（分层设计：profile=账号层，save=进度层）；主菜单"玩家信息"面板显示的 profile 数据恒为注册快照——**如需面板显示最新进度，属后续任务** |
| R3 | move_speed/crit 等加成字段 | 存档/恢复完整，游戏内消费为已知 backlog，不影响一致性 |

## 6. 人工验收步骤（服务端已运行、存档已清空）

1. 新游戏 → 打到 3+ 层，途中升级/吃强化/捡金币（让 level/gold/hp/attack 明显偏离初始值）。
2. ESC → 退出到主菜单 → 槽位 1 保存成功。
3. 退出登录 → 重新登录 → 自动进入游戏（或主菜单"继续游戏"）。
4. **HUD 显示与保存时一致**：等级、经验、金币、HP（非 0/100）、攻击、武器。
5. 再测一轮：登录后直接"继续游戏"路径同样一致。

通过标准：等级/经验/金币/生命/攻击/武器全部与保存时一致，无脚本报错。

---

**Phase 18.1 实施完成。未提交 git，等待人工验收。**
