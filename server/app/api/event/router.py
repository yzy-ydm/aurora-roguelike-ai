"""
事件API路由模块

本模块提供事件资源查询相关的API接口。

接口列表：
- GET /api/events: 获取事件列表（公开接口）
- GET /api/events/{event_id}: 获取事件详情（公开接口）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 当前阶段只实现查询接口
- 公开接口，不需要JWT认证（事件属于公共游戏资源）
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.event import EventResponse
from app.services.event_service import EventService

# 创建路由器
router = APIRouter(
    tags=["事件"]
)


# ============================================================
# 获取事件列表接口（公开）
# ============================================================

@router.get(
    "/api/events",
    response_model=List[EventResponse],
    summary="获取事件列表",
    description="获取所有事件基础数据。此接口为公开接口，不需要认证。"
)
async def get_events(db: Session = Depends(get_db)):
    """
    获取事件列表接口

    返回数据库中所有事件的基础信息。

    **认证要求：** 不需要

    **返回：**
    - 事件列表，每个事件包含完整信息

    **响应示例：**
    ```json
    [
        {
            "id": 1,
            "name": "宝箱发现",
            "description": "你发现了一个闪闪发光的宝箱，上面镶嵌着宝石。",
            "type": "treasure",
            "trigger_rate": 15.0,
            "min_floor": 1,
            "max_floor": 999,
            "effect_data": {"gold": 50},
            "option1_text": "打开宝箱",
            "option1_effect": {"gold": 100},
            "option2_text": "离开",
            "option2_effect": {}
        }
    ]
    ```
    """
    service = EventService(db)
    return service.get_all_events()


# ============================================================
# 获取事件详情接口（公开）
# ============================================================

@router.get(
    "/api/events/{event_id}",
    response_model=EventResponse,
    summary="获取事件详情",
    description="根据事件ID获取单个事件的详细信息。",
    responses={
        404: {"description": "事件不存在"}
    }
)
async def get_event(
    event_id: int,
    db: Session = Depends(get_db)
):
    """
    获取事件详情接口

    根据事件ID查询单个事件的详细信息。

    **认证要求：** 不需要

    **路径参数：**
    - event_id: 事件ID

    **返回：**
    - 事件详细信息

    **错误情况：**
    - 404: 事件不存在
    """
    service = EventService(db)
    success, message, event_data = service.get_event_by_id(event_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return event_data
