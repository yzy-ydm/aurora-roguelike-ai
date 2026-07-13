# 基于云端AI动态内容生成的Roguelike游戏系统

> 本科毕业设计 - 网络工程专业

## 📖 项目简介

本项目设计并实现了一个基于云端AI动态内容生成能力的2D Roguelike游戏系统。项目采用客户端-服务器架构，通过REST API进行网络通信，使用MySQL数据库管理游戏数据，并计划集成云端AI服务实现动态内容生成。

**项目定位：** 本项目不是单纯的游戏制作，而是网络工程专业毕业设计，重点体现客户端-服务器架构、网络通信、数据库管理、后端服务设计和云端AI服务调用等核心技术。

**参考游戏：** 霓虹深渊（Neon Abyss）

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Godot Client                           │
│                    (游戏客户端 4.x)                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP REST API
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    FastAPI Server                            │
│                    (Python 3.12)                             │
├─────────────────────────────────────────────────────────────┤
│    Router → Service → SQLAlchemy ORM → MySQL Database       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 技术栈

| 层级 | 技术 | 用途 |
|------|------|------|
| 客户端 | Godot 4 + GDScript | 游戏界面、玩家控制、游戏逻辑 |
| 服务端 | Python 3.12 + FastAPI | REST API、业务逻辑、数据处理 |
| 数据库 | MySQL 8.0 + SQLAlchemy | 数据持久化存储 |
| 认证 | JWT + bcrypt | 用户认证、密码加密 |
| AI服务 | DeepSeek/Claude API | 动态内容生成（计划中） |

---

## 📁 项目结构

```
GraduationProject/
│
├── 📄 README.md                    # 项目说明（本文件）
├── 📄 SYSTEM_PROMPT.md             # AI工程师工作规则
├── 📄 PROJECT_STATUS.md            # 项目当前状态
├── 📄 ROADMAP.md                   # 开发路线图
├── 📄 TODO.md                      # 任务清单
├── 📄 CHANGELOG.md                 # 变更记录
├── 📄 ARCHITECTURE.md              # 系统架构
├── 📄 AI_CONTEXT.md                # 设计理念
├── 📄 FEATURE_SPEC.md              # 功能需求
├── 📄 DEVELOPMENT_GUIDE.md         # 开发规范
├── 📄 API_DOCUMENT.md              # API接口文档
├── 📄 DATABASE.md                  # 数据库设计
├── 📄 DEPLOYMENT.md                # 部署说明
├── 📄 .gitignore                   # Git忽略规则
│
├── 📂 server/                      # Python服务端
│   ├── 📄 main.py                  # 应用入口
│   ├── 📄 requirements.txt         # Python依赖
│   ├── 📄 .env.example             # 环境变量示例
│   └── 📂 app/                     # 应用核心
│       ├── 📂 api/                # API路由层
│       │   └── 📂 auth/           # 认证模块
│       ├── 📂 core/               # 核心模块（安全）
│       ├── 📂 database/           # 数据库连接
│       ├── 📂 models/             # ORM模型
│       ├── 📂 schemas/            # Pydantic模式
│       └── 📂 services/           # 业务服务层
│
├── 📂 client/                      # Godot客户端（待开发）
│
├── 📂 database/                    # 数据库相关
│   ├── 📂 sql/                    # SQL脚本
│   └── 📂 design/                 # 设计文档
│
└── 📂 docs/                        # 项目文档
    └── 📂 backend/                # 后端文档
```

---

## 🚀 快速开始

### 环境要求

- Python 3.12+
- MySQL 8.0
- Git

### 安装步骤

```bash
# 1. 克隆项目
git clone https://github.com/yzy-ydm/aurora-roguelike-ai.git
cd aurora-roguelike-ai

# 2. 进入服务端目录
cd server

# 3. 创建虚拟环境
python -m venv venv

# 4. 激活虚拟环境
venv\Scripts\activate    # Windows
source venv/bin/activate # Linux/Mac

# 5. 安装依赖
pip install -r requirements.txt

# 6. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，配置数据库密码

# 7. 初始化数据库
mysql -u root -p < ../database/sql/create_tables.sql

# 8. 启动服务
python main.py
```

### 访问服务

- API服务：http://localhost:8000
- Swagger文档：http://localhost:8000/docs
- 健康检查：http://localhost:8000/health

---

## 📊 当前进度

### 已完成

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 项目初始化 | ✅ 完成 |
| Phase 2 | Git工程管理 | ✅ 完成 |
| Phase 3 | MySQL数据库设计 | ✅ 完成 |
| Phase 4.1 | FastAPI数据库连接 | ✅ 完成 |
| Phase 4.2 | 用户认证系统 | ✅ 完成 |

### 待开发

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 4.3 | 玩家角色系统 | ⬜ 待开发 |
| Phase 4.4 | 武器系统 | ⬜ 待开发 |
| Phase 4.5 | 怪物系统 | ⬜ 待开发 |
| Phase 4.6 | 游戏数据接口 | ⬜ 待开发 |
| Phase 5 | Godot客户端 | ⬜ 待开发 |
| Phase 6 | 核心玩法 | ⬜ 待开发 |
| Phase 7 | AI动态生成 | ⬜ 待开发 |
| Phase 8 | 测试优化 | ⬜ 待开发 |
| Phase 9 | 论文答辩 | ⬜ 待开发 |

**总体进度：约 25%**

---

## 🔌 已实现API

| 接口 | 方法 | 功能 | 状态 |
|------|------|------|------|
| /health | GET | 健康检查 | ✅ |
| /api/auth/register | POST | 用户注册 | ✅ |
| /api/auth/login | POST | 用户登录 | ✅ |

---

## 💾 数据库

**数据库名：** aurora_game

**数据表（8张）：**
- users - 用户账号表
- player_profiles - 玩家角色信息表
- weapons - 武器数据表
- monsters - 怪物数据表
- events - 随机事件表
- maps - 地图数据表
- game_saves - 游戏存档表
- ai_generations - AI生成记录表

---

## 🎯 毕业设计价值体现

| 专业方向 | 体现方式 |
|----------|----------|
| 网络通信 | HTTP REST API、客户端-服务器架构 |
| 后端服务 | FastAPI框架、分层架构设计 |
| 数据库管理 | MySQL、SQLAlchemy ORM、8张数据表 |
| 云端服务 | AI API调用（计划中） |
| 系统设计 | 完整的软件工程实践 |

---

## 📚 文档索引

| 文档 | 说明 |
|------|------|
| [SYSTEM_PROMPT.md](SYSTEM_PROMPT.md) | AI工程师工作规则 |
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | 项目当前状态 |
| [ROADMAP.md](ROADMAP.md) | 开发路线图 |
| [TODO.md](TODO.md) | 任务清单 |
| [CHANGELOG.md](CHANGELOG.md) | 变更记录 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 系统架构说明 |
| [AI_CONTEXT.md](AI_CONTEXT.md) | 设计理念 |
| [FEATURE_SPEC.md](FEATURE_SPEC.md) | 功能需求规格 |
| [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) | 开发规范指南 |
| [API_DOCUMENT.md](API_DOCUMENT.md) | API接口文档 |
| [DATABASE.md](DATABASE.md) | 数据库设计文档 |
| [DEPLOYMENT.md](DEPLOYMENT.md) | 部署说明 |

---

## 📝 开发日志

| 日期 | 内容 | Git Commit |
|------|------|------------|
| 2026-07-12 | 项目初始化 | 0e61898 |
| 2026-07-13 | 数据库设计 | 494de64 |
| 2026-07-13 | FastAPI数据库连接 | 4d059e8 |
| 2026-07-13 | 用户认证系统 | 0352e25 |

---

## 📄 许可证

本项目为本科毕业设计作品，仅供学习交流使用。

---

**GitHub仓库：** https://github.com/yzy-ydm/aurora-roguelike-ai

**完成日期：** 2026年
