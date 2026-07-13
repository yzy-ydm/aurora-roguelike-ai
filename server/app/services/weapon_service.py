"""
武器服务模块

本模块提供武器相关的业务逻辑，包括：
- 获取武器列表
- 获取武器详情
- 查询玩家武器
- 添加玩家武器

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
"""

from typing import Optional, Tuple, List

from sqlalchemy.orm import Session

from app.models.weapon import Weapon
from app.models.player_weapon import PlayerWeapon
from app.models.player_profile import PlayerProfile
from app.schemas.weapon import (
    WeaponResponse,
    PlayerWeaponResponse,
    AddPlayerWeaponRequest
)


class WeaponService:
    """
    武器服务类

    提供武器相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def get_weapons(db: Session = Depends(get_db)):
            service = WeaponService(db)
            return service.get_all_weapons()
    """

    def __init__(self, db: Session):
        """
        初始化武器服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def get_all_weapons(self) -> List[WeaponResponse]:
        """
        获取所有武器列表

        查询weapons表中的所有武器数据。

        Returns:
            List[WeaponResponse]: 武器列表

        示例:
            >>> service = WeaponService(db)
            >>> weapons = service.get_all_weapons()
        """
        weapons = self.db.query(Weapon).all()
        return [self._to_weapon_response(w) for w in weapons]

    def get_weapon_by_id(self, weapon_id: int) -> Tuple[bool, str, Optional[WeaponResponse]]:
        """
        根据ID获取武器详情

        Args:
            weapon_id: 武器ID

        Returns:
            Tuple[bool, str, Optional[WeaponResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[WeaponResponse]: 武器信息（成功时）

        示例:
            >>> service = WeaponService(db)
            >>> success, msg, weapon = service.get_weapon_by_id(1)
        """
        weapon = self.db.query(Weapon).filter(
            Weapon.id == weapon_id
        ).first()

        if not weapon:
            return False, "武器不存在", None

        return True, "查询成功", self._to_weapon_response(weapon)

    def get_player_weapons(
        self,
        user_id: int
    ) -> Tuple[bool, str, Optional[List[PlayerWeaponResponse]]]:
        """
        查询玩家拥有的所有武器

        流程：
        1. 根据user_id查询player_profiles获取player_id
        2. 根据player_id查询player_weapons
        3. 关联查询weapons表获取武器详情

        Args:
            user_id: 用户ID（从JWT Token中获取）

        Returns:
            Tuple[bool, str, Optional[List[PlayerWeaponResponse]]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[List[PlayerWeaponResponse]]: 玩家武器列表（成功时）

        示例:
            >>> service = WeaponService(db)
            >>> success, msg, weapons = service.get_player_weapons(user_id=1)
        """
        # 1. 查询玩家档案
        player = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        if not player:
            return False, "玩家角色不存在", None

        # 2. 查询玩家武器
        player_weapons = self.db.query(PlayerWeapon).filter(
            PlayerWeapon.player_id == player.id
        ).all()

        # 3. 构建响应
        result = []
        for pw in player_weapons:
            weapon = self.db.query(Weapon).filter(
                Weapon.id == pw.weapon_id
            ).first()

            if weapon:
                weapon_response = self._to_weapon_response(weapon)
                player_weapon_response = PlayerWeaponResponse(
                    id=pw.id,
                    player_id=pw.player_id,
                    weapon_id=pw.weapon_id,
                    is_equipped=pw.is_equipped,
                    created_at=pw.created_at,
                    weapon=weapon_response
                )
                result.append(player_weapon_response)

        return True, "查询成功", result

    def add_player_weapon(
        self,
        user_id: int,
        request: AddPlayerWeaponRequest
    ) -> Tuple[bool, str, Optional[PlayerWeaponResponse]]:
        """
        为玩家添加武器

        流程：
        1. 验证玩家存在
        2. 验证武器存在
        3. 创建player_weapon记录

        Args:
            user_id: 用户ID（从JWT Token中获取）
            request: 添加武器请求（包含weapon_id）

        Returns:
            Tuple[bool, str, Optional[PlayerWeaponResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[PlayerWeaponResponse]: 添加的武器信息（成功时）

        示例:
            >>> service = WeaponService(db)
            >>> success, msg, weapon = service.add_player_weapon(
            ...     user_id=1,
            ...     request=AddPlayerWeaponRequest(weapon_id=1)
            ... )
        """
        # 1. 查询玩家档案
        player = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        if not player:
            return False, "玩家角色不存在", None

        # 2. 验证武器存在
        weapon = self.db.query(Weapon).filter(
            Weapon.id == request.weapon_id
        ).first()

        if not weapon:
            return False, "武器不存在", None

        # 3. 创建player_weapon记录
        player_weapon = PlayerWeapon(
            player_id=player.id,
            weapon_id=request.weapon_id,
            is_equipped=0
        )

        self.db.add(player_weapon)
        self.db.commit()
        self.db.refresh(player_weapon)

        # 4. 构建响应
        weapon_response = self._to_weapon_response(weapon)
        result = PlayerWeaponResponse(
            id=player_weapon.id,
            player_id=player_weapon.player_id,
            weapon_id=player_weapon.weapon_id,
            is_equipped=player_weapon.is_equipped,
            created_at=player_weapon.created_at,
            weapon=weapon_response
        )

        return True, "武器添加成功", result

    def _to_weapon_response(self, weapon: Weapon) -> WeaponResponse:
        """
        将ORM模型转换为响应Schema

        处理字段映射：
        - weapon_type → type
        - attack_bonus → damage
        - special_effect_data → attributes

        Args:
            weapon: 武器ORM对象

        Returns:
            WeaponResponse: 武器响应对象
        """
        return WeaponResponse(
            id=weapon.id,
            name=weapon.name,
            description=weapon.description,
            type=weapon.weapon_type,  # weapon_type → type
            rarity=weapon.rarity,
            damage=weapon.attack_bonus,  # attack_bonus → damage
            crit_rate_bonus=float(weapon.crit_rate_bonus) if weapon.crit_rate_bonus else 0.0,
            special_effect=weapon.special_effect,
            attributes=weapon.special_effect_data,  # special_effect_data → attributes
            icon_path=weapon.icon_path,
            price=weapon.price
        )
