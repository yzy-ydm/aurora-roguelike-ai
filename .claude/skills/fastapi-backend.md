---
name: fastapi-backend
description: FastAPI Python后端技能，用于维护server/ai目录，支持FastAPI最佳实践
version: 1.0.0
tags: [python, fastapi, api, backend, async]
---

# FastAPI Python 后端技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的 FastAPI 后端开发，主要维护 `server/ai` 目录。

## 项目结构

```
server/ai/
├── main.py                      # 入口
├── api/
│   └── ai_routes.py             # 路由定义
├── services/
│   ├── ai_service.py            # AI服务
│   └── prompt_builder.py        # 提示词构建
├── security/
│   └── auth.py                  # Token认证
├── database/
│   └── db_manager.py            # 数据库管理
├── cache/
│   └── cache_manager.py         # 缓存管理
└── logger/
    └── logger.py                # 日志系统
```

## FastAPI 最佳实践

### 路由定义

```python
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

router = APIRouter(tags=["AI内容生成"])

class FloorGenerateRequest(BaseModel):
    floor_level: int
    player_level: int

@router.post("/generate/floor")
async def generate_floor(
    request: FloorGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    # 处理逻辑
    return {"floor": request.floor_level}
```

### Pydantic 模型

```python
from pydantic import BaseModel, Field

class FloorResponse(BaseModel):
    floor: int
    player_level: int
    room_count: int
    rooms: list[dict]
```

### 异步处理

```python
@router.post("/generate/floor")
async def generate_floor(request: FloorGenerateRequest):
    # 异步调用
    result = await ai_service.generate_floor(
        request.floor_level,
        request.player_level
    )
    return result
```

### 依赖注入

```python
from fastapi import Depends

async def verify_api_key(token: str = Depends(oauth2_scheme)):
    # 验证Token
    return token

@router.post("/protected")
async def protected_route(token: str = Depends(verify_api_key)):
    return {"token": token}
```

## 项目特定规范

### API响应格式

```json
{
    "floor": 1,
    "player_level": 1,
    "room_count": 10,
    "rooms": [...],
    "ai_mode": "mock"
}
```

### 错误处理

```python
@router.post("/generate/floor")
async def generate_floor(request: FloorGenerateRequest):
    try:
        result = await ai_service.generate_floor(...)
        return result
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

### 日志记录

```python
from logger.logger import logger

@log_timing
async def generate_floor(floor_level: int, player_level: int):
    logger.info(f"Generating floor: level={floor_level}")
    # 处理逻辑
    logger.info(f"Floor generated: {room_count} rooms")
```

## 使用场景

当需要：
- 维护FastAPI后端
- 添加新的API接口
- 优化异步处理
- 改进错误处理
- 集成新的服务
