"""
地图数据模型

本模块定义 maps 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 地图ID（主键，自增）
- name: 地图名称
- description: 地图描述
- theme: 地图主题（dungeon, cave, castle, forest, volcano, ice）
- floor_level: 层数
- width: 宽度
- height: 高度
- room_count: 房间数
- room_data: 房间数据（JSON）
- monster_spawn_config: 怪物生成配置（JSON）
- event_spawn_config: 事件生成配置（JSON）
- difficulty: 难度等级
- is_ai_generated: 是否AI生成
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


class Map(Base):
    """
    地图模型类

    映射到数据库 maps 表，存储Roguelike地图配置数据。

    Attributes:
        id: 地图唯一标识（主键）
        name: 地图名称
        description: 地图描述文本
        theme: 地图主题（dungeon/cave/castle/forest/volcano/ice）
        floor_level: 对应层数
        width: 地图宽度（格子数）
        height: 地图高度（格子数）
        room_count: 房间数量
        room_data: 房间布局数据（JSON格式）
        monster_spawn_config: 怪物生成配置（JSON格式）
        event_spawn_config: 事件生成配置（JSON格式）
        difficulty: 难度等级
        is_ai_generated: 是否为AI生成的地图
        created_at: 记录创建时间
    """

    # 表名
    __tablename__ = "maps"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="地图ID"
    )

    # 地图名称
    name = Column(
        String(100),
        nullable=False,
        comment="地图名称"
    )

    # 地图描述
    description = Column(
        Text,
        nullable=True,
        comment="地图描述"
    )

    # 地图主题
    theme = Column(
        SAEnum(
            'dungeon', 'cave', 'castle', 'forest', 'volcano', 'ice',
            name='map_theme_enum'
        ),
        default='dungeon',
        comment="地图主题"
    )

    # 层数
    floor_level = Column(
        Integer,
        nullable=False,
        comment="层数"
    )

    # 宽度
    width = Column(
        Integer,
        default=20,
        comment="地图宽度"
    )

    # 高度
    height = Column(
        Integer,
        default=15,
        comment="地图高度"
    )

    # 房间数
    room_count = Column(
        Integer,
        default=8,
        comment="房间数量"
    )

    # 房间数据（JSON格式）
    room_data = Column(
        JSON,
        nullable=True,
        comment="房间数据"
    )

    # 怪物生成配置（JSON格式）
    monster_spawn_config = Column(
        JSON,
        nullable=True,
        comment="怪物生成配置"
    )

    # 事件生成配置（JSON格式）
    event_spawn_config = Column(
        JSON,
        nullable=True,
        comment="事件生成配置"
    )

    # 难度等级
    difficulty = Column(
        Integer,
        default=1,
        comment="难度等级"
    )

    # 是否为AI生成的内容
    is_ai_generated = Column(
        Integer,
        default=0,
        comment="是否AI生成"
    )

    # 创建时间
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="创建时间"
    )

    # ==================== 索引定义 ====================
    __table_args__ = (
        Index("idx_floor_level", "floor_level"),
        Index("idx_theme", "theme"),
        Index("idx_difficulty", "difficulty"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回地图对象的字符串表示"""
        return (
            f"<Map(id={self.id}, name='{self.name}', "
            f"theme='{self.theme}', floor={self.floor_level})>"
        )

    def to_dict(self) -> dict:
        """
        将地图对象转换为字典

        Returns:
            dict: 地图信息字典
        """
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "theme": self.theme,
            "floor_level": self.floor_level,
            "width": self.width,
            "height": self.height,
            "room_count": self.room_count,
            "room_data": self.room_data,
            "monster_spawn_config": self.monster_spawn_config,
            "event_spawn_config": self.event_spawn_config,
            "difficulty": self.difficulty,
            "is_ai_generated": self.is_ai_generated,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
