"""
AI质量检查器

负责验证AI生成内容的游戏平衡性
确保数值在合理范围内
"""

from typing import Dict, Any, List, Optional

from logger.logger import logger


class AIQualityChecker:
    """
    AI质量检查器

    职责：
    - 验证游戏平衡性
    - 检查数值范围
    - 根据玩家等级检查合理性
    """

    # 数值范围限制
    MIN_DIFFICULTY = 1
    MAX_DIFFICULTY = 10

    MIN_MONSTER_COUNT = 1
    MAX_MONSTER_COUNT = 10

    MIN_REWARD_QUALITY = 0.1
    MAX_REWARD_QUALITY = 3.0

    MIN_DAMAGE = 1
    MAX_DAMAGE = 999

    MIN_HEALTH = 1
    MAX_HEALTH = 9999

    # 怪物等级范围（相对于玩家等级）
    MONSTER_LEVEL_OFFSET_MIN = -2
    MONSTER_LEVEL_OFFSET_MAX = 5

    def check_floor_quality(
        self,
        data: Dict[str, Any],
        player_level: int = 1
    ) -> Dict[str, Any]:
        """
        检查楼层数据质量

        Args:
            data: 楼层数据
            player_level: 玩家等级

        Returns:
            检查后的数据（可能已修正）
        """
        # 检查房间数量
        rooms = data.get("rooms", [])
        if len(rooms) < 1:
            logger.warning("Floor has no rooms, adding default room")
            rooms = [{"id": 0, "type": "start", "connections": [], "monsters": [], "rewards": {}, "chests": 0}]
            data["rooms"] = rooms
            data["room_count"] = 1

        # 检查每个房间
        for room in rooms:
            self._check_room_quality(room, player_level)

        logger.debug(f"Floor quality checked: {len(rooms)} rooms")
        return data

    def check_room_content_quality(
        self,
        data: Dict[str, Any],
        player_level: int = 1
    ) -> Dict[str, Any]:
        """
        检查房间内容质量

        Args:
            data: 房间内容数据
            player_level: 玩家等级

        Returns:
            检查后的数据
        """
        # 检查difficulty
        difficulty = data.get("difficulty", 1)
        data["difficulty"] = self._clamp_value(
            difficulty,
            self.MIN_DIFFICULTY,
            self.MAX_DIFFICULTY
        )

        # 检查monsters
        monsters = data.get("monsters", [])
        data["monsters"] = self._check_monsters(monsters, player_level)

        # 检查rewards
        rewards = data.get("rewards", {})
        data["rewards"] = self._check_rewards(rewards)

        logger.debug(f"Room content quality checked: difficulty={data['difficulty']}")
        return data

    def check_monster_quality(
        self,
        data: Dict[str, Any],
        player_level: int = 1
    ) -> Dict[str, Any]:
        """
        检查怪物数据质量

        Args:
            data: 怪物数据
            player_level: 玩家等级

        Returns:
            检查后的数据
        """
        monsters = data.get("monsters", [])
        data["monsters"] = self._check_monsters(monsters, player_level)
        data["total_count"] = len(data["monsters"])

        logger.debug(f"Monster quality checked: {data['total_count']} monsters")
        return data

    def check_weapon_quality(
        self,
        data: Dict[str, Any],
        player_level: int = 1
    ) -> Dict[str, Any]:
        """
        检查武器数据质量

        Args:
            data: 武器数据
            player_level: 玩家等级

        Returns:
            检查后的数据
        """
        weapon = data.get("weapon", {})

        # 检查damage
        damage = weapon.get("damage", 10)
        weapon["damage"] = self._clamp_value(damage, self.MIN_DAMAGE, self.MAX_DAMAGE)

        # 检查稀有度
        rarity = weapon.get("rarity", "common")
        if rarity not in ["common", "uncommon", "rare", "epic", "legendary"]:
            weapon["rarity"] = "common"

        data["weapon"] = weapon

        logger.debug(f"Weapon quality checked: {weapon.get('name', 'unknown')}")
        return data

    def _check_room_quality(self, room: Dict[str, Any], player_level: int) -> None:
        """检查单个房间质量"""
        # 检查怪物
        monsters = room.get("monsters", [])
        room["monsters"] = self._check_monsters(monsters, player_level)

        # 检查奖励
        rewards = room.get("rewards", {})
        room["rewards"] = self._check_rewards(rewards)

    def _check_monsters(
        self,
        monsters: List[Dict[str, Any]],
        player_level: int
    ) -> List[Dict[str, Any]]:
        """检查怪物列表"""
        if not isinstance(monsters, list):
            return []

        checked_monsters = []
        for monster in monsters:
            if not isinstance(monster, dict):
                continue

            # 检查count
            count = monster.get("count", 1)
            monster["count"] = self._clamp_value(
                count,
                self.MIN_MONSTER_COUNT,
                self.MAX_MONSTER_COUNT
            )

            # 检查level（如果存在）
            if "level" in monster:
                level = monster["level"]
                min_level = max(1, player_level + self.MONSTER_LEVEL_OFFSET_MIN)
                max_level = player_level + self.MONSTER_LEVEL_OFFSET_MAX
                monster["level"] = self._clamp_value(level, min_level, max_level)

            checked_monsters.append(monster)

        return checked_monsters

    def _check_rewards(self, rewards: Dict[str, Any]) -> Dict[str, Any]:
        """检查奖励配置"""
        if not isinstance(rewards, dict):
            return {"count": 1, "quality": 1.0}

        # 检查count
        count = rewards.get("count", 1)
        rewards["count"] = self._clamp_value(count, 0, 10)

        # 检查quality
        quality = rewards.get("quality", 1.0)
        rewards["quality"] = self._clamp_value(
            quality,
            self.MIN_REWARD_QUALITY,
            self.MAX_REWARD_QUALITY
        )

        return rewards

    def _clamp_value(self, value: Any, min_val: float, max_val: float) -> float:
        """将值限制在范围内"""
        try:
            num = float(value)
            return max(min_val, min(max_val, num))
        except (TypeError, ValueError):
            return min_val
