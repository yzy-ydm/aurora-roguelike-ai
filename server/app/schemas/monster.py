"""
怪物相关Pydantic模式

本模块定义怪物相关的数据验证模式，用于：
- 响应数据序列化
- API文档自动生成

模式列表：
- MonsterResponse: 怪物信息响应

注意：当前阶段只实现查询接口，不实现创建/更新/删除Schema。
"""

from typing import Optional, Any

from pydantic import BaseModel, Field


# ============================================================
# 响应模式
# ============================================================

class MonsterResponse(BaseModel):
    """
    怪物信息响应模式

    用于返回怪物的基础信息。
    字段映射：
    - type → monster_type（数据库字段）
    - attributes → special_ability_data（数据库字段）

    Attributes:
        id: 怪物ID
        name: 怪物名称
        description: 怪物描述
        type: 怪物类型（对应数据库monster_type）
        level: 怪物等级
        health: 生命值
        attack: 攻击力
        defense: 防御力
        speed: 速度
        experience_reward: 经验奖励
        gold_reward: 金币奖励
        special_ability: 特殊能力描述
        attributes: 特殊能力数据（对应数据库special_ability_data）
        icon_path: 图标路径
        min_floor: 最小出现层数
        max_floor: 最大出现层数
    """
    id: int = Field(..., description="怪物ID")
    name: str = Field(..., description="怪物名称")
    description: Optional[str] = Field(None, description="怪物描述")
    type: str = Field(..., description="怪物类型")
    level: int = Field(1, description="怪物等级")
    health: int = Field(..., description="生命值")
    attack: int = Field(..., description="攻击力")
    defense: int = Field(..., description="防御力")
    speed: int = Field(10, description="速度")
    experience_reward: int = Field(10, description="经验奖励")
    gold_reward: int = Field(5, description="金币奖励")
    special_ability: Optional[str] = Field(None, description="特殊能力描述")
    attributes: Optional[Any] = Field(None, description="特殊能力数据")
    icon_path: Optional[str] = Field(None, description="图标路径")
    min_floor: int = Field(1, description="最小出现层数")
    max_floor: int = Field(999, description="最大出现层数")

    class Config:
        """Pydantic配置"""
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "name": "史莱姆",
                "description": "最基础的怪物，由粘液构成，行动缓慢。",
                "type": "normal",
                "level": 1,
                "health": 20,
                "attack": 5,
                "defense": 2,
                "speed": 3,
                "experience_reward": 10,
                "gold_reward": 5,
                "special_ability": None,
                "attributes": None,
                "icon_path": None,
                "min_floor": 1,
                "max_floor": 10
            }
        }
