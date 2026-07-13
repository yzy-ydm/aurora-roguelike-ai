"""
怪物数据模型

本模块定义 monsters 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 怪物ID（主键，自增）
- name: 怪物名称
- description: 怪物描述
- monster_type: 怪物类型（normal, elite, boss）
- level: 等级
- health: 生命值
- attack: 攻击力
- defense: 防御力
- speed: 速度
- experience_reward: 经验奖励
- gold_reward: 金币奖励
- special_ability: 特殊能力描述
- special_ability_data: 特殊能力数据（JSON）
- icon_path: 图标路径
- min_floor: 最小出现层数
- max_floor: 最大出现层数
- is_ai_generated: 是否AI生成
- ai_generation_id: AI生成记录ID
- created_at: 创建时间
"""

from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    DateTime,
    JSON,
    Index,
    Enum as SAEnum
)
from sqlalchemy.sql import func

from app.database.connection import Base


class Monster(Base):
    """
    怪物模型类

    映射到数据库 monsters 表，存储游戏怪物基础数据。

    Attributes:
        id: 怪物唯一标识（主键）
        name: 怪物名称
        description: 怪物描述文本
        monster_type: 怪物类型（normal/elite/boss）
        level: 怪物等级
        health: 生命值
        attack: 攻击力
        defense: 防御力
        speed: 速度
        experience_reward: 击杀经验奖励
        gold_reward: 击杀金币奖励
        special_ability: 特殊能力描述
        special_ability_data: 特殊能力结构化数据（JSON格式）
        icon_path: 怪物图标文件路径
        min_floor: 最小出现层数
        max_floor: 最大出现层数
        is_ai_generated: 是否为AI生成的怪物
        ai_generation_id: 关联的AI生成记录ID
        created_at: 记录创建时间
    """

    # 表名
    __tablename__ = "monsters"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="怪物ID"
    )

    # 怪物名称
    name = Column(
        String(100),
        nullable=False,
        comment="怪物名称"
    )

    # 怪物描述
    description = Column(
        Text,
        nullable=True,
        comment="怪物描述"
    )

    # 怪物类型
    monster_type = Column(
        SAEnum(
            'normal', 'elite', 'boss',
            name='monster_type_enum'
        ),
        default='normal',
        comment="怪物类型"
    )

    # 等级
    level = Column(
        Integer,
        default=1,
        comment="怪物等级"
    )

    # 生命值
    health = Column(
        Integer,
        nullable=False,
        comment="生命值"
    )

    # 攻击力
    attack = Column(
        Integer,
        nullable=False,
        comment="攻击力"
    )

    # 防御力
    defense = Column(
        Integer,
        nullable=False,
        comment="防御力"
    )

    # 速度
    speed = Column(
        Integer,
        default=10,
        comment="速度"
    )

    # 经验奖励
    experience_reward = Column(
        Integer,
        default=10,
        comment="经验奖励"
    )

    # 金币奖励
    gold_reward = Column(
        Integer,
        default=5,
        comment="金币奖励"
    )

    # 特殊能力描述
    special_ability = Column(
        Text,
        nullable=True,
        comment="特殊能力"
    )

    # 特殊能力数据（JSON格式）
    special_ability_data = Column(
        JSON,
        nullable=True,
        comment="特殊能力数据"
    )

    # 怪物图标路径
    icon_path = Column(
        String(255),
        nullable=True,
        comment="图标路径"
    )

    # 最小出现层数
    min_floor = Column(
        Integer,
        default=1,
        comment="最小出现层数"
    )

    # 最大出现层数
    max_floor = Column(
        Integer,
        default=999,
        comment="最大出现层数"
    )

    # 是否为AI生成的内容
    is_ai_generated = Column(
        Integer,
        default=0,
        comment="是否AI生成"
    )

    # AI生成记录ID
    ai_generation_id = Column(
        Integer,
        nullable=True,
        comment="AI生成记录ID"
    )

    # 创建时间
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="创建时间"
    )

    # ==================== 索引定义 ====================
    __table_args__ = (
        Index("idx_monster_type", "monster_type"),
        Index("idx_level", "level"),
        Index("idx_min_floor", "min_floor"),
        Index("idx_is_ai_generated", "is_ai_generated"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回怪物对象的字符串表示"""
        return (
            f"<Monster(id={self.id}, name='{self.name}', "
            f"type='{self.monster_type}', level={self.level})>"
        )

    def to_dict(self) -> dict:
        """
        将怪物对象转换为字典

        Returns:
            dict: 怪物信息字典
        """
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "monster_type": self.monster_type,
            "level": self.level,
            "health": self.health,
            "attack": self.attack,
            "defense": self.defense,
            "speed": self.speed,
            "experience_reward": self.experience_reward,
            "gold_reward": self.gold_reward,
            "special_ability": self.special_ability,
            "special_ability_data": self.special_ability_data,
            "icon_path": self.icon_path,
            "min_floor": self.min_floor,
            "max_floor": self.max_floor,
            "is_ai_generated": self.is_ai_generated,
            "ai_generation_id": self.ai_generation_id,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
