"""
武器相关Pydantic模式

本模块定义武器相关的数据验证模式，用于：
- 请求数据验证
- 响应数据序列化
- API文档自动生成

模式列表：
- WeaponResponse: 武器信息响应
- PlayerWeaponResponse: 玩家拥有武器响应
- WeaponCreate: 创建武器请求（服务器内部使用）
"""

from datetime import datetime
from typing import Optional, Any

from pydantic import BaseModel, Field


# ============================================================
# 响应模式
# ============================================================

class WeaponResponse(BaseModel):
    """
    武器信息响应模式

    用于返回武器的基础信息。
    字段映射：
    - type → weapon_type（数据库字段）
    - damage → attack_bonus（数据库字段）
    - attributes → special_effect_data（数据库字段）

    Attributes:
        id: 武器ID
        name: 武器名称
        description: 武器描述
        type: 武器类型（对应数据库weapon_type）
        rarity: 稀有度
        damage: 攻击力加成（对应数据库attack_bonus）
        crit_rate_bonus: 暴击率加成
        special_effect: 特殊效果描述
        attributes: 特殊效果数据（对应数据库special_effect_data）
        icon_path: 图标路径
        price: 价格
    """
    id: int = Field(..., description="武器ID")
    name: str = Field(..., description="武器名称")
    description: Optional[str] = Field(None, description="武器描述")
    type: str = Field(..., description="武器类型")
    rarity: str = Field(..., description="稀有度")
    damage: int = Field(..., description="攻击力加成")
    crit_rate_bonus: float = Field(0.0, description="暴击率加成")
    special_effect: Optional[str] = Field(None, description="特殊效果描述")
    attributes: Optional[Any] = Field(None, description="特殊效果数据")
    icon_path: Optional[str] = Field(None, description="图标路径")
    price: int = Field(0, description="价格")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "铁剑",
                "description": "一把普通的铁制长剑",
                "type": "sword",
                "rarity": "common",
                "damage": 5,
                "crit_rate_bonus": 0.0,
                "special_effect": None,
                "attributes": None,
                "icon_path": None,
                "price": 50
            }
        }


class PlayerWeaponResponse(BaseModel):
    """
    玩家拥有武器响应模式

    用于返回玩家拥有的武器信息，包含武器详情和装备状态。

    Attributes:
        id: 记录ID
        player_id: 玩家档案ID
        weapon_id: 武器ID
        is_equipped: 是否装备中
        created_at: 获取时间
        weapon: 武器详细信息
    """
    id: int = Field(..., description="记录ID")
    player_id: int = Field(..., description="玩家档案ID")
    weapon_id: int = Field(..., description="武器ID")
    is_equipped: int = Field(0, description="是否装备中")
    created_at: Optional[datetime] = Field(None, description="获取时间")
    weapon: WeaponResponse = Field(..., description="武器详细信息")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "player_id": 1,
                "weapon_id": 1,
                "is_equipped": 0,
                "created_at": "2026-07-13T00:00:00",
                "weapon": {
                    "id": 1,
                    "name": "铁剑",
                    "description": "一把普通的铁制长剑",
                    "type": "sword",
                    "rarity": "common",
                    "damage": 5,
                    "crit_rate_bonus": 0.0,
                    "special_effect": None,
                    "attributes": None,
                    "icon_path": None,
                    "price": 50
                }
            }
        }


# ============================================================
# 请求模式
# ============================================================

class WeaponCreate(BaseModel):
    """
    创建武器请求模式（服务器内部使用）

    用于服务器内部创建武器记录。
    客户端不应直接提交此数据。

    Attributes:
        name: 武器名称
        description: 武器描述
        weapon_type: 武器类型
        rarity: 稀有度
        attack_bonus: 攻击力加成
        crit_rate_bonus: 暴击率加成
        special_effect: 特殊效果描述
        special_effect_data: 特殊效果数据
        icon_path: 图标路径
        price: 价格
    """
    name: str = Field(..., max_length=100, description="武器名称")
    description: Optional[str] = Field(None, description="武器描述")
    weapon_type: str = Field(..., description="武器类型")
    rarity: str = Field("common", description="稀有度")
    attack_bonus: int = Field(0, description="攻击力加成")
    crit_rate_bonus: float = Field(0.0, description="暴击率加成")
    special_effect: Optional[str] = Field(None, description="特殊效果描述")
    special_effect_data: Optional[Any] = Field(None, description="特殊效果数据")
    icon_path: Optional[str] = Field(None, description="图标路径")
    price: int = Field(0, description="价格")


class AddPlayerWeaponRequest(BaseModel):
    """
    添加玩家武器请求模式

    用于为玩家添加武器。

    Attributes:
        weapon_id: 武器ID
    """
    weapon_id: int = Field(..., description="武器ID")

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
                "weapon_id": 1
            }
        }
