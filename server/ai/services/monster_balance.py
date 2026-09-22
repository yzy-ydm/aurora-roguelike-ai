"""
怪物属性平衡配置

定义不同房间类型和楼层的怪物属性范围
所有AI生成和Mock生成必须使用此配置
禁止硬编码具体数值
"""

from typing import Dict, Any, Tuple


class MonsterBalanceConfig:
    """
    怪物属性平衡配置类

    提供统一的怪物属性生成规则，确保：
    1. 数值在合理范围内
    2. 随楼层递增
    3. 不同类型怪物有差异化
    """

    # ==================== 普通怪物配置 ====================
    NORMAL = {
        "hp_min": 40,
        "hp_max": 80,
        "attack_min": 5,
        "attack_max": 10,
        "defense_min": 0,
        "defense_max": 3,
    }

    # ==================== 精英怪物配置 ====================
    ELITE = {
        "hp_min": 120,
        "hp_max": 200,
        "attack_min": 12,
        "attack_max": 20,
        "defense_min": 3,
        "defense_max": 8,
    }

    # ==================== Boss配置 ====================
    BOSS = {
        "hp_min": 500,
        "hp_max": 800,
        "attack_min": 20,
        "attack_max": 35,
        "defense_min": 5,
        "defense_max": 15,
    }

    # ==================== 楼层缩放系数 ====================
    # 每层增加的比例（降低以避免数值膨胀）
    HP_SCALE_PER_LEVEL = 0.10      # 每层HP +10%
    ATK_SCALE_PER_LEVEL = 0.08     # 每层攻击 +8%
    DEF_SCALE_PER_LEVEL = 0.05     # 每层防御 +5%

    @classmethod
    def get_config(cls, monster_type: str, floor_level: int) -> Dict[str, int]:
        """
        根据怪物类型和楼层获取属性配置

        Args:
            monster_type: "normal", "elite", "boss"
            floor_level: 楼层等级 (1-100)

        Returns:
            {"health": int, "attack": int, "defense": int}
        """
        # 选择基础配置
        if monster_type == "elite":
            base = cls.ELITE
        elif monster_type == "boss":
            base = cls.BOSS
        else:
            base = cls.NORMAL

        # 计算楼层缩放（限制最大倍数）
        max_multiplier = 3.0  # 最高3倍
        level_factor = min(1.0 + (floor_level - 1) * cls.HP_SCALE_PER_LEVEL, max_multiplier)

        # 生成属性值（带随机性）
        import random

        hp_range = base["hp_max"] - base["hp_min"]
        hp = cls._clamp(
            int(base["hp_min"] * level_factor + random.randint(0, int(hp_range * level_factor * 0.5))),
            base["hp_min"],
            int(base["hp_max"] * level_factor)
        )

        atk_range = base["attack_max"] - base["attack_min"]
        atk = cls._clamp(
            int(base["attack_min"] * (1.0 + (floor_level - 1) * cls.ATK_SCALE_PER_LEVEL) + random.randint(0, int(atk_range * 0.3))),
            base["attack_min"],
            int(base["attack_max"] * min(1.0 + (floor_level - 1) * 0.05, 2.0))
        )

        def_range = base["defense_max"] - base["defense_min"]
        def_val = cls._clamp(
            int(base["defense_min"] * (1.0 + (floor_level - 1) * cls.DEF_SCALE_PER_LEVEL) + random.randint(0, int(def_range * 0.3))),
            base["defense_min"],
            int(base["defense_max"] * min(1.0 + (floor_level - 1) * 0.03, 1.5))
        )

        return {
            "health": hp,
            "attack": atk,
            "defense": def_val,
            "level": floor_level
        }

    @staticmethod
    def _clamp(value: int, min_val: int, max_val: int) -> int:
        """将值限制在范围内"""
        return max(min_val, min(max_val, value))

    @classmethod
    def validate_monster(cls, monster: Dict[str, Any], floor_level: int) -> Dict[str, Any]:
        """
        验证并修正怪物属性

        Args:
            monster: 怪物数据字典
            floor_level: 当前楼层

        Returns:
            修正后的怪物数据
        """
        # 获取基础配置（用于确定钳制范围）
        if monster.get("type") == "elite":
            base = cls.ELITE
        elif monster.get("type") == "boss":
            base = cls.BOSS
        else:
            base = cls.NORMAL

        # 生成当前楼层的配置用于参考范围
        config = cls.get_config(
            monster.get("type", "normal"),
            floor_level
        )

        # 使用基础配置范围 × 楼层缩放作为钳制上限
        max_multiplier = min(1.0 + (floor_level - 1) * cls.HP_SCALE_PER_LEVEL, 3.0)

        # 修正属性
        if "health" in monster:
            monster["health"] = cls._clamp(monster["health"], base["hp_min"], int(base["hp_max"] * max_multiplier))
        if "attack" in monster:
            monster["attack"] = cls._clamp(monster["attack"], base["attack_min"], int(base["attack_max"] * min(1.0 + (floor_level - 1) * 0.05, 2.0)))
        if "defense" in monster:
            monster["defense"] = cls._clamp(monster["defense"], base["defense_min"], int(base["defense_max"] * min(1.0 + (floor_level - 1) * 0.03, 1.5)))

        # 确保必填字段
        monster.setdefault("level", floor_level)
        monster.setdefault("id", monster.get("id", "unknown"))
        monster.setdefault("count", 1)

        return monster


# 单例实例
balance_config = MonsterBalanceConfig()
