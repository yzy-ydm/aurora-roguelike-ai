# CLAUDE_CONTEXT.md

> Claude AI 开发上下文 - 项目核心理念与设计原则

最后更新：2026-07-16

---

## 项目核心理念

本项目是**网络工程专业毕业设计**，重点体现：

1. **客户端-服务器架构** - Godot + FastAPI + MySQL
2. **网络通信** - HTTP REST API
3. **云端AI服务** - 小米MiMo API动态内容生成
4. **游戏开发** - 横版Roguelike动作游戏

**参考游戏：** 霓虹深渊、死亡细胞

---

## 当前架构原则

### 分层架构

```
客户端 (Godot GDScript)
    ↓ HTTP
游戏服务器 (FastAPI)
    ↓ SQLAlchemy
MySQL数据库

AI服务器 (FastAPI)
    ↓
小米MiMo API
```

### 核心模块

| 模块 | 职责 | 入口文件 |
|------|------|----------|
| 玩家系统 | 移动、攻击、属性 | `player_controller.gd` |
| 战斗系统 | 伤害计算、武器 | `damage_system.gd` |
| 怪物系统 | AI、生成、死亡 | `monster_node.gd` |
| Boss系统 | 阶段、技能 | `boss_controller.gd` |
| 房间系统 | 楼层、房间生成 | `floor_manager.gd` |
| AI系统 | 内容生成 | `ai_content_service.gd` |

---

## 为什么这样设计

1. **数据驱动** - MonsterData/WeaponData/RewardData独立于渲染
2. **信号驱动** - 模块间通过信号通信，低耦合
3. **AI优先** - 内容可由AI生成，也可本地Fallback
4. **渐进式开发** - 从俯视角逐步转型横版

---

## 禁止修改的架构

| 系统 | 原因 |
|------|------|
| FastAPI路由结构 | 已稳定，影响前后端通信 |
| MySQL表结构 | 存档兼容性 |
| AI服务接口 | 已有客户端依赖 |
| 信号系统 | 模块间耦合 |

---

## 下一阶段开发路线

1. **美术资源制作** - 像素艺术Sprite
2. **数值平衡调整** - 怪物HP、玩家DPS
3. **小地图系统** - Roguelike标配
4. **精英怪词缀** - 增加战斗多样性
5. **Boss阶段系统** - 增加挑战性

---

**本文档帮助Claude理解项目核心设计决策**
