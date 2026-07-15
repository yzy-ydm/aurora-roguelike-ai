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
        return """你是一个Roguelike游戏内容生成AI。

【严格要求】
1. 只返回JSON格式，不要添加任何说明文字
2. 不要使用代码块标记（```json）
3. 确保JSON格式正确，可以被直接解析

【游戏规则】
- 难度范围：1-10
- 怪物数量：1-10个
- 奖励品质：0.1-3.0
- 怪物等级应接近玩家等级（±2级）
- 房间类型：start, combat, elite, boss, reward, treasure, shop, event

【数值约束】
- difficulty: 1-10
- monster.count: 1-10
- monster.level: 1-20
- rewards.quality: 0.1-3.0
- weapon.damage: 1-999
- weapon.rarity: common, uncommon, rare, epic, legendary"""

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

    def build_event_prompt(
        self,
        room_type: str,
        player_level: int,
        context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建事件生成提示词

        Args:
            room_type: 房间类型
            player_level: 玩家等级
            context: 上下文信息

        Returns:
            提示词字符串
        """
        prompt = f"""请生成一个Roguelike游戏中的随机事件。

参数：
- 房间类型: {room_type}
- 玩家等级: {player_level}
"""

        if context:
            prompt += f"- 房间ID: {context.get('room_id', 0)}\n"

        prompt += """
要求：
1. 事件标题简洁有力
2. 事件描述生动有趣
3. 提供3个选择，每个选择有不同的奖励和风险
4. 奖励和风险要平衡
5. 根据房间类型调整事件主题

房间类型说明：
- combat: 战斗房间，事件偏向战斗相关
- elite: 精英房间，事件偏向高风险高回报
- boss: Boss房间，事件偏向最终挑战
- reward: 奖励房间，事件偏向获取奖励
- treasure: 宝箱房间，事件偏向探索和发现
- shop: 商店房间，事件偏向交易
- event: 事件房间，事件可以是任何类型

请返回以下JSON格式：
{
    "title": "事件标题",
    "description": "事件描述",
    "choices": [
        {
            "text": "选择文本",
            "reward": {"health": 数值, "attack": 数值, "gold": 数值, "max_health": 数值},
            "risk": {"damage": 数值, "lose_gold": 数值}
        }
    ]
}
"""
        return prompt

    def build_dialogue_prompt(
        self,
        npc_type: str,
        room_environment: str,
        player_state: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建NPC对话提示词

        Args:
            npc_type: NPC类型
            room_environment: 房间环境
            player_state: 玩家状态

        Returns:
            提示词字符串
        """
        prompt = f"""请生成Roguelike游戏中NPC的对话。

参数：
- NPC类型: {npc_type}
- 房间环境: {room_environment}
"""

        if player_state:
            prompt += f"""- 玩家生命值: {player_state.get('health', 100)}
- 玩家金币: {player_state.get('gold', 0)}
"""

        prompt += """
NPC类型说明：
- merchant: 商人，对话偏向交易和商品
- sage: 智者，对话偏向提示和警告
- guard: 守卫，对话偏向安全和警告
- healer: 治疗师，对话偏向治疗和恢复

要求：
1. 对话简洁明了
2. 符合NPC性格
3. 根据环境调整语气
4. 返回2-3句对话

请返回以下JSON格式：
{
    "dialogue": ["对话1", "对话2", "对话3"]
}
"""
        return prompt

    def build_upgrade_prompt(
        self,
        player_level: int,
        player_stats: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建升级强化提示词

        Args:
            player_level: 玩家等级
            player_stats: 玩家属性

        Returns:
            提示词字符串
        """
        prompt = f"""请为Roguelike游戏玩家生成3个升级强化选项。

参数：
- 玩家等级: {player_level}
"""

        if player_stats:
            prompt += f"""- 当前生命值: {player_stats.get('current_health', 100)}
- 最大生命值: {player_stats.get('max_health', 100)}
- 攻击力: {player_stats.get('attack', 10)}
- 防御力: {player_stats.get('defense', 5)}
- 移动速度: {player_stats.get('move_speed', 200)}
"""

        prompt += """
要求：
1. 生成3个不同的强化选项
2. 根据玩家等级调整强化强度
3. 根据玩家当前属性推荐合适的强化
4. 如果玩家攻击低，推荐攻击强化
5. 如果玩家生命低，推荐生命强化
6. 强化类型包括：属性提升、百分比提升、特殊能力

强化稀有度：
- common: 基础强化
- uncommon: 中等强化
- rare: 高级强化
- epic: 史诗强化

请返回以下JSON格式：
{
    "upgrades": [
        {
            "id": "唯一ID",
            "name": "强化名称",
            "description": "强化描述",
            "type": "stat_boost 或 ability",
            "rarity": "common, uncommon, rare, epic",
            "modifiers": {"属性名": 数值},
            "percent_modifiers": {"属性名": 百分比(0.0-1.0)}
        }
    ]
}

可用属性：
- attack: 攻击力
- max_health: 最大生命值
- defense: 防御力
- move_speed: 移动速度
- crit_rate: 暴击率
- crit_damage: 暴击伤害
- heal_on_kill: 击杀回复
"""
        return prompt

    def build_difficulty_prompt(
        self,
        context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建难度调整提示词

        Args:
            context: 游戏上下文

        Returns:
            提示词字符串
        """
        prompt = """请根据玩家行为数据生成难度调整建议。

"""
        if context:
            prompt += f"""玩家数据：
- 战斗风格: {context.get('combat_style', 'balanced')}
- 死亡率: {context.get('death_rate', 0.0)}
- 受伤率: {context.get('damage_rate', 0.0)}
- 无伤率: {context.get('no_hit_rate', 0.0)}
- 总击杀: {context.get('total_kills', 0)}
- 死亡次数: {context.get('death_count', 0)}
- 玩家等级: {context.get('player_level', 1)}
"""

        prompt += """
调整规则：
1. 专家玩家(高无伤率)：增加难度，提高奖励
2. 困难玩家(高死亡率)：降低难度，提高奖励
3. 激进玩家(高受伤率)：稍微增加难度
4. 平衡玩家：保持默认

请返回以下JSON格式：
{
    "enemy_hp_multiplier": 1.0,
    "enemy_damage_multiplier": 1.0,
    "elite_spawn_rate": 0.1,
    "reward_multiplier": 1.0
}

数值范围：
- enemy_hp_multiplier: 0.5-2.0
- enemy_damage_multiplier: 0.5-2.0
- elite_spawn_rate: 0.0-0.5
- reward_multiplier: 0.5-3.0
"""
        return prompt

    def build_room_strategy_prompt(
        self,
        context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建房间策略提示词

        Args:
            context: 游戏上下文

        Returns:
            提示词字符串
        """
        prompt = """请根据玩家状态生成房间策略建议。

"""
        if context:
            prompt += f"""玩家数据：
- 战斗风格: {context.get('combat_style', 'balanced')}
- 升级偏好: {context.get('upgrade_preference', 'balanced')}
- 当前生命百分比: {context.get('current_health_percent', 1.0)}
- 玩家等级: {context.get('player_level', 1)}
- 当前楼层: {context.get('floor_level', 1)}
"""

        prompt += """
房间类型：
- combat: 战斗房
- elite: 精英房
- boss: Boss房
- reward: 奖励房
- treasure: 宝箱房
- shop: 商店房
- event: 事件房

请返回以下JSON格式：
{
    "preferred_room_types": ["combat", "reward"],
    "avoid_room_types": ["elite"],
    "recommended_difficulty": "normal"
}

recommended_difficulty: easy, normal, hard
"""
        return prompt

    def build_npc_memory_prompt(
        self,
        npc_id: str,
        context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建NPC记忆提示词

        Args:
            npc_id: NPC ID
            context: NPC记忆上下文

        Returns:
            提示词字符串
        """
        prompt = f"""请根据NPC记忆生成个性化对话。

NPC ID: {npc_id}
"""
        if context:
            prompt += f"""NPC记忆：
- 交互次数: {context.get('interaction_count', 0)}
- 关系值: {context.get('relationship', 0.0)}
- 玩家过去选择: {context.get('player_choices', [])}
"""

        prompt += """
关系值说明：
- 0.8以上：密友
- 0.5-0.8：朋友
- 0.2-0.5：友好
- -0.2到0.2：中立
- -0.5到-0.2：不友好
- -0.5以下：敌对

请返回以下JSON格式：
{
    "dialogue": ["对话1", "对话2"]
}

要求：
1. 对话要体现NPC对玩家的记忆
2. 根据关系值调整语气
3. 交互次数越多，对话越个性化
"""
        return prompt

    def build_context_event_prompt(
        self,
        context: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        构建上下文事件提示词

        Args:
            context: 游戏上下文

        Returns:
            提示词字符串
        """
        prompt = """请根据玩家状态生成个性化事件。

"""
        if context:
            prompt += f"""玩家数据：
- 战斗风格: {context.get('combat_style', 'balanced')}
- 升级偏好: {context.get('upgrade_preference', 'balanced')}
- 当前生命百分比: {context.get('current_health_percent', 1.0)}
- 玩家等级: {context.get('player_level', 1)}
"""

        prompt += """
要求：
1. 事件要与玩家状态相关
2. 高攻击玩家：出现武器强化事件
3. 低生命玩家：出现治疗事件
4. 专家玩家：出现高风险高回报事件

请返回以下JSON格式：
{
    "title": "事件标题",
    "description": "事件描述",
    "choices": [
        {
            "text": "选择文本",
            "reward": {"属性": 数值},
            "risk": {"属性": 数值}
        }
    ]
}

可用属性：
- health: 生命值
- attack: 攻击力
- defense: 防御力
- max_health: 最大生命值
- gold: 金币
- damage: 伤害(风险)
"""
        return prompt
