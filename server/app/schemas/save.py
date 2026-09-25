"""
游戏存档相关Pydantic模式

本模块定义游戏存档相关的数据验证模式，用于：
- 请求数据验证
- 响应数据序列化
- API文档自动生成

模式列表：
- SaveCreate: 创建存档请求
- SaveUpdate: 更新存档请求
- SaveResponse: 存档信息响应
"""

from datetime import datetime
from typing import Optional, Any

from pydantic import BaseModel, Field, field_validator


# ============================================================
# 请求模式
# ============================================================

class SaveCreate(BaseModel):
    """
    创建游戏存档请求模式

    用于验证创建游戏存档时提交的数据。

    Attributes:
        save_name: 存档名称（1-100字符）
        slot_number: 存档槽位（1-3）
        player_state: 玩家状态数据（JSON格式）
    """
    save_name: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="存档名称",
        examples=["第一次冒险"]
    )
    slot_number: int = Field(
        ...,
        ge=1,
        le=3,
        description="存档槽位（1-3）",
        examples=[1]
    )
    player_state: Any = Field(
        ...,
        description="玩家状态数据（JSON格式）",
        examples=[{"health": 100, "max_health": 100, "attack": 10, "defense": 5, "level": 1, "experience": 0, "gold": 0}]
    )
    # TASK-026: 创建存档时持久化游戏进度字段
    # （客户端 404→POST 兜底路径会携带这些字段；此前被 schema 丢弃，首次保存丢失楼层）
    current_floor: Optional[int] = Field(
        None,
        ge=1,
        description="当前层数"
    )
    play_time: Optional[int] = Field(
        None,
        ge=0,
        description="游戏时长（秒）"
    )
    kill_count: Optional[int] = Field(
        None,
        ge=0,
        description="击杀数"
    )
    gold_collected: Optional[int] = Field(
        None,
        ge=0,
        description="收集金币"
    )

    @field_validator("save_name")
    @classmethod
    def validate_save_name(cls, v: str) -> str:
        """
        验证存档名称格式

        规则：
        - 不能以空格开头或结尾
        """
        v = v.strip()
        if not v:
            raise ValueError("存档名称不能为空")
        return v

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
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
        }


class SaveUpdate(BaseModel):
    """
    更新游戏存档请求模式

    用于验证更新游戏存档时提交的数据。
    只允许更新游戏进度相关字段，禁止修改玩家核心属性。

    Attributes:
        save_name: 存档名称（可选）
        current_floor: 当前层数（可选）
        player_state: 玩家状态数据（可选）
        inventory_data: 背包数据（可选）
        current_map_data: 当前地图数据（可选）
        play_time: 游戏时长（可选）
        kill_count: 击杀数（可选）
        gold_collected: 收集金币（可选）
    """
    save_name: Optional[str] = Field(
        None,
        min_length=1,
        max_length=100,
        description="存档名称"
    )
    current_floor: Optional[int] = Field(
        None,
        ge=1,
        description="当前层数"
    )
    player_state: Optional[Any] = Field(
        None,
        description="玩家状态数据"
    )
    inventory_data: Optional[Any] = Field(
        None,
        description="背包数据"
    )
    current_map_data: Optional[Any] = Field(
        None,
        description="当前地图数据"
    )
    play_time: Optional[int] = Field(
        None,
        ge=0,
        description="游戏时长（秒）"
    )
    kill_count: Optional[int] = Field(
        None,
        ge=0,
        description="击杀数"
    )
    gold_collected: Optional[int] = Field(
        None,
        ge=0,
        description="收集金币"
    )

    @field_validator("save_name")
    @classmethod
    def validate_save_name(cls, v: Optional[str]) -> Optional[str]:
        """
        验证存档名称格式

        规则：
        - 不能以空格开头或结尾
        """
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError("存档名称不能为空")
        return v

    class Config:
        """Pydantic配置"""
        json_schema_extra = {
            "example": {
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
        }


# ============================================================
# 响应模式
# ============================================================

class SaveResponse(BaseModel):
    """
    游戏存档信息响应模式

    用于返回游戏存档的完整信息。

    Attributes:
        id: 存档ID
        user_id: 用户ID
        save_name: 存档名称
        current_floor: 当前层数
        player_state: 玩家状态数据
        inventory_data: 背包数据
        current_map_data: 当前地图数据
        explored_maps: 已探索地图
        play_time: 游戏时长
        kill_count: 击杀数
        gold_collected: 收集金币
        slot_number: 存档槽位
        is_active: 是否活跃
        created_at: 创建时间
        updated_at: 更新时间
    """
    id: int = Field(..., description="存档ID")
    user_id: int = Field(..., description="用户ID")
    save_name: str = Field(..., description="存档名称")
    current_floor: int = Field(1, description="当前层数")
    player_state: Any = Field(..., description="玩家状态数据")
    inventory_data: Optional[Any] = Field(None, description="背包数据")
    current_map_data: Optional[Any] = Field(None, description="当前地图数据")
    explored_maps: Optional[Any] = Field(None, description="已探索地图")
    play_time: int = Field(0, description="游戏时长（秒）")
    kill_count: int = Field(0, description="击杀数")
    gold_collected: int = Field(0, description="收集金币")
    slot_number: int = Field(..., description="存档槽位")
    is_active: int = Field(1, description="是否活跃")
    created_at: Optional[datetime] = Field(None, description="创建时间")
    updated_at: Optional[datetime] = Field(None, description="更新时间")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "user_id": 1,
                "save_name": "第一次冒险",
                "current_floor": 3,
                "player_state": {
                    "health": 85,
                    "max_health": 100,
                    "attack": 12,
                    "defense": 8,
                    "level": 2,
                    "experience": 150,
                    "gold": 230
                },
                "inventory_data": {
                    "weapons": [{"id": 1, "name": "铁剑"}],
                    "items": [{"name": "生命药水", "count": 3}]
                },
                "current_map_data": {
                    "floor": 3,
                    "theme": "dungeon",
                    "explored_rooms": [1, 2, 3]
                },
                "explored_maps": None,
                "play_time": 1800,
                "kill_count": 25,
                "gold_collected": 230,
                "slot_number": 1,
                "is_active": 1,
                "created_at": "2026-07-13T00:00:00",
                "updated_at": "2026-07-13T00:30:00"
            }
        }
