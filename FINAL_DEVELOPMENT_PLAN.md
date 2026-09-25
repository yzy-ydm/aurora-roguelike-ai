# FINAL_DEVELOPMENT_PLAN — 毕业设计最终收尾开发计划

> 生成日期：2026-09-24
> 依据：PROJECT_CURRENT_STATE_REPORT.md（真实状态）+ DEAD_CODE_AUDIT.md（死代码清单）
> 目标：把项目提升到**本科毕业设计答辩稳定版本**（真实性 / 稳定性 / 可演示 / 论文一致）
>
> 约束遵守：不新增大型玩法；不重构稳定架构（房间状态机/楼层DAG/战斗流程/存档架构均不动）；不修改 AI 服务端整体架构；所有修改测试通过后交付；发现的设计问题先说明影响、不做大改。
>
> **执行方式**：按既有工作流，每个任务单独实施 → 自查 → 测试 → 输出 TASK_REPORT → **停止等待人工验收** → 验收通过后提交 git。
>
> ⚠️ 前置待办（用户操作）：TASK-025 人工验收通过后立即 `git add -A && git commit && git push`（当前 6+2 个未提交文件）；尽快轮换已泄漏的 AGNES/MIMO API Key。

---

## P0 —— 必须完成（答辩前）

### P0-1. TASK-025 提交与版本保护
- **为什么需要**：工作区有 6 个修改 + 2 个新文件未入库，任何后续改动都建立在未保护状态上；版本保护是本轮工作的基础。
- **修改范围**：无代码改动；git 全量提交 + 推送 GitHub。
- **风险**：无（提交前跑一遍全量测试确认无回归）。
- **验收方式**：`git status` 干净；`git log origin/main..HEAD` 为空；GitHub 页面可见新提交。

### P0-2. AI 房间内容真实生效（修复 finalize 时序截断）
- **为什么需要**：论文题目核心是"AI 动态内容生成"。当前 `room_content`/`reward_generation` 两条 AI 管线被 `_on_fm_room_entered` 进房即 `content.finalize()` 的时序截断——AI 生成后必被丢弃（AI_FEATURE 6 项中 2 项是假功能）。这是"AI 内容真实作用于游戏"的最小修复。
- **修改范围**（客户端 floor_manager.gd + game_scene.gd，复用现有函数，不改状态机）：
  - 方案 B（预生成）：进入房间 N 时，对 N 的**前向未访问邻居**（1~2 个）后台发起 `generate_room_content_from_new` 预取，AI 结果在房间被进入**之前**写入 `room.content`（此时 content==null，两个守卫均不拦截）；
  - 玩家进入该房间时 `_ensure_room_content` 发现 content 已存在 → 直接使用 AI 内容，不再异步竞态；
  - AI 不可用/超时 → 预取失败 → 进房时 content 仍为 null → 走现有本地默认兜底（现有降级链路完全保留）。
- **风险**：中低。不动 finalize 守卫、不动房间状态机、不动战斗流程；新增 HTTP 请求量（每层约等于房间数的 2 倍）。需注意：预取结果要过 `validate_for_room_type()` 规则校验（复用现有调用）。
- **验收方式**：新增测试（预取写入→进房使用→fallback 兜底 3 条路径）；9 套旧测试全绿；headless 0 错误；人工实测：AI 服务开 mock 模式，进战斗房日志出现 "AI content applied"，怪物数量/等级与本地默认有可见差异。

### P0-3. AI 难度调整接入游戏（F-2 断裂修复）
- **为什么需要**："AI 自适应难度"是论文卖点（Phase 13 设计文档明示），当前 AI 难度结果只存不读。
- **修改范围**（客户端，3 个消费点）：
  1. `room_spawner._apply_monster_clamp`：对 `MonsterBalanceConfig.generate_monster_stats` 结果乘 `enemy_hp_multiplier` / `enemy_damage_multiplier`（经现有 GameScene→FloorManager 查找链取 `get_difficulty_adjustment()`）；
  2. `game_scene` 奖励生成处（`_on_combat_cleared`/`_on_boss_defeated`）：`reward_count = clamp(int(count * reward_multiplier), 1, 上限)`；
  3. `elite_spawn_rate`：**明确不消费**（当前精英由房间类型决定，无随机精英生成机制；加机制属新增玩法，违反约束）——论文不写此项。
- **风险**：低。乘数默认 1.0 时行为不变；钳制上限防止 AI 异常值（复用现有 clamp 模式）。
- **验收方式**：新增测试（乘数作用于怪物属性与奖励数量的纯逻辑）；旧测试全绿；人工实测：改 mock 难度上下文（如 combat_style=expert）后进战斗房，怪物 HP 明显高于 baseline。

### P0-4. NPC 对白 HUD 显示（F-3 断裂修复）
- **为什么需要**：AI NPC 对白是论文"动态叙事"章节的证据；当前对白生成后只有一行控制台日志，玩家完全看不到。
- **修改范围**（客户端）：
  - hud.tscn 新增一个 DialogueLabel（状态栏下方，自动换行，几秒后淡出或按句切换）；
  - floor_manager 新增 `dialogue_received(dialogue: Array[String])` 信号（替代 print）；
  - game_scene 连接信号 → HUD 逐条显示（用现有 set_status 风格，不新增玩法）。
- **风险**：低。纯 UI 增量；不影响任何流程。
- **验收方式**：旧测试全绿 + headless 0 错误；人工实测：REAL/mock 模式下进房，HUD 出现 NPC 对白文本并自动消失。

### P0-5. 论文六件套文档（阶段六交付物）
- **为什么需要**：毕业设计的最终交付物；答辩按文档展开。
- **修改范围**（纯文档，基于本报告与既有 50+ 份过程文档提炼）：
  1. ARCHITECTURE.md（在现有 2026-07-13 版基础上更新到当前架构：三端 + 数据流 + 降级策略）
  2. SYSTEM_DESIGN.md（系统设计：需求/模块划分/关键流程时序图）
  3. AI_DESIGN.md（AI 设计：Provider 抽象、11 生成端点、Prompt 体系、验证/质量/缓存/降级、**如实标注当前生效范围**）
  4. ALGORITHM_DESIGN.md（算法：分层 DAG 楼层生成算法 + V1~V7 校验、伤害公式、怪物平衡配置、房间状态机）
  5. DATABASE_DESIGN.md（基于 database/design 与 server/app/models 的 ER 设计）
  6. TEST_REPORT.md（9 套客户端测试 + 143 项服务端测试的覆盖说明与结果）
- **风险**：无代码风险；**诚实边界**：文档必须与代码一致（本报告 §4 的六功能判定表直接作为 AI_DESIGN 的"生效范围"章节素材）。
- **验收方式**：用户逐份审阅；文档中每个"已完成"断言都能在代码/测试中找到证据。

---

## P1 —— 建议完成（提升论文可信度与答辩安全性）

### P1-1. 武器伤害双计 + 玩家双重减伤修复（F-1 + F-2 数值，联动实测）
- **为什么需要**：伤害公式是答辩可能被追问的硬核问题；双计/双减属于"设计外行为"。
- **修改范围**：
  - damage_system.on_bullet_hit：`calculate_damage(attacker_attack, 0, ...)`（attacker_attack 已含武器伤害，不再二次加武器）；
  - 防御双计二选一（推荐保留 DamageSystem 百分比减伤，PlayerStats.take_damage 去掉 `- defense`，改由伤害系统统一）——或反向，取决于实测手感。
- **风险**：中。玩家 DPS 约降 25%、受击伤害上升，必须与怪物平衡（MonsterBalanceConfig）联动实测调整（可能需微调 NORMAL_ATK 或玩家 HP）。
- **验收方式**：数值单测断言新公式；全量测试绿；人工实测 3 场战斗：击杀时长与受击节奏可接受（TTK 目标参考 docs/Phase25_2_Combat_TTK_Analysis.md）。

### P1-2. 暴击成长接线（F-3）
- **为什么需要**："暴击强化"升级目前完全无效（升级面板可选出，但无效果——演示时被点破会很尴尬）。
- **修改范围**：
  - weapon._fire：`crit_rate = owner.get_stats().get_crit_rate()`（子弹新增 crit_multiplier 字段传递 get_crit_multiplier()）；
  - damage_system.on_bullet_hit：用子弹携带的 crit_multiplier 替代硬编码 ×1.5。
- **风险**：低。默认值（0.1/×1.5）与现状完全一致，不改变 baseline 手感。
- **验收方式**：新增测试（crit_rate_bonus 生效）；全量测试绿；人工实测：选"暴击率+10%"强化后暴击出现频率肉眼可辨。

### P1-3. API Key 轮换 + .env.example 占位符化（用户操作 + 我改文件）
- **为什么需要**：公开仓库中的真实密钥随时可能被盗刷；答辩展示 GitHub 仓库时这是安全隐患。
- **修改范围**：用户到 AGNES/MiMo 平台轮换两个 Key（我无法代办，需用户操作）；轮换后我把 .env.example 的 Key 替换为占位符并提交。
- **风险**：轮换前旧 Key 仍有效（尽快）。
- **验收方式**：.env.example 无真实 Key；本地 .env 用新 Key 后 AI 服务恢复正常调用。

### P1-4. context_event 面板接线（AIEventPanel/AIEventManager 复活）
- **为什么需要**：context_event 是"玩家行为→AI 上下文事件"论文卖点，当前只有一行 HUD 文本、选项不可选，是半成品状态；接线材料（面板脚本+管理器脚本）已存在，是纯接线工作。
- **修改范围**：game_scene 代码创建 AIEventManager + AIEventPanel（或 tscn 加节点）→ set_event_manager 接线 → _show_ai_event 走面板 → 选择回调应用奖励/风险（_apply_reward 已有实现）→ 完成恢复 EXPLORATION。事件房（本地事件）可复用同一面板。
- **风险**：中低。涉及 UI 弹出时玩家控制开关（复用 TASK-003 的 set_control_enabled 模式）。
- **验收方式**：旧测试全绿；人工实测：进房弹出事件面板、三选一、奖励（金币/攻击）生效、面板关闭后控制恢复。

### P1-5. Boss 多阶段技能：决策（接入 或 论文不写）
- **为什么需要**：BossController 技能/阶段代码全部存在但零调用（Boss 由 MonsterAI 驱动）。两个选项：
  - A：接入——monster_node 对 Boss 每帧调 boss_controller.update(delta)，需回归实测 Boss 战（风险中）；
  - B：论文不写"多阶段技能"，Boss 章节只写"独立数值体系+专属奖励+楼层 Boss 流程"（风险零）。
- **修改范围**：选 A 才动代码（monster_node/combat_manager/room_spawner 信号核对）；选 B 不动代码，仅文档边界。
- **风险**：A 为中（Boss 战是主流程，改动可能影响通关节奏）。
- **验收方式**：选 A：Boss 战人工实测 3 层；选 B：论文与答辩口径一致。
- **默认建议**：选 B（符合"不扩大范围"约束；Boss 战现状已可完整演示）。

---

## P2 —— 可选优化（时间充裕再做）

### P2-1. 死代码清理
- **为什么需要**：仓库有约 20 个运行时不可达脚本（DEAD_CODE_AUDIT.md §一）；毕业设计评审时"整洁度"是软加分项。
- **修改范围**：仅删除审计确认的 A1/A2/A3 类文件（先全量提交一版备份，git 可回溯）；禁止删除 save_system.gd 与 fake_ai_service.gd（论文降级/双方案素材）。
- **风险**：低（引用已逐一核对）；注意 boss_controller.gd 保留被动接口（take_damage/get_attack 等被 room_spawner/monster_node 使用）。
- **验收方式**：删除后 headless 启动 0 错误 + 全量测试绿。

### P2-2. 首次存档楼层修复（F-6）
- **为什么需要**：首次保存（POST 创建路径）服务端硬编码 current_floor=1。
- **修改范围**：schemas/save.py 加 `current_floor: Optional[int]`；services/save_service.py 用之（默认 1 保持兼容）。
- **风险**：极低（服务端小改 + pytest）。
- **验收方式**：新增/沿用 pytest 断言创建时楼层写入；人工验收首次保存后继续游戏显示正确楼层。

### P2-3. 存档统计接线（F-7）
- **为什么需要**：kill_count/gold_collected 恒 0，存档面板统计失真。
- **修改范围**：GameStateManager 加运行时计数器（怪物击杀/金币拾取时累加），get_save_data 写入。
- **风险**：低。
- **验收方式**：测试断言累加；人工验收杀怪拾金后存档数值>0。

### P2-4. heal_on_kill / move_speed 接线或降级
- **为什么需要**：两个强化选项无效（F-4/F-5）；两选一：接线（击杀时 heal、移动读 get_final_move_speed）或从升级池移除并论文不写。
- **修改范围**：接线=monster_died 回调 + player_controller 移动速度读取（小改动）；移除=upgrade_manager 池子删两项。
- **风险**：低。
- **验收方式**：对应测试 + 人工实测。

### P2-5. 三槽位存档 UI（可选，不推荐答辩前做）
- **为什么需要**：save_selection 面板为三槽位设计，实际仅槽位 1 可用。
- **修改范围**：面板与 enter_game/load_save_by_slot 全链路（中改动，涉及 UI 流程）。
- **风险**：中（存档是 P0 级功能，改动不当影响主流程）。
- **验收方式**：三槽位保存/读取/覆盖人工全流程。
- **默认建议**：答辩前不做；论文写"单槽位存储、三槽位架构预留"。

---

## 执行顺序建议

```
TASK-025 人工验收（用户）
  → P0-1 提交推送
  → P0-2 AI房间内容生效 → P0-3 难度消费 → P0-4 对白显示
  → P0-5 论文六件套（与 P0-2~4 并行推进，代码定稿后最终修订）
  → P1-1 伤害公式（联动实测）→ P1-2 暴击接线 → P1-3 Key轮换 → P1-4 事件面板 → P1-5 Boss决策
  → P2（按剩余时间取舍）
  → 最终全量审计 + 真实运行游戏完整通关测试 + FINAL_PROJECT_REPORT.md
```

**答辩演示最小闭环（P0 完成后即具备）**：登录 → 新游戏 → 战斗（AI 房间内容生效）→ 升级（AI 选项）→ 事件（HUD 提示）→ 对白显示 → 难度随表现变化 → 存档 → 退出 → 继续游戏 → Boss → 下一层。

---

**本计划等待用户确认后执行。**
