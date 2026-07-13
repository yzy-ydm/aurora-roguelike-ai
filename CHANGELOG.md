# CHANGELOG.md

> Aurora-Roguelike-AI 项目变更记录

本文档记录项目所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

### 待开发
- Phase 5.7 基础游戏交互准备

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
