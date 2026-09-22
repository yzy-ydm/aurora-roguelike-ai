# CHANGELOG.md

> Aurora-Roguelike-AI 项目变更记录

本文档记录项目所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [0.9.3] - 2026-09-22

### Added - AI内容质量保障体系 (Phase 0 Task 0.3)

**Git Commit:** 待提交

#### 新增功能

**Validator增强：**
- 新增怪物属性范围验证 (`_validate_monster_attributes`)
  - HP: 10-500 (修复AI生成过高HP问题)
  - Attack: 1-50 (修复AI生成过高攻击力)
  - Defense: 0-30 (修复AI生成过高防御力)
- 新增枚举值验证
  - `validate_room_type()`: 房间类型合法性检查
  - `validate_rarity()`: 武器稀有度合法性检查
- `_validate_room()` 方法集成怪物属性验证

**QualityChecker增强：**
- 新增质量评分系统 `calculate_quality_score()`
- 四维度评分模型：
  - Legality (30%): 字段完整性和格式正确性
  - Balance (30%): 数值在游戏平衡范围内
  - Diversity (20%): 内容差异化程度
  - Completeness (20%): 必需字段齐全度
- 调整数值范围常量：
  - MAX_HEALTH: 9999 → 500 (防止HP过高)
  - 新增 MAX_MONSTER_ATTACK: 50
  - 新增 MAX_MONSTER_DEFENSE: 30

#### 新增测试

- `server/ai/tests/test_content_validator.py` (15个测试)
  - Monster属性范围验证 (7个)
  - 房间类型枚举验证 (2个)
  - 武器稀有度枚举验证 (2个)
  - 楼层验证增强 (1个)
  - 质量评分计算 (3个)

#### 测试结果

```
总测试数: 114 → 129 (+15)
全部通过: 129 passed ✅
运行时间: 5.16s
```

#### 文档产出

- `AI_CONTENT_PIPELINE_ANALYSIS.md` — AI生成流程分析
- `AI_CONTENT_VALIDATION_DESIGN.md` — 质量保障体系设计（论文材料）

---

## [0.9.2] - 2026-09-22

### Refactored - Provider Factory 集成与 AIService 解耦 (Phase 0 Task 0.2)

**Git Commit:** 待提交

#### 新增文件
- `server/ai/services/provider_factory.py`
  - ProviderFactory类，统一Provider创建入口
  - 支持通过AI_PROVIDER环境变量动态切换Provider
  - 自动注册Agnes和MiMo Provider
  - 支持动态注册自定义Provider

#### 修改文件
- `server/ai/services/ai_service.py`
  - 移除MimoClient直接import依赖
  - 使用ProviderFactory创建Provider实例
  - ai_mode字段改为动态获取(provider.get_provider_name())
  - fallback逻辑泛化（支持任何Provider失败降级）
  - 环境变量优先级: AI_PROVIDER > LLM_PROVIDER > "mock"
  - 新增_get_ai_mode()和_is_llm_mode()辅助方法

#### 新增测试
- `server/ai/tests/test_provider_factory.py` (10个测试)
  - ProviderFactory注册/创建/查询功能
  - 环境变量配置测试
- `server/ai/tests/test_ai_service_provider_switch.py` (10个测试)
  - AIService Mock模式初始化
  - AIService MiMo模式初始化
  - AIService Agnes模式初始化(有/无Key)
  - 向后兼容LLM_PROVIDER
  - AI_PROVIDER优先级
  - Agnes Provider生成楼层/房间内容
  - Provider不可用/异常时的Fallback

#### 测试结果
- 总测试数: 94 → 114 (+20)
- 全部通过: 114 passed ✅

#### 架构变化
```
修改前:
AIService → (硬编码) → MimoClient

修改后:
AIService → ProviderFactory → AgnesProvider / MimoClient / Mock
```

---

## [0.9.1] - 2026-09-22

### Added - Agnes AI Provider 集成 (Phase 0 Task 0.1)

**Git Commit:** 待提交

- 新增 `server/ai/services/agnes_provider.py`
  - AgnesProvider类，实现LLMProvider接口
  - 支持OpenAI Chat Completions格式 (`/v1/chat/completions`)
  - 认证方式: `Authorization: Bearer`
  - 配置全部来自环境变量，禁止硬编码API Key
  - JSON容错解析（支持markdown代码块包裹）
  - 超时/连接错误处理
- 更新 `server/.env.example`
  - 新增Agnes AI配置段 (AGNES_API_KEY, AGNES_BASE_URL等)
  - 新增AI_PROVIDER统一配置 (agnes/mimo/mock/auto)
  - 保留MiMo配置作为降级方案
- 新增 `server/ai/tests/test_agnes_provider.py`
  - 21个单元测试，覆盖率100%
  - 测试初始化、环境变量、JSON解析、异常处理、请求格式验证

#### 架构变更
- LLMProvider抽象层保持不变
- MimoClient完整保留，向后兼容
- AIService新增Agnes分支（待后续任务修改）
- 总测试数: 73 → 94 (+21)

#### 向后兼容
- `LLM_PROVIDER=mimo` 仍然工作
- `LLM_PROVIDER=mock` 仍然工作
- 现有测试全部通过

---

## [0.9.0-alpha] - 2026-07-16

### Project Freeze - 项目冻结版本

**状态：** Development Paused

#### 核心系统完成
- 登录认证系统 (JWT)
- 玩家系统 (移动、攻击、受伤)
- 武器系统 (射击、伤害计算)
- 怪物系统 (AI、生成、死亡)
- Boss系统 (阶段、技能)
- 房间系统 (楼层、房间生成)
- 战斗系统 (伤害、奖励)
- 存档系统 (保存/加载)
- AI内容生成 (Mock + MiMo API)
- 横版移动系统 (重力、跳跃、冲刺)
- 房间装饰系统
- 视觉升级 (玩家/怪物/奖励Sprite)

#### 数值分析完成
- Phase 24: 战斗平衡分析
- Phase 25: 怪物平衡设计
- Phase 26: 怪物战斗体验设计
- Phase 27: 精英怪词缀设计
- Phase 28: Boss阶段系统设计
- Phase 29: 美术资源架构设计

#### 项目冻结
- 建立完整文档体系
- 创建 PROJECT_RECOVERY.md
- 代码整理完成

---

## [0.22.1] - 2026-07-13

### Fixed - 用户注册自动创建玩家角色

**Git Commit:** 待提交

- 修复用户注册后登录返回"玩家角色不存在"的问题
- 修改 `server/app/services/auth_service.py`
  - register_user() 方法：注册成功后自动创建 PlayerProfile
  - authenticate_user() 方法：登录时检测并自动创建角色（兼容已有用户）
  - 新增 _ensure_player_profile() 方法：确保玩家角色档案存在
- 保持现有架构：Router → Service → ORM → Database

---

## [0.22.0] - 2026-07-13

### Added - 玩家资源系统 (Phase 6.1)

**Git Commit:** 待提交

- 新增武器对象 `client/scripts/weapon/weapon_object.gd`
  - WeaponObject类，继承GameObject
  - 武器数据绑定（WeaponData）
  - 拾取状态管理
  - InteractiveObject关联
- 新增背包管理器 `client/scripts/inventory/inventory_manager.gd`
  - InventoryManager，管理玩家武器库存
  - add_weapon()添加武器
  - remove_weapon()移除武器
  - get_weapon()查询武器
  - load_from_server_data()从服务器加载
  - 信号机制（weapon_added, weapon_removed, inventory_updated）
- 新增装备管理器 `client/scripts/inventory/equipment_manager.gd`
  - EquipmentManager，管理装备状态
  - equip_weapon()装备武器
  - unequip_weapon()卸下武器
  - get_equipped_weapon()获取当前装备
- 新增武器拾取场景 `client/scenes/object/weapon_pickup.tscn`
- 更新API配置 `client/scripts/api/api_config.gd`
  - 添加PLAYER_WEAPONS端点
- 更新游戏场景 `client/scenes/game/game_scene.gd`
  - 集成InventoryManager和EquipmentManager
  - 创建武器拾取对象
  - 武器拾取交互流程
  - 与player_weapons API同步

---

## [0.21.0] - 2026-07-13

### Added - 基础游戏对象实例化系统 (Phase 5.11)

**Git Commit:** 待提交

- 新增游戏对象基础类 `client/scripts/object/game_object.gd`
  - GameObject类，所有游戏对象的基类
  - ObjectState枚举（CREATED, ACTIVE, INTERACTED, DISABLED）
  - 对象唯一ID系统
  - 位置管理
  - 生命周期状态管理
  - InteractiveObject关联
- 新增对象管理器 `client/scripts/object/object_manager.gd`
  - ObjectManager，统一管理GameObject
  - register_object()注册对象
  - unregister_object()注销对象
  - get_object()查询对象
  - get_objects_by_type()按类型查询
  - 类型索引机制
  - 信号机制（object_registered, object_state_changed）
- 新增测试宝箱对象 `client/scripts/object/test_chest.gd`
  - TestChest类，继承GameObject
  - 创建InteractiveObject并关联
  - 交互完成回调
  - 宝箱打开状态管理
- 更新游戏场景 `client/scenes/game/game_scene.gd`
  - 集成ObjectManager
  - 创建测试宝箱实例
  - 宝箱与InteractiveObject关联
  - 玩家靠近宝箱可交互

---

## [0.20.0] - 2026-07-13

### Added - 基础游戏对象交互框架 (Phase 5.10)

**Git Commit:** 待提交

- 新增交互对象基础类 `client/scripts/interaction/interactive_object.gd`
  - InteractiveObject类，所有可交互对象的基类
  - InteractionType枚举（NONE, PICKUP, USE, TALK, EXAMINE, ENTER, CUSTOM）
  - InteractionState枚举（IDLE, IN_RANGE, INTERACTING, COOLDOWN, DISABLED）
  - 交互提示文本
  - 冷却时间机制
- 新增交互管理器 `client/scripts/interaction/interaction_manager.gd`
  - InteractionManager，管理所有可交互对象
  - register_object()注册交互对象
  - unregister_object()注销交互对象
  - object_enter_range()对象进入范围
  - object_exit_range()对象离开范围
  - trigger_interaction()触发交互
  - 最近对象追踪
  - 信号机制（object_registered, interaction_triggered, nearest_object_changed）
- 新增交互检测器 `client/scripts/interaction/interaction_detector.gd`
  - InteractionDetector，使用Area2D检测交互范围
  - body_entered/body_exited信号处理
  - area_entered/area_exited信号处理
  - 可配置检测范围
- 新增交互提示UI `client/scripts/ui/interaction_hint.gd`
  - InteractionHint，显示交互提示
  - show_hint()显示提示
  - hide_hint()隐藏提示
- 新增交互提示场景 `client/scenes/ui/interaction_hint.tscn`
- 更新项目配置 `client/project.godot`
  - 添加interaction输入动作（E键）
- 更新游戏场景 `client/scenes/game/game_scene.tscn`
  - 添加InteractionManager节点
  - 添加InteractionDetector到Player节点
  - 添加InteractionHint UI节点
- 更新游戏场景脚本 `client/scenes/game/game_scene.gd`
  - 集成InteractionManager和InteractionDetector
  - E键触发交互
  - 交互提示显示/隐藏

---

## [0.19.0] - 2026-07-13

### Added - 游戏实体基础框架 (Phase 5.9)

**Git Commit:** 待提交

- 新增实体基础类 `client/scripts/entity/entity.gd`
  - Entity类，所有游戏实体的基类
  - EntityState枚举（CREATED, ACTIVE, PAUSED, DESTROYED）
  - 唯一ID系统（自动生成）
  - 位置管理（Vector2）
  - 生命周期状态管理
  - 自定义数据存储
  - 序列化/反序列化（to_dict/from_dict）
- 新增实体管理器 `client/scripts/entity/entity_manager.gd`
  - EntityManager，统一管理实体
  - register_entity()注册实体
  - unregister_entity()注销实体
  - get_entity()查询实体
  - get_entities_by_type()按类型查询
  - destroy_entity()销毁实体
  - 类型索引机制
  - 信号机制（entity_registered, entity_unregistered, entity_destroyed）
- 新增玩家实体 `client/scripts/entity/player_entity.gd`
  - PlayerEntity类，继承Entity
  - 绑定PlayerController节点
  - 玩家数据管理（level, health, attack, defense, gold）
  - 位置同步（Node ↔ Entity）
  - 与已有PlayerController兼容

---

## [0.18.0] - 2026-07-13

### Added - 基础游戏世界构建 (Phase 5.8)

**Git Commit:** 待提交

- 新增世界管理器 `client/scripts/world/world_manager.gd`
  - WorldState枚举（UNINITIALIZED, LOADING, READY, IN_ROOM, TRANSITIONING）
  - 世界初始化和地图加载
  - 房间生命周期管理
  - 信号机制（world_initialized, room_changed）
- 新增房间管理器 `client/scripts/world/room_manager.gd`
  - 房间进入/退出/切换
  - 房间列表管理
  - 信号机制（room_entered, room_exited, room_changed）
- 新增地图渲染器 `client/scripts/world/map_renderer.gd`
  - 根据地图资源显示地图
  - 房间渲染（背景、边框、标签）
  - 碰撞墙生成
  - 房间类型颜色区分
- 新增房间数据模型 `client/scripts/models/room_data.gd`
  - RoomData类，解析房间数据
  - from_map_data()从MapData创建房间列表
- 新增世界场景 `client/scenes/world/world.tscn`
- 新增房间场景 `client/scenes/world/rooms/room.tscn`
- 更新游戏场景 `client/scenes/game/game_scene.tscn`
  - 添加World节点
  - 移除TestWalls（由MapRenderer生成）
- 更新游戏场景脚本 `client/scenes/game/game_scene.gd`
  - 集成WorldManager和RoomManager
  - 世界初始化和房间切换处理

---

## [0.17.0] - 2026-07-13

### Added - 基础游戏交互系统 (Phase 5.7)

**Git Commit:** 待提交

- 新增暂停菜单场景 `client/scenes/ui/pause_menu.tscn`
  - Continue继续游戏按钮
  - Save保存游戏按钮
  - Settings设置按钮
  - Exit退出游戏按钮
- 新增暂停菜单控制器 `client/scripts/ui/pause_menu.gd`
  - ESC打开/关闭暂停
  - 保存游戏功能
  - Godot暂停机制集成（process_mode = 3）
- 新增设置菜单场景 `client/scenes/ui/settings_menu.tscn`
  - 主音量滑块
  - 音乐音量滑块
  - 音效音量滑块
  - 恢复默认按钮
- 新增设置菜单控制器 `client/scripts/ui/settings_menu.gd`
  - 音量设置管理
  - 设置保存和加载
- 新增存档选择场景 `client/scenes/ui/save_selection.tscn`
  - 3个存档槽位
  - 存档信息显示
  - 返回按钮
- 新增存档选择控制器 `client/scripts/ui/save_selection.gd`
  - 存档列表加载
  - 槽位选择
  - SaveService集成
- 新增设置管理器 `client/scripts/managers/settings_manager.gd`
  - ConfigFile本地配置保存
  - 音量设置管理
  - 信号机制（settings_changed）
- 更新游戏场景 `client/scenes/game/game_scene.tscn`
  - 添加暂停菜单、设置菜单、存档选择节点
- 更新游戏场景脚本 `client/scenes/game/game_scene.gd`
  - 集成暂停菜单（ESC切换）
  - 集成设置菜单
  - 集成存档选择界面
  - 暂停时冻结游戏逻辑
- 更新项目配置 `client/project.godot`
  - 添加SettingsManager全局单例

---

## [0.16.0] - 2026-07-13

### Added - 游戏循环系统 (Phase 5.6)

**Git Commit:** 待提交

- 新增游戏状态管理器 `client/scripts/managers/game_state_manager.gd`
  - GameState枚举（NOT_STARTED, LOADING, PLAYING, PAUSED, GAME_OVER）
  - 玩家数据管理
  - 存档状态管理
  - 游戏运行时间追踪
  - 信号机制（state_changed, player_data_updated, save_loaded）
- 新增存档服务 `client/scripts/services/save_service.gd`
  - load_saves()加载存档列表
  - load_save_by_slot()加载指定存档
  - save_game()保存存档
  - create_save()创建新存档
  - 信号机制（saves_loaded, save_loaded, save_saved, save_error）
- 新增游戏流程控制器 `client/scripts/managers/game_flow_controller.gd`
  - FlowState枚举管理流程状态
  - start_game()开始游戏流程
  - enter_game()进入游戏场景
  - exit_game()退出并保存
  - 流程：加载玩家→加载存档→加载资源→进入游戏
- 更新API配置 `client/scripts/api/api_config.gd`
  - 添加GAME_SAVE端点常量
- 更新登录场景 `client/scenes/login/login_scene.gd`
  - 集成GameFlowController
  - 登录成功后自动加载游戏数据
- 更新游戏场景 `client/scenes/game/game_scene.gd`
  - 集成GameStateManager
  - 添加退出保存功能
  - 添加游戏运行时间追踪
- 更新项目配置 `client/project.godot`
  - 添加GameStateManager、SaveService、GameFlowController单例

---

## [0.15.0] - 2026-07-13

### Added - 基础游戏资源展示系统 (Phase 5.5)

**Git Commit:** 待提交

- 新增资源中心场景 `client/scenes/resource/resource_center.tscn`
  - TabContainer四Tab布局（武器/怪物/地图/事件）
  - 每个Tab包含列表和详情面板
  - 返回游戏按钮
- 新增资源中心控制器 `client/scripts/ui/resource_center.gd`
  - 调用ResourceService加载资源
  - 填充武器/怪物/地图/事件列表
  - 显示选中资源详情
  - 错误处理
- 更新场景管理器 `client/scripts/managers/scene_manager.gd`
  - 添加RESOURCE_CENTER常量
  - 添加go_to_resource_center()方法
- 更新游戏场景 `client/scenes/game/game_scene.tscn`
  - 添加菜单面板（资源中心按钮、退出登录按钮）
- 更新游戏场景脚本 `client/scenes/game/game_scene.gd`
  - 添加资源中心按钮处理
  - 添加退出登录按钮处理

---

## [0.14.0] - 2026-07-13

### Added - 游戏资源加载系统 (Phase 5.4)

**Git Commit:** 待提交

- 新增武器数据模型 `client/scripts/models/weapon_data.gd`
  - WeaponData类，解析武器JSON数据
  - from_dict/from_array静态方法
- 新增怪物数据模型 `client/scripts/models/monster_data.gd`
  - MonsterData类，解析怪物JSON数据
  - from_dict/from_array静态方法
- 新增地图数据模型 `client/scripts/models/map_data.gd`
  - MapData类，解析地图JSON数据
  - from_dict/from_array静态方法
- 新增事件数据模型 `client/scripts/models/event_data.gd`
  - EventData类，解析事件JSON数据
  - from_dict/from_array静态方法
- 新增资源加载服务 `client/scripts/services/resource_service.gd`
  - ResourceService单例，负责API资源请求和缓存
  - load_all_resources()加载所有游戏资源
  - get_weapons/get_monsters/get_maps/get_events获取资源
  - get_*_by_id按ID查询资源
- 更新HUD场景 `client/scenes/game/hud.tscn`
  - 添加资源统计面板（武器/怪物/地图/事件数量）
- 更新HUD控制器 `client/scripts/ui/hud_controller.gd`
  - 添加update_resource_counts方法
- 更新游戏场景 `client/scenes/game/game_scene.gd`
  - 集成ResourceService资源加载
  - 资源加载完成后更新HUD显示
- 更新项目配置 `client/project.godot`
  - 添加ResourceService全局单例

---

## [0.13.0] - 2026-07-13

### Added - 玩家基础控制 (Phase 5.3)

**Git Commit:** 待提交

- 更新项目配置 `client/project.godot`
  - 添加Input Map配置（move_up, move_down, move_left, move_right）
  - 支持WASD和方向键输入
- 更新玩家控制器 `client/scripts/player/player_controller.gd`
  - 实现输入处理（_get_input_direction）
  - 实现移动逻辑（_physics_process + move_and_slide）
  - 移动速度200像素/秒
  - 对角线移动归一化
- 更新玩家场景 `client/scenes/game/player.tscn`
  - 添加Camera2D子节点
  - 摄像机跟随玩家移动
- 更新游戏场景 `client/scenes/game/game_scene.tscn`
  - 添加测试边界碰撞墙（上下左右四面墙）
  - 使用StaticBody2D + CollisionShape2D
- 更新游戏场景脚本 `client/scenes/game/game_scene.gd`
  - 更新状态提示信息

---

## [0.12.0] - 2026-07-13

### Added - 基础游戏场景 (Phase 5.2)

**Git Commit:** 待提交

- 新增游戏主场景 `client/scenes/game/game_scene.tscn`
  - 游戏世界容器
  - 背景层
  - UI层
  - 摄像机配置
- 新增玩家节点 `client/scenes/game/player.tscn`
  - CharacterBody2D基础节点
  - Sprite占位显示
  - CollisionShape碰撞体
- 新增玩家控制器 `client/scripts/player/player_controller.gd`
  - 玩家数据管理
  - 显示初始化
- 新增HUD系统 `client/scenes/game/hud.tscn`
  - 玩家昵称显示
  - 等级显示
  - 生命值进度条
  - 金币显示
  - 状态栏
- 新增HUD控制器 `client/scripts/ui/hud_controller.gd`
  - HUD数据更新
  - 生命值进度条计算
- 新增场景管理器 `client/scripts/managers/scene_manager.gd`
  - 登录/主界面/游戏场景切换
  - 场景状态管理
- 新增资源管理器 `client/scripts/managers/resource_manager.gd`
  - 纹理资源加载缓存
  - 音频资源加载缓存
- 更新登录场景使用场景管理器
- 更新主界面场景使用场景管理器
- 更新project.godot添加SceneManager和ResourceManager单例

---

## [0.11.0] - 2026-07-13

### Added - Godot客户端基础框架 (Phase 5.1)

**Git Commit:** 待提交

- 初始化Godot 4.x项目 `client/project.godot`
- 新增API配置模块 `client/scripts/api/api_config.gd`
  - 服务器地址配置
  - API端点常量定义
- 新增Token管理模块 `client/scripts/api/token_manager.gd`
  - JWT Token保存/读取/清除
  - Token文件持久化
  - Authorization头生成
- 新增HTTP客户端模块 `client/scripts/api/api_client.gd`
  - GET/POST/PUT请求封装
  - JSON解析
  - 统一错误处理
  - 信号机制
- 新增登录界面 `client/scenes/login/`
  - 登录功能
  - 注册功能
  - Tab切换
- 新增主界面 `client/scenes/main/`
  - 玩家信息显示
  - 刷新功能
  - 退出登录
- 验证客户端-服务器通信链路

---

## [0.10.0] - 2026-07-13

### Added - 事件资源接口 (Phase 4.6.3)

**Git Commit:** 待提交

- 新增事件ORM模型 `app/models/event.py`
  - Event类映射events表
  - 包含事件属性：name, event_type, description, trigger_rate等
  - 包含选项数据：option1_text, option1_effect, option2_text, option2_effect（JSON）
- 新增事件Schema `app/schemas/event.py`
  - EventResponse: 事件信息响应（字段映射：type→event_type）
- 新增事件服务 `app/services/event_service.py`
  - get_all_events(): 获取所有事件列表
  - get_event_by_id(): 获取事件详情
- 新增事件API路由 `app/api/event/router.py`
  - GET /api/events: 事件列表（公开接口）
  - GET /api/events/{event_id}: 事件详情（公开接口）
- 更新main.py注册事件路由
- 更新models/schemas/services __init__.py导出

---

## [0.9.0] - 2026-07-13

### Added - 地图资源接口 (Phase 4.6.2)

**Git Commit:** 待提交

- 新增地图ORM模型 `app/models/map.py`
  - Map类映射maps表
  - 包含地图属性：name, theme, floor_level, width, height, room_count等
  - 包含配置数据：room_data, monster_spawn_config, event_spawn_config（JSON）
- 新增地图Schema `app/schemas/map.py`
  - MapResponse: 地图信息响应（字段映射：type→theme）
- 新增地图服务 `app/services/map_service.py`
  - get_all_maps(): 获取所有地图列表
  - get_map_by_id(): 获取地图详情
- 新增地图API路由 `app/api/map/router.py`
  - GET /api/maps: 地图列表（公开接口）
  - GET /api/maps/{map_id}: 地图详情（公开接口）
- 更新main.py注册地图路由
- 更新models/schemas/services __init__.py导出

---

## [0.8.0] - 2026-07-13

### Added - 游戏存档系统 (Phase 4.6.1)

**Git Commit:** 待提交

- 新增游戏存档ORM模型 `app/models/game_save.py`
  - GameSave类映射game_saves表
  - 包含存档属性：save_name, current_floor, player_state, inventory_data等
  - 槽位唯一性约束（user_id + slot_number）
- 新增游戏存档Schema `app/schemas/save.py`
  - SaveCreate: 创建存档请求（save_name, slot_number, player_state）
  - SaveUpdate: 更新存档请求（current_floor, player_state, inventory_data等）
  - SaveResponse: 存档信息响应
- 新增游戏存档服务 `app/services/save_service.py`
  - create_save(): 创建游戏存档
  - get_user_saves(): 查询用户所有存档
  - get_save_by_slot(): 查询指定槽位存档
  - update_save(): 更新游戏存档
- 新增游戏存档API路由 `app/api/save/router.py`
  - POST /api/game/save: 创建存档（JWT认证）
  - GET /api/game/save: 查询所有存档（JWT认证）
  - GET /api/game/save/{slot_number}: 查询指定存档（JWT认证）
  - PUT /api/game/save/{slot_number}: 更新存档（JWT认证）
- 更新main.py注册存档路由
- 更新models/schemas/services __init__.py导出

---

## [0.7.0] - 2026-07-13

### Added - 怪物系统 (Phase 4.5)

**Git Commit:** 待提交

- 新增怪物ORM模型 `app/models/monster.py`
  - Monster类映射monsters表
  - 包含怪物属性：name, monster_type, level, health, attack, defense, speed等
  - 包含特殊能力：special_ability, special_ability_data（JSON）
- 新增怪物Schema `app/schemas/monster.py`
  - MonsterResponse: 怪物信息响应（字段映射：type→monster_type, attributes→special_ability_data）
- 新增怪物服务 `app/services/monster_service.py`
  - get_all_monsters(): 获取所有怪物列表
  - get_monster_by_id(): 获取怪物详情
- 新增怪物API路由 `app/api/monster/router.py`
  - GET /api/monsters: 怪物列表（公开接口）
  - GET /api/monsters/{monster_id}: 怪物详情（公开接口）
- 更新main.py注册怪物路由
- 更新models/schemas/services __init__.py导出

---

## [0.6.0] - 2026-07-13

### Added - 武器系统 (Phase 4.4)

**Git Commit:** 待提交

- 新增武器ORM模型 `app/models/weapon.py`
  - Weapon类映射weapons表
  - 包含武器属性：name, weapon_type, rarity, attack_bonus, crit_rate_bonus等
- 新增玩家武器关联模型 `app/models/player_weapon.py`
  - PlayerWeapon类映射player_weapons表
  - 实现玩家与武器的多对多关系
- 新增武器Schema `app/schemas/weapon.py`
  - WeaponResponse: 武器信息响应（字段映射：type→weapon_type, damage→attack_bonus, attributes→special_effect_data）
  - PlayerWeaponResponse: 玩家武器响应（包含武器详情和装备状态）
  - AddPlayerWeaponRequest: 添加武器请求
- 新增武器服务 `app/services/weapon_service.py`
  - get_all_weapons(): 获取所有武器列表
  - get_weapon_by_id(): 获取武器详情
  - get_player_weapons(): 查询玩家武器
  - add_player_weapon(): 添加玩家武器
- 新增武器API路由 `app/api/weapon/router.py`
  - GET /api/weapons: 武器列表（公开接口）
  - GET /api/weapons/{weapon_id}: 武器详情（公开接口）
  - GET /api/player/weapons: 玩家武器（JWT认证）
  - POST /api/player/weapons: 添加武器（JWT认证）
- 新增共享认证依赖模块 `app/api/deps.py`
- 创建player_weapons关联表SQL脚本
- 更新main.py注册武器路由
- 更新models/schemas/services __init__.py导出

---

## [0.5.0] - 2026-07-13

### Added - 玩家角色系统 (Phase 4.3)

**Git Commit:** 待提交

- 新增玩家角色ORM模型 `app/models/player_profile.py`
  - PlayerProfile类映射player_profiles表
  - 与users表1:1关系（UNIQUE约束）
  - 包含角色属性：level, experience, health, attack, defense, gold等
- 新增玩家角色Schema `app/schemas/player.py`
  - PlayerCreate: 创建角色请求（nickname）
  - PlayerUpdate: 更新角色请求（nickname）
  - PlayerResponse: 角色信息响应
- 新增玩家角色服务 `app/services/player_service.py`
  - create_player(): 创建角色（检查唯一性）
  - get_player_profile(): 查询角色信息
  - update_player_profile(): 更新角色昵称
- 新增玩家角色API路由 `app/api/player/router.py`
  - POST /api/player/profile: 创建角色（JWT认证）
  - GET /api/player/profile: 查询角色（JWT认证）
  - PUT /api/player/profile: 更新角色（JWT认证）
- 更新main.py注册玩家路由
- 更新models/schemas/services __init__.py导出

---

## [0.4.1] - 2026-07-13

### Fixed - 项目安全修复与文档同步 (Phase 4.2.5)

**Git Commit:** 待提交

- 修复 `.env.example` 变量名不一致（`DB_*` → `MYSQL_*`）
- 修复 `database/design/README.md` 表名错误（`ai_generation_logs` → `ai_generations`）
- 更新 `docs/backend/FastAPI启动说明.md` 模块状态
- 补充 `CHANGELOG.md` 遗漏的提交记录
- 新增项目恢复报告和文档审计报告

---

## [0.4.0] - 2026-07-13

### Added - 项目文档体系 (Phase 1补充)

**Git Commit:** `fcaf9f4`

- 新增 SYSTEM_PROMPT.md 项目规则文档
- 新增 PROJECT_STATUS.md 项目状态文档
- 新增 ROADMAP.md 开发路线图
- 新增 TODO.md 任务清单
- 新增 ARCHITECTURE.md 系统架构文档
- 新增 AI_CONTEXT.md 设计理念文档
- 新增 FEATURE_SPEC.md 功能需求文档
- 新增 DEVELOPMENT_GUIDE.md 开发规范文档
- 新增 API_DOCUMENT.md API接口文档
- 新增 DATABASE.md 数据库设计文档
- 新增 DEPLOYMENT.md 部署说明文档
- 更新 README.md 项目说明

---

## [0.3.1] - 2026-07-13

### Added - 用户认证系统 (Phase 4.2)

**Git Commit:** `0352e25`

- 用户注册接口 `POST /api/auth/register`
- 用户登录接口 `POST /api/auth/login`
- JWT Token认证机制
- bcrypt密码加密
- 用户数据模型 `app/models/user.py`
- 安全模块 `app/core/security.py`
- 认证Schema `app/schemas/auth.py`
- 认证服务 `app/services/auth_service.py`
- 认证路由 `app/api/auth/router.py`

---

## [0.3.0] - 2026-07-13

### Added - FastAPI数据库连接层 (Phase 4.1)

**Git Commit:** `4d059e8`

- FastAPI应用初始化
- SQLAlchemy数据库连接
- PyMySQL驱动配置
- 环境变量配置 `.env`
- 数据库健康检查接口 `GET /health`
- 数据库连接模块 `app/database/connection.py`
- FastAPI启动说明文档

---

## [0.2.0] - 2026-07-13

### Added - MySQL数据库设计 (Phase 3)

**Git Commit:** `494de64`

- 数据库 `aurora_game` 创建
- 8张核心数据表设计：
  - `users` 用户账号表
  - `player_profiles` 玩家角色信息表
  - `weapons` 武器数据表
  - `monsters` 怪物数据表
  - `events` 随机事件表
  - `maps` 地图数据表
  - `game_saves` 游戏存档表
  - `ai_generations` AI生成记录表
- 测试数据脚本
- 数据库设计文档

---

## [0.1.0] - 2026-07-12

### Added - 项目初始化 (Phase 1 & Phase 2)

**Git Commit:** `0e61898`

- 项目目录结构设计
- README.md 项目说明文档
- .gitignore 配置
- 开发规范文档
- Git仓库初始化
- GitHub私有仓库创建
- 基础工程规范

---

## 版本号说明

- **主版本号 (Major)**：重大架构变更或功能里程碑
- **次版本号 (Minor)**：新功能模块完成
- **修订号 (Patch)**：Bug修复和小改动

---

## Git提交规范

```
<type>(<scope>): <subject>

type:
- feat: 新功能
- fix: 修复
- docs: 文档
- style: 格式
- refactor: 重构
- test: 测试
- chore: 构建/工具

示例:
feat(auth): add user login endpoint
fix(api): fix token validation error
docs(readme): update project description
```
