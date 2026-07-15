# AI系统设计文档

> Aurora-Roguelike-AI AI系统架构说明

最后更新：2026-07-16

---

## 系统架构

```
Godot Client (AIContentService)
    ↓ HTTP REST
FastAPI Server (port 8001)
    ↓
├── Mock模式: 本地随机生成
└── LLM模式: 小米MiMo API
```

---

## 已接入游戏的AI接口

| 接口 | 路径 | 用途 |
|------|------|------|
| 楼层生成 | `/generate/floor` | 生成楼层房间结构 |
| 房间内容 | `/generate/room` | 生成房间怪物/奖励 |
| 上下文事件 | `/generate/context_event` | 动态事件 |
| NPC对话 | `/generate/dialogue` | NPC对话内容 |
| 难度调整 | `/generate/difficulty` | 动态难度调节 |

---

## 未接入的AI接口（预留）

| 接口 | 路径 | 说明 |
|------|------|------|
| 怪物生成 | `/generate/monster` | 独立怪物配置 |
| 武器生成 | `/generate/weapon` | 武器属性生成 |
| 升级选项 | `/generate/upgrade` | 升级选项生成 |
| 房间策略 | `/generate/room_strategy` | 房间布局策略 |
| NPC记忆 | `/generate/npc_memory` | NPC记忆系统 |

---

## Fallback机制

```
AI请求 → 缓存检查 → AI服务调用 → 质量检查 → 返回
    ↓           ↓           ↓           ↓
  失败        命中        超时        不达标
    ↓           ↓           ↓           ↓
  使用FakeAI  返回缓存   使用FakeAI  使用FakeAI
```

---

## 配置

```bash
# server/.env
LLM_PROVIDER=mock  # mock 或 mimo
MIMO_API_KEY=your_key
MIMO_MODEL=mimo-v2.5-pro
```

---

**当前状态：Mock模式运行，可随时切换MiMo**
