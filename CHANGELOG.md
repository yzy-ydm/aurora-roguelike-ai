# CHANGELOG.md

> Aurora-Roguelike-AI 项目变更记录

本文档记录项目所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

### 待开发
- Phase 4.3 玩家角色系统
- Phase 4.4 武器系统
- Phase 4.5 怪物系统
- Phase 4.6 游戏数据接口

---

## [0.4.0] - 2026-07-13

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
