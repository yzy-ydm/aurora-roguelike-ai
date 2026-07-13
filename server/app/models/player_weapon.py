"""
玩家武器关联数据模型

本模块定义 player_weapons 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 记录ID（主键，自增）
- player_id: 玩家档案ID（外键，关联player_profiles表）
- weapon_id: 武器ID（外键，关联weapons表）
- is_equipped: 是否装备中
- created_at: 获取时间

表关系：
- player_id → player_profiles.id (N:1, CASCADE)
- weapon_id → weapons.id (N:1, CASCADE)
"""

from sqlalchemy import (
    Column,
    Integer,
    DateTime,
    ForeignKey,
    Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database.connection import Base


class PlayerWeapon(Base):
    """
    玩家武器关联模型类

    映射到数据库 player_weapons 表，记录玩家拥有哪些武器。

    一个玩家可以拥有多把武器，一把武器可以被多个玩家拥有。

    Attributes:
        id: 记录唯一标识（主键）
        player_id: 关联的玩家档案ID
        weapon_id: 关联的武器ID
        is_equipped: 是否装备中（0-未装备，1-已装备）
        created_at: 获取武器的时间
    """

    # 表名
    __tablename__ = "player_weapons"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="记录ID"
    )

    # 玩家档案ID
    player_id = Column(
        Integer,
        ForeignKey("player_profiles.id", ondelete="CASCADE"),
        nullable=False,
        comment="玩家档案ID"
    )

    # 武器ID
    weapon_id = Column(
        Integer,
        ForeignKey("weapons.id", ondelete="CASCADE"),
        nullable=False,
        comment="武器ID"
    )

    # 是否装备中
    is_equipped = Column(
        Integer,
        default=0,
        comment="是否装备中"
    )

    # 获取时间
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="获取时间"
    )

    # ==================== 关系定义 ====================

    # 与 player_profiles 表的关联关系
    player = relationship(
        "PlayerProfile",
        backref="player_weapons",
        lazy="select"
    )

    # 与 weapons 表的关联关系
    weapon = relationship(
        "Weapon",
        backref="player_weapons",
        lazy="select"
    )

    # ==================== 索引定义 ====================
    __table_args__ = (
        Index("idx_player_id", "player_id"),
        Index("idx_weapon_id", "weapon_id"),
        Index("idx_is_equipped", "is_equipped"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回玩家武器关联对象的字符串表示"""
        return (
            f"<PlayerWeapon(id={self.id}, player_id={self.player_id}, "
            f"weapon_id={self.weapon_id}, equipped={self.is_equipped})>"
        )

    def to_dict(self) -> dict:
        """
        将玩家武器关联对象转换为字典

        Returns:
            dict: 玩家武器关联信息字典
        """
        return {
            "id": self.id,
            "player_id": self.player_id,
            "weapon_id": self.weapon_id,
            "is_equipped": self.is_equipped,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
