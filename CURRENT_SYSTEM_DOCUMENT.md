# Aurora-Roguelike-AI 当前系统文档

> 生成日期：2026-09-21
> 分支：main (before-refactor-v1)
> 状态：冻结版本 v0.9.0-alpha

---

## 一、当前架构

```
┌──────────────────────────────────────────────────────────────┐
│                    Godot 4.7 客户端                          │
│                                                              │
│  [登录] → [主菜单] → [游戏场景]                              │
│    │         │           │                                   │
│    │         │     ┌─────┴──────┐                            │
│    │         │     │ FloorManager│                            │
│    │         │     │ CombatManager│                           │
│    │         │     │ UpgradeManager│                          │
│    │         │     │ AIContentService│                        │
│    │         │     └──────────────┘                           │
│    │         │          │                                     │
│    │         │     HTTP REST API                              │
│    └─────────┴──────────┼─────────────────────────────────────┘
│                         │
│               ┌─────────▼──────────┐                          │
│         Port 8000  │  FastAPI 主服务 │                          │
│               │  • 用户认证(JWT)    │                          │
│               │  • CRUD API(7模块)  │                          │
│               │  • MySQL持久化      │                          │
│               └─────────┬──────────┘                          │
│                         │                                     │
│               ┌─────────▼──────────┐                          │
│         Port 8001  │  FastAPI AI服务 │                          │
│               │  • 11个AI生成接口   │                          │
│               │  • Mock模式(默认)   │                          │
│               │  • MiMo LLM(已配置) │                          │
│               │  • 缓存/限流/日志   │                          │
│               └─────────┬──────────┘                          │
│                         │                                     │
│               ┌─────────▼──────────┐                          │
│               │    MySQL 8.0       │                          │
│               │  aurora_game 库    │                          │
│               │    9张数据表       │                          │
│               └────────────────────┘                          │
│                         │                                     │
│               ┌─────────▼──────────┐                          │
│               │   SQLite (AI数据)  │                          │
│               │  ai_generations.db │                          │
│               │  aurora.db         │                          │
│               └────────────────────┘                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 二、当前功能清单

### 2.1 已完成功能 ✅

#### 客户端 (Godot)

| 系统 | 状态 | 说明 |
|------|------|------|
| 登录/注册 | ✅ | JWT认证，自动创建玩家角色 |
| 主菜单 | ✅ | 玩家信息显示、退出登录 |
| 横版移动 | ✅ | WASD/方向键移动，空格跳跃，Shift冲刺 |
| 战斗系统 | ✅ | 射击武器、伤害计算、暴击、击退、无敌帧 |
| 怪物系统 | ✅ | AI寻敌、攻击、死亡、等级修正 |
| Boss系统 | ✅ | 3阶段技能、血量条UI |
| 房间图 | ✅ | 节点式地图、主路径+分支、Boss房间 |
| 楼层生成 | ✅ | 本地随机生成(8-12房间) |
| 奖励系统 | ✅ | 掉落生成、拾取、属性加成 |
| 升级系统 | ✅ | 经验成长、强化选项面板 |
| 存档系统 | ✅ | 3槽位、保存/加载 |
| AI内容服务 | ✅ | Mock模式运行，有MiMo LLM代码 |
| AI自适应难度 | ✅ | 行为分析→上下文→难度调整 |
| AI NPC对话 | ✅ | 上下文感知NPC记忆 |
| AI事件系统 | ✅ | 动态事件生成 |
| 交互框架 | ✅ | Area2D检测、E键交互 |
| UI系统 | ✅ | HUD、暂停菜单、设置、资源中心 |
| 视觉升级 | ✅ | 像素艺术Sprite、房间装饰 |

#### 服务端 (FastAPI)

| 模块 | API端点 | 状态 |
|------|---------|------|
| 认证 | POST /api/auth/register, /login | ✅ |
| 玩家 | GET/PUT /api/player/profile | ✅ |
| 武器 | GET /api/weapons, POST /api/player/weapons | ✅ |
| 怪物 | GET /api/monsters | ✅ |
| 地图 | GET /api/maps | ✅ |
| 事件 | GET /api/events | ✅ |
| 存档 | CRUD /api/game/save | ✅ |
| AI楼层生成 | POST /api/generate/floor | ✅ |
| AI房间内容 | POST /api/generate/room | ✅ |
| AI怪物生成 | POST /api/generate/monster | ✅ |
| AI武器生成 | POST /api/generate/weapon | ✅ |
| AI事件生成 | POST /api/generate/event | ✅ |
| AI对话生成 | POST /api/generate/dialogue | ✅ |
| AI升级选项 | POST /api/generate/upgrade | ✅ |
| AI难度调整 | POST /api/generate/difficulty | ✅ |
| AI房间策略 | POST /api/generate/room_strategy | ✅ |
| AI NPC记忆 | POST /api/generate/npc_memory | ✅ |
| AI上下文事件 | POST /api/generate/context_event | ✅ |
| AI测试 | GET /api/generate/test | ✅ |

### 2.2 部分功能 ⚠️

| 功能 | 状态 | 说明 |
|------|------|------|
| 真实云端AI | ⚠️ | MiMo API Key已配置，但LLM_PROVIDER=mock |
| 小地图 | ❌ | 未实现 |
| 商店系统 | ❌ | SHOP房间类型存在但无交互 |
| 精英怪词缀 | ❌ | Phase 27设计完成但代码未实现 |
| 音效 | ❌ | 完全缺失 |

---

## 三、当前目录结构

### 3.1 根目录

```
GraduationProject/
├── PROJECT_AUDIT_REPORT.md      # 审计报告(新增)
├── REFACTOR_ROADMAP.md          # 重构路线图(新增)
├── README.md                    # 项目说明
├── CHANGELOG.md                 # 变更记录
├── PROJECT_STATUS.md            # 项目状态
├── ARCHITECTURE.md              # 架构文档
├── DATABASE.md                  # 数据库设计
├── FEATURE_SPEC.md              # 功能规格
├── GAMEPLAY_SYSTEM.md           # 玩法系统
├── BALANCE_ANALYSIS.md          # 数值分析
├── ART_RESOURCE_PLAN.md         # 美术规划
├── DEPLOYMENT.md                # 部署说明
├── DEVELOPMENT_GUIDE.md         # 开发指南
├── ROADMAP.md                   # 开发路线图
├── TODO.md                      # 任务清单
├── .gitignore
├── requirements.txt             # Python依赖
├── client/                      # Godot客户端
├── server/                      # Python服务端
├── database/                    # SQL脚本
├── docs/                        # 详细文档
├── tools/                       # 工具脚本
├── paper_material/              # 论文材料
└── aurora-roguelike-ai-(4.2)/   # 旧版本备份
```

### 3.2 客户端 (Godot)

```
client/
├── project.godot                # 项目配置(Godot 4.7)
├── icon.svg
├── scenes/
│   ├── login/                   # 登录场景
│   ├── main/                    # 主菜单场景
│   ├── game/                    # 游戏主场景
│   │   ├── game_scene.tscn
│   │   ├── player.tscn
│   │   └── hud.tscn
│   ├── world/
│   │   ├── world.tscn
│   │   └── rooms/room.tscn
│   ├── combat/                  # 战斗UI
│   ├── drop/                    # 掉落UI
│   ├── enemy/                   # 怪物场景
│   ├── ui/                      # UI场景
│   └── resource/                # 资源中心
├── scripts/
│   ├── ai/          (12文件)    # AI内容服务
│   ├── api/         (3文件)     # API通信
│   ├── boss/        (2文件)     # Boss系统
│   ├── combat/        (6文件)    # 战斗系统
│   ├── drop/          (2文件)    # 掉落系统
│   ├── enemy/         (4文件)    # 怪物系统
│   ├── entity/        (3文件)    # 实体框架
│   ├── events/        (2文件)    # AI事件
│   ├── interaction/   (3文件)    # 交互框架
│   ├── inventory/     (2文件)    # 背包系统
│   ├── managers/      (7文件)    # 管理器
│   ├── models/        (10文件)   # 数据模型
│   ├── object/        (3文件)    # 游戏对象
│   ├── player/        (2文件)    # 玩家系统
│   ├── progression/   (2文件)    # 升级系统
│   ├── services/      (2文件)    # 服务层
│   ├── ui/            (11文件)   # UI系统
│   ├── weapon/        (1文件)    # 武器对象
│   └── world/         (12文件)   # 世界系统
├── addons/
├── assets/
├── resources/
└── tests/
```

**统计：** 92个GDScript文件

### 3.3 服务端 (Python)

```
server/
├── main.py                      # 主服务入口(Port 8000)
├── requirements.txt
├── .env                         # 环境变量(含API Key)
├── .env.example
├── app/
│   ├── api/                     # API路由(7模块)
│   ├── core/                    # 安全模块
│   ├── database/                # 数据库连接
│   ├── models/                  # ORM模型(8个)
│   ├── schemas/                 # Pydantic Schema(8个)
│   ├── services/                # 业务逻辑(7个)
│   └── utils/                   # 工具函数
├── ai/                          # AI服务(Port 8001)
│   ├── main.py
│   ├── api/ai_routes.py         # 11个AI路由
│   ├── services/
│   │   ├── ai_service.py        # 核心AI服务(1400行)
│   │   ├── mimo_client.py       # MiMo API客户端
│   │   ├── prompt_builder.py    # 提示词构建
│   │   ├── ai_validator.py      # AI结果验证
│   │   ├── ai_quality_checker.py # 质量检查
│   │   └── request_manager.py   # 请求管理
│   ├── cache/                   # 内存缓存
│   ├── database/                # SQLite管理
│   ├── data/
│   │   ├── ai_generations.db    # AI生成记录
│   │   └── aurora.db           # 另一数据库
│   ├── logger/                  # 日志
│   ├── middleware/              # 限流
│   ├── monitoring/              # 监控
│   ├── security/                # Token认证
│   └── tests/                   # 测试
├── tests/
├── tools/
│   └── ai_benchmark.py
├── venv/
└── __pycache__/
```

---

## 四、当前启动方式

### 4.1 前置要求

```
- Godot 4.7
- Python 3.12+
- MySQL 8.0
- pip install -r server/requirements.txt
```

### 4.2 启动步骤

```bash
# 1. 启动MySQL，执行建库脚本
mysql -u root -p < database/sql/create_database.sql
mysql -u root -p aurora_game < database/sql/create_tables.sql
mysql -u root -p aurora_game < database/sql/insert_test_data.sql

# 2. 启动AI服务
cd server
source venv/bin/activate  # 或 Windows: venv\Scripts\activate
python ai/main.py         # Port 8001

# 3. 启动主服务(新终端)
python main.py            # Port 8000

# 4. 启动Godot客户端
# 打开 client/project.godot 或在Godot编辑器中运行
```

### 4.3 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| 主服务 | http://localhost:8000 | CRUD API |
| 主服务文档 | http://localhost:8000/docs | Swagger UI |
| AI服务 | http://localhost:8001 | AI生成API |
| AI服务文档 | http://localhost:8001/docs | Swagger UI |
| AI健康检查 | http://localhost:8001/health | 服务状态 |
| AI测试 | http://localhost:8001/api/generate/test | AI功能测试 |

---

## 五、当前配置状态

### 5.1 AI配置 (server/.env)

```
LLM_PROVIDER=mimo              # ← 已配置为MiMo!
MIMO_API_KEY=tp-cf4dal6g...    # ← 有真实API Key!
MIMO_MODEL=mimo-v2.5-pro
MIMO_ENDPOINT=https://token-plan-cn.xiaomimimo.com/anthropic
```

### 5.2 数据库配置

```
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=123456
MYSQL_DATABASE=aurora_game
```

### 5.3 JWT配置

```
JWT_SECRET_KEY=aurora-roguelike-secret-key-change-in-production
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=1440
```

### 5.4 Godot配置

```
分辨率: 1280x720
渲染器: mobile
输入: WASD/方向键移动, 空格/W/Up跳跃, Shift/C冲刺, E交互, ESC暂停
```

---

## 六、当前已知问题

### 6.1 严重问题

| # | 问题 | 影响 |
|---|------|------|
| 1 | **AI Provider未切换到真实模式** | LLM_PROVIDER=mimo但游戏默认使用FakeAI |
| 2 | **零单元测试** | 工程规范硬伤 |
| 3 | **大量调试print残留** | 影响性能和可读性 |
| 4 | **旧版本目录共存** | 容易混淆 |

### 6.2 中等问题

| # | 问题 | 影响 |
|---|------|------|
| 5 | **AI生成接口未全部接入游戏** | 7个预留接口未使用 |
| 6 | **掉落算法过于简单** | 无概率分布理论 |
| 7 | **动态难度仅规则引擎** | 缺少算法深度 |
| 8 | **无小地图系统** | Roguelike标配缺失 |
| 9 | **文档与代码脱节** | FEATURE_SPEC过时 |

### 6.3 轻微问题

| # | 问题 | 影响 |
|---|------|------|
| 10 | **无音效** | 沉浸感下降 |
| 11 | **Git tag混乱** | v0.9-beta/v1.0-stable/v1.0.0共存 |
| 12 | **maps表未被使用** | 楼层在客户端本地生成 |

---

## 七、代码量统计

| 分类 | 文件数 | 代码行数 |
|------|--------|----------|
| Godot客户端 (.gd) | 92 | ~19,973 |
| FastAPI主服务 (.py) | ~40 | ~4,000 |
| AI服务 (.py) | ~25 | ~2,500 |
| 数据库SQL | 4 | ~550 |
| 配置文件 | ~5 | ~200 |
| 文档 (.md) | ~25 | ~15,000 |
| **总计** | **~191** | **~42,000+** |

---

## 八、核心优势总结

1. **架构完整** — C/S + AI微服务分离
2. **技术栈现代** — Godot 4.7 + FastAPI + MySQL + AI API
3. **AI框架完善** — 11个生成接口 + Mock/Lite双模式
4. **已有真实API Key** — MiMo LLM可立即启用
5. **文档齐全** — 25+文档文件
6. **版本管理规范** — Conventional commits + tag管理

---

*本文档为重构前的系统快照，记录于 before-refactor-v1 tag*
