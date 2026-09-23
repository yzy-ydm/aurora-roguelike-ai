# 《Aurora-Roguelike-AI 架构审查与重构建议报告》

> 角色：首席架构工程师
> 日期：2026-09-23
> 依据：对 client/（80+ 脚本、22 场景）与 server/（FastAPI 双服务、55+ 源文件）的逐文件静态审查与引用关系分析
> 约束：本文档只做规划，不修改任何代码、不提交 Git、不新增功能、不修 Bug；执行需等待确认

---

## 1. 当前真实架构

### 1.1 客户端（Godot 4.7）真实架构图

```
┌────────────────────────── UI Scenes（CanvasLayer/Control）──────────────────────────┐
│ LoginScene  MainScene  GameScene  HUD  PauseMenu  SettingsMenu  SaveSelection       │
│ LevelUpPanel(动态)  BossHealthBar(动态)  GameOverPanel(动态)  ResourceCenter  Hint  │
└──────────────────────────────────────┬───────────────────────────────────────────────┘
                                       │ change_scene
┌───────────────────── Autoload 单例（10个，project.godot:23-34）─────────────────────┐
│ APIConfig  TokenManager  ApiClient(信号广播式)  SceneManager  ResourceManager【死】 │
│ ResourceService  GameStateManager  SaveService  GameFlowController  SettingsManager │
└──────────────────────────────────────┬───────────────────────────────────────────────┘
                                       │
┌────────────────── GameScene 组合根（game_scene.gd, 1540行, 动态 new+set_script）────┐
│ ┌─世界域─┐  FloorManager──┬─ FloorGenerator（本地，AI已锁定禁用）                    │
│ │        │                ├─ RoomRenderer──┬─ RoomDecorationManager【从未调用】      │
│ │GameWorld│               │                ├─ RoomClearFeedback（坐标错）            │
│ │+Player  │               │                └─ BackgroundManager（挂载错）            │
│ │+Bullets │               └─ RoomSpawner（怪物/奖励/房间中心）                       │
│ │+Effects │  CombatManager ── DamageSystem（伤害公式+特效）                          │
│ └────────┘  UpgradeManager ── LevelUpPanel                                          │
│  ┌─资产域─┐ InventoryManager  EquipmentManager【空壳】 ObjectManager【空注册】       │
│  │        │ SaveSystem【本地JSON，死】 InteractionManager（有接线无对象）             │
│  │        │ BehaviorAnalyzer → AIContextManager → NPCMemoryManager → AnalyticsMgr   │
│  │        │ AIContentService(1375行)─┬─ AIResponseParser  AIValidator               │
│  └────────┘                         ├─ AICacheManager  AIQualityChecker             │
│                                     └─ FakeAIService                                 │
└──────────────────────────────────────────────────────────────────────────────────────┘
┌─ 运行时节点 Component ───────────────────────────────────────────────────────────────┐
│ Player(CharacterBody2D+Camera2D zoom2+Weapon+InteractionDetector)                   │
│ MonsterNode(CharacterBody2D+MonsterAI子节点+HealthBar)  BossController(无驱动)       │
│ Bullet(Area2D)  RewardItem(Area2D)  DamageNumber  HitEffect  Portal(Area2D动态)      │
└──────────────────────────────────────────────────────────────────────────────────────┘
┌─ Data Model（RefCounted）────────────────────────────────────────────────────────────┐
│ NewRoomData  RoomContentData  FloorData  MonsterData  WeaponData  WeaponInstance    │
│ RewardData  BossData  UpgradeData  MonsterBalanceConfig  MapData  EventData          │
│ AIEventData  PlayerBehaviorData  PlayerStats（运行时状态源）                          │
│ 【遗留】RoomNodeData  RoomData  Entity  PlayerEntity  EntityManager                  │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**关键事实（与文档宣称不同的地方）：**
- 除 UI 场景外，**几乎所有 Manager 都由 GameScene 在运行时用 `Node.new()+set_script(load(...))` 动态创建**，.tscn 中不存在对应节点。
- 场景树中存在两条被闲置的节点：全局 MonsterContainer/RewardContainer（game_scene.gd:317-323）在生成时立即被"每房间容器"（RoomRenderer 创建）取代。
- `scripts/map/`、`scripts/network/`、`scripts/utils/` 是**空目录**。
- `scenes/world/world.tscn`、`scenes/world/rooms/room.tscn`、`scenes/object/weapon_pickup.tscn`、`scenes/test/platform_test_scene.tscn` 全项目无加载方（死场景）。

### 1.2 服务器真实架构图

```
┌────────── 游戏服务器 server/main.py（FastAPI, :8000）──────────┐
│ Router 层：auth / player / weapon / monster / save / map / event│
│   （api/game、api/user 为空目录）                                │
│ Service 层：auth_service 337行 / player_service 227行           │
│   save_service 277行 / weapon_service 250行 / monster/map/event │
│ Schema 层（Pydantic）：auth/player/weapon/monster/save/map/event │
│ Model 层（SQLAlchemy）：user/player_profile/weapon/player_weapon│
│   /monster/game_save/map/event                                   │
│ 基础设施：core/security.py(JWT)  database/connection.py(MySQL)  │
│   deps.py(get_current_user_id)                                   │
└──────────────────────────────────────────────────────────────────┘
┌────────── AI 内容服务器 server/ai/main.py（FastAPI, :8001）─────┐
│ api/ai_routes.py（970行单体路由：floor/room/monster/weapon/      │
│   event/dialogue/upgrade/difficulty/room_strategy/npc_memory/    │
│   context_event + 统计/清理端点）                                │
│ services：ai_service  llm_provider(接口)  agnes_provider        │
│   mimo_client  provider_factory  prompt_builder  request_manager│
│   ai_validator  ai_quality_checker  monster_balance             │
│ cache：cache_manager（floor/room/monster/weapon 四缓存）        │
│ database：db_manager（路由实际使用）+ enhanced_db_manager        │
│   （仅统计端点使用）【重复】                                     │
│ logger：logger/logger.py（实际使用）+ monitoring/logger.py      │
│   （仅main导入）【重复】                                         │
│ 其它：security/auth  middleware/rate_limit  tests/（11个测试）  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.3 数据流

```
Godot客户端 ──登录/注册/玩家/武器/怪物/地图/事件/存档──▶ 游戏服务器(:8000) ──MySQL(aurora_game)
Godot客户端 ──floor/room/monster/weapon/event/dialogue/upgrade/
             difficulty/room_strategy/npc_memory/context_event──▶ AI服务器(:8001)
             ──ProviderFactory→ agnes / mimo / mock ──▶ 外部LLM
```
- 客户端当前**禁用了 AI 楼层生成**（floor_manager.gd:161-167 注释"Floor structure LOCKED"），AI 仅剩房间内容/难度/事件/对话的后台请求。
- 存档 = 游戏服务器 MySQL 中的 JSON 大字段（player_state），房间图/背包不落库。

---

## 2. 八大系统逐项检查

### 2.1 房间生成系统
- **现状**：FloorGenerator 本地生成（start + 主路径 4-6 间 + 分支若干 + Boss），返回 NewRoomData；FloorManager 组装 FloorData 并 `enter_room(0)`；RoomRenderer 每次切换重建单房间子树；RoomSpawner 负责怪物/奖励。**每帧只存在一个房间节点，无残留。**
- **问题**：① 分支房间永远不会被传送门选中（连接顺序+优先级逻辑），实际是线性走廊；② `enter_count>=2` 回溯封锁造成分支房/回溯软锁；③ 全局容器 vs 每房间容器双轨；④ AI 楼层生成被禁用（论文核心卖点未生效）。
- **目标**：房间图与导航规则重构（见路线阶段2.1），AI 楼层生成恢复（阶段3.2）。

### 2.2 坐标系统
- **现状**：三套坐标系并存——GameWorld(global)、每房间子树(local)、AI/特效旧代码假设(两者混用)。WorldCoordinate 工具类存在但约束力为零。
- **问题**：MonsterAI、BossController 用 `position` 混算距离；RoomClearFeedback、BackgroundManager 挂错容器；RewardItem 动画起点捕获时机错误（详见 PROJECT_AUDIT_REPORT.md B-01/02/03/07/08）。
- **目标**：**运行时实体一律 global_position；local 坐标仅存在于 RoomRenderer 的布局生成过程**（进房间子树前完成换算）。

### 2.3 玩家系统
- **现状**：PlayerController(CharacterBody2D) + PlayerStats(RefCounted 运行时状态源) + Weapon 节点 + Bullets 容器。移动/跳跃/coyote/buffer/dash 实现完整。
- **问题**：move_speed_bonus、crit_rate 等 PlayerStats 加成未接入移动/射击（常量硬编码）；get_attack() 含武器伤害导致 DamageSystem 二次叠加；Camera2D zoom=2 无 limit。
- **目标**：属性加成全部从 PlayerStats 读取；伤害口径收口到 DamageSystem；相机 limit 随房间更新。

### 2.4 怪物系统
- **现状**：MonsterData(服务端/降级)→MonsterEntity(RefCounted)→MonsterNode(CharacterBody2D)+MonsterAI(Node)。数值由 MonsterBalanceConfig 统一钳制。
- **问题**：MonsterAI 距离计算混用坐标系→所有房间怪物永久 IDLE；降级数据 speed=2-12 px/s（俯视时代数值）；死亡通知走场景树字符串查找。
- **目标**：MonsterAI 全部改 global_position；速度纳入 BalanceConfig；死亡/伤害通知改依赖注入。

### 2.5 Boss系统
- **现状**：BossData + BossController（阶段/技能/前摇逻辑齐全）+ MonsterNode 复用 + 独立血条 UI。**BossController.update() 全项目无调用方**，Boss 同时挂载 MonsterAI 与 BossController 两套 AI。
- **目标**：明确单一驱动者（BossController 自持 _physics_process 或由 MonsterNode 分派），删除重复 AI 驱动路径。

### 2.6 掉落系统
- **现状**：RoomSpawner.spawn_rewards → RewardItem(Area2D, 像素纹理, 浮动动画) → body_entered 拾取 → RewardData.apply_to_player → all_rewards_collected → 开门。链路完整但存在出生点/动画起点竞态。
- **目标**：spawn 流程重构（先定位后入树，或惰性捕获动画起点），奖励容器归属每房间子树。

### 2.7 存档系统
- **现状**：双系统并存——SaveService(API, 活跃) 与 SaveSystem(本地JSON, 死)；保存可用（自动+暂停菜单），**读取无 UI 入口、enter_game(save_slot) 无调用方、current_floor 不恢复、房间图不落库**；play_time/kill_count 不累计。
- **目标**：单一 API 存档服务 + 显式存档数据模型（玩家态+楼层+房间完成状态）；读档闭环。

### 2.8 AI服务系统
- **现状**：客户端 AIContentService(1375行网关：解析/校验/缓存/质检/降级) + 服务端 AI 服务器(ProviderFactory: agnes/mimo/mock + 缓存 + 限流 + 日志 + DB记录)。结构完整但**游戏内实际生效面很小**（楼层锁定，仅后台房间内容/难度/事件）。
- **问题**：客户端 HTTPRequest 无 timeout；ai_routes.py 970行单体；服务端双 DB 管理器/双 logger；客户端 6 个 AI 相关文件（ai_event_manager/ai_event_panel/ai_room_content/ai_status_display/ai_debug_panel/network_stats_ui）从未接线。
- **目标**：客户端网关瘦身+超时与降级契约；服务端路由按域拆分；AI 生成内容恢复为可观测的玩法来源。

---

## 3. 当前架构问题清单（按严重度排序）

| # | 问题 | 严重度 | 影响面 |
|---|---|---|---|
| 1 | **坐标规范缺失**：local/global 混用无治理，Phase 26 半迁移 | 架构级 | 怪物AI、Boss、奖励、特效、背景、反馈全部中招（6个已确认bug的共同根因） |
| 2 | **GameScene 上帝类**（1540行）+ 运行时动态建 Manager | 架构级 | 依赖顺序脆弱、跨管理器私有成员访问（`_floor_manager._current_floor`、`_room_spawner._reward_container`）、组合根不可测试 |
| 3 | **场景树字符串查找泛滥**（`root.get_node_or_null("GameScene")` 出现在 7+ 文件） | 架构级 | 改名即断、无静态检查、隐含单例耦合 |
| 4 | **死代码面积大**：旧地图系统、双存档、双资源管理、空对象/交互层、6个AI文件、4个死场景、空目录 | 架构级 | 维护心智负担；遗留模型（RoomNodeData/RoomData）仍在活跃代码中作为类型引用 |
| 5 | **三套状态机各自为政**（FlowState/GameState/CombatState），GameState 转换表与调用顺序脱节 | 高 | 启动即产生非法转换警告；is_playing() 失真→退出不保存、时长不统计 |
| 6 | **信号广播式 ApiClient**：所有响应广播给全部监听者，靠状态标志过滤 | 高 | 多监听者互相污染响应，登录流程反复重构的结构性原因 |
| 7 | **存档数据模型不完整**：房间图/背包不落库、current_floor 读取缺失、双系统并存 | 高 | 读档闭环不存在 |
| 8 | **双容器体系**：全局 Monster/RewardContainer 与每房间容器并存，前者是死节点 | 中 | 坐标混乱来源之一 |
| 9 | **服务端重复基础设施**：AI 服务器双 DB 管理器、双 logger；api/game、api/user 空目录 | 中 | 维护歧义 |
| 10 | **AI 集成"装饰化"**：楼层生成被锁定，AI 仅后台请求且无 timeout | 高（论文风险） | 毕业设计"基于云端AI动态内容生成"卖点与代码实际不符 |

---

## 4. 根因分析

1. **分阶段开发没有"架构冻结"环节**：Phase 17（横版化）、Phase 26（local坐标）等迁移都是"先改生产者、后改消费者"，消费者（AI/特效/反馈）从未跟进，且没有任何静态检查手段（Godot 无编译期坐标类型）兜底。
2. **Manager 创建方式倒退**：早期用 tscn 组织节点，后期改为 GameScene 动态 new，导致 scene tree 不可见、组合顺序靠 _ready 时序，进而催生字符串查找和私有成员直访。
3. **"先堆功能再清理"的工作方式**：每次 Phase 都新增系统而不退役旧系统（RoomNodeData 与 NewRoomData 并存、SaveService 与 SaveSystem 并存、MonsterSpawner 与 RoomSpawner 并存），没有明确的删除标准。
4. **服务边界靠文件名而非接口**：谁都可以 `load()` 任何脚本、`get_node()` 任何节点，Godot 又没有模块可见性，边界只能靠约定——而约定从未写入 CLAUDE.md/开发规范。
5. **AI 子系统按"论文卖点"设计、按"演示风险"裁剪**：设计了完整的生成/校验/缓存/质检链路，但担心稳定性把楼层生成锁死，结果 AI 只剩装饰性调用，客户端侧 6 个配套 UI 文件成了死代码。

---

## 5. 删除 / 合并决策表

### 5.1 应删除（C类，无活跃引用或纯重复）

| 目标 | 理由 | 前置条件 |
|---|---|---|
| `scripts/world/room_manager.gd`、`world_manager.gd`、`map_renderer.gd`、`room_graph.gd`、`scripts/models/room_data.gd` | 旧地图系统，FloorManager 已完全取代 | 无 |
| `scenes/world/world.tscn`、`scenes/world/rooms/room.tscn` | 旧地图场景，无加载方 | 无 |
| `scripts/enemy/monster_spawner.gd`、`scripts/drop/drop_manager.gd` | 旧生成/掉落系统，RoomSpawner 已取代 | 无 |
| `scripts/managers/save_system.gd` + game_scene.gd:437-447 的 SaveSystem 接线 | 双存档之本地分支，SaveService(API) 是唯一活跃路径 | 确认无文档要求本地离线存档；若论文要求离线存档，改为反向决策（删除 API 保存） |
| `scripts/managers/resource_manager.gd`（autoload ResourceManager） | 纹理/音频缓存，全项目无调用方 | 从 project.godot 移除 autoload 条目 |
| `scripts/entity/entity_manager.gd`、`player_entity.gd` | Entity 管理体系废弃（entity.gd 保留，MonsterEntity 的基类） | 无 |
| `scripts/events/ai_event_manager.gd`、`scripts/ai/ai_room_content.gd`、`scripts/ai/ai_status_display.gd`、`scripts/ai/ai_debug_panel.gd`、`scripts/network/network_stats_ui.gd` | 从未接线（ai_event_data.gd 保留，AIContentService 在用） | 无 |
| `scripts/object/test_chest.gd`、`scripts/weapon/weapon_object.gd`、`scenes/object/weapon_pickup.tscn` | 测试/演示对象，无生成方 | 与交互系统决策联动（见5.2） |
| `scenes/test/platform_test_scene.tscn` | 调试场景 | 无 |
| `scripts/models/room_node_data.gd` | 被 NewRoomData 取代 | **须先删除 ai_content_service.gd 中 5 个 RoomNodeData 旧签名函数（:201/:309/:370/:625）与 room_content_data.gd:171 from_room_node()** |
| 空目录 `scripts/map/`、`scripts/network/`、`scripts/utils/` | 空 | 无 |
| game_scene.gd:317-323 全局 MonsterContainer/RewardContainer 创建 | 死节点（生成时被每房间容器覆盖） | 确认 room_spawner 不再回退到它们 |

### 5.2 应合并（重复职责）

| 合并项 | 方案 |
|---|---|
| SaveSystem(本地) + SaveService(API) | 保留 SaveService；若未来需要离线存档，在 SaveService 内加本地缓存层，不复活第二系统 |
| ResourceManager(autoload) + ResourceService(autoload) | 保留 ResourceService；纹理/音频缓存作为其内部子功能（需要时） |
| server/ai `database/db_manager.py` + `enhanced_db_manager.py` | 保留 routes 实际使用的 db_manager；把 enhanced 独有的统计能力并入后删除后者 |
| server/ai `logger/logger.py` + `monitoring/logger.py` | 合并为一个 logger 模块 |
| MonsterAI + BossController 双 AI 驱动 | BossController 成为 Boss 的唯一驱动者；MonsterNode 只对非 Boss 怪物创建 MonsterAI（或 MonsterAI 抽象出接口由两者共用） |
| GameState(枚举状态机) 与 CombatState | 全局 GameState 收口为"流程态（登录/主菜单/游戏中/暂停/结束）"，战斗态完全由 CombatManager 负责，删除 GameState 中 COMBAT/BOSS/LEVEL_UP/EVENT 等玩法态 |
| 全局容器 + 每房间容器 | 只保留每房间容器（RoomRenderer 所有），RoomSpawner 通过注入获取 |

### 5.3 应保留（A类核心资产）

- **客户端网络/认证**：api_client.gd、api_config.gd、token_manager.gd
- **客户端流程/存档**：game_flow_controller.gd、game_state_manager.gd、save_service.gd、scene_manager.gd、settings_manager.gd
- **世界系统（核心玩法）**：floor_manager.gd、floor_generator.gd、room_renderer.gd、room_spawner.gd、world_coordinate.gd、new_room_data.gd、room_content_data.gd、floor_data.gd
- **战斗系统**：combat_manager.gd、damage_system.gd、weapon.gd、weapon_instance.gd、weapon_data.gd、bullet.gd/tscn、damage_number.gd/tscn、hit_effect.gd
- **怪物/Boss**：monster_node.gd/tscn、monster_entity.gd、monster_data.gd、monster_ai.gd、monster_balance_config.gd、boss_controller.gd、boss_data.gd
- **掉落**：reward_item.gd/tscn、reward_data.gd
- **玩家**：player_controller.gd、player.tscn、player_stats.gd
- **成长**：upgrade_manager.gd、upgrade_data.gd、level_up_panel.gd
- **UI**：hud_controller.gd/tscn、pause_menu、settings_menu、save_selection、boss_health_bar.gd、attribute_popup.gd/tscn、resource_center、interaction_hint（若保留交互）
- **数据模型**：map_data.gd、event_data.gd、ai_event_data.gd、player_behavior_data.gd、entity.gd
- **AI 客户端网关**：ai_content_service.gd、ai_response_parser.gd、ai_validator.gd、ai_cache_manager.gd、ai_quality_checker.gd、fake_ai_service.gd
- **AI 自适应**：behavior_analyzer.gd、ai_context_manager.gd、npc_memory_manager.gd、analytics_manager.gd（接线已存在，是否保留功能按阶段3决定，代码暂保留）
- **服务器**：全部 7 个 Router/Service/Schema/Model + security/deps/connection + AI 服务器核心（ai_service、llm_provider、agnes_provider、mimo_client、provider_factory、prompt_builder、request_manager、ai_validator、ai_quality_checker、monster_balance、cache_manager、rate_limit、11 个测试）

### 5.4 决策悬而未决项（需要你拍板）

1. **交互系统**（interaction_manager/interaction_detector/interactive_object/game_object/inventory_manager/equipment_manager/object_manager/interaction_hint）：已接线但零内容。方案A：整体删除，未来需要时重做（推荐，减负）；方案B：保留 interaction_manager+detector+hint 作为扩展点，删除 GameObject/WeaponObject/TestChest 层。**装备管理器 equipment_manager.gd 无论选哪个方案都建议删除（仅被创建与 initialize，无任何功能调用）。**
2. **本地离线存档**：若论文答辩需要演示"断网可玩/可存"，决策反转——保留本地 JSON 存档为唯一存储，API 存档降级为云同步。
3. **AI 楼层生成的启用时机**：阶段3.2 恢复还是保持锁定（论文表述需与代码一致）。

---

## 6. 推荐的新架构

### 6.1 目标架构图（客户端）

```
┌──────── UI Scenes（纯视图，不创建系统）────────────────────────────────┐
│ Login / Main / Game / HUD / Pause / Settings / SaveSelect / LevelUp / │
│ BossBar / ResourceCenter                                              │
└──────────────────────────────────┬────────────────────────────────────┘
                                   │ SceneRouter.go_to_*
┌──────────── Autoload（7个，只做无状态服务）────────────────────────────┐
│ NetworkService(ApiClient+TokenManager合并, 请求ID回调式)  Settings     │
│ ResourceService  SaveService  FlowController  SceneRouter  APIConfig  │
└──────────────────────────────────┬────────────────────────────────────┘
                                   │ 显式依赖注入（组合根，禁止字符串查找）
┌──────────── GameScene = 组合根（唯一 new 系统的地方，<400行）──────────┐
│  GameWorld(Node2D, 原点)                                             │
│   ├─ Player(+Weapon+Camera2D+Stats)   Bullets   Effects              │
│   └─ CurrentRoom(子树, 每次切换整体替换)                              │
│        ├─ Layout(背景/地面/墙/平台, 生成期用local)                     │
│        ├─ MonsterContainer  RewardContainer  Portals  Feedback        │
│  Managers(注入引用, 不查场景树):                                       │
│   FloorManager  CombatManager  ProgressionManager  Analytics/AI网关   │
└────────────────────────────────────────────────────────────────────────┘
运行时规则（写入开发规范）:
  1. 运行时实体一律 global_position；local 只允许在 RoomRenderer 布局生成内部
  2. 跨系统通信=信号或注入引用；禁止 root.get_node / 私有成员直访
  3. 每房间一个子树：怪物/奖励/传送门/背景/反馈全部挂房间节点，切换=整树替换
  4. 新系统必须"退役旧系统"同 PR 提交，禁止并存双轨
```

### 6.2 目标架构图（服务器，变化小）

```
游戏服务器(:8000)  维持现状结构（Router→Service→Schema→Model 分层已正确）
  └─ 补一个 /api/game/save 之外的房间进度字段即可（阶段2.5）
AI服务器(:8001)
  └─ ai_routes.py 按域拆分: floor/room/monster/weapon/event/dialogue/
     progression/difficulty/memory + admin(统计/清理)
  └─ database 单管理器、logger 单模块、每请求超时契约
```

### 6.3 七条架构决策（本次重构的宪法）

- **D1 坐标宪法**：运行时全局坐标；布局期局部坐标；WorldCoordinate 为唯一换算点。
- **D2 组合根**：系统创建只在 GameScene._ready 一处；一切子系统引用经构造/设置器注入。
- **D3 每房间子树**：房间切换 = 子树替换，消灭"清理清单"类代码（clear_monsters/clear_rewards/clear_decorations/clear_background 各自为政的现状）。
- **D4 状态机收口**：FlowState（流程）+ CombatState（战斗）两套；GameState 枚举表废弃或精简为流程态。
- **D5 存档数据模型显式化**：SaveData = { player_state, floor_state{level, rooms:[{id,type,visited,completed}]}, runtime_stats }，客户端单一 SaveService 读写。
- **D6 网络回调制**：请求带 ID，响应按 ID 派发，废除广播+状态过滤。
- **D7 退役即删除**：任何系统被取代时，同一次改动中删除旧系统与旧场景。

---

## 7. A / B / C 分类清单（文件级）

### A. 必须保留（不改或只做坐标类小改）
客户端：api_client.gd / api_config.gd / token_manager.gd / scene_manager.gd / settings_manager.gd / game_flow_controller.gd / game_state_manager.gd / save_service.gd / resource_service.gd / floor_generator.gd / world_coordinate.gd / new_room_data.gd / room_content_data.gd / floor_data.gd / monster_data.gd / monster_balance_config.gd / monster_entity.gd / entity.gd / weapon_data.gd / weapon_instance.gd / bullet.gd / damage_number.gd / hit_effect.gd / reward_data.gd / boss_data.gd / upgrade_data.gd / player_stats.gd / map_data.gd / event_data.gd / ai_event_data.gd / player_behavior_data.gd / login_scene / main_scene / hud / pause_menu / settings_menu / boss_health_bar.gd / attribute_popup.gd / resource_center / monster.tscn / bullet.tscn / damage_number.tscn / player.tscn / reward_item.tscn
服务器：全部 Router/Service/Schema/Model、core/security.py、database/connection.py、api/deps.py、AI 服务器核心（ai_service、llm_provider、agnes_provider、mimo_client、provider_factory、prompt_builder、request_manager、ai_validator、ai_quality_checker、monster_balance、cache_manager、middleware/rate_limit、tests/*）

### B. 可以重构（保留职责，改结构）
- **game_scene.gd**（上帝类 → 纯组合根，系统创建抽到 GameSystemsBuilder，事件处理下沉到各 Manager）
- **ai_content_service.gd**（1375行 → 网关瘦身：请求/降级/超时统一，解析校验缓存质检下沉子模块；删除 RoomNodeData 旧 API）
- **floor_manager.gd / room_renderer.gd / room_spawner.gd**（容器所有权归 RoomRenderer；房间子树统一创建/销毁接口；spawn 流程先定位后入树）
- **monster_ai.gd / boss_controller.gd**（global_position 化；Boss 单一驱动）
- **background_manager.gd / room_clear_feedback.gd**（挂载到房间子树；修复调用顺序）
- **reward_item.gd**（动画起点惰性捕获）
- **player_controller.gd**（属性加成接入 PlayerStats；get_attack 口径收口）
- **combat_manager.gd / damage_system.gd**（伤害口径唯一化）
- **save_service.gd**（按请求类型独立状态，废除 _is_loading 单标志）
- **game_state_manager.gd**（状态机表修正或精简）
- **api_client.gd**（请求 ID 回调制）
- **room_decoration_manager.gd**（要么接线（挂房间子树+由 RoomRenderer 调用），要么转 C 删除——建议删除，背景系统已覆盖视觉层次）
- 服务器 **ai_routes.py**（按域拆分）

### C. 可以删除（见 5.1 完整清单）
旧地图系统 5 文件 + 2 场景、旧生成 2 文件、本地 SaveSystem、ResourceManager autoload、entity_manager/player_entity、6 个未接线 AI/UI 文件、test_chest/weapon_object/weapon_pickup、platform_test_scene、RoomNodeData（前置条件满足后）、全局死容器、空目录、equipment_manager.gd。

---

## 8. 下一阶段重构路线（软件工程正确顺序）

> 原则：**架构稳定 → 核心玩法 → AI功能 → 优化**。
> 本路线不按 Bug 清单推进；Bug 修复是各阶段架构改动的自然结果与验收标准。
> 每阶段结束都有明确验收标准，全部通过才进入下一阶段。

### 阶段 0：基线冻结（0.5 天）
- 提交当前工作区（含 12 个未提交修改），打 tag `baseline-pre-refactor`
- 将 PROJECT_AUDIT_REPORT.md 列为已知行为基线（当前 bug 不改、不复现即通过）
- 在 docs/开发规范.md 补入 D1-D7 七条架构决策
- 验收：工作区干净，规范文档生效

### 阶段 1：架构稳定（按此顺序，不做任何玩法改动）
1. **1.1 死代码清除**：执行 5.1 全清单删除（含 project.godot autoload 条目、GameScene 死接线、空目录），RoomNodeData 旧 API 随 ai_content_service 旧函数一并删。每删一批跑一次 Godot 无报错启动。
   - 验收：`grep -r "load(\"res://scripts/world/room_manager" client/` 等 20 个死引用检查全部为空；游戏启动输出无新警告
2. **1.2 坐标宪法落地**：全项目 grep `position`/`global_position` 建立坐标使用清单 → MonsterAI/BossController/DamageSystem/Bullet/Background/Feedback 统一 global；spawn 流程"先定位后入树"；写入规范并留代码注释。
   - 验收：grep 坐标清单逐条复核通过；运行时日志中怪物/玩家/奖励 global 坐标同房间一致
3. **1.3 依赖注入改造**：删除全部 `Engine.get_main_loop().root.get_node_or_null(...)`（7 个文件）与 `get_tree().current_scene` 查找，改为组合根注入引用（FloorManager/RoomSpawner/CombatManager/DamageSystem 引用沿现有 set_xxx 通道下发）。
   - 验收：全项目 grep `root.get_node` 为 0；游戏启动无 "not found" 类日志
4. **1.4 状态机与网络收口**：GameStateManager 转换表修正（或精简为流程态）；ApiClient 请求 ID 化（本次只改 ApiClient 内部，调用方接口不变）；SaveService 状态分离。
   - 验收：启动到进游戏全程无 "Invalid state transition" 警告；并发请求无串台
5. **1.5 房间子树所有权**：全局容器死节点删除；clear 逻辑收口为"房间子树整体替换"单一入口；RoomRenderer 成为房间子树唯一所有者。
   - 验收：房间切换前后 `GameWorld` 子节点数稳定（无残留、无翻倍）；连续切换 20 间房内存无增长
6. **阶段验收（架构稳定达成）**：项目可在空运行（不动任何玩法）下完成 启动→登录→进游戏→行走→切换多房间→退出；无引擎警告风暴；死代码检查为 0。

### 阶段 2：核心玩法（架构稳定后的第一次功能重构）
1. **2.1 房间导航与生命周期**：传送门目标选择重写（可达性优先、进入规则由 completed 标志驱动、分支房间可达）；enter_count 机制废除。
   - 验收：一局内可进入分支房间并返回；无软锁路径（图遍历脚本验证）
2. **2.2 掉落系统重构**：spawn 顺序修正（先定位后入树）+ 动画起点惰性捕获 + 拾取范围/磁铁基础；奖励房/宝箱房开门链路回归。
   - 验收：奖励落地可见、可拾取、全拾取后开门；PROJECT_AUDIT_REPORT B-01 复现步骤失败（不再复现）
3. **2.3 战斗系统重构**：MonsterAI/BossController global 化 + Boss 单一驱动接入；怪物速度纳入 BalanceConfig。
   - 验收：怪物追击/攻击生效；Boss 阶段转换与技能释放日志可见；B-02/B-03 不复现
4. **2.4 平台系统**：悬浮平台 one_way_collision + 布局可达性算法补遮挡校验；相机 limit 随房间更新。
   - 验收：所有生成平台均可从地面合法到达（自动化布局自检函数输出 100% 可达）
5. **2.5 存档闭环**：主界面"继续游戏"入口；SaveData 显式模型（含房间图）；current_floor/房间状态/武器/被动恢复；暂停保存 floor 修正。
   - 验收：第 N 层保存→主界面→继续→回到第 N 层对应房间，玩家属性/武器/金币一致
6. **阶段验收（核心玩法达成）**：完整一局：登录→第1层→战斗/奖励/事件→Boss→第2层→保存→读档继续→死亡→重开；全程无卡死。

### 阶段 3：AI 功能（论文核心，必须在玩法稳定后）
1. **3.1 客户端 AI 网关瘦身**：ai_content_service 拆分（HTTP/降级/缓存/校验四模块独立）；全部请求带 timeout；RoomNodeData 残留清零（若阶段1.1未完成）。
2. **3.2 AI 楼层生成恢复**：重新接线 generate_floor_content（服务端已有接口与缓存）；AI 结果经 AIValidator/AIQualityChecker 后注入 FloorManager，本地生成器降级为 fallback。
   - 验收：开关切换 AI/本地楼层生成，两路径均可完整通关
3. **3.3 AI 事件/对话/难度 UI 接线**：事件面板（复用 ai_event_panel 或重做）、难度调整提示、对话气泡接入。
4. **3.4 服务端 AI 路由拆分**：ai_routes.py 按域拆 6-8 个 router 文件；双 DB 管理器/双 logger 合并。
5. **阶段验收**：AI 生成内容在游戏内可观测（楼层拓扑/房间内容/事件均有 AI 来源日志与可视化），降级路径在 AI 服务器关闭时静默可用。

### 阶段 4：优化（最后做）
1. 性能：子弹/奖励对象池、装饰与背景合批、AI 请求缓存命中率统计
2. 存档完整性：kill_count/gold_collected/play_time 真实累计
3. 数值：伤害公式去双计、被动全量生效、TTK 曲线复核
4. 代码卫生：game_scene 瘦身收尾、私有成员直访清零、README/架构文档更新
5. **终验**：答辩演示脚本跑通 + 输出稳定报告

---

## 9. 风险与注意事项

1. **阶段1.1 删除面大**：删除前先 `grep -rn "文件名" client/ server/` 生成引用证据表，无引用才删；删完立即启动 Godot 验证（Godot 对 class_name 全局可见，删除顺序不当会编译失败——RoomNodeData 必须先清 ai_content_service 旧函数）。
2. **阶段1.2 坐标改造与阶段2.3 战斗修复边界**：坐标改造必然修复 B-02/B-03——这不是"抢跑修 Bug"，而是架构改动的验收表现，需在报告中如实记录对应关系。
3. **存档删除决策（5.4-2）必须先拍板**，否则阶段2.5 返工。
4. **AI 楼层生成恢复（阶段3.2）**是唯一会改变游戏内容源的大改动，必须在阶段2 通关验收通过后进行，避免"玩法未稳+内容源变更"双重变量。
5. 本计划执行期间**冻结一切新功能**：新功能提案一律记入 backlog，不在本计划内实现。
