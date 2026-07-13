"""
玩家角色数据模型

本模块定义 player_profiles 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 档案ID（主键，自增）
- user_id: 关联用户ID（唯一，外键）
- nickname: 角色昵称
- level: 角色等级
- experience: 当前经验值
- experience_to_next_level: 升级所需经验
- max_health: 最大生命值
- current_health: 当前生命值
- attack: 基础攻击力
- defense: 基础防御力
- crit_rate: 暴击率
- gold: 金币数量
- total_play_time: 总游戏时长（秒）
- max_floor_reached: 最高到达层数
- total_kills: 击杀怪物总数
- death_count: 死亡次数
- created_at: 创建时间
- updated_at: 更新时间

表关系：
- user_id → users.id (1:1, CASCADE)
"""

from datetime import datetime

from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    ForeignKey,
    Index,
    UniqueConstraint,
    Numeric
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database.connection import Base


class PlayerProfile(Base):
    """
    玩家角色模型类

    映射到数据库 player_profiles 表，存储玩家游戏角色属性和统计数据。

    每个用户只能有一个角色档案（UNIQUE约束 on user_id）。

    Attributes:
        id: 档案唯一标识（主键）
        user_id: 关联的用户ID（外键，唯一）
        nickname: 角色昵称
        level: 角色等级（默认1）
        experience: 当前经验值（默认0）
        experience_to_next_level: 升级所需经验（默认100）
        max_health: 最大生命值（默认100）
        current_health: 当前生命值（默认100）
        attack: 基础攻击力（默认10）
        defense: 基础防御力（默认5）
        crit_rate: 暴击率百分比（默认5.00）
        gold: 金币数量（默认0）
        total_play_time: 总游戏时长，单位秒（默认0）
        max_floor_reached: 最高到达层数（默认1）
        total_kills: 击杀怪物总数（默认0）
        death_count: 死亡次数（默认0）
        created_at: 记录创建时间
        updated_at: 记录最后更新时间
    """

    # 表名
    __tablename__ = "player_profiles"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="档案ID"
    )

    # 关联用户ID，唯一（每个用户只能有一个角色）
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        comment="用户ID"
    )

    # 角色昵称
    nickname = Column(
        String(50),
        nullable=False,
        comment="角色昵称"
    )

    # 角色等级
    level = Column(
        Integer,
        default=1,
        comment="角色等级"
    )

    # 当前经验值
    experience = Column(
        Integer,
        default=0,
        comment="当前经验"
    )

    # 升级所需经验
    experience_to_next_level = Column(
        Integer,
        default=100,
        comment="升级所需经验"
    )

    # 最大生命值
    max_health = Column(
        Integer,
        default=100,
        comment="最大生命值"
    )

    # 当前生命值
    current_health = Column(
        Integer,
        default=100,
        comment="当前生命值"
    )

    # 基础攻击力
    attack = Column(
        Integer,
        default=10,
        comment="基础攻击力"
    )

    # 基础防御力
    defense = Column(
        Integer,
        default=5,
        comment="基础防御力"
    )

    # 暴击率（百分比）
    crit_rate = Column(
        Numeric(5, 2),
        default=5.00,
        comment="暴击率"
    )

    # 金币数量
    gold = Column(
        Integer,
        default=0,
        comment="金币数量"
    )

    # 总游戏时长（秒）
    total_play_time = Column(
        Integer,
        default=0,
        comment="总游戏时长(秒)"
    )

    # 最高到达层数
    max_floor_reached = Column(
        Integer,
        default=1,
        comment="最高到达层数"
    )

    # 击杀怪物总数
    total_kills = Column(
        Integer,
        default=0,
        comment="击杀怪物总数"
    )

    # 死亡次数
    death_count = Column(
        Integer,
        default=0,
        comment="死亡次数"
    )

    # 创建时间，自动填充
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="创建时间"
    )

    # 更新时间，自动更新
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )

    # ==================== 关系定义 ====================

    # 与 users 表的关联关系（多对一，虽然逻辑上是1:1）
    user = relationship(
        "User",
        backref="player_profile",
        lazy="select"
    )

    # ==================== 约束和索引 ====================
    __table_args__ = (
        # 唯一约束：每个用户只能有一个角色档案
        UniqueConstraint("user_id", name="uk_user_id"),
        # 索引
        Index("idx_level", "level"),
        Index("idx_nickname", "nickname"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回玩家角色对象的字符串表示"""
        return (
            f"<PlayerProfile(id={self.id}, user_id={self.user_id}, "
            f"nickname='{self.nickname}', level={self.level})>"
        )

    def to_dict(self) -> dict:
        """
        将玩家角色对象转换为字典

        Returns:
            dict: 玩家角色信息字典
        """
        return {
            "id": self.id,
            "user_id": self.user_id,
            "nickname": self.nickname,
            "level": self.level,
            "experience": self.experience,
            "experience_to_next_level": self.experience_to_next_level,
            "max_health": self.max_health,
            "current_health": self.current_health,
            "attack": self.attack,
            "defense": self.defense,
            "crit_rate": float(self.crit_rate) if self.crit_rate else None,
            "gold": self.gold,
            "total_play_time": self.total_play_time,
            "max_floor_reached": self.max_floor_reached,
            "total_kills": self.total_kills,
            "death_count": self.death_count,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
