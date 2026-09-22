"""
AI内容验证器增强测试

测试新增的数值范围验证和枚举验证功能
"""

import pytest
import os
from unittest.mock import patch

# 设置测试环境
os.environ["LLM_PROVIDER"] = "mock"

from services.ai_validator import AIValidator
from services.ai_quality_checker import AIQualityChecker


class TestMonsterAttributeValidation:
    """怪物属性范围验证测试"""

    def setup_method(self):
        self.validator = AIValidator()
        self.checker = AIQualityChecker()

    def test_validate_monster_hp_clamped_to_max(self):
        """测试HP超过上限时被裁剪"""
        monster = {"id": "goblin", "count": 1, "health": 9999}
        result = self.validator._validate_monster_attributes(monster)
        assert result["health"] <= self.validator.MONSTER_HP_MAX  # 现在使用动态范围  # 500

    def test_validate_monster_hp_clamped_to_min(self):
        """测试HP低于下限时被修正"""
        monster = {"id": "goblin", "count": 1, "health": -100}
        result = self.validator._validate_monster_attributes(monster)
        assert result["health"] >= self.validator.MONSTER_HP_MIN  # 下限由validator保证  # 10

    def test_validate_monster_hp_within_range(self):
        """测试HP在合理范围内不被修改"""
        monster = {"id": "goblin", "count": 1, "health": 100}
        result = self.validator._validate_monster_attributes(monster)
        assert result["health"] == 100

    def test_validate_monster_attack_clamped(self):
        """测试攻击力超过上限时被裁剪"""
        monster = {"id": "goblin", "count": 1, "attack": 999}
        result = self.validator._validate_monster_attributes(monster)
        assert result["attack"] <= self.validator.MONSTER_ATTACK_MAX  # 动态范围  # 50

    def test_validate_monster_defense_clamped(self):
        """测试防御力超过上限时被裁剪"""
        monster = {"id": "goblin", "count": 1, "defense": 999}
        result = self.validator._validate_monster_attributes(monster)
        assert result["defense"] <= self.validator.MONSTER_DEFENSE_MAX  # 动态范围  # 30

    def test_validate_monster_hp_short_form(self):
        """测试HP字段使用短名称'h'时也能验证"""
        monster = {"id": "goblin", "count": 1, "hp": 10000}
        result = self.validator._validate_monster_attributes(monster)
        assert result["hp"] <= self.validator.MONSTER_HP_MAX  # 动态范围  # 500

    def test_validate_monster_no_attributes(self):
        """测试没有属性的怪物也能正常处理"""
        monster = {"id": "goblin", "count": 1}
        result = self.validator._validate_monster_attributes(monster)
        assert result == {"id": "goblin", "count": 1}


class TestRoomTypeValidation:
    """房间类型枚举验证测试"""

    def setup_method(self):
        self.validator = AIValidator()

    def test_valid_room_types(self):
        """测试合法房间类型"""
        for room_type in ["start", "combat", "elite", "boss", "reward", "treasure", "shop", "event"]:
            assert self.validator.validate_room_type(room_type) == room_type

    def test_invalid_room_type_defaults_to_combat(self):
        """测试非法房间类型默认返回combat"""
        assert self.validator.validate_room_type("invalid") == "combat"
        assert self.validator.validate_room_type("") == "combat"
        assert self.validator.validate_room_type(None) == "combat"


class TestRarityValidation:
    """武器稀有度枚举验证测试"""

    def setup_method(self):
        self.validator = AIValidator()

    def test_valid_rarities(self):
        """测试合法稀有度"""
        for rarity in ["common", "uncommon", "rare", "epic", "legendary"]:
            assert self.validator.validate_rarity(rarity) == rarity

    def test_invalid_rarity_defaults_to_common(self):
        """测试非法稀有度默认返回common"""
        assert self.validator.validate_rarity("invalid") == "common"
        assert self.validator.validate_rarity("") == "common"
        assert self.validator.validate_rarity(None) == "common"


class TestFloorValidationEnhanced:
    """楼层验证增强测试"""

    def setup_method(self):
        self.validator = AIValidator()
        self.checker = AIQualityChecker()

    def test_validate_floor_with_high_hp_monsters(self):
        """测试楼层中包含HP过高的怪物"""
        data = {
            "floor": 1,
            "room_count": 2,
            "rooms": [
                {"id": 0, "type": "start", "connections": [1], "monsters": [], "rewards": {}, "chests": 0},
                {
                    "id": 1,
                    "type": "combat",
                    "connections": [0],
                    "monsters": [{"id": "goblin", "count": 1, "health": 9999, "attack": 999}],
                    "rewards": {"count": 1, "quality": 1.0},
                    "chests": 0
                }
            ]
        }
        result = self.validator.validate_floor_data(data)
        # HP和Attack应该被裁剪（使用validator的常量）
        monster = result["rooms"][1]["monsters"][0]
        assert monster["health"] == self.validator.MONSTER_HP_MAX  # 500
        assert monster["attack"] == self.validator.MONSTER_ATTACK_MAX  # 50


class TestQualityScoreCalculation:
    """质量评分计算测试"""

    def setup_method(self):
        self.checker = AIQualityChecker()

    def test_calculate_quality_score_valid_floor(self):
        """测试有效楼层数据的质量评分"""
        data = {
            "floor": 1,
            "room_count": 5,
            "rooms": [
                {"id": 0, "type": "start", "monsters": [], "rewards": {}},
                {"id": 1, "type": "combat", "monsters": [], "rewards": {}},
                {"id": 2, "type": "boss", "monsters": [], "rewards": {}}
            ]
        }
        result = self.checker.calculate_quality_score(data, "floor")
        assert "quality_score" in result
        assert 0 <= result["quality_score"] <= 100
        assert "dimensions" in result
        assert "legality" in result["dimensions"]
        assert "balance" in result["dimensions"]
        assert "completeness" in result["dimensions"]

    def test_calculate_quality_score_invalid_monster(self):
        """测试包含越界数值的怪物数据评分"""
        data = {
            "monsters": [
                {"id": "goblin", "count": 1, "health": 99999, "attack": 999}
            ],
            "total_count": 1
        }
        result = self.checker.calculate_quality_score(data, "monster")
        # 因为数值越界，balance得分应该较低
        assert result["dimensions"]["balance"] < 80

    def test_calculate_quality_score_weapon(self):
        """测试武器数据的质量评分"""
        data = {
            "weapon": {
                "name": "Test Sword",
                "type": "sword",
                "rarity": "rare",
                "damage": 50,
                "special_effect": "Fire damage"
            }
        }
        result = self.checker.calculate_quality_score(data, "weapon")
        assert 0 <= result["quality_score"] <= 100
