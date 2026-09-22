"""
AI响应验证器

负责验证AI返回数据的格式和合法性
提供默认修复机制
"""

import json
from typing import Dict, Any, List, Optional

from logger.logger import logger
from services.monster_balance import MonsterBalanceConfig


class AIValidator:
    """
    AI响应验证器

    职责：
    - JSON合法性检查
    - 必需字段检查
    - 类型检查
    - 默认修复机制
    """

    # 楼层数据必需字段
    FLOOR_REQUIRED_FIELDS = {
        "floor": int,
        "room_count": int,
        "rooms": list
    }

    # 房间数据必需字段
    ROOM_REQUIRED_FIELDS = {
        "room_id": int,
        "room_type": str,
        "monsters": list,
        "rewards": dict
    }

    # 怪物数据必需字段
    MONSTER_REQUIRED_FIELDS = {
        "monsters": list,
        "total_count": int
    }

    # 武器数据必需字段
    WEAPON_REQUIRED_FIELDS = {
        "weapon": dict
    }

    # 武器对象必需字段
    WEAPON_OBJECT_FIELDS = {
        "name": str,
        "type": str,
        "rarity": str,
        "damage": (int, float)
    }

    # ==================== 数值范围常量 ====================
    # 基础安全阈值（绝对上限，永不突破）
    MONSTER_HP_MIN = 10
    MONSTER_HP_MAX = 1000     # 绝对安全上限：防止极端异常数据
    MONSTER_ATTACK_MIN = 1
    MONSTER_ATTACK_MAX = 100  # 绝对安全上限
    MONSTER_DEFENSE_MIN = 0
    MONSTER_DEFENSE_MAX = 50  # 绝对安全上限

    # 房间类型枚举
    VALID_ROOM_TYPES = {
        "start", "combat", "elite", "boss",
        "reward", "treasure", "shop", "event"
    }

    # 武器稀有度枚举
    VALID_RARITIES = {
        "common", "uncommon", "rare", "epic", "legendary"
    }

    def validate_floor_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        验证楼层数据

        Args:
            data: AI返回的楼层数据

        Returns:
            验证后的数据（可能已修复）

        Raises:
            ValueError: 数据无效且无法修复
        """
        if not isinstance(data, dict):
            raise ValueError(f"Floor data must be dict, got {type(data).__name__}")

        # 检查必需字段
        data = self._ensure_fields(data, self.FLOOR_REQUIRED_FIELDS, "floor")

        # 修复floor字段
        if not isinstance(data.get("floor"), int):
            data["floor"] = 1

        # 修复room_count字段
        if not isinstance(data.get("room_count"), int):
            data["room_count"] = len(data.get("rooms", []))

        # 验证rooms列表
        rooms = data.get("rooms", [])
        if not isinstance(rooms, list):
            data["rooms"] = []
            rooms = []

        # 验证每个房间
        validated_rooms = []
        for i, room in enumerate(rooms):
            if isinstance(room, dict):
                validated_room = self._validate_room(room, i)
                validated_rooms.append(validated_room)

        data["rooms"] = validated_rooms
        data["room_count"] = len(validated_rooms)

        logger.debug(f"Floor data validated: {data['room_count']} rooms")
        return data

    def validate_room_content(self, data: Dict[str, Any], floor_level: int = 1) -> Dict[str, Any]:
        """
        验证房间内容数据

        Args:
            data: AI返回的房间内容数据
            floor_level: 楼层级别（用于动态数值校验）

        Returns:
            验证后的数据
        """
        if not isinstance(data, dict):
            raise ValueError(f"Room content must be dict, got {type(data).__name__}")

        # 检查必需字段
        data = self._ensure_fields(data, self.ROOM_REQUIRED_FIELDS, "room_content")

        # 修复room_id
        if not isinstance(data.get("room_id"), int):
            data["room_id"] = 0

        # 修复room_type
        if not isinstance(data.get("room_type"), str):
            data["room_type"] = "combat"

        # 验证monsters列表并应用楼层感知校验
        monsters = data.get("monsters", [])
        if isinstance(monsters, list):
            validated_monsters = []
            for monster in monsters:
                if isinstance(monster, dict):
                    monster = self._validate_single_monster(monster, floor_level)
                    validated_monsters.append(monster)
            data["monsters"] = validated_monsters

        # 验证rewards字典
        rewards = data.get("rewards", {})
        if not isinstance(rewards, dict):
            data["rewards"] = {"count": 1, "quality": 1.0}

        logger.debug(f"Room content validated: room_id={data['room_id']}")
        return data

    def validate_monster_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        验证怪物数据

        Args:
            data: AI返回的怪物数据

        Returns:
            验证后的数据
        """
        if not isinstance(data, dict):
            raise ValueError(f"Monster data must be dict, got {type(data).__name__}")

        # 检查必需字段
        data = self._ensure_fields(data, self.MONSTER_REQUIRED_FIELDS, "monster")

        # 验证monsters列表
        monsters = data.get("monsters", [])
        if not isinstance(monsters, list):
            data["monsters"] = []
            monsters = []

        # 验证每个怪物
        validated_monsters = []
        for monster in monsters:
            if isinstance(monster, dict):
                validated_monster = self._validate_single_monster(monster)
                validated_monsters.append(validated_monster)

        data["monsters"] = validated_monsters
        data["total_count"] = len(validated_monsters)

        logger.debug(f"Monster data validated: {data['total_count']} monsters")
        return data

    def validate_weapon_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        验证武器数据

        Args:
            data: AI返回的武器数据

        Returns:
            验证后的数据
        """
        if not isinstance(data, dict):
            raise ValueError(f"Weapon data must be dict, got {type(data).__name__}")

        # 检查必需字段
        data = self._ensure_fields(data, self.WEAPON_REQUIRED_FIELDS, "weapon")

        # 验证weapon对象
        weapon = data.get("weapon", {})
        if not isinstance(weapon, dict):
            data["weapon"] = {}
            weapon = {}

        # 验证weapon字段
        weapon = self._ensure_fields(weapon, self.WEAPON_OBJECT_FIELDS, "weapon_object")

        # 修复damage类型
        if not isinstance(weapon.get("damage"), (int, float)):
            weapon["damage"] = 10

        data["weapon"] = weapon

        logger.debug(f"Weapon data validated: {weapon.get('name', 'unknown')}")
        return data

    def _validate_room(self, room: Dict[str, Any], index: int) -> Dict[str, Any]:
        """验证单个房间"""
        # 修复id
        if not isinstance(room.get("id"), int):
            room["id"] = index

        # 修复type
        if not isinstance(room.get("type"), str):
            room["type"] = "combat"
        else:
            # 验证房间类型枚举
            room["type"] = self.validate_room_type(room["type"])

        # 修复connections
        connections = room.get("connections", [])
        if not isinstance(connections, list):
            room["connections"] = []

        # 修复monsters
        monsters = room.get("monsters", [])
        if not isinstance(monsters, list):
            room["monsters"] = []
        else:
            # 验证每个怪物的属性范围
            validated_monsters = []
            for monster in monsters:
                if isinstance(monster, dict):
                    validated_monster = self._validate_single_monster(monster)
                    validated_monsters.append(validated_monster)
            room["monsters"] = validated_monsters

        # 修复rewards
        rewards = room.get("rewards", {})
        if not isinstance(rewards, dict):
            room["rewards"] = {}

        # 修复chests
        if not isinstance(room.get("chests"), int):
            room["chests"] = 0

        return room

    def _validate_single_monster(self, monster: Dict[str, Any], floor_level: int = 1) -> Dict[str, Any]:
        """验证单个怪物"""
        # 修复id
        if not isinstance(monster.get("id"), str):
            monster["id"] = "goblin"

        # 修复count
        if not isinstance(monster.get("count"), int):
            monster["count"] = 1

        # 修复level（可选字段）
        if "level" in monster and not isinstance(monster["level"], int):
            monster["level"] = 1

        # 验证怪物属性范围（使用楼层感知的动态约束）
        monster = self._validate_monster_attributes(monster, floor_level)

        return monster

    def _validate_monster_attributes(self, monster: Dict[str, Any], floor_level: int = 1) -> Dict[str, Any]:
        """
        验证怪物属性是否在合理范围内

        使用 MonsterBalanceConfig 获取楼层感知的动态约束
        同时保留绝对安全上限作为最终防护

        Args:
            monster: 怪物数据字典
            floor_level: 当前楼层级别
        """
        # 从 MonsterBalanceConfig 获取当前楼层的合理范围
        try:
            balance_type = monster.get("type", "normal")
            balance_config = MonsterBalanceConfig.get_config(balance_type, floor_level)
            hp_min = balance_config["health"]
            hp_max = balance_config["health"] * 2  # 允许2倍宽松度
            atk_min = balance_config["attack"]
            atk_max = balance_config["attack"] * 2
            def_min = balance_config["defense"]
            def_max = balance_config["defense"] * 2
        except Exception:
            # 降级到静态约束
            hp_min, hp_max = self.MONSTER_HP_MIN, self.MONSTER_HP_MAX
            atk_min, atk_max = self.MONSTER_ATTACK_MIN, self.MONSTER_ATTACK_MAX
            def_min, def_max = self.MONSTER_DEFENSE_MIN, self.MONSTER_DEFENSE_MAX

        # 验证HP (支持health和hp两种字段名)
        if "health" in monster:
            monster["health"] = self._clamp_int(
                monster["health"], hp_min, max(hp_max, self.MONSTER_HP_MAX)
            )
        elif "hp" in monster:
            monster["hp"] = self._clamp_int(
                monster["hp"], hp_min, max(hp_max, self.MONSTER_HP_MAX)
            )

        # 验证Attack
        if "attack" in monster:
            monster["attack"] = self._clamp_int(
                monster["attack"], atk_min, max(atk_max, self.MONSTER_ATTACK_MAX)
            )

        # 验证Defense
        if "defense" in monster:
            monster["defense"] = self._clamp_int(
                monster["defense"], def_min, max(def_max, self.MONSTER_DEFENSE_MAX)
            )

        return monster

    def _clamp_int(self, value: Any, min_val: int, max_val: int) -> int:
        """将整数值限制在范围内"""
        try:
            num = int(value)
            return max(min_val, min(max_val, num))
        except (TypeError, ValueError):
            return min_val

    def validate_room_type(self, room_type: str) -> str:
        """
        验证房间类型是否合法

        Args:
            room_type: 房间类型字符串

        Returns:
            合法的类型字符串，非法时返回默认值"combat"
        """
        if room_type in self.VALID_ROOM_TYPES:
            return room_type
        logger.warning(f"Invalid room type: '{room_type}', defaulting to 'combat'")
        return "combat"

    def validate_rarity(self, rarity: str) -> str:
        """
        验证武器稀有度是否合法

        Args:
            rarity: 稀有度字符串

        Returns:
            合法的稀有度字符串，非法时返回默认值"common"
        """
        if rarity in self.VALID_RARITIES:
            return rarity
        logger.warning(f"Invalid rarity: '{rarity}', defaulting to 'common'")
        return "common"

    def _ensure_fields(
        self,
        data: Dict[str, Any],
        required_fields: Dict[str, type],
        context: str
    ) -> Dict[str, Any]:
        """确保必需字段存在"""
        for field_name, field_type in required_fields.items():
            if field_name not in data:
                logger.warning(f"[{context}] Missing field '{field_name}', adding default")
                data[field_name] = self._get_default_value(field_type)
            elif not isinstance(data[field_name], field_type):
                # 特殊处理：int可以接受float
                if field_type == int and isinstance(data[field_name], float):
                    data[field_name] = int(data[field_name])
                # tuple类型表示多种可接受类型
                elif isinstance(field_type, tuple):
                    if not isinstance(data[field_name], field_type):
                        logger.warning(f"[{context}] Field '{field_name}' type mismatch, fixing")
                        data[field_name] = self._get_default_value(field_type[0])
                else:
                    logger.warning(f"[{context}] Field '{field_name}' type mismatch, fixing")
                    data[field_name] = self._get_default_value(field_type)

        return data

    def _get_default_value(self, field_type: type) -> Any:
        """获取类型的默认值"""
        if field_type == int:
            return 0
        elif field_type == float:
            return 0.0
        elif field_type == str:
            return ""
        elif field_type == list:
            return []
        elif field_type == dict:
            return {}
        elif field_type == bool:
            return False
        else:
            return None
