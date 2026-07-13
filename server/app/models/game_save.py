"""
游戏存档数据模型

本模块定义 game_saves 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 存档ID（主键，自增）
- user_id: 关联用户ID（外键，关联users表）
- save_name: 存档名称
- current_floor: 当前层数
- player_state: 玩家状态数据（JSON）
- inventory_data: 背包数据（JSON）
- current_map_data: 当前地图数据（JSON）
- explored_maps: 已探索地图历史（JSON）
- play_time: 游戏时长（秒）
- kill_count: 击杀怪物数
- gold_collected: 收集金币总数
- slot_number: 存档槽位（1-3）
- is_active: 是否活跃存档
- created_at: 创建时间
- updated_at: 更新时间

表关系：
- user_id → users.id (N:1, CASCADE)
"""

from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    ForeignKey,
    JSON,
    Index,
    UniqueConstraint,
    SmallInteger
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database.connection import Base


class GameSave(Base):
    """
    游戏存档模型类

    映射到数据库 game_saves 表，存储玩家游戏进度存档。

    每个用户每个槽位只能有一个存档（UNIQUE约束 on user_id + slot_number）。

    Attributes:
        id: 存档唯一标识（主键）
        user_id: 关联的用户ID
        save_name: 存档名称
        current_floor: 当前层数
        player_state: 玩家状态数据（JSON格式）
        inventory_data: 背包数据（JSON格式）
        current_map_data: 当前地图数据（JSON格式）
        explored_maps: 已探索地图历史（JSON格式）
        play_time: 游戏时长，单位秒
        kill_count: 击杀怪物数
        gold_collected: 收集金币总数
        slot_number: 存档槽位（1-3）
        is_active: 是否活跃存档
        created_at: 记录创建时间
        updated_at: 记录最后更新时间
    """

    # 表名
    __tablename__ = "game_saves"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="存档ID"
    )

    # 关联用户ID
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        comment="用户ID"
    )

    # 存档名称
    save_name = Column(
        String(100),
        nullable=False,
        comment="存档名称"
    )

    # 当前层数
    current_floor = Column(
        Integer,
        default=1,
        comment="当前层数"
    )

    # 玩家状态数据（JSON格式）
    player_state = Column(
        JSON,
        nullable=False,
        comment="玩家状态数据"
    )

    # 背包数据（JSON格式）
    inventory_data = Column(
        JSON,
        nullable=True,
        comment="背包数据"
    )

    # 当前地图数据（JSON格式）
    current_map_data = Column(
        JSON,
        nullable=True,
        comment="当前地图数据"
    )

    # 已探索地图历史（JSON格式）
    explored_maps = Column(
        JSON,
        nullable=True,
        comment="已探索地图"
    )

    # 游戏时长（秒）
    play_time = Column(
        Integer,
        default=0,
        comment="游戏时长(秒)"
    )

    # 击杀怪物数
    kill_count = Column(
        Integer,
        default=0,
        comment="击杀怪物数"
    )

    # 收集金币总数
    gold_collected = Column(
        Integer,
        default=0,
        comment="收集金币总数"
    )

    # 存档槽位（1-3）
    slot_number = Column(
        SmallInteger,
        nullable=False,
        comment="存档槽位"
    )

    # 是否为当前活跃存档
    is_active = Column(
        Integer,
        default=1,
        comment="是否活跃存档"
    )

    # 创建时间
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="创建时间"
    )

    # 更新时间
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )

    # ==================== 关系定义 ====================

    # 与 users 表的关联关系
    user = relationship(
        "User",
        backref="game_saves",
        lazy="select"
    )

    # ==================== 约束和索引 ====================
    __table_args__ = (
        # 唯一约束：每个用户每个槽位只能有一个存档
        UniqueConstraint("user_id", "slot_number", name="uk_user_slot"),
        # 索引
        Index("idx_user_id", "user_id"),
        Index("idx_current_floor", "current_floor"),
        Index("idx_is_active", "is_active"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回游戏存档对象的字符串表示"""
        return (
            f"<GameSave(id={self.id}, user_id={self.user_id}, "
            f"name='{self.save_name}', slot={self.slot_number})>"
        )

    def to_dict(self) -> dict:
        """
        将游戏存档对象转换为字典

        Returns:
            dict: 游戏存档信息字典
        """
        return {
            "id": self.id,
            "user_id": self.user_id,
            "save_name": self.save_name,
            "current_floor": self.current_floor,
            "player_state": self.player_state,
            "inventory_data": self.inventory_data,
            "current_map_data": self.current_map_data,
            "explored_maps": self.explored_maps,
            "play_time": self.play_time,
            "kill_count": self.kill_count,
            "gold_collected": self.gold_collected,
            "slot_number": self.slot_number,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
