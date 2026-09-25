"""
游戏存档服务模块

本模块提供游戏存档相关的业务逻辑，包括：
- 创建游戏存档
- 查询游戏存档
- 更新游戏存档

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
- 只负责游戏状态持久化，不负责玩家核心属性修改
"""

from typing import Optional, Tuple, List

from sqlalchemy.orm import Session

from app.models.game_save import GameSave
from app.schemas.save import SaveCreate, SaveUpdate, SaveResponse


class SaveService:
    """
    游戏存档服务类

    提供游戏存档相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def create_save(data: SaveCreate, db: Session = Depends(get_db)):
            service = SaveService(db)
            return service.create_save(user_id=1, save_data=data)
    """

    def __init__(self, db: Session):
        """
        初始化游戏存档服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def create_save(
        self,
        user_id: int,
        save_data: SaveCreate
    ) -> Tuple[bool, str, Optional[SaveResponse]]:
        """
        创建游戏存档

        流程：
        1. 检查该用户该槽位是否已有存档
        2. 创建新的游戏存档
        3. 返回存档信息

        Args:
            user_id: 用户ID（从JWT Token中获取）
            save_data: 创建存档数据

        Returns:
            Tuple[bool, str, Optional[SaveResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[SaveResponse]: 存档信息（成功时）

        示例:
            >>> service = SaveService(db)
            >>> success, msg, save = service.create_save(
            ...     user_id=1,
            ...     save_data=SaveCreate(save_name="冒险1", slot_number=1, player_state={...})
            ... )
        """
        # 1. 检查该用户该槽位是否已有存档
        existing_save = self.db.query(GameSave).filter(
            GameSave.user_id == user_id,
            GameSave.slot_number == save_data.slot_number
        ).first()

        if existing_save:
            return False, f"槽位{save_data.slot_number}已有存档", None

        # 2. 创建新的游戏存档
        # TASK-026: 进度字段取自请求（客户端 404→POST 兜底路径已携带）；
        # 未提供时回退默认值保持兼容
        new_save = GameSave(
            user_id=user_id,
            save_name=save_data.save_name,
            slot_number=save_data.slot_number,
            player_state=save_data.player_state,
            current_floor=save_data.current_floor if save_data.current_floor is not None else 1,
            play_time=save_data.play_time if save_data.play_time is not None else 0,
            kill_count=save_data.kill_count if save_data.kill_count is not None else 0,
            gold_collected=save_data.gold_collected if save_data.gold_collected is not None else 0,
            is_active=1
        )

        # 添加到数据库
        self.db.add(new_save)
        self.db.commit()
        self.db.refresh(new_save)

        # 3. 构建返回的存档信息
        save_response = self._to_response(new_save)

        return True, "存档创建成功", save_response

    def get_user_saves(
        self,
        user_id: int
    ) -> List[SaveResponse]:
        """
        查询用户的所有游戏存档

        Args:
            user_id: 用户ID（从JWT Token中获取）

        Returns:
            List[SaveResponse]: 存档列表

        示例:
            >>> service = SaveService(db)
            >>> saves = service.get_user_saves(user_id=1)
        """
        saves = self.db.query(GameSave).filter(
            GameSave.user_id == user_id
        ).order_by(GameSave.slot_number).all()

        return [self._to_response(s) for s in saves]

    def get_save_by_slot(
        self,
        user_id: int,
        slot_number: int
    ) -> Tuple[bool, str, Optional[SaveResponse]]:
        """
        根据槽位查询游戏存档

        Args:
            user_id: 用户ID（从JWT Token中获取）
            slot_number: 存档槽位（1-3）

        Returns:
            Tuple[bool, str, Optional[SaveResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[SaveResponse]: 存档信息（成功时）

        示例:
            >>> service = SaveService(db)
            >>> success, msg, save = service.get_save_by_slot(user_id=1, slot_number=1)
        """
        save = self.db.query(GameSave).filter(
            GameSave.user_id == user_id,
            GameSave.slot_number == slot_number
        ).first()

        if not save:
            return False, f"槽位{slot_number}没有存档", None

        return True, "查询成功", self._to_response(save)

    def update_save(
        self,
        user_id: int,
        slot_number: int,
        update_data: SaveUpdate
    ) -> Tuple[bool, str, Optional[SaveResponse]]:
        """
        更新游戏存档

        允许更新：游戏进度相关字段
        禁止更新：玩家核心属性（level, attack等由player_profiles管理）

        Args:
            user_id: 用户ID（从JWT Token中获取）
            slot_number: 存档槽位（1-3）
            update_data: 更新数据

        Returns:
            Tuple[bool, str, Optional[SaveResponse]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[SaveResponse]: 更新后的存档信息（成功时）

        示例:
            >>> service = SaveService(db)
            >>> success, msg, save = service.update_save(
            ...     user_id=1,
            ...     slot_number=1,
            ...     update_data=SaveUpdate(current_floor=5, play_time=3600)
            ... )
        """
        # 1. 查询存档
        save = self.db.query(GameSave).filter(
            GameSave.user_id == user_id,
            GameSave.slot_number == slot_number
        ).first()

        if not save:
            return False, f"槽位{slot_number}没有存档", None

        # 2. 更新允许修改的字段
        updated = False

        if update_data.save_name is not None:
            save.save_name = update_data.save_name
            updated = True

        if update_data.current_floor is not None:
            save.current_floor = update_data.current_floor
            updated = True

        if update_data.player_state is not None:
            save.player_state = update_data.player_state
            updated = True

        if update_data.inventory_data is not None:
            save.inventory_data = update_data.inventory_data
            updated = True

        if update_data.current_map_data is not None:
            save.current_map_data = update_data.current_map_data
            updated = True

        if update_data.play_time is not None:
            save.play_time = update_data.play_time
            updated = True

        if update_data.kill_count is not None:
            save.kill_count = update_data.kill_count
            updated = True

        if update_data.gold_collected is not None:
            save.gold_collected = update_data.gold_collected
            updated = True

        # 如果没有任何更新
        if not updated:
            return False, "未提供有效的更新数据", None

        # 提交到数据库
        self.db.commit()
        self.db.refresh(save)

        # 3. 构建返回的存档信息
        save_response = self._to_response(save)

        return True, "存档更新成功", save_response

    def _to_response(self, save: GameSave) -> SaveResponse:
        """
        将ORM模型转换为响应Schema

        Args:
            save: 游戏存档ORM对象

        Returns:
            SaveResponse: 游戏存档响应对象
        """
        return SaveResponse(
            id=save.id,
            user_id=save.user_id,
            save_name=save.save_name,
            current_floor=save.current_floor,
            player_state=save.player_state,
            inventory_data=save.inventory_data,
            current_map_data=save.current_map_data,
            explored_maps=save.explored_maps,
            play_time=save.play_time,
            kill_count=save.kill_count,
            gold_collected=save.gold_collected,
            slot_number=save.slot_number,
            is_active=save.is_active,
            created_at=save.created_at,
            updated_at=save.updated_at
        )
