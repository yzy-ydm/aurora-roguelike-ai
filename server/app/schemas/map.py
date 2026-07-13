"""
地图相关Pydantic模式

本模块定义地图相关的数据验证模式，用于：
- 响应数据序列化
- API文档自动生成

模式列表：
- MapResponse: 地图信息响应

注意：当前阶段只实现查询接口，不实现创建/更新/删除Schema。
"""

from typing import Optional, Any

from pydantic import BaseModel, Field


# ============================================================
# 响应模式
# ============================================================

class MapResponse(BaseModel):
    """
    地图信息响应模式

    用于返回地图的基础信息。
    字段映射：
    - type → theme（数据库字段）
    - attributes → room_data + monster_spawn_config + event_spawn_config

    Attributes:
        id: 地图ID
        name: 地图名称
        description: 地图描述
        type: 地图主题（对应数据库theme）
        floor_level: 层数
        width: 宽度
        height: 高度
        room_count: 房间数
        room_data: 房间数据
        monster_spawn_config: 怪物生成配置
        event_spawn_config: 事件生成配置
        difficulty: 难度等级
    """
    id: int = Field(..., description="地图ID")
    name: str = Field(..., description="地图名称")
    description: Optional[str] = Field(None, description="地图描述")
    type: str = Field(..., description="地图主题")
    floor_level: int = Field(..., description="层数")
    width: int = Field(20, description="宽度")
    height: int = Field(15, description="高度")
    room_count: int = Field(8, description="房间数")
    room_data: Optional[Any] = Field(None, description="房间数据")
    monster_spawn_config: Optional[Any] = Field(None, description="怪物生成配置")
    event_spawn_config: Optional[Any] = Field(None, description="事件生成配置")
    difficulty: int = Field(1, description="难度等级")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "新手地牢入口",
                "description": "地牢的最浅层，光线尚可，危险较小。",
                "type": "dungeon",
                "floor_level": 1,
                "width": 15,
                "height": 12,
                "room_count": 5,
                "room_data": {
                    "rooms": [
                        {"id": 1, "x": 2, "y": 2, "w": 4, "h": 3, "type": "start"},
                        {"id": 2, "x": 8, "y": 2, "w": 4, "h": 3, "type": "normal"}
                    ]
                },
                "monster_spawn_config": {
                    "monsters": [{"id": 1, "count": 3}, {"id": 2, "count": 2}]
                },
                "event_spawn_config": {
                    "events": [{"id": 1, "count": 1}, {"id": 3, "count": 1}]
                },
                "difficulty": 1
            }
        }
