"""
怪物服务模块

本模块提供怪物相关的业务逻辑，包括：
- 获取怪物列表
- 获取怪物详情

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
- 当前阶段只实现查询功能
"""

from typing import Optional, Tuple, List

from sqlalchemy.orm import Session

from app.models.monster import Monster
from app.schemas.monster import MonsterResponse


class MonsterService:
    """
    怪物服务类

    提供怪物相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def get_monsters(db: Session = Depends(get_db)):
            service = MonsterService(db)
            return service.get_all_monsters()
    """

    def __init__(self, db: Session):
        """
        初始化怪物服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def get_all_monsters(self) -> List[MonsterResponse]:
        """
        获取所有怪物列表

        查询monsters表中的所有怪物数据。

        Returns:
            List[MonsterResponse]: 怪物列表

        示例:
            >>> service = MonsterService(db)
            >>> monsters = service.get_all_monsters()
        """
        monsters = self.db.query(Monster).all()
        return [self._to_monster_response(m) for m in monsters]

    def get_monster_by_id(self, monster_id: int) -> Tuple[bool, str, Optional[MonsterResponse]]:
        """
        根据ID获取怪物详情

        Args:
            monster_id: 怪物ID

        Returns:
            Tuple[bool, str, Optional[MonsterResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[MonsterResponse]: 怪物信息（成功时）

        示例:
            >>> service = MonsterService(db)
            >>> success, msg, monster = service.get_monster_by_id(1)
        """
        monster = self.db.query(Monster).filter(
            Monster.id == monster_id
        ).first()

        if not monster:
            return False, "怪物不存在", None

        return True, "查询成功", self._to_monster_response(monster)

    def _to_monster_response(self, monster: Monster) -> MonsterResponse:
        """
        将ORM模型转换为响应Schema

        处理字段映射：
        - monster_type → type
        - special_ability_data → attributes

        Args:
            monster: 怪物ORM对象

        Returns:
            MonsterResponse: 怪物响应对象
        """
        return MonsterResponse(
            id=monster.id,
            name=monster.name,
            description=monster.description,
            type=monster.monster_type,  # monster_type → type
            level=monster.level,
            health=monster.health,
            attack=monster.attack,
            defense=monster.defense,
            speed=monster.speed,
            experience_reward=monster.experience_reward,
            gold_reward=monster.gold_reward,
            special_ability=monster.special_ability,
            attributes=monster.special_ability_data,  # special_ability_data → attributes
            icon_path=monster.icon_path,
            min_floor=monster.min_floor,
            max_floor=monster.max_floor
        )
