"""
游戏存档API路由模块

本模块提供游戏存档管理相关的API接口。

接口列表：
- POST /api/game/save: 创建游戏存档（需要JWT认证）
- GET /api/game/save: 查询用户所有存档（需要JWT认证）
- GET /api/game/save/{slot_number}: 查询指定槽位存档（需要JWT认证）
- PUT /api/game/save/{slot_number}: 更新游戏存档（需要JWT认证）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 复用已有JWT认证系统
- 只负责游戏状态持久化，不修改玩家核心属性
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.api.deps import get_current_user_id
from app.schemas.save import SaveCreate, SaveUpdate, SaveResponse
from app.services.save_service import SaveService

# 创建路由器
router = APIRouter(
    tags=["游戏存档"]
)


# ============================================================
# 创建游戏存档接口
# ============================================================

@router.post(
    "/api/game/save",
    response_model=SaveResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建游戏存档",
    description="为当前登录用户创建游戏存档。每个用户每个槽位只能有一个存档。",
    responses={
        401: {"description": "未认证或Token无效"},
        409: {"description": "该槽位已有存档"},
        422: {"description": "请求数据验证失败"}
    }
)
async def create_save(
    save_data: SaveCreate,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    创建游戏存档接口

    为当前登录用户创建游戏存档。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **请求参数：**
    - save_name: 存档名称（1-100字符）
    - slot_number: 存档槽位（1-3）
    - player_state: 玩家状态数据（JSON格式）

    **请求示例：**
    ```json
    {
        "save_name": "第一次冒险",
        "slot_number": 1,
        "player_state": {
            "health": 100,
            "max_health": 100,
            "attack": 10,
            "defense": 5,
            "level": 1,
            "experience": 0,
            "gold": 0
        }
    }
    ```

    **返回：**
    - 创建的存档完整信息

    **错误情况：**
    - 401: 未登录或Token无效
    - 409: 该槽位已有存档
    - 422: 请求数据格式错误
    """
    service = SaveService(db)
    success, message, save = service.create_save(user_id, save_data)

    if not success:
        if "已有存档" in message:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=message
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return save


# ============================================================
# 查询用户所有存档接口
# ============================================================

@router.get(
    "/api/game/save",
    response_model=List[SaveResponse],
    summary="查询用户所有存档",
    description="获取当前登录用户的所有游戏存档。",
    responses={
        401: {"description": "未认证或Token无效"}
    }
)
async def get_saves(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    查询用户所有存档接口

    获取当前登录用户的所有游戏存档列表。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **返回：**
    - 存档列表，按槽位排序
    """
    service = SaveService(db)
    return service.get_user_saves(user_id)


# ============================================================
# 查询指定槽位存档接口
# ============================================================

@router.get(
    "/api/game/save/{slot_number}",
    response_model=SaveResponse,
    summary="查询指定槽位存档",
    description="获取当前登录用户指定槽位的游戏存档。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "该槽位没有存档"}
    }
)
async def get_save(
    slot_number: int,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    查询指定槽位存档接口

    获取当前登录用户指定槽位的游戏存档。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **路径参数：**
    - slot_number: 存档槽位（1-3）

    **返回：**
    - 存档详细信息

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 该槽位没有存档
    """
    service = SaveService(db)
    success, message, save = service.get_save_by_slot(user_id, slot_number)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    return save


# ============================================================
# 更新游戏存档接口
# ============================================================

@router.put(
    "/api/game/save/{slot_number}",
    response_model=SaveResponse,
    summary="更新游戏存档",
    description="更新当前登录用户指定槽位的游戏存档。只允许更新游戏进度相关字段。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "该槽位没有存档"},
        422: {"description": "请求数据验证失败"}
    }
)
async def update_save(
    slot_number: int,
    update_data: SaveUpdate,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    更新游戏存档接口

    更新当前登录用户指定槽位的游戏存档。
    只允许更新游戏进度相关字段，禁止修改玩家核心属性。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **路径参数：**
    - slot_number: 存档槽位（1-3）

    **请求参数（可选）：**
    - save_name: 存档名称
    - current_floor: 当前层数
    - player_state: 玩家状态数据
    - inventory_data: 背包数据
    - current_map_data: 当前地图数据
    - play_time: 游戏时长
    - kill_count: 击杀数
    - gold_collected: 收集金币

    **请求示例：**
    ```json
    {
        "current_floor": 5,
        "player_state": {
            "health": 80,
            "max_health": 100,
            "attack": 15,
            "defense": 8,
            "level": 3,
            "experience": 250,
            "gold": 150
        },
        "play_time": 3600,
        "kill_count": 50
    }
    ```

    **返回：**
    - 更新后的存档完整信息

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 该槽位没有存档
    - 422: 请求数据格式错误
    """
    service = SaveService(db)
    success, message, save = service.update_save(user_id, slot_number, update_data)

    if not success:
        if "没有存档" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return save
