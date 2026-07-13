"""
API认证模块

实现Bearer Token验证
保护AI生成接口
"""

import os
import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel


# 配置
class AuthConfig:
    """认证配置"""
    # API密钥（生产环境应从环境变量读取）
    API_KEYS = {
        "godot_client": os.getenv("AI_API_KEY", "aurora-roguelike-ai-key-2024"),
        "admin": os.getenv("AI_ADMIN_KEY", "admin-secret-key-2024"),
    }

    # Token过期时间（小时）
    TOKEN_EXPIRE_HOURS = 24

    # 是否启用认证（开发时可关闭）
    AUTH_ENABLED = os.getenv("AI_AUTH_ENABLED", "true").lower() == "true"


# Token模型
class TokenData(BaseModel):
    """Token数据"""
    client_id: str
    expires_at: datetime


# Token存储（内存缓存，生产环境应使用Redis）
_active_tokens: dict = {}


# HTTP Bearer安全方案
security = HTTPBearer(auto_error=False)


def generate_token(client_id: str) -> str:
    """
    生成API Token

    Args:
        client_id: 客户端ID

    Returns:
        Token字符串
    """
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now() + timedelta(hours=AuthConfig.TOKEN_EXPIRE_HOURS)

    _active_tokens[token] = TokenData(
        client_id=client_id,
        expires_at=expires_at
    )

    return token


def verify_token(token: str) -> Optional[TokenData]:
    """
    验证Token

    Args:
        token: Token字符串

    Returns:
        Token数据或None
    """
    if token not in _active_tokens:
        return None

    token_data = _active_tokens[token]

    # 检查是否过期
    if datetime.now() > token_data.expires_at:
        del _active_tokens[token]
        return None

    return token_data


def revoke_token(token: str) -> bool:
    """
    撤销Token

    Args:
        token: Token字符串

    Returns:
        是否成功
    """
    if token in _active_tokens:
        del _active_tokens[token]
        return True
    return False


async def verify_api_key(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security)
) -> str:
    """
    验证API密钥（FastAPI依赖注入）

    Args:
        credentials: HTTP Bearer凭证

    Returns:
        客户端ID

    Raises:
        HTTPException: 认证失败
    """
    # 如果认证未启用，返回默认客户端ID
    if not AuthConfig.AUTH_ENABLED:
        return "godot_client"

    # 检查是否提供了凭证
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Missing authentication credentials",
            headers={"WWW-Authenticate": "Bearer"}
        )

    token = credentials.credentials

    # 验证Token
    token_data = verify_token(token)
    if token_data is None:
        # 尝试作为API密钥验证
        for client_id, api_key in AuthConfig.API_KEYS.items():
            if token == api_key:
                return client_id

        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"}
        )

    return token_data.client_id


async def verify_admin_key(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security)
) -> str:
    """
    验证管理员密钥

    Args:
        credentials: HTTP Bearer凭证

    Returns:
        客户端ID

    Raises:
        HTTPException: 认证失败
    """
    client_id = await verify_api_key(credentials)

    # 检查是否是管理员
    if client_id != "admin":
        raise HTTPException(
            status_code=403,
            detail="Admin access required"
        )

    return client_id


def get_auth_status() -> dict:
    """
    获取认证状态

    Returns:
        认证状态信息
    """
    return {
        "auth_enabled": AuthConfig.AUTH_ENABLED,
        "active_tokens": len(_active_tokens),
        "registered_clients": list(AuthConfig.API_KEYS.keys())
    }
