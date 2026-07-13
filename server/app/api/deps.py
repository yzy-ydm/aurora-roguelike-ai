"""
API共享依赖模块

本模块提供API路由共享的依赖注入函数，包括：
- JWT认证依赖
- 用户ID提取

设计原则：
- 避免代码重复
- 统一认证逻辑
- 便于维护
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.security import decode_access_token

# HTTP Bearer 认证方案
security_scheme = HTTPBearer()


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
