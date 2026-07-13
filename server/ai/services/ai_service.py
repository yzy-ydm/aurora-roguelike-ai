"""
AI内容生成服务

负责生成Roguelike游戏内容
暂时使用Mock实现，未来接入真实大语言模型
集成日志记录
"""

import random
import time
from typing import Dict, Any, List, Optional

# 导入日志
from logger.logger import logger, log_timing


class AIService:
    """AI内容生成服务"""

    def __init__(self):
        """初始化"""
        self.monster_types = ["goblin", "skeleton", "bat", "slime", "spider"]
        self.weapon_types = ["sword", "axe", "bow", "staff", "dagger"]
        self.rarities = ["common", "uncommon", "rare", "epic", "legendary"]
        logger.info("AIService initialized (Mock mode)")

    @log_timing
    async def generate_floor(
        self,
        floor_level: int,
        player_level: int,
        player_stats: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        生成楼层内容

        Args:
            floor_level: 楼层级别
            player_level: 玩家等级
            player_stats: 玩家属性

        Returns:
            楼层数据
        """
        logger.info(f"Generating floor: level={floor_level}, player={player_level}")

        # 生成房间数量
        room_count = random.randint(8, 12)

        # 生成房间列表
        rooms = []

        # 起始房间
        rooms.append(self._generate_start_room(0))

        # 中间房间
        for i in range(1, room_count - 1):
            room_type = self._get_random_room_type(floor_level)
            room = self._generate_room(i, room_type, floor_level, player_level)
            rooms.append(room)

        # Boss房间
        rooms.append(self._generate_boss_room(room_count - 1, floor_level, player_level))

        # 建立连接
        self._setup_connections(rooms)

        result = {
            "floor": floor_level,
            "player_level": player_level,
            "room_count": room_count,
            "rooms": rooms,
            "ai_mode": "mock"
        }

        logger.info(f"Floor generated: {room_count} rooms")
        return result

    @log_timing
    async def generate_room_content(
        self,
        room_id: int,
        room_type: str,
        floor_level: int,
        player_level: int
    ) -> Dict[str, Any]:
        """
        生成房间内容

        Args:
            room_id: 房间ID
            room_type: 房间类型
            floor_level: 楼层级别
            player_level: 玩家等级

        Returns:
            房间内容数据
        """
        logger.info(f"Generating room content: id={room_id}, type={room_type}")

        # 计算难度
        difficulty = self._calculate_difficulty(floor_level, room_type)

        # 生成怪物配置
        monsters = self._generate_monster_config(room_type, floor_level, player_level)

        # 生成奖励配置
        rewards = self._generate_reward_config(room_type, floor_level)

        # 生成宝箱数量
        chests = self._generate_chest_config(room_type)

        result = {
            "room_id": room_id,
            "room_type": room_type,
            "floor_level": floor_level,
            "player_level": player_level,
            "difficulty": difficulty,
            "monsters": monsters,
            "rewards": rewards,
            "chests": chests,
            "ai_mode": "mock"
        }

        logger.info(f"Room content generated: monsters={len(monsters)}, rewards={rewards.get('count', 0)}")
        return result

    @log_timing
    async def generate_monsters(
        self,
        room_type: str,
        floor_level: int,
        player_level: int,
        monster_count: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        生成怪物配置

        Args:
            room_type: 房间类型
            floor_level: 楼层级别
            player_level: 玩家等级
            monster_count: 怪物数量

        Returns:
            怪物配置数据
        """
        logger.info(f"Generating monsters: room_type={room_type}, floor={floor_level}")

        if monster_count is None:
            monster_count = self._get_monster_count(room_type)

        monsters = []
        for _ in range(monster_count):
            monster_type = random.choice(self.monster_types)
            level = max(1, floor_level + random.randint(-1, 1))
            monsters.append({
                "id": monster_type,
                "count": 1,
                "level": level
            })

        result = {
            "monsters": monsters,
            "total_count": monster_count,
            "ai_mode": "mock"
        }

        logger.info(f"Monsters generated: {monster_count} monsters")
        return result

    @log_timing
    async def generate_weapon(
        self,
        player_level: int,
        rarity: Optional[str] = None,
        weapon_type: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        生成武器配置

        Args:
            player_level: 玩家等级
            rarity: 稀有度
            weapon_type: 武器类型

        Returns:
            武器配置数据
        """
        logger.info(f"Generating weapon: level={player_level}, rarity={rarity}, type={weapon_type}")

        if rarity is None:
            rarity = self._get_random_rarity()

        if weapon_type is None:
            weapon_type = random.choice(self.weapon_types)

        # 基础伤害
        base_damage = 10 + player_level * 2

        # 稀有度倍率
        rarity_multiplier = self._get_rarity_multiplier(rarity)

        # 最终伤害
        damage = int(base_damage * rarity_multiplier)

        # 暴击率
        crit_rate = 0.05 + (player_level * 0.01)

        # 特殊效果
        special_effect = self._generate_special_effect(rarity)

        weapon_name = self._generate_weapon_name(rarity, weapon_type)

        result = {
            "weapon": {
                "id": f"{rarity}_{weapon_type}",
                "name": weapon_name,
                "description": f"A {rarity} {weapon_type}",
                "type": weapon_type,
                "rarity": rarity,
                "damage": damage,
                "crit_rate_bonus": crit_rate,
                "special_effect": special_effect,
                "fire_rate": 0.3,
                "bullet_speed": 400.0,
                "price": int(damage * 10 * rarity_multiplier)
            },
            "ai_mode": "mock"
        }

        logger.info(f"Weapon generated: {weapon_name} (damage={damage})")
        return result

    # ==================== 辅助方法 ====================

    def _generate_start_room(self, room_id: int) -> Dict[str, Any]:
        """生成起始房间"""
        return {
            "id": room_id,
            "type": "start",
            "monsters": [],
            "rewards": [],
            "chests": 0,
            "connections": []
        }

    def _generate_boss_room(
        self,
        room_id: int,
        floor_level: int,
        player_level: int
    ) -> Dict[str, Any]:
        """生成Boss房间"""
        return {
            "id": room_id,
            "type": "boss",
            "monsters": [
                {
                    "id": "boss_goblin_king",
                    "count": 1,
                    "level": floor_level + 1
                }
            ],
            "rewards": {
                "count": random.randint(3, 5),
                "quality": 2.0 + (floor_level - 1) * 0.3
            },
            "chests": 2,
            "connections": []
        }

    def _generate_room(
        self,
        room_id: int,
        room_type: str,
        floor_level: int,
        player_level: int
    ) -> Dict[str, Any]:
        """生成普通房间"""
        return {
            "id": room_id,
            "type": room_type,
            "monsters": self._generate_monster_config(room_type, floor_level, player_level),
            "rewards": self._generate_reward_config(room_type, floor_level),
            "chests": self._generate_chest_config(room_type),
            "connections": []
        }

    def _get_random_room_type(self, floor_level: int) -> str:
        """获取随机房间类型"""
        rand = random.random()

        if floor_level <= 2:
            if rand < 0.6:
                return "combat"
            elif rand < 0.8:
                return "reward"
            elif rand < 0.9:
                return "event"
            else:
                return "treasure"
        else:
            if rand < 0.4:
                return "combat"
            elif rand < 0.6:
                return "reward"
            elif rand < 0.7:
                return "elite"
            elif rand < 0.8:
                return "event"
            elif rand < 0.9:
                return "shop"
            else:
                return "treasure"

    def _generate_monster_config(
        self,
        room_type: str,
        floor_level: int,
        player_level: int
    ) -> List[Dict[str, Any]]:
        """生成怪物配置"""
        monsters = []

        if room_type == "combat":
            count = random.randint(2, 4)
            monsters.append({
                "id": random.choice(self.monster_types),
                "count": count
            })
            if floor_level > 2:
                monsters.append({
                    "id": random.choice(self.monster_types),
                    "count": random.randint(1, 2)
                })
        elif room_type == "elite":
            monsters.append({
                "id": "elite_goblin",
                "count": random.randint(1, 2)
            })
            monsters.append({
                "id": random.choice(self.monster_types),
                "count": random.randint(1, 3)
            })
        elif room_type == "treasure":
            if random.random() < 0.5:
                monsters.append({
                    "id": random.choice(self.monster_types),
                    "count": random.randint(1, 2)
                })
        elif room_type == "event":
            if random.random() < 0.3:
                monsters.append({
                    "id": random.choice(self.monster_types),
                    "count": random.randint(1, 2)
                })

        return monsters

    def _generate_reward_config(
        self,
        room_type: str,
        floor_level: int
    ) -> Dict[str, Any]:
        """生成奖励配置"""
        quality = 1.0
        strategy = ""
        items = []

        if room_type == "combat":
            quality = 1.0 + (floor_level - 1) * 0.1
            strategy = random.choice(["power_growth", "balanced", "survival"])
        elif room_type == "elite":
            quality = 1.5 + (floor_level - 1) * 0.15
            strategy = "power_growth"
            items = self._generate_reward_items("elite", quality)
        elif room_type == "boss":
            quality = 2.0 + (floor_level - 1) * 0.2
            strategy = "power_growth"
            items = self._generate_reward_items("boss", quality)
        elif room_type == "reward":
            quality = 1.2 + (floor_level - 1) * 0.12
            strategy = "balanced"
            items = self._generate_reward_items("reward", quality)
        elif room_type == "treasure":
            quality = 1.3 + (floor_level - 1) * 0.13
            strategy = "balanced"
            items = self._generate_reward_items("treasure", quality)

        return {
            "count": random.randint(1, 3),
            "quality": quality,
            "strategy": strategy,
            "items": items
        }

    def _generate_reward_items(
        self,
        room_type: str,
        quality: float
    ) -> List[Dict[str, Any]]:
        """生成具体的奖励物品列表"""
        items = []

        if room_type == "elite":
            # 精英房间：高概率武器或攻击提升
            items.append({
                "type": random.choice(["weapon", "attack_up"]),
                "rarity": random.choice(["uncommon", "rare"]),
                "value": random.randint(3, 8)
            })
        elif room_type == "boss":
            # Boss房间：稀有武器 + 大量金币
            items.append({
                "type": "weapon",
                "rarity": random.choice(["rare", "epic"]),
                "value": random.randint(10, 20)
            })
            items.append({
                "type": "gold",
                "rarity": "rare",
                "value": random.randint(50, 100)
            })
        elif room_type == "reward":
            # 奖励房间：平衡奖励
            items.append({
                "type": random.choice(["health_up", "attack_up", "heal"]),
                "rarity": random.choice(["common", "uncommon"]),
                "value": random.randint(5, 15)
            })
        elif room_type == "treasure":
            # 宝箱房间：金币为主
            items.append({
                "type": "gold",
                "rarity": "uncommon",
                "value": random.randint(30, 60)
            })
            if random.random() < 0.5:
                items.append({
                    "type": random.choice(["attack_up", "health_up"]),
                    "rarity": "common",
                    "value": random.randint(2, 5)
                })

        return items

    def _generate_chest_config(self, room_type: str) -> int:
        """生成宝箱配置"""
        if room_type == "treasure":
            return random.randint(2, 3)
        elif room_type == "elite":
            return 1
        elif room_type == "boss":
            return 2
        else:
            return 0

    def _calculate_difficulty(self, floor_level: int, room_type: str) -> int:
        """计算难度"""
        base_difficulty = floor_level

        if room_type == "elite":
            base_difficulty += 1
        elif room_type == "boss":
            base_difficulty += 2

        return min(10, base_difficulty)

    def _setup_connections(self, rooms: List[Dict[str, Any]]) -> None:
        """设置房间连接"""
        # 线性连接
        for i in range(len(rooms) - 1):
            rooms[i]["connections"].append(i + 1)
            rooms[i + 1]["connections"].append(i)

        # 添加分支
        if len(rooms) > 4:
            branch_count = random.randint(1, 3)
            for _ in range(branch_count):
                from_idx = random.randint(0, len(rooms) - 3)
                to_idx = from_idx + random.randint(2, 3)
                if to_idx < len(rooms):
                    if to_idx not in rooms[from_idx]["connections"]:
                        rooms[from_idx]["connections"].append(to_idx)
                    if from_idx not in rooms[to_idx]["connections"]:
                        rooms[to_idx]["connections"].append(from_idx)

    def _get_monster_count(self, room_type: str) -> int:
        """获取怪物数量"""
        if room_type == "combat":
            return random.randint(2, 4)
        elif room_type == "elite":
            return random.randint(3, 5)
        elif room_type == "boss":
            return 1
        elif room_type == "treasure":
            return random.randint(0, 2)
        else:
            return random.randint(0, 1)

    def _get_random_rarity(self) -> str:
        """获取随机稀有度"""
        rand = random.random()
        if rand < 0.5:
            return "common"
        elif rand < 0.8:
            return "uncommon"
        elif rand < 0.95:
            return "rare"
        elif rand < 0.99:
            return "epic"
        else:
            return "legendary"

    def _get_rarity_multiplier(self, rarity: str) -> float:
        """获取稀有度倍率"""
        multipliers = {
            "common": 1.0,
            "uncommon": 1.3,
            "rare": 1.6,
            "epic": 2.0,
            "legendary": 3.0
        }
        return multipliers.get(rarity, 1.0)

    def _generate_special_effect(self, rarity: str) -> str:
        """生成特殊效果"""
        if rarity == "common":
            return ""
        elif rarity == "uncommon":
            return random.choice([
                "Increased attack speed",
                "Life steal 5%",
                "Critical chance +10%"
            ])
        elif rarity == "rare":
            return random.choice([
                "Fire damage",
                "Ice damage",
                "Lightning damage",
                "Double damage chance 15%"
            ])
        elif rarity == "epic":
            return random.choice([
                "Chain lightning",
                "Explosive attacks",
                "Time slow on hit",
                "Summon ally on kill"
            ])
        else:  # legendary
            return random.choice([
                "Instant kill chance 5%",
                "Invincibility on critical",
                "Time rewind",
                "Duplicate attacks"
            ])

    def _generate_weapon_name(self, rarity: str, weapon_type: str) -> str:
        """生成武器名称"""
        prefixes = {
            "common": ["Basic", "Simple", "Rusty"],
            "uncommon": ["Fine", "Sharp", "Sturdy"],
            "rare": ["Ancient", "Enchanted", "Mystic"],
            "epic": ["Epic", "Legendary", "Hero's"],
            "legendary": ["Divine", "Godly", "Eternal"]
        }

        prefix = random.choice(prefixes.get(rarity, ["Basic"]))
        return f"{prefix} {weapon_type.capitalize()}"
