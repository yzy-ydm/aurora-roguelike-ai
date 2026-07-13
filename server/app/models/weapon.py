"""
武器数据模型

本模块定义 weapons 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 武器ID（主键，自增）
- name: 武器名称
- description: 武器描述
- weapon_type: 武器类型（sword, axe, bow, staff, dagger, spear, hammer）
- rarity: 稀有度（common, uncommon, rare, epic, legendary）
- attack_bonus: 攻击力加成
- crit_rate_bonus: 暴击率加成
- special_effect: 特殊效果描述
- special_effect_data: 特殊效果数据（JSON）
- icon_path: 图标路径
- price: 价格
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
    Numeric,
    JSON,
    Index,
    Enum as SAEnum
)
from sqlalchemy.sql import func

from app.database.connection import Base


class Weapon(Base):
    """
    武器模型类

    映射到数据库 weapons 表，存储游戏武器基础数据。

    Attributes:
        id: 武器唯一标识（主键）
        name: 武器名称
        description: 武器描述文本
        weapon_type: 武器类型（sword/axe/bow/staff/dagger/spear/hammer）
        rarity: 稀有度等级（common/uncommon/rare/epic/legendary）
        attack_bonus: 攻击力加成值
        crit_rate_bonus: 暴击率加成百分比
        special_effect: 特殊效果描述文本
        special_effect_data: 特殊效果结构化数据（JSON格式）
        icon_path: 武器图标文件路径
        price: 商店售价
        is_ai_generated: 是否为AI生成的武器
        ai_generation_id: 关联的AI生成记录ID
        created_at: 记录创建时间
    """

    # 表名
    __tablename__ = "weapons"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="武器ID"
    )

    # 武器名称
    name = Column(
        String(100),
        nullable=False,
        comment="武器名称"
    )

    # 武器描述
    description = Column(
        Text,
        nullable=True,
        comment="武器描述"
    )

    # 武器类型
    weapon_type = Column(
        SAEnum(
            'sword', 'axe', 'bow', 'staff', 'dagger', 'spear', 'hammer',
            name='weapon_type_enum'
        ),
        nullable=False,
        comment="武器类型"
    )

    # 稀有度
    rarity = Column(
        SAEnum(
            'common', 'uncommon', 'rare', 'epic', 'legendary',
            name='rarity_enum'
        ),
        default='common',
        comment="稀有度"
    )

    # 攻击力加成
    attack_bonus = Column(
        Integer,
        default=0,
        comment="攻击力加成"
    )

    # 暴击率加成（百分比）
    crit_rate_bonus = Column(
        Numeric(5, 2),
        default=0.00,
        comment="暴击率加成"
    )

    # 特殊效果描述
    special_effect = Column(
        Text,
        nullable=True,
        comment="特殊效果"
    )

    # 特殊效果数据（JSON格式）
    special_effect_data = Column(
        JSON,
        nullable=True,
        comment="特殊效果数据"
    )

    # 武器图标路径
    icon_path = Column(
        String(255),
        nullable=True,
        comment="图标路径"
    )

    # 武器价格
    price = Column(
        Integer,
        default=0,
        comment="武器价格"
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
        Index("idx_weapon_type", "weapon_type"),
        Index("idx_rarity", "rarity"),
        Index("idx_is_ai_generated", "is_ai_generated"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回武器对象的字符串表示"""
        return (
            f"<Weapon(id={self.id}, name='{self.name}', "
            f"type='{self.weapon_type}', rarity='{self.rarity}')>"
        )

    def to_dict(self) -> dict:
        """
        将武器对象转换为字典

        Returns:
            dict: 武器信息字典
        """
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "weapon_type": self.weapon_type,
            "rarity": self.rarity,
            "attack_bonus": self.attack_bonus,
            "crit_rate_bonus": float(self.crit_rate_bonus) if self.crit_rate_bonus else None,
            "special_effect": self.special_effect,
            "special_effect_data": self.special_effect_data,
            "icon_path": self.icon_path,
            "price": self.price,
            "is_ai_generated": self.is_ai_generated,
            "ai_generation_id": self.ai_generation_id,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
