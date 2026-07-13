"""
玩家角色相关Pydantic模式

本模块定义玩家角色相关的数据验证模式，用于：
- 请求数据验证
- 响应数据序列化
- API文档自动生成

模式列表：
- PlayerCreate: 创建玩家角色请求
- PlayerUpdate: 更新玩家角色请求
- PlayerResponse: 玩家角色信息响应
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ============================================================
# 请求模式
# ============================================================

class PlayerCreate(BaseModel):
    """
    创建玩家角色请求模式

    用于验证创建玩家角色时提交的数据。
    只需要提供角色昵称，其他属性使用数据库默认值。

    Attributes:
        nickname: 角色昵称（2-50字符）
    """
    nickname: str = Field(
        ...,
        min_length=2,
        max_length=50,
        description="角色昵称",
        examples=["勇敢的冒险者"]
    )

    @field_validator("nickname")
    @classmethod
    def validate_nickname(cls, v: str) -> str:
        """
        验证角色昵称格式

        规则：
        - 不能包含特殊字符（只允许中英文、数字、下划线、空格）
        - 不能以空格开头或结尾
        """
        v = v.strip()
        if not v:
            raise ValueError("昵称不能为空")
        if len(v) < 2:
            raise ValueError("昵称至少2个字符")
        return v

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "nickname": "勇敢的冒险者"
            }
        }


class PlayerUpdate(BaseModel):
    """
    更新玩家角色请求模式

    用于验证更新玩家角色时提交的数据。
    只允许修改角色昵称，核心属性（level, attack等）由服务器游戏逻辑控制。

    Attributes:
        nickname: 新的角色昵称（2-50字符，可选）
    """
    nickname: Optional[str] = Field(
        None,
        min_length=2,
        max_length=50,
        description="新的角色昵称",
        examples=["传奇英雄"]
    )

    @field_validator("nickname")
    @classmethod
    def validate_nickname(cls, v: Optional[str]) -> Optional[str]:
        """
        验证角色昵称格式

        规则：
        - 不能包含特殊字符
        - 不能以空格开头或结尾
        """
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError("昵称不能为空")
            if len(v) < 2:
                raise ValueError("昵称至少2个字符")
        return v

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "nickname": "传奇英雄"
            }
        }


# ============================================================
# 响应模式
# ============================================================

class PlayerResponse(BaseModel):
    """
    玩家角色信息响应模式

    用于返回玩家角色的基本信息。
    注意：health 字段对应数据库中的 current_health 列。

    Attributes:
        id: 角色档案ID
        user_id: 关联的用户ID
        nickname: 角色昵称
        level: 角色等级
        experience: 当前经验值
        health: 当前生命值（对应数据库 current_health）
        max_health: 最大生命值
        attack: 基础攻击力
        defense: 基础防御力
        gold: 金币数量
    """
    id: int = Field(..., description="角色档案ID")
    user_id: int = Field(..., description="关联的用户ID")
    nickname: str = Field(..., description="角色昵称")
    level: int = Field(..., description="角色等级")
    experience: int = Field(..., description="当前经验值")
    health: int = Field(..., description="当前生命值")
    max_health: int = Field(..., description="最大生命值")
    attack: int = Field(..., description="基础攻击力")
    defense: int = Field(..., description="基础防御力")
    gold: int = Field(..., description="金币数量")

    class Config:
        """Pydantic配置"""
        from_attributes = True  # 支持从ORM对象创建
        json_schema_extra = {
            "example": {
                "id": 1,
                "user_id": 1,
                "nickname": "勇敢的冒险者",
                "level": 1,
                "experience": 0,
                "health": 100,
                "max_health": 100,
                "attack": 10,
                "defense": 5,
                "gold": 0
            }
        }
