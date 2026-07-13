"""
武器API路由模块

本模块提供武器管理相关的API接口。

接口列表：
- GET /api/weapons: 获取武器列表（公开接口）
- GET /api/weapons/{weapon_id}: 获取武器详情（公开接口）
- GET /api/player/weapons: 获取玩家武器（需要JWT认证）
- POST /api/player/weapons: 添加玩家武器（需要JWT认证）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 复用已有JWT认证系统
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.api.deps import get_current_user_id
from app.schemas.weapon import (
    WeaponResponse,
    PlayerWeaponResponse,
    AddPlayerWeaponRequest
)
from app.schemas.auth import MessageResponse
from app.services.weapon_service import WeaponService

# 创建路由器
router = APIRouter(
    tags=["武器"]
)


# ============================================================
# 获取武器列表接口（公开）
# ============================================================

@router.get(
    "/api/weapons",
    response_model=List[WeaponResponse],
    summary="获取武器列表",
    description="获取所有基础武器数据。此接口为公开接口，不需要认证。"
)
async def get_weapons(db: Session = Depends(get_db)):
    """
    获取武器列表接口

    返回数据库中所有武器的基础信息。

    **认证要求：** 不需要

    **返回：**
    - 武器列表，每个武器包含完整信息

    **响应示例：**
    ```json
    [
        {
            "id": 1,
            "name": "铁剑",
            "description": "一把普通的铁制长剑",
            "type": "sword",
            "rarity": "common",
            "damage": 5,
            "crit_rate_bonus": 0.0,
            "special_effect": null,
            "attributes": null,
            "icon_path": null,
            "price": 50
        }
    ]
    ```
    """
    service = WeaponService(db)
    return service.get_all_weapons()


# ============================================================
# 获取武器详情接口（公开）
# ============================================================

@router.get(
    "/api/weapons/{weapon_id}",
    response_model=WeaponResponse,
    summary="获取武器详情",
    description="根据武器ID获取单个武器的详细信息。",
    responses={
        404: {"description": "武器不存在"}
    }
)
async def get_weapon(
    weapon_id: int,
    db: Session = Depends(get_db)
):
    """
    获取武器详情接口

    根据武器ID查询单个武器的详细信息。

    **认证要求：** 不需要

    **路径参数：**
    - weapon_id: 武器ID

    **返回：**
    - 武器详细信息

    **错误情况：**
    - 404: 武器不存在
    """
    service = WeaponService(db)
    success, message, weapon = service.get_weapon_by_id(weapon_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return weapon


# ============================================================
# 获取玩家武器接口（需要认证）
# ============================================================

@router.get(
    "/api/player/weapons",
    response_model=List[PlayerWeaponResponse],
    summary="获取玩家武器",
    description="获取当前登录用户拥有的所有武器。需要JWT认证。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "玩家角色不存在"}
    }
)
async def get_player_weapons(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    获取玩家武器接口

    获取当前登录用户拥有的所有武器列表。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **返回：**
    - 玩家拥有的武器列表，包含武器详情和装备状态

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 玩家角色不存在
    """
    service = WeaponService(db)
    success, message, weapons = service.get_player_weapons(user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return weapons


# ============================================================
# 添加玩家武器接口（需要认证）
# ============================================================

@router.post(
    "/api/player/weapons",
    response_model=PlayerWeaponResponse,
    status_code=status.HTTP_201_CREATED,
    summary="添加玩家武器",
    description="为当前登录用户添加一把武器。需要JWT认证。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "玩家或武器不存在"},
        422: {"description": "请求数据验证失败"}
    }
)
async def add_player_weapon(
    request: AddPlayerWeaponRequest,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    添加玩家武器接口

    为当前登录用户添加一把武器。
    此接口用于服务器建立玩家与武器的拥有关系。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **请求参数：**
    - weapon_id: 武器ID

    **请求示例：**
    ```json
    {
        "weapon_id": 1
    }
    ```

    **返回：**
    - 添加的武器信息，包含武器详情

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 玩家角色不存在或武器不存在
    - 422: 请求数据格式错误
    """
    service = WeaponService(db)
    success, message, weapon = service.add_player_weapon(user_id, request)

    if not success:
        if "玩家" in message and "不存在" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message
            )
        if "武器" in message and "不存在" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return weapon
