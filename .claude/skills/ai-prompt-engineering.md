---
name: ai-prompt-engineering
description: AI Prompt Engineering技能，用于设计AI提示词、优化AI输出、接入LLM API
version: 1.0.0
tags: [ai, prompt, llm, openai, mimo]
---

# AI Prompt Engineering 技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的 AI 内容生成，支持接入小米 Mimo API。

## Prompt 设计原则

### 清晰明确

```markdown
# 好的Prompt
请生成一个包含10个房间的Roguelike楼层，要求：
1. 包含起始房间和Boss房间
2. 房间类型包括：战斗、奖励、商店
3. 建立合理的连接关系

# 不好的Prompt
生成一个楼层
```

### 结构化输出

```markdown
请返回以下JSON格式：
{
    "floor": 1,
    "room_count": 10,
    "rooms": [
        {
            "id": 0,
            "type": "start",
            "connections": [1]
        }
    ]
}
```

### 约束条件

```markdown
要求：
1. 房间数量在8-12之间
2. 必须包含起始房间和Boss房间
3. 房间类型只能是：start, combat, elite, boss, reward, treasure, shop, event
4. 连接关系必须有效
```

## Prompt 模板

### 楼层生成Prompt

```python
def build_floor_prompt(floor_level: int, player_level: int) -> str:
    return f"""请生成一个Roguelike游戏楼层。

参数：
- 楼层级别: {floor_level}
- 玩家等级: {player_level}

要求：
1. 生成8-12个房间
2. 包含起始房间和Boss房间
3. 房间类型包括：combat, reward, elite, event, treasure, shop
4. 建立合理的连接关系
5. 根据楼层级别调整难度

请返回以下JSON格式：
{{
    "floor": {floor_level},
    "room_count": 房间数量,
    "rooms": [
        {{
            "id": 房间ID,
            "type": "房间类型",
            "connections": [连接的房间ID]
        }}
    ]
}}
"""
```

### 房间内容生成Prompt

```python
def build_room_content_prompt(room_id: int, room_type: str, floor_level: int) -> str:
    return f"""请生成一个Roguelike游戏房间的内容。

参数：
- 房间ID: {room_id}
- 房间类型: {room_type}
- 楼层级别: {floor_level}

要求：
1. 根据房间类型生成合适的怪物配置
2. 根据房间类型生成合适的奖励配置
3. 难度适合楼层级别

请返回以下JSON格式：
{{
    "room_id": {room_id},
    "room_type": "{room_type}",
    "difficulty": 难度等级,
    "monsters": [{{"id": "怪物类型", "count": 数量}}],
    "rewards": {{"count": 数量, "quality": 品质}},
    "chests": 宝箱数量
}}
"""
```

## JSON 结构约束

### 楼层数据结构

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
        }
    ]
}
```

### 房间内容结构

```json
{
    "room_id": 1,
    "room_type": "combat",
    "difficulty": 1,
    "monsters": [
        {"id": "goblin", "count": 3, "level": 1}
    ],
    "rewards": {
        "count": 2,
        "quality": 1.5,
        "strategy": "power_growth",
        "items": [
            {"type": "weapon", "rarity": "rare"}
        ]
    },
    "chests": 0
}
```

## AI 输出稳定性

### 验证策略

```python
def validate_ai_response(data: dict, schema: dict) -> bool:
    """验证AI响应是否符合schema"""
    for key, type_check in schema.items():
        if key not in data:
            return False
        if not isinstance(data[key], type_check):
            return False
    return True
```

### 降级策略

```python
async def generate_with_fallback(prompt: str) -> dict:
    """带降级的AI生成"""
    try:
        # 尝试AI生成
        result = await call_ai_api(prompt)
        if validate_response(result):
            return result
    except Exception as e:
        logger.error(f"AI generation failed: {e}")

    # 降级到本地生成
    return generate_locally()
```

## 小米 Mimo API 接入

### API 调用

```python
async def call_mimo_api(prompt: str) -> dict:
    """调用小米Mimo API"""
    response = await httpx.post(
        "https://api.mimo.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {API_KEY}"},
        json={
            "model": "mimo-chat",
            "messages": [
                {"role": "system", "content": "你是Roguelike游戏内容生成器"},
                {"role": "user", "content": prompt}
            ]
        }
    )
    return response.json()
```

### Prompt 优化

```python
def optimize_prompt_for_mimo(base_prompt: str) -> str:
    """为Mimo优化Prompt"""
    return f"""请严格按照以下要求生成内容，只返回JSON格式，不要添加其他说明。

{base_prompt}

重要：只返回JSON，不要返回任何其他内容。"""
```

## 使用场景

当需要：
- 设计AI提示词
- 优化AI输出质量
- 接入新的LLM API
- 提高AI输出稳定性
- 处理AI输出异常
