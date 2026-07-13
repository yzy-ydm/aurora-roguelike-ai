"""
玩家角色服务模块

本模块提供玩家角色相关的业务逻辑，包括：
- 创建玩家角色
- 查询玩家角色信息
- 更新玩家角色信息

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
"""

from typing import Optional, Tuple

from sqlalchemy.orm import Session

from app.models.player_profile import PlayerProfile
from app.schemas.player import PlayerCreate, PlayerUpdate, PlayerResponse


class PlayerService:
    """
    玩家角色服务类

    提供玩家角色相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def create_profile(user_id: int, data: PlayerCreate, db: Session = Depends(get_db)):
            service = PlayerService(db)
            return service.create_player(user_id, data)
    """

    def __init__(self, db: Session):
        """
        初始化玩家角色服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def create_player(
        self,
        user_id: int,
        player_data: PlayerCreate
    ) -> Tuple[bool, str, Optional[PlayerResponse]]:
        """
        创建玩家角色

        流程：
        1. 检查该用户是否已有角色档案
        2. 创建新的角色档案（使用数据库默认属性值）
        3. 返回玩家角色信息

        Args:
            user_id: 用户ID（从JWT Token中获取）
            player_data: 创建角色数据（角色昵称）

        Returns:
            Tuple[bool, str, Optional[PlayerResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[PlayerResponse]: 玩家角色信息（成功时）

        示例:
            >>> service = PlayerService(db)
            >>> success, msg, player = service.create_player(
            ...     user_id=1,
            ...     player_data=PlayerCreate(nickname="冒险者")
            ... )
        """
        # 1. 检查该用户是否已有角色档案
        existing_profile = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        if existing_profile:
            return False, "该用户已有角色档案", None

        # 2. 创建新的角色档案
        new_profile = PlayerProfile(
            user_id=user_id,
            nickname=player_data.nickname
            # 其他字段使用数据库默认值：
            # level=1, experience=0, max_health=100, current_health=100,
            # attack=10, defense=5, gold=0, etc.
        )

        # 添加到数据库
        self.db.add(new_profile)
        self.db.commit()
        self.db.refresh(new_profile)  # 刷新以获取自增ID等

        # 3. 构建返回的玩家角色信息
        player_response = self._to_response(new_profile)

        return True, "角色创建成功", player_response

    def get_player_profile(
        self,
        user_id: int
    ) -> Tuple[bool, str, Optional[PlayerResponse]]:
        """
        查询玩家角色信息

        流程：
        1. 根据user_id查询player_profiles表
        2. 返回玩家角色信息

        Args:
            user_id: 用户ID（从JWT Token中获取）

        Returns:
            Tuple[bool, str, Optional[PlayerResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[PlayerResponse]: 玩家角色信息（成功时）

        示例:
            >>> service = PlayerService(db)
            >>> success, msg, player = service.get_player_profile(user_id=1)
        """
        # 1. 根据user_id查询角色档案
        profile = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        # 角色不存在
        if not profile:
            return False, "玩家角色不存在", None

        # 2. 构建返回的玩家角色信息
        player_response = self._to_response(profile)

        return True, "查询成功", player_response

    def update_player_profile(
        self,
        user_id: int,
        update_data: PlayerUpdate
    ) -> Tuple[bool, str, Optional[PlayerResponse]]:
        """
        更新玩家角色信息

        允许修改：角色昵称
        禁止修改：level, experience, attack, defense, gold 等核心属性
        （这些数据未来由服务器游戏逻辑控制）

        流程：
        1. 根据user_id查询player_profiles表
        2. 更新允许修改的字段
        3. 返回更新后的玩家角色信息

        Args:
            user_id: 用户ID（从JWT Token中获取）
            update_data: 更新数据（角色昵称）

        Returns:
            Tuple[bool, str, Optional[PlayerResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[PlayerResponse]: 更新后的玩家角色信息（成功时）

        示例:
            >>> service = PlayerService(db)
            >>> success, msg, player = service.update_player_profile(
            ...     user_id=1,
            ...     update_data=PlayerUpdate(nickname="新昵称")
            ... )
        """
        # 1. 根据user_id查询角色档案
        profile = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        # 角色不存在
        if not profile:
            return False, "玩家角色不存在", None

        # 2. 更新允许修改的字段
        updated = False

        if update_data.nickname is not None:
            profile.nickname = update_data.nickname
            updated = True

        # 如果没有任何更新
        if not updated:
            return False, "未提供有效的更新数据", None

        # 提交到数据库
        self.db.commit()
        self.db.refresh(profile)

        # 3. 构建返回的玩家角色信息
        player_response = self._to_response(profile)

        return True, "角色信息更新成功", player_response

    def _to_response(self, profile: PlayerProfile) -> PlayerResponse:
        """
        将ORM模型转换为响应Schema

        处理字段映射：
        - 数据库 current_health → API health

        Args:
            profile: 玩家角色ORM对象

        Returns:
            PlayerResponse: 玩家角色响应对象
        """
        return PlayerResponse(
            id=profile.id,
            user_id=profile.user_id,
            nickname=profile.nickname,
            level=profile.level,
            experience=profile.experience,
            health=profile.current_health,  # current_health → health
            max_health=profile.max_health,
            attack=profile.attack,
            defense=profile.defense,
            gold=profile.gold
        )
