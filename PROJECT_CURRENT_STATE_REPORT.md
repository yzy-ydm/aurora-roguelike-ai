# PROJECT_CURRENT_STATE_REPORT — 项目当前真实状态报告

> 生成日期：2026-09-24（新接手工程师视角，全部结论基于当前代码逐行复核，不采信旧报告）
> 审计方式：Git 状态核对 + 全量代码扫描 + AI 六功能闭环追踪 + 核心系统数值审计 + 死代码引用分析 + 测试套件实跑
> 配套文档：DEAD_CODE_AUDIT.md（死代码清单）、FINAL_DEVELOPMENT_PLAN.md（最终收尾计划）

---

## 1. 项目快照

| 项 | 状态 |
|---|---|
| 当前分支 | `main`，与 `origin/main` **完全同步**（无未推送提交） |
| 未提交改动 | **TASK-025 存档流程修复**：6 个修改文件 + 2 个未跟踪文件（game_scene.gd / main_scene.gd(.tscn) / game_flow_controller.gd / game_state_manager.gd / player_controller.gd / TASK-025_IMPLEMENTATION_REPORT.md / tests/test_save_state.gd），**等待人工验收后提交** |
| 最近提交 | a324f45 "chore: complete system audit baseline before final optimization"（TASK-017.7 ~ 024 全部代码与 18 份报告已入库） |
| 客户端测试（本次实跑） | ✅ 9 套全绿：16/16、2001/2001、20/20、13/13、11/11、12/12、35/35、19/19、11/11（test_weapon_growth 需包装脚本，本次未计入） |
| 服务端测试（本次实跑） | ✅ pytest 143 passed |
| Godot headless 启动 | ✅ exit 0，0 脚本错误 |
| 本地运行环境 | Godot 4.7（D:\Godot_v4.7-stable_win64.exe\...console.exe）；游戏服务 :8000、AI 服务 :8001 依赖 MySQL 8.0（库 aurora_game） |

---

## 2. 当前项目真实完成度

### 2.1 分维度评估

| 维度 | 完成度 | 说明 |
|---|---|---|
| 工程骨架（客户端+双服务端+MySQL+JWT） | **~95%** | 三层架构完整、稳定运行、测试全绿 |
| Roguelike 核心玩法（DAG楼层/房间状态机/战斗/奖励/升级） | **~90%** | 状态机与地图闭环经 TASK-001~006/017.7~018 多轮修复，9 套测试覆盖 |
| AI 服务端能力（11 端点/验证/缓存/降级/限流/记录） | **~90%** | MiMo 真实 LLM 已接入（LLM_PROVIDER=mimo），有 mock 降级 |
| **AI 动态内容真实生效程度** | **~30%** | 6 个生成功能中仅 1 个完全闭环、1 个部分可见、2 个断裂、2 个被时序截断（详见 §4）；AI 楼层拓扑生成已按 Phase 25 设计停用 |
| 存档系统 | **~85%** | TASK-025 后闭环（槽位/继续游戏/楼层恢复），3 个小缺陷待修（§5） |
| 毕业设计文档 | **~40%** | 论文六件套（ARCHITECTURE/SYSTEM_DESIGN/AI_DESIGN/ALGORITHM_DESIGN/DATABASE_DESIGN/TEST_REPORT）尚未产出 |

> 原 README/PROJECT_STATUS 宣称"总体进度 ~90%"为**工程层面**口径；若按"论文题目声称的 AI 动态内容生成能力是否真实作用于游戏"衡量，当前约 **30%**。这是本次审计与旧文档的最大分歧点。

### 2.2 已完成系统（代码级确认）

| 系统 | 证据 | 状态 |
|---|---|---|
| 登录认证 | JWT + bcrypt（server/app/api/auth/），登录→注册→开发者快速登录 | ✅ |
| 玩家系统 | 横版移动/跳跃（Coyote/缓冲）/冲刺/无敌帧/击退/死亡重生，player_controller.gd 893 行 | ✅ |
| 战斗系统 | DamageSystem 唯一入口、子弹碰撞、伤害数字、CombatManager 状态机、按住连发、怪物攻击前摇、出生保护 | ✅ |
| 怪物系统 | MonsterEntity/MonsterAI/MonsterNode，坐标统一（TASK-017.7）、速度平衡、平台感知出生点（TASK-017.8/018.0） | ✅ |
| Boss 战 | 可生成、可战斗（由 MonsterAI 驱动）、可击败、专属奖励、下一层传送门 | ✅（技能/阶段为死代码，见下） |
| 房间/楼层系统 | 分层 DAG 生成 + V1~V7 校验（2001 项测试）、RoomState 状态机（35 项测试）、Portal 选择 + 紧急出口防软锁 | ✅ |
| 奖励系统 | 平台感知生成位置、浮动动画、拾取、清怪→REWARD→COMPLETED 流程（12+11+16+19 项测试） | ✅ |
| 升级系统 | EXP 曲线、连续升级、3 选 1 面板、AI 选项优先+本地池补足 | ✅ |
| 存档系统 | 保存（PUT/404→POST）/存档列表/槽位 1/继续游戏/楼层与属性恢复（11 项新测试，待人工验收） | ✅（有小缺陷） |
| 游戏服务端 | 7 组 REST 路由（auth/player/weapon/monster/save/map/event）、SQLAlchemy+MySQL | ✅ |
| AI 服务端 | 11 个生成端点、ProviderFactory（mock/agnes/mimo）、验证器、质量检查器、缓存、限流、请求记录、Token 认证 | ✅ |
| 客户端 AI 管线 | Token 管理（401 自动刷新）、请求封装、JSON 适配层（TASK-022/023）、缓存 | ✅ |

### 2.3 未完成/断裂系统（代码级确认）

| 系统 | 状态 | 详情 |
|---|---|---|
| AI 难度调整 → 游戏生效 | ❌ 断裂 | §4.5 |
| AI NPC 对白 → UI 显示 | ❌ 断裂 | §4.6 |
| AI 房间内容 → 怪物/奖励 | ⚠️ 假功能 | §4.4（AI 生成后被 finalize 时序截断，玩家实际玩到的是本地默认内容） |
| AI 楼层拓扑生成 | ⏸ 按设计停用 | Phase 25 锁定：FloorGenerator 是唯一拓扑源；客户端 generate_floor_content 仅剩死代码调用方 |
| Boss 多阶段技能 | ❌ 未接入 | boss_controller.gd 的 update()/技能/阶段转换全工程零调用点（Boss 由 MonsterAI 驱动）；论文不可写 |
| 暴击成长 | ❌ 未接线 | 暴击率硬编码 0.1、倍率硬编码 ×1.5；crit_rate_bonus/crit_damage_bonus 零消费者 |
| 移动速度加成 | ❌ 未接线 | 移动用 MOVE_SPEED=200 常量；move_speed_bonus 零消费者 |
| 击杀回血强化 | ❌ 未接线 | heal_on_kill 可写入但零读取 |
| 交互/物品系统 | ❌ 运行时无对象 | ObjectManager 运行时零对象生成 → 武器拾取/宝箱交互/背包全链路不可达 |
| 存档统计字段 | ⚠️ 恒 0 | kill_count/gold_collected 无累加来源 |
| 三槽位 UI | ⚠️ 仅槽位 1 | save_selection 面板为三槽位设计，实际只走槽位 1 |

---

## 3. 本次审计的两个关键修正（相对旧报告）

1. **AI 闭环计数修正**：TASK-024 审计（AI_FEATURE_FLOW_AUDIT.md）结论"4/6 完整闭环"，经逐行时序复核**不成立**：
   - `room_content` 与 `reward_generation` 号称"完整闭环"，实际上 `game_scene._on_fm_room_entered` 在进房**同一帧**调用 `content.finalize()`；AI HTTP 响应至少 1 帧后才返回，命中 `is_finalized` 守卫 → **AI 内容 100% 被丢弃**（战斗房还会命中 `monster_count > 0` 第二道闸）。玩家看到的怪物数量/等级/奖励全部来自本地默认 RoomContentData。
   - `context_event` 号称"事件面板弹出、玩家可选"——实际 game_scene.tscn **不存在** UI/AIEventPanel 节点，AIEventPanel/AIEventManager 从未被实例化，最终只落为 HUD 状态栏一行文本（标题+描述），**选项不可见、奖励/风险不生效**。
   - 结论：真正完整闭环仅 `upgrade_options` 1 项；`context_event` 部分可见；`difficulty_adjustment`、`npc_dialogue` 断裂（与旧审计一致）；`room_content`、`reward_generation` 为**假功能**。
2. **"完成度 ~90%"口径修正**：见 §2.1。

---

## 4. AI 六功能闭环逐项验证（输入→生成→解析→消费）

| # | 功能 | 生成端 | 解析端 | 游戏消费端 | 判定 |
|---|---|---|---|---|---|
| 1 | context_event | ✅ AIContentService.generate_context_event → POST /api/generate/context_event（服务端含 LLM+fallback） | ✅ AIResponseAdapter + AIEventData.from_dict | ⚠️ 信号→GameScene→**无面板节点→仅 HUD 文本**；选项/奖励/风险不生效 | **部分实现** |
| 2 | room_content | ✅ generate_room_content_from_new → POST /api/generate/room | ✅ parse_room_content + validate_for_room_type | ❌ **进房即 finalize → AI 结果必被丢弃**；实际怪物/奖励来自本地默认 | **假功能** |
| 3 | reward_generation | ✅ 随 room_content（rewards 段） | ✅ RoomContentData.reward_items | ❌ 同一 finalize 截断；AI 奖励策略（strategy/items）永不生效 | **假功能** |
| 4 | upgrade_options | ✅ generate_upgrade_options → POST /api/generate/upgrade | ✅ to_dictionary_array + UpgradeData.from_dict | ✅ LevelUpPanel 3 选 1 → apply_upgrade → PlayerStats 生效 | **完整闭环** |
| 5 | difficulty_adjustment | ✅ generate_difficulty_adjustment → POST /api/generate/difficulty | ✅ to_float 规整 | ❌ 仅存 FloorManager._difficulty_adjustment；唯一读取者 ai_debug_panel.gd 是死代码；怪物生成/伤害计算不读 | **断裂** |
| 6 | npc_dialogue | ✅ generate_npc_dialogue → POST /api/generate/dialogue | ✅ to_string_array | ❌ 仅 `print("[FloorManager] AI dialogue received: N lines")` | **断裂** |

另：`generate_floor_content`（AI 楼层拓扑）按 Phase 25 设计锁定停用；`generate_room_event`（旧事件）、`generate_room_strategy`、`generate_npc_memory_response` 在客户端**零调用点**（服务端端点存在）。

---

## 5. 已知问题清单（按严重度）

### 5.1 数值/真实性问题

| # | 问题 | 证据 | 影响 |
|---|---|---|---|
| F-1 | 武器伤害双重计入 | player_controller.get_attack() 已含 weapon_instance.get_damage()（:536-544）；damage_system.on_bullet_hit 又传 bullet 的 weapon_damage 做 base = attack + weapon_damage（:60-73） | 玩家实际伤害比设计高一个武器伤害档位 |
| F-2 | 玩家防御双重减伤 | DamageSystem.calculate_damage 先做 def/(def+100) 百分比减伤（:31-34），PlayerStats.take_damage 再减 flat defense（:182 `max(1, amount - defense)`） | 玩家受击伤害被减两次 |
| F-3 | 暴击成长零接线 | weapon._fire 硬编码 crit_rate=0.1（:137）；damage_system 硬编码 ×1.5（:39,77-79）；PlayerStats.get_crit_rate()/get_crit_multiplier() 全工程零调用 | "暴击强化"升级完全无效 |
| F-4 | 击杀回血零接线 | heal_on_kill 仅 upgrade_manager 写入（:242），全工程零读取 | "嗜血"强化无效 |
| F-5 | 移动速度加成零接线 | 移动用常量 MOVE_SPEED（player_controller:221），move_speed_bonus 零读取 | "速度强化"升级无效 |
| F-6 | 首次存档楼层丢失 | 服务端 save_service.create_save 硬编码 current_floor=1（save_service.py:91）；SaveCreate schema 无该字段 | 新存档首次保存（404→POST 路径）楼层记录为 1 |
| F-7 | 存档统计字段恒 0 | 客户端 kill_count/gold_collected 无任何累加来源 | 存档面板统计无意义 |
| F-8 | Boss 血条冻结 | boss_health_bar.set_controller 零调用者 → boss_damaged 信号未连接 → 血条只显示满血初值 | Boss 战 UI 不可信（可演示但需提前知道） |

### 5.2 流程/健壮性问题

| # | 问题 | 说明 |
|---|---|---|
| P-1 | 怪物数值与 AI 内容脱钩 | 即使 AI 房间内容生效，_apply_monster_clamp 也会用 MonsterBalanceConfig 覆盖 health/attack/defense/speed（room_spawner.gd:229-243），AI 的 monster_level 才是有效输入。论文表述需注意 |
| P-2 | 事件房事件为本地随机 | game_scene._generate_random_event() 硬编码 4 个事件；AI generate_room_event 是死函数。事件房体验与 AI 无关 |
| P-3 | 交互系统运行时零对象 | ObjectManager 无 add_object 调用 → 武器拾取/宝箱交互/背包 UI 链路不可达（代码保留） |
| P-4 | AI 服务 token 内存态 | 服务端 auth 为内存 token（重启失效）；客户端已有 401 自动刷新+重试（TASK-020），闭环成立 |
| P-5 | 每房进房都触发 AI context_event 请求 | floor_manager._request_ai_room_content 对所有房间类型发起（含战斗房），REAL 模式下每次进房多 2 个 HTTP 请求（event+dialogue），仅换来一行 HUD 文本 |

### 5.3 安全/工程问题

| # | 问题 | 说明 |
|---|---|---|
| S-1 | **API Key 泄漏** | server/.env.example 含真实 AGNES_API_KEY 与 MIMO_API_KEY 明文，已随提交 27fcfe3 推送到公开仓库。**用户必须尽快轮换两个 Key**（账号操作，无法代办）；后续 .env.example 只放占位符 |
| S-2 | 未提交改动 | TASK-025 6+2 文件在工作区未提交（等待人工验收后提交推送） |
| S-3 | 死代码量大 | 约 20 个脚本运行时不可达（详见 DEAD_CODE_AUDIT.md）；按约束不删除，仅记录 |

---

## 6. 与毕业论文题目的匹配程度

题目：《基于云端AI动态内容生成能力的2D横版Roguelike游戏系统设计与实现》

| 题目要素 | 匹配度 | 说明 |
|---|---|---|
| 2D 横版 Roguelike 游戏系统 | ✅ 高 | 玩法系统完整可玩（移动/跳跃/战斗/房间/楼层/奖励/升级/Boss） |
| 云端 AI（服务端） | ✅ 高 | FastAPI AI 服务 + 真实 MiMo LLM（Anthropic 格式）+ Agnes 备选 Provider + mock 降级，11 个生成端点、验证/质量检查/缓存/限流/记录齐全，pytest 143 项 |
| AI 动态内容生成能力（客户端消费） | ⚠️ 中低 | 6 个功能仅升级选项真实生效；事件部分可见；难度/对白断裂；房间内容/奖励被时序截断 |
| 网络通信（HTTP REST + JWT） | ✅ 高 | 双服务端 + JWT/bcrypt + AI Token + 401 恢复 |
| 数据库 | ✅ 高 | MySQL + SQLAlchemy（用户/玩家/武器/怪物/地图/事件/存档表） |

**论文写作边界（当前状态下）**：
- ✅ 可写：系统架构（双服务端设计）、AI 服务链路（Prompt 构建→LLM 调用→验证→质量检查→缓存→降级→数据库记录）、升级选项个性化生成（唯一完全闭环）、登录/存档/资源网络协议、DAG 楼层算法（论文可写为本地生成+AI 增强内容的结构）。
- ❌ 不能写（未修复前）：动态难度实时生效、AI 生成楼层拓扑、AI 对白展示、AI 房间内容生效、Boss 多阶段技能、存档多槽位 UI。
- 建议答辩策略：如实表述"AI 增强层"当前生效范围，主动说明断裂点的修复计划（FINAL_DEVELOPMENT_PLAN.md）。

---

## 7. 结论

1. 项目**工程基础扎实**：三端架构完整、双端测试全绿（客户端 9 套、服务端 143）、核心玩法闭环稳定——具备答辩演示条件。
2. 项目**最大短板是 AI 内容的真实生效度**：6 个 AI 功能只有 1 个完整闭环。这是论文题目（AI 动态内容生成）的核心主张，必须在答辩前修复至少 3 项（房间内容生效、难度消费、对白显示）。
3. 版本保护与安全动作：TASK-025 验收后立即提交推送；用户轮换已泄漏的 API Key。
4. 全部修复建议（P0/P1/P2 分级、方案、风险、验收）见 FINAL_DEVELOPMENT_PLAN.md，**等待确认后实施**。

---

**本报告基于 2026-09-24 当前代码生成。审计过程未修改任何代码。**
