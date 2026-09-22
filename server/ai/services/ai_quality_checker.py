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

    MIN_HEALTH = 10        # 调整为合理下限
    MAX_HEALTH = 500       # 调整为合理上限（防止HP过高）

    # 新增：怪物属性范围限制
    MAX_MONSTER_ATTACK = 50   # 防止攻击力过高
    MAX_MONSTER_DEFENSE = 30  # 防止防御力过高

    # 新增：质量评分维度权重
    DIMENSION_WEIGHTS = {
        "legality": 0.30,      # 合法性: 字段完整性和格式正确性
        "balance": 0.30,       # 平衡性: 数值在游戏平衡范围内
        "diversity": 0.20,     # 多样性: 与历史生成的差异化程度
        "completeness": 0.20,  # 完整性: 必需字段齐全度
    }

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

            # 新增：检查怪物属性范围（修复HP过高等问题）
            monster = self._check_monster_attributes(monster)

            checked_monsters.append(monster)

        return checked_monsters

    def _check_monster_attributes(self, monster: Dict[str, Any]) -> Dict[str, Any]:
        """
        检查并修正怪物属性到合理范围

        Args:
            monster: 怪物数据字典

        Returns:
            修正后的怪物数据
        """
        # 检查HP
        if "health" in monster or "hp" in monster:
            hp_key = "health" if "health" in monster else "hp"
            hp = monster.get(hp_key, 50)
            monster[hp_key] = self._clamp_value(
                hp, self.MIN_HEALTH, self.MAX_HEALTH
            )

        # 检查Attack
        if "attack" in monster:
            monster["attack"] = self._clamp_value(
                monster["attack"], 1, self.MAX_MONSTER_ATTACK
            )

        # 检查Defense
        if "defense" in monster:
            monster["defense"] = self._clamp_value(
                monster["defense"], 0, self.MAX_MONSTER_DEFENSE
            )

        return monster

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

    # ==================== 质量评分系统 ====================

    def calculate_quality_score(
        self,
        data: Dict[str, Any],
        content_type: str = "unknown"
    ) -> Dict[str, Any]:
        """
        计算AI生成内容的综合质量评分

        评分维度：
        - legality (30%): 字段完整性和格式正确性
        - balance (30%): 数值在游戏平衡范围内
        - diversity (20%): 与历史生成的差异化程度（简化版）
        - completeness (20%): 必需字段齐全度

        Args:
            data: AI生成的数据
            content_type: 内容类型 (floor/room/monster/weapon等)

        Returns:
            {
                "quality_score": 85,      # 总分 0-100
                "dimensions": {           # 各维度得分
                    "legality": 90,
                    "balance": 80,
                    "diversity": 75,
                    "completeness": 95
                },
                "weights": {...},         # 权重配置
                "content_type": "floor"
            }
        """
        scores = {
            "legality": self._score_legality(data),
            "balance": self._score_balance(data, content_type),
            "diversity": self._score_diversity(data, content_type),
            "completeness": self._score_completeness(data),
        }

        # 加权计算总分
        total_score = sum(
            scores[dim] * self.DIMENSION_WEIGHTS[dim]
            for dim in self.DIMENSION_WEIGHTS
        )

        return {
            "quality_score": int(round(total_score)),
            "dimensions": {k: int(v) for k, v in scores.items()},
            "weights": self.DIMENSION_WEIGHTS.copy(),
            "content_type": content_type
        }

    def _score_legality(self, data: Dict[str, Any]) -> float:
        """
        合法性评分：检查数据结构是否合法

        评分标准：
        - 必需字段存在: +25分
        - 字段类型正确: +25分
        - 枚举值合法: +25分
        - 无异常值: +25分
        """
        score = 0.0

        # 检查是否为字典
        if not isinstance(data, dict):
            return 0.0
        score += 25.0  # 基本结构合法

        # 检查必需字段
        required_checks = {
            "floor": ["floor", "room_count", "rooms"],
            "room": ["room_id", "room_type", "monsters", "rewards"],
            "monster": ["monsters", "total_count"],
            "weapon": ["weapon"],
        }

        found_required = False
        for content_type, fields in required_checks.items():
            if all(field in data for field in fields):
                score += 25.0
                found_required = True
                break

        if not found_required:
            # 部分字段存在时给 partial score
            all_fields = set()
            for fields in required_checks.values():
                all_fields.update(fields)
            present_fields = set(data.keys()) & all_fields
            score += 25.0 * len(present_fields) / len(all_fields) if all_fields else 0.0

        # 检查枚举值合法性
        if "room_type" in data:
            valid_types = {"start", "combat", "elite", "boss", "reward", "treasure", "shop", "event"}
            if data["room_type"] in valid_types:
                score += 12.5
            else:
                score += 6.25

        if "rarity" in data:
            valid_rarities = {"common", "uncommon", "rare", "epic", "legendary"}
            if data["rarity"] in valid_rarities:
                score += 12.5
            else:
                score += 6.25

        return min(100.0, score)

    def _score_balance(self, data: Dict[str, Any], content_type: str) -> float:
        """
        平衡性评分：检查数值是否在合理游戏平衡范围内

        评分标准：
        - 数值在合理范围内: 高分
        - 数值越界但可修复: 中等分
        - 严重越界: 低分
        """
        score = 100.0

        # 检查怪物HP
        monsters = data.get("monsters", [])
        if isinstance(monsters, list):
            for monster in monsters:
                if isinstance(monster, dict):
                    hp = monster.get("health", monster.get("hp", 0))
                    if hp > self.MAX_HEALTH:
                        score -= 20.0
                    elif hp < self.MIN_HEALTH:
                        score -= 10.0

                    attack = monster.get("attack", 0)
                    if attack > self.MAX_MONSTER_ATTACK:
                        score -= 15.0

                    defense = monster.get("defense", 0)
                    if defense > self.MAX_MONSTER_DEFENSE:
                        score -= 10.0

        # 检查武器伤害
        weapon = data.get("weapon", {})
        if isinstance(weapon, dict):
            damage = weapon.get("damage", 0)
            if damage > self.MAX_DAMAGE:
                score -= 25.0
            elif damage < self.MIN_DAMAGE:
                score -= 15.0

        # 检查难度
        difficulty = data.get("difficulty", 1)
        if difficulty < self.MIN_DIFFICULTY or difficulty > self.MAX_DIFFICULTY:
            score -= 20.0

        return max(0.0, score)

    def _score_diversity(self, data: Dict[str, Any], content_type: str) -> float:
        """
        多样性评分：简化版，检查内容是否有足够的变化

        评分标准：
        - 包含多种元素: 高分
        - 内容单一: 低分
        """
        score = 50.0  # 基础分

        # 根据内容类型给予不同评分
        if content_type in ["floor", "room"]:
            # 检查房间/楼层的多样性
            rooms = data.get("rooms", [])
            if isinstance(rooms, list) and len(rooms) > 1:
                room_types = set()
                for room in rooms:
                    if isinstance(room, dict):
                        room_types.add(room.get("type", ""))
                if len(room_types) >= 3:
                    score += 30.0
                elif len(room_types) >= 2:
                    score += 20.0
                else:
                    score += 10.0

        elif content_type == "monster":
            monsters = data.get("monsters", [])
            if isinstance(monsters, list) and len(monsters) > 1:
                monster_ids = set(m.get("id", "") for m in monsters if isinstance(m, dict))
                if len(monster_ids) >= 2:
                    score += 30.0
                else:
                    score += 15.0

        elif content_type == "weapon":
            weapon = data.get("weapon", {})
            if isinstance(weapon, dict):
                if weapon.get("special_effect"):
                    score += 25.0
                if weapon.get("rarity") in ["rare", "epic", "legendary"]:
                    score += 15.0

        return min(100.0, score)

    def _score_completeness(self, data: Dict[str, Any]) -> float:
        """
        完整性评分：检查必需字段是否齐全

        评分标准：
        - 所有必需字段存在: 100分
        - 部分缺失: 按比例扣分
        """
        if not isinstance(data, dict):
            return 0.0

        # 定义各类型的必需字段
        required_fields = {
            "floor": ["floor", "room_count", "rooms"],
            "room": ["room_id", "room_type", "monsters", "rewards"],
            "monster": ["monsters", "total_count"],
            "weapon": ["weapon"],
        }

        # 尝试匹配最合适的类型
        best_score = 0.0
        for content_type, fields in required_fields.items():
            present = sum(1 for f in fields if f in data)
            score = (present / len(fields)) * 100 if fields else 0
            best_score = max(best_score, score)

        return best_score
