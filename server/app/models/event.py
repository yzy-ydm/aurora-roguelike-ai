"""
事件数据模型

本模块定义 events 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 事件ID（主键，自增）
- name: 事件名称
- description: 事件描述
- event_type: 事件类型（treasure, trap, merchant, npc, mystery, rest, combat）
- trigger_rate: 触发概率（%）
- min_floor: 最小层数
- max_floor: 最大层数
- effect_data: 效果数据（JSON）
- option1_text: 选项1文本
- option1_effect: 选项1效果（JSON）
- option2_text: 选项2文本
- option2_effect: 选项2效果（JSON）
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
    Numeric,
    Index,
    Enum as SAEnum
)
from sqlalchemy.sql import func

from app.database.connection import Base


class Event(Base):
    """
    事件模型类

    映射到数据库 events 表，存储Roguelike随机事件数据。

    Attributes:
        id: 事件唯一标识（主键）
        name: 事件名称
        description: 事件描述文本
        event_type: 事件类型（treasure/trap/merchant/npc/mystery/rest/combat）
        trigger_rate: 触发概率百分比
        min_floor: 最小触发层数
        max_floor: 最大触发层数
        effect_data: 事件效果数据（JSON格式）
        option1_text: 选项1文本
        option1_effect: 选项1效果数据（JSON格式）
        option2_text: 选项2文本
        option2_effect: 选项2效果数据（JSON格式）
        is_ai_generated: 是否为AI生成的事件
        created_at: 记录创建时间
    """

    # 表名
    __tablename__ = "events"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="事件ID"
    )

    # 事件名称
    name = Column(
        String(100),
        nullable=False,
        comment="事件名称"
    )

    # 事件描述
    description = Column(
        Text,
        nullable=False,
        comment="事件描述"
    )

    # 事件类型
    event_type = Column(
        SAEnum(
            'treasure', 'trap', 'merchant', 'npc', 'mystery', 'rest', 'combat',
            name='event_type_enum'
        ),
        nullable=False,
        comment="事件类型"
    )

    # 触发概率（百分比）
    trigger_rate = Column(
        Numeric(5, 2),
        default=10.00,
        comment="触发概率"
    )

    # 最小触发层数
    min_floor = Column(
        Integer,
        default=1,
        comment="最小触发层数"
    )

    # 最大触发层数
    max_floor = Column(
        Integer,
        default=999,
        comment="最大触发层数"
    )

    # 效果数据（JSON格式）
    effect_data = Column(
        JSON,
        nullable=True,
        comment="效果数据"
    )

    # 选项1文本
    option1_text = Column(
        String(200),
        nullable=True,
        comment="选项1文本"
    )

    # 选项1效果（JSON格式）
    option1_effect = Column(
        JSON,
        nullable=True,
        comment="选项1效果"
    )

    # 选项2文本
    option2_text = Column(
        String(200),
        nullable=True,
        comment="选项2文本"
    )

    # 选项2效果（JSON格式）
    option2_effect = Column(
        JSON,
        nullable=True,
        comment="选项2效果"
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
        Index("idx_event_type", "event_type"),
        Index("idx_trigger_floor", "min_floor", "max_floor"),
        Index("idx_is_active", "is_ai_generated"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回事件对象的字符串表示"""
        return (
            f"<Event(id={self.id}, name='{self.name}', "
            f"type='{self.event_type}')>"
        )

    def to_dict(self) -> dict:
        """
        将事件对象转换为字典

        Returns:
            dict: 事件信息字典
        """
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "event_type": self.event_type,
            "trigger_rate": float(self.trigger_rate) if self.trigger_rate else None,
            "min_floor": self.min_floor,
            "max_floor": self.max_floor,
            "effect_data": self.effect_data,
            "option1_text": self.option1_text,
            "option1_effect": self.option1_effect,
            "option2_text": self.option2_text,
            "option2_effect": self.option2_effect,
            "is_ai_generated": self.is_ai_generated,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
