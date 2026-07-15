# 基于云端AI动态内容生成的Roguelike游戏系统

> 本科毕业设计 - 网络工程专业

## 📖 项目简介

本项目设计并实现了一个基于云端AI动态内容生成能力的2D横版Roguelike游戏系统。项目采用客户端-服务器架构，通过REST API进行网络通信，使用MySQL数据库管理游戏数据，并集成了小米MiMo AI服务实现动态内容生成。

**项目定位：** 网络工程专业毕业设计，重点体现客户端-服务器架构、网络通信、数据库管理、后端服务设计和云端AI服务调用等核心技术。

**参考游戏：** 霓虹深渊（Neon Abyss）、死亡细胞（Dead Cells）

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Godot 4.7 Client                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │ Player  │ │ Combat  │ │ Monster │ │  Room   │          │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘          │
│       └───────────┴───────────┴───────────┘                │
│                        │                                    │
│                 AIContentService                            │
└────────────────────────┼────────────────────────────────────┘
                         │ HTTP REST API
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server (8000)                      │
│         Router → Service → SQLAlchemy → MySQL               │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   AI Server (8001)                           │
│              Mock AI / MiMo LLM API                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 技术栈

| 层级 | 技术 | 用途 |
|------|------|------|
| 客户端 | Godot 4.7 + GDScript | 游戏引擎、横版动作、UI系统 |
| 服务端 | Python 3.12 + FastAPI | REST API、业务逻辑 |
| 数据库 | MySQL 8.0 + SQLAlchemy | 数据持久化 |
| 认证 | JWT + bcrypt | 用户认证、密码加密 |
| AI服务 | 小米MiMo API | 动态内容生成 |

---

## 🎮 当前完成度

### 核心系统 ✅

| 系统 | 状态 | 说明 |
|------|------|------|
| 登录认证 | ✅ | JWT Token |
| 玩家系统 | ✅ | 横版移动、跳跃、冲刺 |
| 战斗系统 | ✅ | 射击、伤害计算 |
| 怪物系统 | ✅ | AI、生成、死亡 |
| Boss系统 | ✅ | 阶段、技能 |
| 房间系统 | ✅ | 楼层、房间生成 |
| 奖励系统 | ✅ | 掉落、拾取 |
| 存档系统 | ✅ | 保存/加载 |
| AI系统 | ✅ | Mock + MiMo API |

### 数值分析 ✅

| 分析 | 状态 | 说明 |
|------|------|------|
| 战斗平衡 | ✅ | TTK/DPS分析 |
| 怪物设计 | ✅ | 精英词缀、Boss阶段 |
| 美术规划 | ✅ | 资源需求清单 |

**总体进度：~90%**

---

## 🚀 快速开始

### 环境要求

- Godot 4.7
- Python 3.12+
- MySQL 8.0

### 启动步骤

```bash
# 1. 启动AI服务
cd server/ai
python main.py

# 2. 启动游戏服务
cd server
python main.py

# 3. 启动Godot客户端
# 打开 client/project.godot
```

### 访问服务

- 游戏服务：http://localhost:8000
- AI服务：http://localhost:8001
- Swagger文档：http://localhost:8000/docs

---

## 📚 文档索引

| 文档 | 说明 |
|------|------|
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | 项目当前状态 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 系统架构 |
| [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) | 开发指南 |
| [API_DOCUMENT.md](API_DOCUMENT.md) | API接口文档 |
| [DATABASE.md](DATABASE.md) | 数据库设计 |
| [AI_SYSTEM.md](AI_SYSTEM.md) | AI系统设计 |
| [GAMEPLAY_SYSTEM.md](GAMEPLAY_SYSTEM.md) | 玩法系统 |
| [BALANCE_ANALYSIS.md](BALANCE_ANALYSIS.md) | 数值分析 |
| [ART_RESOURCE_PLAN.md](ART_RESOURCE_PLAN.md) | 美术规划 |
| [CHANGELOG.md](CHANGELOG.md) | 变更记录 |
| [PROJECT_RECOVERY.md](PROJECT_RECOVERY.md) | 项目恢复指南 |

---

## 🎯 毕业设计价值体现

| 专业方向 | 体现方式 |
|----------|----------|
| 网络通信 | HTTP REST API、客户端-服务器架构 |
| 后端服务 | FastAPI框架、分层架构设计 |
| 数据库管理 | MySQL、SQLAlchemy ORM |
| 云端AI服务 | 小米MiMo API集成 |
| 游戏开发 | Godot 4.7横版动作Roguelike |
| 系统设计 | 完整的软件工程实践 |

---

## 📄 许可证

本项目为本科毕业设计作品，仅供学习交流使用。

---

**GitHub仓库：** https://github.com/yzy-ydm/aurora-roguelike-ai

**版本：** v0.9.0-alpha (Development Paused)

**完成日期：** 2026年
