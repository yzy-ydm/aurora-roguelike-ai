"""
地图服务模块

本模块提供地图相关的业务逻辑，包括：
- 获取地图列表
- 获取地图详情

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
- 当前阶段只实现查询功能
"""

from typing import Optional, Tuple, List

from sqlalchemy.orm import Session

from app.models.map import Map
from app.schemas.map import MapResponse


class MapService:
    """
    地图服务类

    提供地图相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def get_maps(db: Session = Depends(get_db)):
            service = MapService(db)
            return service.get_all_maps()
    """

    def __init__(self, db: Session):
        """
        初始化地图服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def get_all_maps(self) -> List[MapResponse]:
        """
        获取所有地图列表

        查询maps表中的所有地图数据。

        Returns:
            List[MapResponse]: 地图列表

        示例:
            >>> service = MapService(db)
            >>> maps = service.get_all_maps()
        """
        maps = self.db.query(Map).all()
        return [self._to_map_response(m) for m in maps]

    def get_map_by_id(self, map_id: int) -> Tuple[bool, str, Optional[MapResponse]]:
        """
        根据ID获取地图详情

        Args:
            map_id: 地图ID

        Returns:
            Tuple[bool, str, Optional[MapResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[MapResponse]: 地图信息（成功时）

        示例:
            >>> service = MapService(db)
            >>> success, msg, map_data = service.get_map_by_id(1)
        """
        map_data = self.db.query(Map).filter(
            Map.id == map_id
        ).first()

        if not map_data:
            return False, "地图不存在", None

        return True, "查询成功", self._to_map_response(map_data)

    def _to_map_response(self, map_data: Map) -> MapResponse:
        """
        将ORM模型转换为响应Schema

        处理字段映射：
        - theme → type

        Args:
            map_data: 地图ORM对象

        Returns:
            MapResponse: 地图响应对象
        """
        return MapResponse(
            id=map_data.id,
            name=map_data.name,
            description=map_data.description,
            type=map_data.theme,  # theme → type
            floor_level=map_data.floor_level,
            width=map_data.width,
            height=map_data.height,
            room_count=map_data.room_count,
            room_data=map_data.room_data,
            monster_spawn_config=map_data.monster_spawn_config,
            event_spawn_config=map_data.event_spawn_config,
            difficulty=map_data.difficulty
        )
