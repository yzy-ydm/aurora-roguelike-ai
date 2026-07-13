# TODO.md

> Aurora-Roguelike-AI 项目任务清单

最后更新：2026-07-13

---

## 当前阶段：Phase 5.3 已完成，准备进入 Phase 5.4

---

## ✅ 已完成任务

### Phase 1：项目初始化
- [x] 项目目录结构设计
- [x] README.md 项目说明文档
- [x] .gitignore 配置
- [x] 开发规范文档

### Phase 2：Git工程管理
- [x] Git仓库初始化
- [x] GitHub私有仓库创建（aurora-roguelike-ai）
- [x] main分支管理
- [x] 提交规范建立

### Phase 3：MySQL数据库设计
- [x] 数据库 aurora_game 创建
- [x] users 用户表设计
- [x] player_profiles 玩家档案表设计
- [x] weapons 武器表设计
- [x] monsters 怪物表设计
- [x] events 事件表设计
- [x] maps 地图表设计
- [x] game_saves 存档表设计
- [x] ai_generations AI生成记录表设计
- [x] 测试数据导入
- [x] 数据库设计文档

### Phase 4.1：FastAPI数据库连接
- [x] FastAPI应用初始化
- [x] SQLAlchemy ORM配置
- [x] MySQL数据库连接
- [x] 环境变量配置（.env）
- [x] 健康检查接口（/health）
- [x] 数据库连接模块（app/database/）

### Phase 4.2：用户认证系统
- [x] 用户模型（app/models/user.py）
- [x] 安全模块（app/core/security.py）
- [x] 认证Schema（app/schemas/auth.py）
- [x] 认证服务（app/services/auth_service.py）
- [x] 认证路由（app/api/auth/router.py）
- [x] 用户注册接口（POST /api/auth/register）
- [x] 用户登录接口（POST /api/auth/login）
- [x] JWT Token认证
- [x] bcrypt密码加密

### Phase 4.2.5：安全修复与文档同步
- [x] 环境安全检查（.env未被Git跟踪，确认安全）
- [x] 统一 .env.example 变量名（DB_* → MYSQL_*）
- [x] 修复 database/design/README.md 表名错误
- [x] 更新 docs/backend/FastAPI启动说明.md 模块状态
- [x] 补充 CHANGELOG.md 遗漏提交记录
- [x] 新增项目恢复报告（docs/PROJECT_RECOVERY_REPORT.md）
- [x] 新增文档审计报告（docs/DOCUMENT_AUDIT_REPORT.md）

### 项目文档体系
- [x] SYSTEM_PROMPT.md 项目规则
- [x] PROJECT_STATUS.md 项目状态
- [x] ROADMAP.md 开发路线
- [x] TODO.md 任务清单
- [x] CHANGELOG.md 变更记录
- [x] ARCHITECTURE.md 系统架构
- [x] AI_CONTEXT.md 设计理念
- [x] FEATURE_SPEC.md 功能需求
- [x] DEVELOPMENT_GUIDE.md 开发规范
- [x] API_DOCUMENT.md 接口文档
- [x] DATABASE.md 数据库设计
- [x] DEPLOYMENT.md 部署说明

---

## ⬜ 待开发任务

### Phase 4.3：玩家角色系统
- [x] player_profiles 模型（app/models/player_profile.py）
- [x] 玩家Schema（app/schemas/player.py）
- [x] 玩家服务（app/services/player_service.py）
- [x] 玩家路由（app/api/player/router.py）
- [x] 创建角色接口（POST /api/player/profile）
- [x] 查询角色接口（GET /api/player/profile）
- [x] 更新角色接口（PUT /api/player/profile）

### Phase 4.4：武器系统
- [x] weapons 模型（app/models/weapon.py）
- [x] player_weapons 模型（app/models/player_weapon.py）
- [x] 武器Schema（app/schemas/weapon.py）
- [x] 武器服务（app/services/weapon_service.py）
- [x] 武器路由（app/api/weapon/router.py）
- [x] 武器列表接口（GET /api/weapons）
- [x] 武器详情接口（GET /api/weapons/{id}）
- [x] 玩家武器接口（GET /api/player/weapons）
- [x] 添加武器接口（POST /api/player/weapons）

### Phase 4.5：怪物系统
- [x] monsters 模型（app/models/monster.py）
- [x] 怪物Schema（app/schemas/monster.py）
- [x] 怪物服务（app/services/monster_service.py）
- [x] 怪物路由（app/api/monster/router.py）
- [x] 怪物列表接口（GET /api/monsters）
- [x] 怪物详情接口（GET /api/monsters/{id}）

### Phase 4.6：游戏数据接口
- [x] game_saves 模型（app/models/game_save.py）
- [x] 存档Schema（app/schemas/save.py）
- [x] 存档服务（app/services/save_service.py）
- [x] 存档路由（app/api/save/router.py）
- [x] 创建存档接口（POST /api/game/save）
- [x] 查询所有存档接口（GET /api/game/save）
- [x] 查询指定存档接口（GET /api/game/save/{slot}）
- [x] 更新存档接口（PUT /api/game/save/{slot}）
- [x] maps 模型（app/models/map.py）
- [x] 地图Schema（app/schemas/map.py）
- [x] 地图服务（app/services/map_service.py）
- [x] 地图路由（app/api/map/router.py）
- [x] 地图列表接口（GET /api/maps）
- [x] 地图详情接口（GET /api/maps/{id}）
- [x] events 模型（app/models/event.py）
- [x] 事件Schema（app/schemas/event.py）
- [x] 事件服务（app/services/event_service.py）
- [x] 事件路由（app/api/event/router.py）
- [x] 事件列表接口（GET /api/events）
- [x] 事件详情接口（GET /api/events/{id}）

### Phase 5：Godot客户端
- [x] Godot项目初始化（client/project.godot）
- [x] API配置模块（client/scripts/api/api_config.gd）
- [x] Token管理模块（client/scripts/api/token_manager.gd）
- [x] HTTP客户端模块（client/scripts/api/api_client.gd）
- [x] 登录界面（client/scenes/login/）
- [x] 注册功能
- [x] JWT Token保存和管理
- [x] 玩家信息显示界面（client/scenes/main/）
- [x] 游戏主场景（client/scenes/game/game_scene.tscn）
- [x] 玩家节点（client/scenes/game/player.tscn）
- [x] 玩家控制器（client/scripts/player/player_controller.gd）
- [x] HUD系统（client/scenes/game/hud.tscn）
- [x] HUD控制器（client/scripts/ui/hud_controller.gd）
- [x] 场景管理器（client/scripts/managers/scene_manager.gd）
- [x] 资源管理器（client/scripts/managers/resource_manager.gd）
- [x] 登录→游戏场景切换
- [x] Input Map配置（WASD + 方向键）
- [x] 玩家移动控制（CharacterBody2D + move_and_slide）
- [x] 摄像机跟随（Camera2D作为Player子节点）
- [x] 基础碰撞检测（测试边界碰撞墙）

### Phase 6：核心玩法
- [ ] 随机地图生成
- [ ] 玩家控制
- [ ] 战斗系统

### Phase 7：AI动态生成
- [ ] AI服务抽象层
- [ ] DeepSeek API接入
- [ ] 动态内容生成

### Phase 8：测试优化
- [ ] 单元测试
- [ ] 接口测试
- [ ] 性能优化

### Phase 9：论文答辩
- [ ] 论文撰写
- [ ] 答辩准备

---

## 任务优先级

1. **高优先级**：Phase 4.3-4.6 后端API完善
2. **中优先级**：Phase 5 Godot客户端基础
3. **中优先级**：Phase 6 核心玩法
4. **低优先级**：Phase 7 AI集成（可选功能）
