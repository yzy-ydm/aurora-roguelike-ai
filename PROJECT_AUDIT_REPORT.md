# Aurora-Roguelike-AI 项目完整审计报告

> 审计时间：2026-09-23
> 审计对象：《基于云端AI动态内容生成能力的2D横版Roguelike游戏系统设计与实现》
> 审计方式：静态代码审计（客户端 95 个 GDScript 脚本 / 22 个场景、服务端 55+ Python 源文件、SQL 脚本、配置与文档）+ **真实运行验证**（Godot 4.7 无头启动、服务端测试套件、客户端测试套件、进程状态检查）
> 审计原则：**不采信任何既有 Phase 报告结论**。所有判断以当前工作区代码为准（含 12 个未提交修改文件），并引用具体文件与行号；所有可运行验证项均已实际执行，结果见附录 A。

---

## 0. 审计方法与实测记录（摘要）

| 验证项 | 方式 | 结果 |
|---|---|---|
| 客户端能否无错启动 | `Godot_v4.7-stable_win64_console.exe --headless --path client --quit` | ✅ 零报错，10 个 Autoload 全部初始化，登录场景就绪 |
| 客户端武器成长测试 | SceneTree 包装器运行 `tests/test_weapon_growth.gd` | ✅ 12 passed, 0 failed（注：该测试无法直接 headless 运行，需包装脚本） |
| AI 服务端测试套件 | `python -m pytest ai/tests/ -q` | ✅ 143 passed（10 个测试文件） |
| MySQL 数据库 | netstat + tasklist | ✅ 运行中（:3306 LISTENING，mysqld.exe ×2） |
| 游戏服务端 (:8000) | netstat | ❌ 未启动 |
| AI 服务端 (:8001) | netstat | ❌ 未启动 |
| 工作区状态 | git status | ⚠️ 12 个客户端文件有未提交修改（上一个会话的 Phase 24-27 半成品）+ REFACTOR_PLAN.md 未跟踪 |

---

## 1. 当前项目结构分析

### 1.1 总体架构（实际部署形态）

```
┌─────────────────────────────────────────────────────────────────┐
│ Godot 4.7 客户端 (client/, ~23,700 行 GDScript, 95 脚本/22 场景) │
└──────┬──────────────────────────────┬───────────────────────────┘
       │ 登录/玩家/武器/怪物/存档等      │ 楼层/房间/怪物/武器/事件/
       │ REST API                     │ 对话/升级/难度 生成请求
       ▼                              ▼
┌──────────────────────┐    ┌────────────────────────────────────┐
│ 游戏服务端 :8000      │    │ AI 内容服务端 :8001                │
│ server/main.py       │    │ server/ai/main.py                  │
│ FastAPI 分层架构      │    │ ProviderFactory → agnes / mimo /   │
│ Router→Service→      │    │ mock（缓存+验证+质检+限流+日志）     │
│ Schema→Model         │    │ 生成记录 → SQLite (server/ai/data) │
└──────────┬───────────┘    └────────────────────────────────────┘
           ▼
┌─────────────────────────────────────────────────────────────────┐
│ MySQL 8.0 (aurora_game 库, 9 张表, 当前运行中)                    │
└─────────────────────────────────────────────────────────────────┘
```

**三个进程 + 一个数据库**。客户端是唯一入口，两个 FastAPI 服务互相独立（无服务端间调用），AI 生成记录不入 MySQL 而是写本地 SQLite。

### 1.2 客户端模块（Godot 4.7）

**Autoload 单例（10 个，project.godot:23-34）**：
APIConfig / TokenManager / ApiClient（信号广播式）/ SceneManager / ResourceManager【死代码】/ ResourceService / GameStateManager / SaveService / GameFlowController / SettingsManager

| 模块目录 | 文件 | 状态说明 |
|---|---|---|
| scripts/api/ | api_client.gd, api_config.gd, token_manager.gd | 活跃。ApiClient 广播式响应分发（见问题 3.1-5） |
| scripts/managers/ | game_flow_controller.gd(253), game_state_manager.gd(352), scene_manager.gd, settings_manager.gd, resource_manager.gd(99), save_system.gd(195), analytics_manager.gd(270) | 前 4 个活跃；ResourceManager、SaveSystem 为死代码；AnalyticsManager 已接线 |
| scripts/services/ | resource_service.gd(354), save_service.gd(160) | 活跃（资源降级 + API 存档） |
| scripts/ai/ | ai_content_service.gd(1375), ai_cache_manager.gd(202), ai_context_manager.gd(277), ai_quality_checker.gd(335), ai_response_parser.gd(209), ai_validator.gd(266), behavior_analyzer.gd(164), fake_ai_service.gd(247), npc_memory_manager.gd(174), player_behavior_data.gd(300), ai_room_content.gd(73)【死】 | AIContentService 为 1375 行网关；ai_room_content 无接线 |
| scripts/combat/ | combat_manager.gd(287), damage_system.gd(297), weapon.gd(182), weapon_instance.gd(133), bullet.gd(258), damage_number.gd, hit_effect.gd | 活跃（伤害公式存在双计问题 B-12） |
| scripts/enemy/ | monster_node.gd(364), monster_ai.gd(209), monster_entity.gd(195), monster_spawner.gd(313)【死】 | MonsterAI 坐标混用（B-02） |
| scripts/boss/ | boss_controller.gd(450), boss_data.gd(127) | BossController.update() 全项目无调用方（B-03） |
| scripts/drop/ | reward_item.gd(518), drop_manager.gd(343)【死】 | 奖励动画起点 bug（B-01） |
| scripts/world/ | floor_manager.gd(410), floor_generator.gd(191), room_renderer.gd(623), room_spawner.gd(555), world_coordinate.gd(116), background_manager.gd(418), room_clear_feedback.gd(222), room_content_manager.gd(178), room_decoration_manager.gd(236)【无调用方】, room_manager.gd(311)【死】, world_manager.gd(182)【死】, map_renderer.gd(183)【死】, room_graph.gd(257)【死】 | 核心玩法链路在 floor_manager→renderer→spawner |
| scripts/player/ | player_controller.gd(867), player_stats.gd(313) | 活跃。属性加成未接入（B-13） |
| scripts/progression/ | upgrade_manager.gd(335), upgrade_data.gd(162) | 已接线（升级面板链路存在） |
| scripts/models/ | new_room_data.gd(214), room_content_data.gd(238), floor_data.gd(147), monster_data.gd, monster_balance_config.gd(116), weapon_data.gd, reward_data.gd(456), map_data.gd, event_data.gd, upgrade_data.gd, room_data.gd(75)【死】, room_node_data.gd(164)【半死】 | NewRoomData 体系活跃；RoomData/RoomNodeData 为旧模型残留 |
| scripts/entity/ | entity.gd, entity_manager.gd【死】, player_entity.gd【死】 | 仅 entity.gd 被 MonsterEntity 继承 |
| scripts/events/ | ai_event_data.gd, ai_event_manager.gd(214)【无接线】 | 事件房走 game_scene 简化路径 |
| scripts/interaction/ | interaction_manager.gd, interaction_detector.gd, interactive_object.gd | 已接线但零内容（无任何可交互对象） |
| scripts/inventory/ | inventory_manager.gd(98), equipment_manager.gd(77)【空壳】 | 动态创建于 GameScene，装备管理器无功能调用 |
| scripts/object/ | game_object.gd, object_manager.gd(157)【空注册】, test_chest.gd【测试残留】 | 无生成方 |
| scripts/ui/ | hud_controller, pause_menu, settings_menu, save_selection, level_up_panel(368), boss_health_bar, attribute_popup, resource_center, interaction_hint, ai_debug_panel(126)【死】, ai_event_panel(75)【死】, ai_status_display(82)【死】, network_stats_ui【死】 | HUD/暂停/升级/血条活跃 |
| scripts/weapon/ | weapon_object.gd(92)【死】 | 无生成方 |
| scenes/ | game/（game_scene.gd **1540 行上帝类** + hud + player + monster + bullet + reward_item 等 tscn）、login/、main/、ui/(7)、world/(2)【死】、object/(1)【死】、test/(1)【死】、drop/ | 22 个场景中 4 个无加载方 |
| tests/ | test_weapon_growth.gd | 唯一客户端测试；无法直接 headless 运行 |

### 1.3 服务端模块

**游戏服务端 server/（FastAPI, :8000, ~5,500 行）**

| 层 | 文件 | 说明 |
|---|---|---|
| 入口 | main.py(155) | CORS 全开（allow_origins=["*"] + allow_credentials=True）；print 式计时中间件 |
| 路由层 app/api/ | auth/router.py(181)、player/router.py(213)、save/router.py(284)、weapon/router.py(245)、monster/router.py(124)、map/router.py(120)、event/router.py(120)、deps.py(71) | 7 域 16 端点，分层正确；**api/game、api/user 为空目录** |
| 服务层 app/services/ | auth_service(337)、player_service(227)、save_service(277)、weapon_service(250)、monster_service(118)、map_service(113)、event_service(113) | 业务逻辑完整 |
| Schema 层 app/schemas/ | auth/player/weapon/monster/save/map/event | Pydantic v2 校验完整 |
| 模型层 app/models/ | user(159)、player_profile(270)、weapon(215)、player_weapon(140)、monster(262)、game_save(239)、map(211)、event(212) | SQLAlchemy 2.x，与 SQL 脚本一致 |
| 基础设施 | core/security.py(211) bcrypt+JWT；database/connection.py(208) SQLAlchemy+PyMySQL | `init_database()` 为死代码（模型从未 import，create_all 不会建任何表） |

**AI 内容服务端 server/ai/（FastAPI, :8001, ~8,000 行）**

| 模块 | 文件 | 说明 |
|---|---|---|
| 入口 | main.py(374) | 硬编码 "ai_mode": "mock"；限流中间件双重实例化 bug（S-03） |
| 路由 | api/ai_routes.py(970) | 11 个 /generate/* 端点 + test + history，单体文件 |
| 核心服务 | services/ai_service.py(1540) | 11 类内容生成，每类：LLM 尝试 → 失败重试1次 → mock fallback；缓存 + 验证 + 质检流水线 |
| Provider | llm_provider.py(65)接口、agnes_provider.py(289, OpenAI 兼容)、mimo_client.py(203, Anthropic 兼容)、provider_factory.py(94) | 双真实 Provider + mock；工厂未注册 "mock" 名 |
| Prompt | prompt_builder.py(662) | 14 个 prompt 构建方法 + JSON 格式约束系统提示词 |
| 质量保障 | ai_validator.py(429, 12 函数)、ai_quality_checker.py(504, 14 函数四维评分) | 字段/枚举/数值钳制 + 合法性30%/平衡30%/多样性20%/完整性20% 评分 |
| 缓存 | cache/cache_manager.py(334) | floor/room/monster/weapon 四类内存缓存 |
| 数据库 | database/db_manager.py(288, SQLite)、enhanced_db_manager.py(569)【仅统计端点用】 | 双管理器并存；生成记录落 SQLite，不落 MySQL |
| 日志 | logger/logger.py(247)、monitoring/logger.py(261)【仅 main 导入】 | 双 logger 并存 |
| 中间件 | middleware/rate_limit.py(208) | 60/min 普通、10/min AI、429 响应 |
| 安全 | security/auth.py(193) | 静态 API Key 字典认证 |
| 测试 | tests/ 10 个文件 | 143 项测试全部通过（实测） |

### 1.4 数据库（MySQL 8.0, aurora_game 库, 9 张表）

| 表 | 职责 | 关键字段 | 状态 |
|---|---|---|---|
| users | 用户账号 | username 唯一、bcrypt 哈希、软删除 | ✅ 活跃 |
| player_profiles | 玩家角色（1:1 users） | 等级/属性/金币/统计（max_floor/total_kills/death_count） | ✅ 活跃（游戏中属性变化仅存于存档 JSON，不更新此表） |
| weapons | 武器数据 | ENUM 类型/稀有度、attack_bonus、special_effect(JSON)、is_ai_generated | ⚠️ 有种子数据，客户端实际用本地 ResourceService 降级数据，几乎不查询 |
| monsters | 怪物数据 | ENUM normal/elite/boss、数值、min/max_floor、is_ai_generated | ⚠️ 同上 |
| events | 随机事件 | 选项 JSON、触发概率/层数 | ⚠️ 事件房实际走客户端简化路径，不查询 |
| maps | 地图配置 | room_data/corridor_data JSON、is_ai_generated | ❌ 客户端从未调用地图 API（楼层本地生成） |
| game_saves | 游戏存档（槽位 1-3） | player_state/inventory_data/current_map_data/explored_maps JSON | ✅ 保存侧活跃；current_map_data/explored_maps 客户端从不写入 |
| ai_generations | AI 生成记录 | content_type/model_name/prompt/raw_response/parsed_data/status/user_rating | ❌ **无任何服务端代码写入**（AI 服务写 SQLite） |
| player_weapons | 玩家武器关联 | is_equipped | ⚠️ 服务端有 CRUD，客户端装备系统未接云端 |

SQL 资产：create_database.sql / create_tables.sql / create_player_weapons_table.sql / insert_test_data.sql（226 行种子数据）+ database/design/ 两份设计文档。**建模双源**：建表靠 SQL 脚本，ORM 仅做映射（Alembic 未引入，无迁移体系）。

### 1.5 文档资产

- 根目录：30+ 份 Markdown（README、CHANGELOG(29KB)、ARCHITECTURE、DATABASE、API_DOCUMENT、DEPLOYMENT、10 余份 Phase 报告、8 份 AI 分析文档、PROJECT_TECHNICAL_AUDIT_REPORT、REFACTOR_PLAN 等），其中 7 月文档（DEPLOYMENT/API_REFERENCE 等）已与现状脱节。
- docs/：90+ 份 Phase 报告与设计文档（Phase15~29 系列）。
- paper_material/、tools/（ai_benchmark.py 等）、aurora-roguelike-ai-(4.2)/（旧版本副本，已被 gitignore）。
- **文档数量与代码体量倒挂**：文档总量 > 代码总量，且多份文档描述的功能（AI 楼层生成、商店、事件选择、交互系统）在代码中不可用——文档体系成为"计划墓地"，也是维护负担。

---

## 2. 当前完成情况

以"玩家实际可玩 / 系统实际可运行"为标准，不以代码存在为标准。

### 2.1 客户端

| 系统 | 结论 | 说明（依据） |
|---|---|---|
| 启动 → 登录 → 主界面 | ✅ 完成 | 无头实测零报错；登录/注册依赖本地后端 :8000，无离线模式 |
| 资源加载 | ✅ 完成 | API 失败有默认数据降级（resource_service.gd） |
| 楼层生成 | ✅ 完成 | FloorGenerator 本地生成（AI 楼层生成被禁用，floor_manager.gd:161-167） |
| 房间渲染 | ⚠️ 部分完成 | 房间/地面/墙/标签正常；视差背景仅起始房间生效（B-07）；装饰系统从未调用 |
| 玩家移动/跳跃/冲刺/射击 | ✅ 完成 | coyote/buffer/dash 完整；子弹→伤害→死亡链路完整 |
| 怪物 AI | ❌ 未完成（B-02） | 混合坐标系导致所有房间怪物永久 IDLE |
| Boss 战 | ❌ 未完成（B-03） | BossController.update 无调用方，Boss 站立不动（打木桩） |
| 奖励系统 | ❌ 未完成（B-01） | 奖励生成后每帧被动画拉回房间中心高度，不可见、不可拾取 |
| 奖励房/宝箱房 | ❌ 卡死 | 出口依赖拾取全部奖励 ⇒ 无法离开（B-01 连锁） |
| 房间图（分支） | ❌ 未完成 | 分支房间永远不会被传送门选中（B-05） |
| 楼层推进/通关 | ❌ 未完成 | 主路径随机房 60%+ 概率出现 REWARD/TREASURE 房即卡死；Boss 无 AI |
| 存档保存 | ✅ 完成 | 自动存档 + 暂停菜单存档均可写入服务器（PUT→404 回退 POST） |
| 存档读取 | ❌ 未完成（B-04） | 无任何 UI/代码入口；current_floor 不恢复；房间图不落库 |
| 升级系统 | ⚠️ 部分完成 | 经验→升级→面板选强化链路存在，未实测且百分比加成不生效（B-13） |
| 事件房间 | ⚠️ 部分完成 | 自动选第一项，玩家无选择权（B-14） |
| 商店房间 | ❌ 未完成 | 无任何商店逻辑，进入即出（B-15） |
| 交互系统（E 键） | ❌ 未完成 | 已接线但零交互对象 |
| 暂停/设置/GameOver | ✅ 完成 | 面板完整 |
| AI 客户端网关 | ⚠️ 部分完成 | 1375 行网关完整（解析/校验/缓存/质检/降级），但 6 个配套 UI 文件从未接线；主 HTTP 请求无 timeout |

### 2.2 游戏服务端

| 系统 | 结论 | 说明 |
|---|---|---|
| 用户认证（注册/登录/JWT） | ✅ 完成 | bcrypt + JWT 24h；路由层残留 [LOGIN TRACE] 调试 print |
| 玩家角色 API | ✅ 完成 | 创建/查询/改昵称；游戏中属性变化不落库（仅存档 JSON） |
| 武器/怪物/地图/事件 API | ✅ 完成 | CRUD 齐全，但客户端基本不消费（使用本地降级数据） |
| 存档 API | ✅ 完成 | POST/GET/GET/PUT 四端点 + 槽位唯一约束 |
| 异常处理 | ⚠️ 部分完成 | 统一 HTTPException 但错误类型靠中文字符串匹配（S-06） |
| 日志系统 | ⚠️ 部分完成 | print 计时中间件 + get_db 每会话 print + 无结构化日志文件 |
| 配置管理 | ⚠️ 部分完成 | .env 体系；.env.example 含**真实 API Key 且已被 Git 推送**（P0 安全） |

### 2.3 AI 服务端

| 系统 | 结论 | 说明 |
|---|---|---|
| Provider 抽象（Agnes/MiMo/mock） | ✅ 完成 | 工厂模式 + OpenAI/Anthropic 双协议客户端 + 超时/重试 |
| Prompt 模板系统 | ✅ 完成 | 14 个 prompt 构建器 + JSON 格式约束 + 数值边界 |
| AI 结果验证机制 | ✅ 完成 | ai_validator（字段/枚举/钳制）+ ai_quality_checker（四维评分） |
| Fallback 机制 | ✅ 完成 | LLM 失败重试 1 次 → mock 降级；**但 7 个生成方法存在 json.loads(dict) bug，LLM 模式下永远走 mock（S-01）** |
| 缓存 | ✅ 完成 | 4 类内存缓存 + TTL |
| 限流 | ⚠️ 部分完成 | 限流本身生效；监控端点因中间件双实例化永远显示 0 客户端（S-03） |
| 生成记录落库 | ⚠️ 部分完成 | 落 SQLite；MySQL ai_generations 表无写入方（S-09） |
| 测试 | ✅ 完成 | 143 项测试实测全部通过 |

### 2.4 数据库

| 项 | 结论 | 说明 |
|---|---|---|
| 表结构设计 | ✅ 完成 | 9 表 + 索引 + 外键 + JSON 字段 + 种子数据，质量良好 |
| 实际使用率 | ⚠️ 低 | 活跃读写仅 users / player_profiles / game_saves 三张表 |
| 与 AI 链路整合 | ❌ 未完成 | ai_generations 无写入方；AI 记录在 SQLite 孤岛 |

### 2.5 与毕业设计目标的差距总结

论文题目要求"**云端AI动态内容生成**"是系统核心。当前真实差距：

1. **AI 在游戏内的实际生效面 ≈ 0**：楼层拓扑锁定本地生成；房间内容虽走后台 AI 请求，但怪物数值经客户端 MonsterBalanceConfig 钳制、房间布局本地生成，AI 产物对玩家体验的可见影响微弱；事件自动选择、对话无 UI。
2. **核心循环不可通关**：B-01~B-05 五个 P0 缺陷使"完整一局"不可达成（60%+ 概率卡死 + Boss 无 AI + 读档不可用）。
3. **工程资产分布失衡**：服务端工程水平（分层、测试、验证流水线）明显高于客户端（上帝类、坐标混用、死代码）；论文若以代码质量为卖点，客户端是短板。

---

## 3. 发现的问题

> 编号规则：B = 客户端逻辑缺陷（保留既有审计编号 B-01~B-18）；S = 服务端/AI/数据库问题（本次审计新发现）；A = 架构级风险。所有 P0 项均已在当前工作区代码中逐条复验。

### 3.1 架构问题（A 类）

| # | 问题 | 严重度 | 说明与依据 |
|---|---|---|---|
| A-01 | **坐标体系三层并存、治理失败** | P0 | Phase 26 "local 坐标"迁移只做了渲染/生成侧，MonsterAI/BossController/RoomClearFeedback/BackgroundManager 仍按旧世界观写代码。B-01/02/03/07/08 全是这一个根因的变体。WorldCoordinate 工具类存在但约束力为零 |
| A-02 | **GameScene 上帝类（1540 行）** | P0 | 动态 new+set_script 创建全部 Manager；跨管理器私有成员直访（`_floor_manager._current_floor`、`_room_spawner._reward_container`）；事件处理与系统创建混在一起，不可测试 |
| A-03 | **场景树字符串查找泛滥** | P1 | `Engine.get_main_loop().root.get_node_or_null("GameScene")` 出现于 7+ 文件（room_spawner/monster_ai/monster_node/boss_controller/background_manager/damage_system/bullet）。改名即静默断裂 |
| A-04 | **死代码与双轨系统面积大** | P1 | 旧地图系统（room_manager/world_manager/map_renderer/room_graph/room_data）、旧生成（monster_spawner/drop_manager）、双存档（SaveSystem 本地 JSON 死）、双资源管理（ResourceManager 死）、双容器（全局 vs 每房间）、旧场景 4 个、空目录 3 个、未接线 AI/UI 文件 6 个。详见 REFACTOR_PLAN.md §5.1 删除清单 |
| A-05 | **三套状态机并存且互不校验** | P1 | GameFlowController.FlowState / GameStateManager.GameState / CombatManager.CombatState 各自为政；GameState 转换表与实际调用顺序脱节（B-06） |
| A-06 | **ApiClient 信号广播式设计** | P1 | 所有 HTTP 响应广播给全部监听者，各监听者靠状态标志过滤（login/main/game_flow/save_service 四家同时监听）。登录流程反复重构的结构性原因 |
| A-07 | **Boss 双 AI 驱动并存** | P1 | MonsterNode 内建 MonsterAI + 外部 BossController（从未被驱动）。修复 B-03 时若不合并职责，将出现两套逻辑同时写 velocity 的冲突 |
| A-08 | **服务端重复基础设施** | P2 | AI 服务双 DB 管理器（db_manager/enhanced_db_manager）、双 logger（logger/monitoring）、api/game 与 api/user 空目录 |
| A-09 | **建模双源** | P2 | 建表靠 SQL 脚本、映射靠 ORM、无 Alembic 迁移；`init_database()` 因模型从未 import 而成为死代码 |

### 3.2 代码质量问题

1. **调试残留**：auth/router.py:158-159 `[LOGIN TRACE] + inspect.getfile`；connection.py:100-106 get_db 每请求 3 行 print；main.py:128-136 print 计时中间件（应换 logging）。
2. **错误处理靠中文字符串匹配**（S-06）：save/router.py:101 `if "已有存档" in message`、auth/router.py:168 `if message == "账号已被禁用"`——文案一改即坏，且无法国际化。
3. **日志误导**（S-11）：ai_service.py 全部 LLM 日志硬编码 "generated by MiMo"，Agnes 模式同样打 MiMo。
4. **重复条件**（S-12）：ai_service.py:392-397 `_should_use_llm` 中 `self.llm_provider is not None` 写了两次。
5. **构造参数反模式**（S-10）：mimo_client.py:47-48 用"参数值 != 默认值"判断是否传参——显式传默认值与未传参行为不同，易埋雷。
6. **CORS 配置不安全**（S-07）：两个 FastAPI 服务均 `allow_origins=["*"] + allow_credentials=True`（毕设环境可接受，需在论文中注明开发配置）。
7. **客户端测试不可自动化**：tests/test_weapon_growth.gd 注释写明"在 Godot 编辑器中附加到任意节点运行"——无测试框架、无 CI 入口（本次审计用临时包装器才跑通）。
8. **JWT 默认密钥硬编码**：security.py:34-37 有开发默认值（生产需 env 注入，当前 .env 已配置，可接受但需注明）。

### 3.3 性能问题

1. **无对象池**：子弹、奖励、飘字、特效全部运行时 instantiate + queue_free（bullet.gd / reward_item.gd / damage_number.gd）。横版弹幕密度下 GC 与实例化开销随弹量线性增长。
2. **巨型文件**：game_scene.gd 1540 行、ai_content_service.gd 1375 行、reward_item.gd 518 行——单人维护与审阅负担，也与"模块化架构"的论文表述不符。
3. **AI 请求无超时**：ai_content_service.gd:109-110 主 `_http_request` 未设 timeout（仅 token 请求 5s、另一请求 10s）——AI 服务挂起时后台协程永久等待。
4. **每帧打印日志**：reward_item.gd 调试打印、room_renderer/room_spawner 的 [Reward Spawn Debug] 等未加开关，release 运行持续写 stdout。
5. **渲染为 mobile 渲染器 + zoom=2 无 limit**：无 culling 配合，房间外虚空可见（B-18）。

### 3.4 逻辑问题（客户端 B 类，P0 已复验）

| # | 问题 | 严重度 | 根因（文件:行） |
|---|---|---|---|
| B-01 | 奖励生成后不可见不可拾取 → REWARD/TREASURE 房死锁 | **P0** | reward_item.gd:49 在 _ready 捕获 _start_position，而 room_spawner.gd:499-500 先 add_child 后赋值 position；_process(:62) 每帧把 y 重置回房间中心（y≈0），高于镜头与跳跃极限 |
| B-02 | 怪物 AI 全程 IDLE | **P0** | monster_ai.gd:87 `_monster_node.position.distance_to(_player_node.position)` 混用 local/global 坐标系，距离恒 > 300 |
| B-03 | Boss 完全静止 | **P0** | BossController.update() 全项目无调用方；其内部 6 处距离计算同样混用坐标系（boss_controller.gd:208,272,284,306,321,338,386） |
| B-04 | 存档读取不可用 | **P0** | 主界面无读档按钮；enter_game(save_slot) 仅以 -1 调用；game_scene.gd:280,387 硬编码 generate_floor(1)；房间图/背包不落库 |
| B-05 | 分支房间不可达 + 回溯软锁 | **P0** | floor_generator.gd:35-69 先建主路径后建分支，传送门按 connections 顺序选第一个未访问（game_scene.gd:1024-1030）；enter_count>=2 封锁（floor_manager.gd:183-185）配合兜底选择已完成房间（:1042-1047）→ 软锁 |
| B-06 | GameState 状态机启动即失效 | P1 | 转换表 NOT_STARTED 只能转 LOGIN/LOADING（game_state_manager.gd:97-98），但登录流程从不调用 → is_playing() 恒 false → 退出不保存、play_time 恒 0 |
| B-07 | 视差背景仅起始房间可见 | P1 | room_renderer.gd:129-130 在房间节点创建（:133）之前调 spawn_background；BackgroundManager 挂到旧节点或 GameWorld(0,0)。**未提交修改尝试修复但调用顺序未改，bug 仍在** |
| B-08 | 房间清空反馈显示在世界原点 | P1 | room_clear_feedback.gd:88 硬编码 (0,-50) 且容器是 GameWorld |
| B-09 | 平台全部实心碰撞、多数不可登 | P1 | room_renderer.gd:253-275 无 one_way_collision（全项目 0 处）；可达性校验不检查路径遮挡 |
| B-10 | 传送门重复创建 | P1 | 清怪与奖励收集各触发一次 _complete_current_room（game_scene.gd:741-748），_create_room_exits 不清旧门 |
| B-11 | 暂停菜单保存 current_floor 恒为 1 | P1 | get_save_data 读从未写入的 _current_save（game_state_manager.gd:323）；仅 _auto_save 手动修正 |
| B-12 | 武器伤害双重计算 | P2 | damage_system.gd:66-67：get_attack() 已含武器伤害 + bullet.get_damage() 再加一次 |
| B-13 | PlayerStats 百分比加成不生效 | P2 | 移动用常量 MOVE_SPEED=200（player_controller.gd:18,214）；暴击硬编码 0.1（weapon.gd:137）；thorns/regen/magnet/lucky 被动无效果逻辑 |
| B-14 | 事件房间自动选第一项 | P2 | game_scene.gd:880-881 明确"简化版"；AIEventPanel 未入场景树 |
| B-15 | 商店房间为空 | P2 | game_scene.gd:601-609 match 无 SHOP 分支 |
| B-16 | 降级怪物速度 2-12 px/s（俯视时代数值） | P2 | resource_service.gd:163-224；钳制只修 HP/ATK/DEF |
| B-17 | 死代码清单（见 A-04） | P2 | 清单见 REFACTOR_PLAN.md §5.1 |
| B-18 | Camera zoom=2 无 limit、虚空可见 | P2 | player.tscn:14-19 |

### 3.5 AI 功能问题（论文核心，S 类）

| # | 问题 | 严重度 | 说明与依据 |
|---|---|---|---|
| S-01 | **7 个 LLM 生成方法永远回退 mock** | **P0** | ai_service.py 的 `_generate_{event,dialogue,upgrade,difficulty,room_strategy,npc_memory,context_event}_with_llm`（:958-964 等 7 处）对 `self.llm_provider.generate()` 的**已解析 Dict 结果**再次调用 `json.loads()` → 抛 TypeError（Dict 非 str），而 except 只捕获 `json.JSONDecodeError` → 异常冒泡到外层 try → 永远走 mock fallback。**即使配置了真实 API Key，这 7 类内容也拿不到 LLM 结果**。floor/room/monster/weapon 四个方法没有此 bug（不二次解析）。测试通过是因为测试 mock 了 generate() 返回字符串 |
| S-02 | ai_mode 硬编码 "mock" | P1 | ai/main.py:117,224 的 / 与 /api/info 端点无视实际 Provider 模式；答辩演示真实 LLM 时接口自报 mock |
| S-03 | 限流中间件双重实例化 | P1 | ai/main.py:53-55：实例 A 注册给 rate_limit_manager，`app.add_middleware(RateLimitMiddleware)` 传入**类名**使 Starlette 新建实例 B 进请求链路 → 限流生效但 `/api/rate-limit/status`、`/api/stats` 永远显示 0 客户端 |
| S-04 | 双日志/双 DB 体系 | P2 | logger 与 monitoring.logger、db_manager 与 enhanced_db_manager 并存，职责重叠 |
| S-05 | AI 楼层生成被禁用 | **P1（论文风险）** | 客户端 floor_manager.gd:161-167 明确 "Floor structure LOCKED"；服务端 generate_floor 接口与缓存齐全却无消费方。论文"AI 动态生成楼层拓扑"章节将无实机证据 |
| S-06 | AI 生成记录不入 MySQL | P2 | ai_generations 表（MySQL）零写入方；AI 服务生成历史写 SQLite（server/ai/data/*.db，gitignored）。论文"AI 内容入库可追溯"表述与实际不符 |
| S-07 | AI 客户端网关无超时 | P1 | 见 3.3-3；AI 服务挂起时游戏内后台协程永久等待 |
| S-08 | ai_routes.py 970 行单体 + 模板重复 | P2 | 每端点重复"缓存→生成→DB→日志→fallback"模板，可抽装饰器/基类 |

### 3.6 数据库问题

1. **实际使用率低**：9 张表中仅 users/player_profiles/game_saves 活跃读写；weapons/monsters/events/maps 有完整 API 与种子数据但客户端不消费（走本地降级数据），player_weapons 云端侧无客户端对接。
2. **ai_generations 表空转**：设计完整（prompt/raw_response/parsed_data/user_rating 等字段适合论文），但没有写入方——S-06。
3. **game_saves JSON 字段未充分利用**：current_map_data/explored_maps 从不写入；房间图状态（visited/completed）不落库 → 读档后房间进度无法恢复（B-04 的数据库侧根因）。
4. **无迁移工具**：Alembic 未引入，schema 演进靠手工 SQL（create_player_weapons_table.sql 即为补丁式建表）。
5. **无备份/初始化脚本验证**：database/backups 目录规则在 .gitignore 中存在但无自动化。

### 3.7 毕业设计展示问题

1. **🔴 P0 安全：真实 API 密钥已泄漏到公开仓库**：`server/.env.example` 含真实 `AGNES_API_KEY` 与 `MIMO_API_KEY` 且已被 Git 跟踪并推送（最近提交 27fcfe3 包含该文件）。**必须立即轮换密钥并清理提交历史或至少移除明文密钥**。答辩前若密钥被他人使用产生费用，后果由项目承担。
2. **AI 卖点与实机效果不符**：见 2.5。答辩演示"云端 AI 动态生成"时，实际生效的是本地生成 + mock fallback（除非先修 S-01 并配置 Key）。
3. **启动依赖链长且无脚本**：MySQL + 游戏服务 + AI 服务 + Godot 四步手工启动（README 有步骤但无一键脚本）；答辩现场换机风险高。建议补 start_all 脚本或 Docker Compose。
4. **无 CI/自动化回归**：服务端有 143 项测试但无 CI 管线；客户端 1 个测试且无法自动化运行。
5. **文档与代码脱节**：根目录 30+ 文档、docs/ 90+ 文件，大量描述未实现功能；README 声称的完成度与代码实际不符（如"核心系统 ✅"）。
6. **演示剧本缺失**：无"答辩演示脚本"（哪一步演示什么、AI 如何可视化、网络断开时如何演示降级）。论文答辩需要一条可复现的 AI 内容演示路径。

---

## 4. 重构建议

> 完整执行路线（任务拆分、验收标准）见 REFACTOR_PLAN.md（已存在，Phase 2 时按要求改版为 PROJECT_REBUILD_PLAN.md 的 TASK-xxx 格式）。本节给出建议总表与执行顺序。

### 4.1 建议总表

| # | 建议 | 优先级 | 修改原因 | 预计影响 | 工作量 |
|---|---|---|---|---|---|
| R-01 | **轮换 Agnes/MiMo API 密钥，从 .env.example 移除明文 Key，改写历史或至少在 GitHub 上确认旧 Key 作废** | 🔴 P0 立即 | 密钥已在公开仓库泄漏 | 防费用损失/账号风险；不影响代码 | 0.5h（用户操作） |
| R-02 | 修复 B-01 奖励出生顺序（先定位后入树 + 动画起点惰性捕获） | P0 | 解锁奖励系统 + 解除两类房间死锁 | 战斗房可拾取奖励；REWARD/TREASURE 房可离开 | 小（2 文件数行） |
| R-03 | 修复 B-02 坐标混用（统一 global_position） | P0 | 恢复全部战斗体验 | 怪物开始追击/攻击；游戏难度体系才成立 | 小（1 文件） |
| R-04 | 修复 B-03 Boss 驱动（接通 BossController + 单一驱动职责） | P0 | Boss 战当前是打木桩 | 阶段转换/技能/前摇生效；楼层推进闭环 | 中 |
| R-05 | 修复 B-05 房间导航（completed 标志驱动 + 分支可达 + 无软锁） | P0 | 地图从线性走廊变为真实房间图 | 分支内容可达；消除回溯卡死 | 中 |
| R-06 | 修复 B-04 存档闭环（读档入口 + current_floor/房间图落库恢复） | P0 | 存档系统验收硬门槛 | 读档→回到原楼层原状态 | 中 |
| R-07 | 修复 S-01 LLM 二次解析 bug | P0 | 论文核心：7 类 AI 内容真实 LLM 模式不可用 | 配 Key 后 AI 内容真正生效 | 小（删 7 处 json.loads） |
| R-08 | 坐标宪法落地（D1）+ 场景树查找清除（依赖注入） | P0 架构 | B 类 bug 的系统性根因 | 新系统不再产生同类坐标 bug；改名不再断裂 | 大（分步） |
| R-09 | GameScene 拆分（组合根化，目标 <400 行） | P1 | 上帝类不可维护、不可测试 | 各 Manager 可独立测试；结构对应论文架构图 | 大（分步） |
| R-10 | 死代码清除（REFACTOR_PLAN §5.1 清单） | P1 | 维护负担 + 误伤风险 | 代码量约 -30%；类型模型清爽 | 中 |
| R-11 | 状态机收口（D4）+ ApiClient 回调制（D6） | P1 | 启动警告、退出不保存、请求串台 | 存档/时长统计恢复正确 | 中 |
| R-12 | AI 楼层生成恢复 + 事件/对话 UI 接线（阶段3） | P1 论文 | "云端AI动态内容生成"落地 | 论文核心章节有实机证据；答辩可演示 | 大 |
| R-13 | 服务端卫生：S-02/S-03/S-04/S-08/S-11/S-12 + 日志系统统一 | P1 | 答辩接口自报 mock、监控失效 | /stats 真实可用；日志可信 | 小~中 |
| R-14 | 一键启动脚本/Docker Compose + 演示剧本 | P1 展示 | 答辩换机风险 | 5 分钟完成环境重建 | 中 |
| R-15 | 数值修复 B-12/B-13/B-16 + 被动效果实现 | P2 | 伤害/成长体系失真 | 武器成长、强化选项真实生效 | 中 |
| R-16 | 内容补齐 B-09/B-14/B-15（平台单向碰撞、事件选择 UI、商店） | P2 | 玩法完整度 | Roguelike 内容多样性 | 中 |
| R-17 | 相机 limit（B-18）、传送门去重（B-10）、current_floor 收口（B-11） | P2 | 体验与正确性 | 视觉干净、存档准确 | 小 |
| R-18 | 对象池 + 日志开关 + timeout 统一 | P2 | 性能与稳定性 | 长局帧率稳定；AI 挂起不再卡协程 | 小 |
| R-19 | 客户端测试基建（GUT 或自研 runner + CI） | P2 | 目前客户端回归靠人肉 | 每次改动可自动验证 | 中 |
| R-20 | 文档瘦身与对齐（删除过时文档、README/架构文档与代码一致） | P2 | 文档成为计划墓地 | 论文引用文档可信 | 中 |

### 4.2 建议执行顺序（阶段化）

1. **第 0 步（立即）**：R-01 密钥轮换——安全事项，不依赖任何代码改动。
2. **阶段一 核心循环打通**：R-02 → R-03 → R-04 → R-05 → R-06 → R-07。完成后游戏实现"登录→战斗→奖励→Boss→下一层→存档→读档"完整闭环（P0 全部清零）。
3. **阶段二 架构稳定**：R-08（坐标宪法）→ R-10（死代码清除）→ R-09（GameScene 拆分）→ R-11（状态机/网络收口）。此阶段不改玩法，每步以"Godot 无错启动 + 无警告风暴 + 死引用 grep 为 0"为验收。
4. **阶段三 AI 功能（论文核心）**：R-12（AI 楼层恢复 + 事件/对话 UI 接线）→ R-13（服务端卫生）。验收：AI 生成内容在游戏内可观测，AI 服务关闭时降级路径静默可用。
5. **阶段四 优化与展示**：R-14（一键启动/演示剧本）→ R-15/R-16（数值与内容）→ R-17/R-18（体验）→ R-19（测试基建）→ R-20（文档对齐）。

### 4.3 与已有规划文档的关系

- 本报告 = 现状事实与问题清单（Phase 1 交付物）。
- REFACTOR_PLAN.md = 上一会话产出的架构重构规划（含 D1-D7 架构决策、A/B/C 文件分类、4 阶段路线），与本报告结论一致，建议在 Phase 2 将其改版为任务化格式（TASK-xxx：任务目标/修改文件/技术方案/完成标准/测试方法）后继续使用。
- **工作区现有 12 个未提交客户端修改**（Phase 24-27 半成品：统一房间完成接口 + local 坐标迁移尝试）**未完成且未验证**，其中 B-07/B-08 的修复尝试因调用顺序问题实际无效。建议在阶段一前先决定：回退这些修改，或将它们并入对应 TASK 一次性完成。

---

## 附录 A：本次审计实际执行的验证

```bash
# 1. 客户端无头启动（实测通过，零报错）
Godot_v4.7-stable_win64_console.exe --headless --path D:/GraduationProject/client --quit
# → Godot Engine v4.7.stable；10 个 Autoload 初始化完成；LoginScene Ready

# 2. 客户端武器成长测试（12/12 通过，需 SceneTree 包装器）
Godot_v4.7-stable_win64_console.exe --headless --path client --script /tmp/run_wg_test.gd

# 3. AI 服务端测试（143/143 通过）
cd server && venv/Scripts/python.exe -m pytest ai/tests/ -q

# 4. 进程状态
netstat：3306 LISTENING（MySQL ✅）；8000/8001 无监听（服务端未启动 ❌）

# 5. P0 缺陷复验（全部在当前工作区代码中成立）
#  B-01: room_spawner.gd:499-500 add_child 先于 position 赋值；reward_item.gd:49 _ready 捕获起点
#  B-02: monster_ai.gd:87 position.distance_to(position) 混用坐标系
#  B-03: BossController 无 _physics_process 且 update() 零调用方（grep 全项目）
#  B-04: game_scene.gd:280,387 generate_floor(1) 硬编码；主界面无读档按钮
#  B-05: floor_manager.gd:183-185 enter_count>=2 封锁；floor_generator 先主路径后分支
#  S-01: ai_service.py 7 处 json.loads(已解析Dict) → TypeError 不被捕获 → 永远 fallback mock
#  S-03: ai/main.py:53-55 中间件类名二次实例化
```

## 附录 B：问题编号索引

- 客户端逻辑缺陷：B-01 ~ B-18（见 §3.4）
- 服务端/AI/数据库：S-01 ~ S-08（见 §3.5/§3.6）
- 架构级风险：A-01 ~ A-09（见 §3.1）
- 重构建议：R-01 ~ R-20（见 §4.1）
- 既有专项审计（坐标系统/房间生命周期/奖励链路/平台碰撞/存档链路的逐行级分析）已并入本报告 §3.4 与 §3.1。
