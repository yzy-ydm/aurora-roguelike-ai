"""
地图API路由模块

本模块提供地图资源查询相关的API接口。

接口列表：
- GET /api/maps: 获取地图列表（公开接口）
- GET /api/maps/{map_id}: 获取地图详情（公开接口）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 当前阶段只实现查询接口
- 公开接口，不需要JWT认证（地图属于公共游戏资源）
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.map import MapResponse
from app.services.map_service import MapService

# 创建路由器
router = APIRouter(
    tags=["地图"]
)


# ============================================================
# 获取地图列表接口（公开）
# ============================================================

@router.get(
    "/api/maps",
    response_model=List[MapResponse],
    summary="获取地图列表",
    description="获取所有地图基础数据。此接口为公开接口，不需要认证。"
)
async def get_maps(db: Session = Depends(get_db)):
    """
    获取地图列表接口

    返回数据库中所有地图的基础信息。

    **认证要求：** 不需要

    **返回：**
    - 地图列表，每个地图包含完整信息

    **响应示例：**
    ```json
    [
        {
            "id": 1,
            "name": "新手地牢入口",
            "description": "地牢的最浅层，光线尚可，危险较小。",
            "type": "dungeon",
            "floor_level": 1,
            "width": 15,
            "height": 12,
            "room_count": 5,
            "room_data": {...},
            "monster_spawn_config": {...},
            "event_spawn_config": {...},
            "difficulty": 1
        }
    ]
    ```
    """
    service = MapService(db)
    return service.get_all_maps()


# ============================================================
# 获取地图详情接口（公开）
# ============================================================

@router.get(
    "/api/maps/{map_id}",
    response_model=MapResponse,
    summary="获取地图详情",
    description="根据地图ID获取单个地图的详细信息。",
    responses={
        404: {"description": "地图不存在"}
    }
)
async def get_map(
    map_id: int,
    db: Session = Depends(get_db)
):
    """
    获取地图详情接口

    根据地图ID查询单个地图的详细信息。

    **认证要求：** 不需要

    **路径参数：**
    - map_id: 地图ID

    **返回：**
    - 地图详细信息

    **错误情况：**
    - 404: 地图不存在
    """
    service = MapService(db)
    success, message, map_data = service.get_map_by_id(map_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return map_data
