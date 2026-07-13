"""
玩家角色API路由模块

本模块提供玩家角色管理相关的API接口。

接口列表：
- POST /api/player/profile: 创建玩家角色（需要JWT认证）
- GET /api/player/profile: 查询玩家角色信息（需要JWT认证）
- PUT /api/player/profile: 更新玩家角色信息（需要JWT认证）

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
- 复用已有JWT认证系统
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.core.security import decode_access_token
from app.schemas.player import PlayerCreate, PlayerUpdate, PlayerResponse
from app.schemas.auth import MessageResponse
from app.services.player_service import PlayerService

# 创建路由器
router = APIRouter(
    prefix="/api/player",
    tags=["玩家角色"]
)

# HTTP Bearer 认证方案
security_scheme = HTTPBearer()


# ============================================================
# 认证依赖注入
# ============================================================

def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme)
) -> int:
    """
    从JWT Token中获取当前用户ID

    解析Authorization Header中的Bearer Token，
    验证Token有效性并提取用户ID。

    Args:
        credentials: HTTP Bearer认证凭据

    Returns:
        int: 当前用户ID

    Raises:
        HTTPException: Token无效或已过期时返回401
    """
    # 获取Token字符串
    token = credentials.credentials

    # 解码Token
    payload = decode_access_token(token)

    # Token无效或已过期
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证凭据，请重新登录",
            headers={"WWW-Authenticate": "Bearer"}
        )

    # 获取用户ID
    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token中缺少用户信息",
            headers={"WWW-Authenticate": "Bearer"}
        )

    try:
        return int(user_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token中用户ID格式无效",
            headers={"WWW-Authenticate": "Bearer"}
        )


# ============================================================
# 创建玩家角色接口
# ============================================================

@router.post(
    "/profile",
    response_model=PlayerResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建玩家角色",
    description="为当前登录用户创建游戏角色。每个用户只能创建一个角色。",
    responses={
        401: {"description": "未认证或Token无效"},
        409: {"description": "角色已存在"},
        422: {"description": "请求数据验证失败"}
    }
)
async def create_player_profile(
    player_data: PlayerCreate,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    创建玩家角色接口

    为当前登录用户创建游戏角色。
    角色的基础属性（等级、生命值、攻击力等）使用数据库默认值。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **请求参数：**
    - nickname: 角色昵称（2-50字符）

    **返回：**
    - 创建的玩家角色完整信息

    **错误情况：**
    - 401: 未登录或Token无效
    - 409: 该用户已有角色档案
    - 422: 请求数据格式错误
    """
    # 创建玩家角色服务实例
    service = PlayerService(db)

    # 调用创建方法
    success, message, player = service.create_player(user_id, player_data)

    # 处理创建失败
    if not success:
        if "已有角色档案" in message:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=message
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    # 返回创建的角色信息
    return player


# ============================================================
# 查询玩家角色信息接口
# ============================================================

@router.get(
    "/profile",
    response_model=PlayerResponse,
    summary="查询玩家角色信息",
    description="获取当前登录用户的角色信息。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "玩家角色不存在"}
    }
)
async def get_player_profile(
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    查询玩家角色信息接口

    获取当前登录用户的角色属性信息。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **返回：**
    - 玩家角色完整信息（等级、生命值、攻击力、防御力、金币等）

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 玩家角色不存在（尚未创建角色）
    """
    # 创建玩家角色服务实例
    service = PlayerService(db)

    # 调用查询方法
    success, message, player = service.get_player_profile(user_id)

    # 处理查询失败
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message
        )

    # 返回角色信息
    return player


# ============================================================
# 更新玩家角色信息接口
# ============================================================

@router.put(
    "/profile",
    response_model=PlayerResponse,
    summary="更新玩家角色信息",
    description="更新当前登录用户的角色信息。目前只允许修改角色昵称。",
    responses={
        401: {"description": "未认证或Token无效"},
        404: {"description": "玩家角色不存在"},
        422: {"description": "请求数据验证失败"}
    }
)
async def update_player_profile(
    update_data: PlayerUpdate,
    user_id: int = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    更新玩家角色信息接口

    更新当前登录用户的角色信息。
    目前只允许修改角色昵称。
    核心属性（等级、攻击力、防御力、金币等）由服务器游戏逻辑控制，客户端不可修改。

    **认证要求：** 需要在Header中携带JWT Token
    ```
    Authorization: Bearer <token>
    ```

    **请求参数：**
    - nickname: 新的角色昵称（2-50字符，可选）

    **返回：**
    - 更新后的玩家角色完整信息

    **错误情况：**
    - 401: 未登录或Token无效
    - 404: 玩家角色不存在
    - 422: 请求数据格式错误
    """
    # 创建玩家角色服务实例
    service = PlayerService(db)

    # 调用更新方法
    success, message, player = service.update_player_profile(user_id, update_data)

    # 处理更新失败
    if not success:
        if "不存在" in message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=message
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    # 返回更新后的角色信息
    return player
