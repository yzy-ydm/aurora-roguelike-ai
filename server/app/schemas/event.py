"""
事件相关Pydantic模式

本模块定义事件相关的数据验证模式，用于：
- 响应数据序列化
- API文档自动生成

模式列表：
- EventResponse: 事件信息响应

注意：当前阶段只实现查询接口，不实现创建/更新/删除Schema。
"""

from typing import Optional, Any

from pydantic import BaseModel, Field


# ============================================================
# 响应模式
# ============================================================

class EventResponse(BaseModel):
    """
    事件信息响应模式

    用于返回事件的基础信息。
    字段映射：
    - type → event_type（数据库字段）
    - attributes → effect_data + option1_effect + option2_effect

    Attributes:
        id: 事件ID
        name: 事件名称
        description: 事件描述
        type: 事件类型（对应数据库event_type）
        trigger_rate: 触发概率
        min_floor: 最小层数
        max_floor: 最大层数
        effect_data: 效果数据
        option1_text: 选项1文本
        option1_effect: 选项1效果
        option2_text: 选项2文本
        option2_effect: 选项2效果
    """
    id: int = Field(..., description="事件ID")
    name: str = Field(..., description="事件名称")
    description: str = Field(..., description="事件描述")
    type: str = Field(..., description="事件类型")
    trigger_rate: float = Field(10.0, description="触发概率(%)")
    min_floor: int = Field(1, description="最小层数")
    max_floor: int = Field(999, description="最大层数")
    effect_data: Optional[Any] = Field(None, description="效果数据")
    option1_text: Optional[str] = Field(None, description="选项1文本")
    option1_effect: Optional[Any] = Field(None, description="选项1效果")
    option2_text: Optional[str] = Field(None, description="选项2文本")
    option2_effect: Optional[Any] = Field(None, description="选项2效果")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "宝箱发现",
                "description": "你发现了一个闪闪发光的宝箱，上面镶嵌着宝石。",
                "type": "treasure",
                "trigger_rate": 15.0,
                "min_floor": 1,
                "max_floor": 999,
                "effect_data": {"gold": 50},
                "option1_text": "打开宝箱",
                "option1_effect": {"gold": 100, "risk": "可能有陷阱"},
                "option2_text": "离开",
                "option2_effect": {}
            }
        }
