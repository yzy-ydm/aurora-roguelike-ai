"""
事件服务模块

本模块提供事件相关的业务逻辑，包括：
- 获取事件列表
- 获取事件详情

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
- 当前阶段只实现查询功能
"""

from typing import Optional, Tuple, List

from sqlalchemy.orm import Session

from app.models.event import Event
from app.schemas.event import EventResponse


class EventService:
    """
    事件服务类

    提供事件相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def get_events(db: Session = Depends(get_db)):
            service = EventService(db)
            return service.get_all_events()
    """

    def __init__(self, db: Session):
        """
        初始化事件服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def get_all_events(self) -> List[EventResponse]:
        """
        获取所有事件列表

        查询events表中的所有事件数据。

        Returns:
            List[EventResponse]: 事件列表

        示例:
            >>> service = EventService(db)
            >>> events = service.get_all_events()
        """
        events = self.db.query(Event).all()
        return [self._to_event_response(e) for e in events]

    def get_event_by_id(self, event_id: int) -> Tuple[bool, str, Optional[EventResponse]]:
        """
        根据ID获取事件详情

        Args:
            event_id: 事件ID

        Returns:
            Tuple[bool, str, Optional[EventResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[EventResponse]: 事件信息（成功时）

        示例:
            >>> service = EventService(db)
            >>> success, msg, event = service.get_event_by_id(1)
        """
        event_data = self.db.query(Event).filter(
            Event.id == event_id
        ).first()

        if not event_data:
            return False, "事件不存在", None

        return True, "查询成功", self._to_event_response(event_data)

    def _to_event_response(self, event_data: Event) -> EventResponse:
        """
        将ORM模型转换为响应Schema

        处理字段映射：
        - event_type → type

        Args:
            event_data: 事件ORM对象

        Returns:
            EventResponse: 事件响应对象
        """
        return EventResponse(
            id=event_data.id,
            name=event_data.name,
            description=event_data.description,
            type=event_data.event_type,  # event_type → type
            trigger_rate=float(event_data.trigger_rate) if event_data.trigger_rate else 10.0,
            min_floor=event_data.min_floor,
            max_floor=event_data.max_floor,
            effect_data=event_data.effect_data,
            option1_text=event_data.option1_text,
            option1_effect=event_data.option1_effect,
            option2_text=event_data.option2_text,
            option2_effect=event_data.option2_effect
        )
