"""
认证相关Pydantic模式

本模块定义用户认证相关的数据验证模式，用于：
- 请求数据验证
- 响应数据序列化
- API文档自动生成

模式列表：
- UserRegister: 用户注册请求
- UserLogin: 用户登录请求
- TokenResponse: Token响应
- UserInfo: 用户信息响应
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, EmailStr, field_validator


# ============================================================
# 请求模式
# ============================================================

class UserRegister(BaseModel):
    """
    用户注册请求模式

    用于验证用户注册时提交的数据。

    Attributes:
        username: 用户名（3-50字符，只允许字母数字下划线）
        password: 密码（8-100字符）
        email: 邮箱地址（可选）
    """
    username: str = Field(
        ...,
        min_length=3,
        max_length=50,
        description="用户名",
        examples=["player1"]
    )
    password: str = Field(
        ...,
        min_length=8,
        max_length=100,
        description="密码",
        examples=["password123"]
    )
    email: Optional[str] = Field(
        None,
        description="邮箱地址（可选）",
        examples=["player1@example.com"]
    )

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """
        验证用户名格式

        规则：
        - 只允许字母、数字、下划线
        - 不能以数字开头
        """
        if not v.isascii():
            raise ValueError("用户名只能包含字母、数字、下划线")
        if not v.replace("_", "").isalnum():
            raise ValueError("用户名只能包含字母、数字、下划线")
        if v[0].isdigit():
            raise ValueError("用户名不能以数字开头")
        return v

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "username": "player1",
                "password": "password123",
                "email": "player1@example.com"
            }
        }


class UserLogin(BaseModel):
    """
    用户登录请求模式

    用于验证用户登录时提交的数据。

    Attributes:
        username: 用户名
        password: 密码
    """
    username: str = Field(
        ...,
        description="用户名",
        examples=["player1"]
    )
    password: str = Field(
        ...,
        description="密码",
        examples=["password123"]
    )

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "username": "player1",
                "password": "password123"
            }
        }


# ============================================================
# 响应模式
# ============================================================

class UserInfo(BaseModel):
    """
    用户信息响应模式

    用于返回用户基本信息（不包含敏感数据）。

    Attributes:
        id: 用户ID
        username: 用户名
        email: 邮箱地址
        is_active: 是否启用
        created_at: 创建时间
    """
    id: int = Field(..., description="用户ID")
    username: str = Field(..., description="用户名")
    email: Optional[str] = Field(None, description="邮箱地址")
    is_active: bool = Field(..., description="是否启用")
    created_at: Optional[datetime] = Field(None, description="创建时间")

    class Config:
        """Pydantic配置"""
        from_attributes = True  # 支持从ORM对象创建


class TokenResponse(BaseModel):
    """
    Token响应模式

    用于登录成功后返回JWT Token信息。

    Attributes:
        access_token: JWT访问令牌
        token_type: Token类型（固定为bearer）
        user: 用户信息
    """
    access_token: str = Field(
        ...,
        description="JWT访问令牌",
        examples=["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."]
    )
    token_type: str = Field(
        default="bearer",
        description="Token类型",
        examples=["bearer"]
    )
    user: UserInfo = Field(
        ...,
        description="用户信息"
    )

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "user": {
                    "id": 1,
                    "username": "player1",
                    "email": "player1@example.com",
                    "is_active": True,
                    "created_at": "2026-07-13T00:00:00"
                }
            }
        }


# ============================================================
# 通用响应模式
# ============================================================

class MessageResponse(BaseModel):
    """
    通用消息响应模式

    用于返回简单的消息响应。

    Attributes:
        code: 状态码
        message: 消息内容
    """
    code: int = Field(200, description="状态码")
    message: str = Field(..., description="消息内容")
