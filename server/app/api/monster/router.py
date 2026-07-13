"""
怪物API路由模块

本模块提供怪物数据查询相关的API接口。

接口列表：
- GET /api/monsters: 获取怪物列表（公开接口）
- GET /api/monsters/{monster_id}: 获取怪物详情（公开接口）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 当前阶段只实现查询接口
- 公开接口，不需要JWT认证（未来Godot需要加载资源）
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.monster import MonsterResponse
from app.services.monster_service import MonsterService

# 创建路由器
router = APIRouter(
    tags=["怪物"]
)


# ============================================================
# 获取怪物列表接口（公开）
# ============================================================

@router.get(
    "/api/monsters",
    response_model=List[MonsterResponse],
    summary="获取怪物列表",
    description="获取所有怪物基础数据。此接口为公开接口，不需要认证。"
)
async def get_monsters(db: Session = Depends(get_db)):
    """
    获取怪物列表接口

    返回数据库中所有怪物的基础信息。

    **认证要求：** 不需要

    **返回：**
    - 怪物列表，每个怪物包含完整信息

    **响应示例：**
    ```json
    [
        {
            "id": 1,
            "name": "史莱姆",
            "description": "最基础的怪物，由粘液构成，行动缓慢。",
            "type": "normal",
            "level": 1,
            "health": 20,
            "attack": 5,
            "defense": 2,
            "speed": 3,
            "experience_reward": 10,
            "gold_reward": 5,
            "special_ability": null,
            "attributes": null,
            "icon_path": null,
            "min_floor": 1,
            "max_floor": 10
        }
    ]
    ```
    """
    service = MonsterService(db)
    return service.get_all_monsters()


# ============================================================
# 获取怪物详情接口（公开）
# ============================================================

@router.get(
    "/api/monsters/{monster_id}",
    response_model=MonsterResponse,
    summary="获取怪物详情",
    description="根据怪物ID获取单个怪物的详细信息。",
    responses={
        404: {"description": "怪物不存在"}
    }
)
async def get_monster(
    monster_id: int,
    db: Session = Depends(get_db)
):
    """
    获取怪物详情接口

    根据怪物ID查询单个怪物的详细信息。

    **认证要求：** 不需要

    **路径参数：**
    - monster_id: 怪物ID

    **返回：**
    - 怪物详细信息

    **错误情况：**
    - 404: 怪物不存在
    """
    service = MonsterService(db)
    success, message, monster = service.get_monster_by_id(monster_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return monster
