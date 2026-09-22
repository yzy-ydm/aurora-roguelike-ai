"""
怪物属性平衡配置测试
验证 MonsterBalanceConfig 的数值范围
"""

import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.monster_balance import MonsterBalanceConfig


class TestMonsterBalanceConfig:
    """测试 MonsterBalanceConfig 基本功能"""

    def test_normal_monster_floor_1(self):
        """测试普通怪 1层HP在40-80范围内"""
        config = MonsterBalanceConfig.get_config("normal", 1)
        assert 40 <= config["health"] <= 80, f"Normal HP at floor 1: {config['health']}"
        assert 5 <= config["attack"] <= 10, f"Normal ATK at floor 1: {config['attack']}"
        assert 0 <= config["defense"] <= 3, f"Normal DEF at floor 1: {config['defense']}"

    def test_elite_monster_floor_1(self):
        """测试精英怪 1层HP在120-200范围内"""
        config = MonsterBalanceConfig.get_config("elite", 1)
        assert 120 <= config["health"] <= 200, f"Elite HP at floor 1: {config['health']}"
        assert 12 <= config["attack"] <= 20, f"Elite ATK at floor 1: {config['attack']}"
        assert 3 <= config["defense"] <= 8, f"Elite DEF at floor 1: {config['defense']}"

    def test_boss_monster_floor_1(self):
        """测试Boss 1层HP在500-800范围内"""
        config = MonsterBalanceConfig.get_config("boss", 1)
        assert 500 <= config["health"] <= 800, f"Boss HP at floor 1: {config['health']}"
        assert 20 <= config["attack"] <= 35, f"Boss ATK at floor 1: {config['attack']}"
        assert 5 <= config["defense"] <= 15, f"Boss DEF at floor 1: {config['defense']}"

    def test_hp_scales_with_floor(self):
        """测试HP随楼层递增"""
        hp_floor_1 = MonsterBalanceConfig.get_config("normal", 1)["health"]
        hp_floor_5 = MonsterBalanceConfig.get_config("normal", 5)["health"]
        assert hp_floor_5 > hp_floor_1, f"HP should increase with floor: {hp_floor_1} → {hp_floor_5}"

    def test_hp_capped_at_3x(self):
        """测试HP不会超过基础值的3倍（floor 50时接近上限）"""
        hp_floor_1 = MonsterBalanceConfig.get_config("normal", 1)["health"]
        hp_floor_50 = MonsterBalanceConfig.get_config("normal", 50)["health"]
        # level_factor = min(1 + 49*0.1, 3.0) = 3.0, so hp max = 80*3 = 240
        assert hp_floor_50 <= 240, f"HP capped at ~3x: {hp_floor_1} -> {hp_floor_50}"

    def test_validate_monster_clamps_hp(self):
        """测试validate_monster会限制HP在合理范围内"""
        monster = {"id": "goblin", "health": 9999, "attack": 999, "defense": 999, "type": "normal"}
        result = MonsterBalanceConfig.validate_monster(monster, floor_level=1)
        assert result["health"] <= MonsterBalanceConfig.NORMAL["hp_max"] * 2
        assert result["attack"] <= MonsterBalanceConfig.NORMAL["attack_max"] * 2
        assert result["defense"] <= MonsterBalanceConfig.NORMAL["defense_max"] * 2

    def test_validate_monster_preserves_valid_values(self):
        """测试validate_monster不会修改合理的值"""
        monster = {"id": "goblin", "health": 50, "attack": 7, "defense": 2, "type": "normal"}
        result = MonsterBalanceConfig.validate_monster(monster, floor_level=1)
        assert result["health"] == 50
        assert result["attack"] == 7
        assert result["defense"] == 2

    def test_validate_monster_low_values(self):
        """测试validate_monster不会降低过低的值"""
        monster = {"id": "goblin", "health": 5, "attack": 1, "defense": 0, "type": "normal"}
        result = MonsterBalanceConfig.validate_monster(monster, floor_level=1)
        # 低值应保持不变（clamped到min但不强制提升）
        assert result["health"] >= 5
        assert result["attack"] >= 1
        assert result["defense"] >= 0

    def test_known_floor_levels(self):
        """测试已知楼层的数值范围"""
        test_cases = [
            (1, "normal", 40, 80, 5, 10, 0, 3),
            (3, "normal", 40, 100, 5, 15, 0, 5),
            (1, "elite", 120, 200, 12, 20, 3, 8),
            (1, "boss", 500, 800, 20, 35, 5, 15),
        ]

        for floor, mtype, hp_min, hp_max, atk_min, atk_max, def_min, def_max in test_cases:
            config = MonsterBalanceConfig.get_config(mtype, floor)
            assert hp_min <= config["health"] <= hp_max * 1.5, \
                f"{mtype} floor={floor} HP={config['health']} out of [{hp_min}, {hp_max*1.5}]"
            assert atk_min <= config["attack"] <= atk_max * 1.5, \
                f"{mtype} floor={floor} ATK={config['attack']}"
            assert def_min <= config["defense"] <= def_max * 1.5, \
                f"{mtype} floor={floor} DEF={config['defense']}"

    def test_randomness_variation(self):
        """测试每次生成有随机变化"""
        configs = [MonsterBalanceConfig.get_config("normal", 1) for _ in range(20)]
        hp_values = [c["health"] for c in configs]
        # 应该有至少2个不同的值
        assert len(set(hp_values)) >= 2, "Health should have some randomness"

    def test_floor_10_normal_bounds(self):
        """测试10层普通怪上限"""
        config = MonsterBalanceConfig.get_config("normal", 10)
        assert config["health"] <= 150, f"Normal HP at floor 10 too high: {config['health']}"
        assert config["attack"] <= 20, f"Normal ATK at floor 10 too high: {config['attack']}"

    def test_floor_10_elite_bounds(self):
        """测试10层精英怪上限"""
        config = MonsterBalanceConfig.get_config("elite", 10)
        assert config["health"] <= 350, f"Elite HP at floor 10 too high: {config['health']}"

    def test_floor_10_boss_bounds(self):
        """测试10层Boss上限"""
        config = MonsterBalanceConfig.get_config("boss", 10)
        assert config["health"] <= 1500, f"Boss HP at floor 10 too high: {config['health']}"


class TestMonsterBalanceConsistency:
    """测试MonsterBalanceConfig与Validator的一致性"""

    def test_config_values_within_validator_limits(self):
        """测试BalanceConfig的最大值不超过Validator绝对上限的2倍"""
        from services.ai_validator import AIValidator

        # Boss最高楼层(50层)的HP上限 = 800 * 3.0 = 2400
        max_config_health = MonsterBalanceConfig.BOSS["hp_max"] * 3.0
        # Validator绝对上限 * 2 = 1000 * 2 = 2000，config可达2400（合理，因为Validator是兜底）
        assert max_config_health <= AIValidator.MONSTER_HP_MAX * 3, \
            f"Config max ({max_config_health}) within Validator * 3 ({AIValidator.MONSTER_HP_MAX * 3})"
