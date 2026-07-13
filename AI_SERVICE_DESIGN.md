# AI_SERVICE_DESIGN.md

> Aurora-Roguelike-AI 服务设计文档

最后更新：2026-07-13

---

## 概述

本系统采用双层AI架构：
- **客户端AI层**：AIContentService，负责调用管理、验证、缓存、降级
- **服务端AI层**：FastAPI AI Server，负责内容生成、认证、日志

---

## 客户端AI服务

### AIContentService

**文件**：`client/scripts/ai/ai_content_service.gd`

**职责**：
- 统一AI调用接口
- 管理服务类型（FAKE/REAL）
- 协调验证、缓存、质量检查
- 实现降级策略

**核心方法**：
```gdscript
func generate_floor_content(floor_level, player_level) -> Array[RoomNodeData]
func generate_room_content(room_node, floor_level, player_level) -> RoomContentData
func set_service_type(type: AIServiceType)
```

**服务类型**：
```gdscript
enum AIServiceType {
    FAKE,   # 本地模拟
    REAL    # 云端AI
}
```

### 降级流程

```
generate_floor_content()
    ↓
检查缓存
    ↓ (未命中)
_call_ai_service_floor()
    ↓ (REAL模式)
_call_cloud_ai_floor()
    ↓
HTTP请求
    ↓
成功 → 验证 → 质量检查 → 缓存 → 返回
失败 → _generate_fallback_floor() → 本地生成
```

### AIValidator

**文件**：`client/scripts/ai/ai_validator.gd`

**职责**：
- 验证AI返回数据格式
- 自动修正非法数据
- 限制数值范围

**验证规则**：
- 房间数量 ≤ 20
- 每房间怪物数 ≤ 20
- 难度范围 1-10
- 奖励品质 ≤ 5.0

### AIQualityChecker

**文件**：`client/scripts/ai/ai_quality_checker.gd`

**职责**：
- 评估AI生成内容质量
- 检查地图连通性
- 检查难度合理性
- 返回质量评分

**评分维度**：
- 地图连通性 (30%)
- 难度合理性 (25%)
- 奖励合理性 (25%)
- 怪物合理性 (20%)

### AICacheManager

**文件**：`client/scripts/ai/ai_cache_manager.gd`

**职责**：
- 缓存AI生成结果
- 支持楼层和房间缓存
- 提供缓存统计

---

## 服务端AI服务

### FastAPI AI Server

**入口**：`server/ai/main.py`

**端口**：8001

**功能**：
- 提供REST API
- Token认证
- 请求日志
- 数据库记录

### AIService (Mock实现)

**文件**：`server/ai/services/ai_service.py`

**职责**：
- 生成游戏内容（当前为随机生成）
- 未来接入真实LLM

**核心方法**：
```python
async def generate_floor(floor_level, player_level) -> Dict
async def generate_room_content(room_id, room_type, floor_level, player_level) -> Dict
async def generate_monsters(room_type, floor_level, player_level) -> Dict
async def generate_weapon(player_level, rarity, weapon_type) -> Dict
```

**奖励策略**：
```python
strategies = ["power_growth", "balanced", "survival"]
```

### PromptBuilder (未来用)

**文件**：`server/ai/services/prompt_builder.py`

**职责**：
- 构建LLM提示词
- 解析LLM响应
- 为未来真实AI做准备

**提示词模板**：
```python
def build_floor_prompt(floor_level, player_level) -> str
def build_room_content_prompt(room_id, room_type, floor_level) -> str
def build_monster_prompt(room_type, floor_level) -> str
def build_weapon_prompt(player_level, rarity) -> str
```

---

## 数据格式

### 楼层请求

```json
{
    "floor_level": 1,
    "player_level": 1,
    "player_stats": {
        "health": 100,
        "attack": 10,
        "defense": 5
    }
}
```

### 楼层响应

```json
{
    "floor": 1,
    "player_level": 1,
    "room_count": 10,
    "rooms": [
        {
            "id": 0,
            "type": "start",
            "connections": [1],
            "monsters": [],
            "rewards": {},
            "chests": 0
        },
        {
            "id": 1,
            "type": "combat",
            "connections": [0, 2],
            "monsters": [
                {"id": "goblin", "count": 3}
            ],
            "rewards": {
                "count": 2,
                "quality": 1.0,
                "strategy": "power_growth",
                "items": [
                    {"type": "weapon", "rarity": "rare"}
                ]
            },
            "chests": 0
        }
    ],
    "ai_mode": "mock"
}
```

### 房间内容响应

```json
{
    "room_id": 1,
    "room_type": "combat",
    "floor_level": 1,
    "player_level": 1,
    "difficulty": 1,
    "monsters": [
        {"id": "goblin", "count": 3, "level": 1}
    ],
    "rewards": {
        "count": 2,
        "quality": 1.5,
        "strategy": "power_growth",
        "items": [
            {"type": "weapon", "rarity": "rare", "value": 10},
            {"type": "gold", "rarity": "uncommon", "value": 50}
        ]
    },
    "chests": 0,
    "ai_mode": "mock"
}
```

---

## 未来LLM扩展方案

### 接入真实LLM

**修改文件**：`server/ai/services/ai_service.py`

**实现方案**：
```python
class RealAIService(AIService):
    async def generate_floor(self, floor_level, player_level):
        # 构建提示词
        prompt = self.prompt_builder.build_floor_prompt(floor_level, player_level)

        # 调用LLM API
        response = await self.call_llm_api(prompt)

        # 解析响应
        data = self.prompt_builder.parse_ai_response(response)

        return data

    async def call_llm_api(self, prompt):
        # 支持多种LLM
        # OpenAI GPT-4
        # Claude
        # 文心一言
        pass
```

### 支持的LLM

| LLM | 说明 | 状态 |
|-----|------|------|
| OpenAI GPT-4 | 云端AI | 待接入 |
| Claude | 云端AI | 待接入 |
| 文心一言 | 国内AI | 待接入 |
| Llama | 本地AI | 可选 |

### 配置管理

```python
# 环境变量
LLM_PROVIDER=openai
LLM_API_KEY=xxx
LLM_MODEL=gpt-4
LLM_MAX_TOKENS=2000
```

---

## 当前状态

- **客户端**：已完成AIContentService，支持FAKE/REAL模式
- **服务端**：已完成MockAIService，支持认证、缓存、日志
- **数据格式**：已定义完整的请求/响应格式
- **降级策略**：已实现，AI失败时自动使用本地生成
- **未来扩展**：PromptBuilder已预留，可快速接入真实LLM
