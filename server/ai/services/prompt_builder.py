"""
提示词构建器

负责构建发送给大语言模型的提示词
为未来接入真实AI做准备
"""

from typing import Dict, Any, Optional, List


class PromptBuilder:
    """提示词构建器"""

    def __init__(self):
        """初始化"""
        self.system_prompt = self._get_system_prompt()

    def _get_system_prompt(self) -> str:
        """获取系统提示词"""
        return """你是一个Roguelike游戏内容生成器。

你的任务是根据给定的参数生成游戏内容，包括：
1. 楼层结构（房间列表和连接关系）
2. 房间内容（怪物配置、奖励配置）
3. 怪物属性
4. 武器属性

你需要确保生成的内容：
- 符合游戏平衡性
- 具有随机性和多样性
- 难度适合玩家等级
- JSON格式正确

请始终返回有效的JSON格式。"""

    def build_floor_prompt(
        self,
        floor_level: int,
        player_level: int,
        player_stats: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建楼层生成提示词

        Args:
            floor_level: 楼层级别
            player_level: 玩家等级
            player_stats: 玩家属性

        Returns:
            提示词字符串
        """
        prompt = f"""请生成一个Roguelike游戏楼层。

参数：
- 楼层级别: {floor_level}
- 玩家等级: {player_level}
"""

        if player_stats:
            prompt += f"""- 玩家生命值: {player_stats.get('health', 100)}
- 玩家攻击力: {player_stats.get('attack', 10)}
- 玩家防御力: {player_stats.get('defense', 5)}
"""

        prompt += """
要求：
1. 生成8-12个房间
2. 包含起始房间和Boss房间
3. 房间类型包括：combat, reward, elite, event, treasure, shop
4. 建立合理的连接关系
5. 根据楼层级别调整难度

请返回以下JSON格式：
{
    "floor": 楼层级别,
    "room_count": 房间数量,
    "rooms": [
        {
            "id": 房间ID,
            "type": "房间类型",
            "monsters": [{"id": "怪物类型", "count": 数量}],
            "rewards": {"count": 数量, "quality": 品质},
            "chests": 宝箱数量,
            "connections": [连接的房间ID列表]
        }
    ]
}
"""
        return prompt

    def build_room_content_prompt(
        self,
        room_id: int,
        room_type: str,
        floor_level: int,
        player_level: int
    ) -> str:
        """
        构建房间内容生成提示词

        Args:
            room_id: 房间ID
            room_type: 房间类型
            floor_level: 楼层级别
            player_level: 玩家等级

        Returns:
            提示词字符串
        """
        return f"""请生成一个Roguelike游戏房间的内容。

参数：
- 房间ID: {room_id}
- 房间类型: {room_type}
- 楼层级别: {floor_level}
- 玩家等级: {player_level}

要求：
1. 根据房间类型生成合适的怪物配置
2. 根据房间类型生成合适的奖励配置
3. 难度适合楼层级别和玩家等级
4. 保持游戏平衡性

房间类型说明：
- combat: 战斗房间，2-4个怪物
- elite: 精英房间，更强的怪物，更好的奖励
- boss: Boss房间，1个强力怪物，最好的奖励
- reward: 奖励房间，少量或无怪物，丰富奖励
- treasure: 宝箱房间，可能有守卫，多个宝箱
- event: 事件房间，随机事件
- shop: 商店房间，无怪物

请返回以下JSON格式：
{{
    "room_id": {room_id},
    "room_type": "{room_type}",
    "difficulty": 难度等级(1-10),
    "monsters": [{{"id": "怪物类型", "count": 数量, "level": 等级}}],
    "rewards": {{"count": 数量, "quality": 品质(0.5-3.0)}},
    "chests": 宝箱数量
}}
"""

    def build_monster_prompt(
        self,
        room_type: str,
        floor_level: int,
        player_level: int,
        monster_count: Optional[int] = None
    ) -> str:
        """
        构建怪物生成提示词

        Args:
            room_type: 房间类型
            floor_level: 楼层级别
            player_level: 玩家等级
            monster_count: 怪物数量

        Returns:
            提示词字符串
        """
        count_str = f"{monster_count}" if monster_count else "根据房间类型自动决定"

        return f"""请生成Roguelike游戏中的怪物配置。

参数：
- 房间类型: {room_type}
- 楼层级别: {floor_level}
- 玩家等级: {player_level}
- 怪物数量: {count_str}

可用怪物类型：
- goblin: 哥布林，低血量，快速
- skeleton: 骷髅，中等血量，中等攻击
- bat: 蝙蝠，低血量，高速度
- slime: 史莱姆，高血量，低攻击
- spider: 蜘蛛，中等血量，毒攻击
- elite_goblin: 精英哥布林，高属性
- boss_goblin_king: 哥布林王，Boss怪物

请返回以下JSON格式：
{{
    "monsters": [
        {{"id": "怪物类型", "count": 数量, "level": 等级}}
    ],
    "total_count": 总数量
}}
"""

    def build_weapon_prompt(
        self,
        player_level: int,
        rarity: Optional[str] = None,
        weapon_type: Optional[str] = None
    ) -> str:
        """
        构建武器生成提示词

        Args:
            player_level: 玩家等级
            rarity: 稀有度
            weapon_type: 武器类型

        Returns:
            提示词字符串
        """
        rarity_str = rarity if rarity else "随机"
        type_str = weapon_type if weapon_type else "随机"

        return f"""请生成Roguelike游戏中的武器。

参数：
- 玩家等级: {player_level}
- 稀有度: {rarity_str}
- 武器类型: {type_str}

可用武器类型：
- sword: 剑，平衡型
- axe: 斧，高伤害，慢速度
- bow: 弓，远程，中等伤害
- staff: 法杖，魔法伤害
- dagger: 匕首，快速，低伤害

稀有度：
- common: 普通，基础属性
- uncommon: 优秀，+30%属性
- rare: 稀有，+60%属性，1个特殊效果
- epic: 史诗，+100%属性，2个特殊效果
- legendary: 传说，+200%属性，3个特殊效果

请返回以下JSON格式：
{{
    "weapon": {{
        "id": "武器ID",
        "name": "武器名称",
        "description": "武器描述",
        "type": "武器类型",
        "rarity": "稀有度",
        "damage": 基础伤害,
        "crit_rate_bonus": 暴击率加成,
        "special_effect": "特殊效果",
        "fire_rate": 攻击间隔,
        "bullet_speed": 子弹速度,
        "price": 价格
    }}
}}
"""

    def parse_ai_response(self, response_text: str) -> Dict[str, Any]:
        """
        解析AI响应

        Args:
            response_text: AI响应文本

        Returns:
            解析后的数据
        """
        import json

        try:
            # 尝试直接解析JSON
            data = json.loads(response_text)
            return data
        except json.JSONDecodeError:
            # 尝试提取JSON部分
            start = response_text.find('{')
            end = response_text.rfind('}') + 1

            if start >= 0 and end > start:
                json_str = response_text[start:end]
                try:
                    data = json.loads(json_str)
                    return data
                except json.JSONDecodeError:
                    pass

            # 解析失败
            return {"error": "Failed to parse AI response", "raw": response_text}
