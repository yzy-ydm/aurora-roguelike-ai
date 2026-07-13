"""
认证API路由模块

本模块提供用户认证相关的API接口。

接口列表：
- POST /api/auth/register: 用户注册
- POST /api/auth/login: 用户登录

设计原则：
- 路由层只处理HTTP请求/响应
- 业务逻辑委托给服务层
- 使用依赖注入获取数据库会话
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.schemas.auth import (
    UserRegister,
    UserLogin,
    TokenResponse,
    UserInfo,
    MessageResponse
)
from app.services.auth_service import AuthService

# 创建路由器
router = APIRouter(
    prefix="/api/auth",
    tags=["认证"]
)


# ============================================================
# 注册接口
# ============================================================

@router.post(
    "/register",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="用户注册",
    description="创建新用户账号。用户名必须唯一，密码将使用bcrypt加密存储。",
    responses={
        400: {"description": "用户名或邮箱已存在"},
        422: {"description": "请求数据验证失败"}
    }
)
async def register(
    user_data: UserRegister,
    db: Session = Depends(get_db)
):
    """
    用户注册接口

    接收用户名、密码和可选的邮箱地址，创建新用户。

    **请求参数：**
    - username: 用户名（3-50字符，只允许字母数字下划线）
    - password: 密码（8-100字符）
    - email: 邮箱地址（可选）

    **返回：**
    - 注册成功消息
    - 新创建的用户信息

    **错误情况：**
    - 400: 用户名已存在
    - 400: 邮箱已被注册
    - 422: 请求数据格式错误
    """
    # 创建认证服务实例
    service = AuthService(db)

    # 调用注册方法
    success, message, user_info = service.register_user(user_data)

    # 处理注册失败
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    # 返回成功响应
    return MessageResponse(
        code=201,
        message=message
    )


# ============================================================
# 登录接口
# ============================================================

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="用户登录",
    description="使用用户名和密码进行登录，成功后返回JWT访问令牌。",
    responses={
        401: {"description": "用户名或密码错误"},
        403: {"description": "账号已被禁用"},
        422: {"description": "请求数据验证失败"}
    }
)
async def login(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    """
    用户登录接口

    验证用户名和密码，成功后返回JWT Token。

    **请求参数：**
    - username: 用户名
    - password: 密码

    **返回：**
    - access_token: JWT访问令牌
    - token_type: Token类型（bearer）
    - user: 用户基本信息

    **使用方式：**
    ```
    POST /api/auth/login
    {
        "username": "player1",
        "password": "password123"
    }
    ```

    **响应示例：**
    ```json
    {
        "access_token": "eyJhbGciOiJIUzI1NiIs...",
        "token_type": "bearer",
        "user": {
            "id": 1,
            "username": "player1",
            "email": "player1@example.com",
            "is_active": true,
            "created_at": "2026-07-13T00:00:00"
        }
    }
    ```

    **错误情况：**
    - 401: 用户名或密码错误
    - 403: 账号已被禁用
    - 422: 请求数据格式错误
    """
    # 创建认证服务实例
    service = AuthService(db)

    # 验证用户身份
    success, message, user = service.authenticate_user(login_data)

    # 认证失败
    if not success:
        # 根据错误类型返回不同的状态码
        if message == "账号已被禁用":
            status_code = status.HTTP_403_FORBIDDEN
        else:
            status_code = status.HTTP_401_UNAUTHORIZED

        raise HTTPException(
            status_code=status_code,
            detail=message
        )

    # 生成Token并返回
    token_response = service.create_access_token(user)

    return token_response
