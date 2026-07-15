# PROJECT_RECOVERY.md

> 项目恢复指南 - 未来重新启动开发时第一阅读文件

最后更新：2026-07-16

---

## 如果半年后重新打开项目

### 第一步：了解项目状态

1. 阅读 `PROJECT_STATUS.md` - 了解当前完成状态
2. 阅读 `ARCHITECTURE.md` - 了解系统架构
3. 阅读 `CHANGELOG.md` - 了解开发历史

### 第二步：环境准备

1. **Godot环境**
   - 版本：Godot 4.7
   - 打开 `client/` 目录
   - 检查项目设置

2. **后端环境**
   - Python 3.11+
   - 进入 `server/` 目录
   - 运行 `pip install -r requirements.txt`
   - 配置 `.env` 文件

3. **数据库**
   - MySQL 8.0
   - 导入 `database/sql/` 脚本

### 第三步：启动项目

1. 启动AI服务：`cd server/ai && python main.py`
2. 启动游戏服务：`cd server && python main.py`
3. 启动Godot客户端：打开 `client/project.godot`

### 第四步：继续开发

**当前应该继续：** Phase 17.7 或 Phase 24（数值平衡）

**不要修改的系统：**
- CombatManager 核心逻辑
- FloorManager 核心逻辑
- AI服务架构
- 数据库结构

**优先开发：**
1. 美术资源制作
2. 数值平衡调整
3. 小地图系统

---

## 项目结构快速参考

```
GraduationProject/
├── client/                    # Godot客户端
│   ├── scripts/
│   │   ├── ai/               # AI内容服务
│   │   ├── boss/             # Boss系统
│   │   ├── combat/           # 战斗系统
│   │   ├── enemy/            # 怪物系统
│   │   ├── drop/             # 掉落系统
│   │   ├── events/           # 事件系统
│   │   ├── progression/      # 升级系统
│   │   ├── world/            # 世界系统
│   │   ├── models/           # 数据模型
│   │   └── ui/               # UI系统
│   └── scenes/               # 场景文件
├── server/
│   ├── app/                  # 游戏服务器
│   └── ai/                   # AI服务端
├── docs/                     # 设计文档
└── database/                 # 数据库脚本
```

---

## 关键文件说明

### 核心入口

| 文件 | 说明 |
|------|------|
| `client/scenes/game/game_scene.gd` | 游戏主场景 |
| `client/scripts/player/player_controller.gd` | 玩家控制 |
| `client/scripts/world/floor_manager.gd` | 楼层管理 |
| `client/scripts/combat/combat_manager.gd` | 战斗管理 |
| `server/main.py` | 游戏服务入口 |
| `server/ai/main.py` | AI服务入口 |

### 数据模型

| 文件 | 说明 |
|------|------|
| `client/scripts/models/monster_data.gd` | 怪物数据 |
| `client/scripts/models/weapon_data.gd` | 武器数据 |
| `client/scripts/models/reward_data.gd` | 奖励数据 |
| `client/scripts/models/room_content_data.gd` | 房间内容 |

---

## 已知问题

| 问题 | 严重度 | 说明 |
|------|--------|------|
| 美术资源缺失 | P0 | 所有Sprite为程序生成 |
| 怪物血量过低 | P1 | 需要平衡调整 |
| 玩家DPS过高 | P1 | 需要平衡调整 |

---

## 开发规范

1. **不要破坏现有系统** - 渐进式修改
2. **保持向后兼容** - 存档/接口兼容
3. **文档同步** - 修改后更新文档
4. **测试验证** - 修改后测试核心流程

---

## 联系方式

- **GitHub:** https://github.com/yzy-ydm/aurora-roguelike-ai
- **技术栈:** Godot 4.7 + FastAPI + MySQL

---

**本文件是项目恢复的第一入口，请妥善保管。**
