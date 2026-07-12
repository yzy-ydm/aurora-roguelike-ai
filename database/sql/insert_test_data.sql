-- ============================================================
-- 基于云端AI动态内容生成的Roguelike游戏系统
-- 测试数据插入脚本
-- ============================================================
-- 文件: insert_test_data.sql
-- 说明: 插入用于开发和测试的示例数据
-- 数据库: MySQL 8.0
-- ============================================================

-- 使用数据库
USE aurora_game;

-- ============================================================
-- 1. 插入测试用户数据
-- ============================================================
-- 密码说明: 以下密码均为 "password123" 的bcrypt哈希值
-- 实际项目中应使用真实的密码哈希
INSERT INTO users (username, password_hash, email, is_active, last_login_at) VALUES
('admin', '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e', 'admin@example.com', 1, NOW()),
('player1', '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e', 'player1@example.com', 1, NOW()),
('player2', '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e', 'player2@example.com', 1, NULL),
('test_user', '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e', 'test@example.com', 0, NULL),
('demo_player', '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e', 'demo@example.com', 1, NOW());


-- ============================================================
-- 2. 插入玩家角色信息
-- ============================================================
INSERT INTO player_profiles (user_id, nickname, level, experience, experience_to_next_level, max_health, current_health, attack, defense, crit_rate, gold, total_play_time, max_floor_reached, total_kills, death_count) VALUES
(1, '管理员', 10, 5000, 6000, 200, 200, 50, 30, 15.00, 9999, 36000, 15, 500, 0),
(2, '勇敢的冒险者', 5, 1200, 2000, 150, 120, 25, 15, 8.50, 350, 7200, 8, 120, 3),
(3, '新手勇者', 1, 0, 100, 100, 100, 10, 5, 5.00, 0, 0, 1, 0, 0),
(5, '测试英雄', 3, 500, 800, 120, 100, 18, 10, 6.00, 150, 3600, 5, 45, 2);


-- ============================================================
-- 3. 插入武器数据
-- ============================================================
INSERT INTO weapons (name, description, weapon_type, rarity, attack_bonus, crit_rate_bonus, special_effect, price, is_ai_generated) VALUES
-- 普通武器
('铁剑', '一把普通的铁制长剑，新手冒险者的标准装备。', 'sword', 'common', 5, 0.00, NULL, 50, 0),
('木弓', '用坚固木材制作的简易弓，适合远程攻击。', 'bow', 'common', 4, 2.00, NULL, 40, 0),
('短匕首', '轻便的匕首，攻击速度快但伤害较低。', 'dagger', 'common', 3, 5.00, '攻击速度+10%', 30, 0),

-- 优秀武器
('精钢长剑', '经过精炼的钢制长剑，锋利耐用。', 'sword', 'uncommon', 12, 3.00, NULL, 200, 0),
('战斧', '沉重的战斧，能造成巨大伤害。', 'axe', 'uncommon', 15, 0.00, '有10%概率造成眩晕', 250, 0),
('猎人长弓', '猎人专用的长弓，射程更远。', 'bow', 'uncommon', 10, 5.00, '射程+2', 220, 0),

-- 稀有武器
('烈焰之剑', '附有火焰魔法的剑，攻击时附加火焰伤害。', 'sword', 'rare', 25, 8.00, '攻击附加15点火焰伤害', 800, 0),
('寒冰法杖', '蕴含寒冰之力的法杖，能冻结敌人。', 'staff', 'rare', 20, 5.00, '有15%概率冻结敌人1回合', 750, 0),
('暗影匕首', '来自暗影世界的匕首，攻击无声无息。', 'dagger', 'rare', 18, 15.00, '暴击时造成3倍伤害', 900, 0),

-- 史诗武器
('雷霆战锤', '雷神之锤的仿制品，蕴含雷电之力。', 'hammer', 'epic', 40, 10.00, '攻击时有20%概率召唤闪电，对周围敌人造成伤害', 2500, 0),
('龙骨弓', '用龙骨制作的传奇弓，威力惊人。', 'bow', 'epic', 35, 12.00, '穿透攻击，可同时攻击2个敌人', 2800, 0),

-- 传说武器
('圣剑·Excalibur', '传说中的圣剑，拥有净化一切邪恶的力量。', 'sword', 'legendary', 80, 20.00, '对邪恶系怪物造成双倍伤害，每10秒恢复5%生命值', 9999, 0),

-- AI生成武器示例
('混沌之刃', '由AI创造的神秘武器，属性随机变化。', 'sword', 'rare', 22, 10.00, '每次攻击随机附加一种元素伤害', 1200, 1);


-- ============================================================
-- 4. 插入怪物数据
-- ============================================================
INSERT INTO monsters (name, description, monster_type, level, health, attack, defense, speed, experience_reward, gold_reward, special_ability, min_floor, max_floor, is_ai_generated) VALUES
-- 普通怪物
('史莱姆', '最基础的怪物，由粘液构成，行动缓慢。', 'normal', 1, 20, 5, 2, 3, 10, 5, NULL, 1, 10, 0),
('哥布林', '小型人形怪物，喜欢成群结队出现。', 'normal', 2, 35, 8, 3, 6, 15, 8, '有20%概率呼叫同伴', 1, 15, 0),
('骷髅兵', '被复活的骷髅战士，手持生锈的武器。', 'normal', 3, 50, 12, 8, 5, 20, 12, '有10%概率格挡攻击', 3, 20, 0),
('蝙蝠', '在黑暗中飞行的蝙蝠，速度极快。', 'normal', 2, 25, 10, 2, 12, 12, 6, '闪避率+20%', 2, 15, 0),
('毒蛇', '带有毒液的蛇，攻击会使人中毒。', 'normal', 3, 30, 15, 3, 10, 18, 10, '攻击有30%概率使目标中毒', 3, 25, 0),

-- 精英怪物
('巨型蜘蛛', '体型巨大的蜘蛛，能吐出粘稠的蛛丝。', 'elite', 5, 120, 25, 15, 8, 50, 30, '有25%概率使目标被蛛网束缚，无法行动1回合', 5, 30, 0),
('石头傀儡', '由魔法驱动的石头人偶，防御极高。', 'elite', 8, 200, 30, 35, 3, 80, 50, '受到物理伤害减少30%', 8, 40, 0),
('暗影刺客', '来自暗影世界的刺客，攻击致命。', 'elite', 10, 150, 45, 10, 15, 100, 60, '第一击必定暴击，之后每3回合有一次必暴击', 10, 50, 0),

-- Boss怪物
('地牢守卫者', '地牢的第一层Boss，守护着宝藏。', 'boss', 5, 500, 35, 20, 5, 200, 100, '每损失25%生命值会召唤2只骷髅兵', 5, 5, 0),
('火焰巨龙', '守护火山区域的远古巨龙，喷吐烈焰。', 'boss', 20, 2000, 80, 50, 8, 1000, 500, '每3回合发动一次龙息，对全体造成火焰伤害', 20, 20, 0),
('混沌领主', '最终Boss，掌握着混沌之力。', 'boss', 30, 5000, 120, 80, 10, 5000, 2000, '拥有多种形态，每损失33%生命值切换形态并改变攻击模式', 30, 30, 0),

-- AI生成怪物示例
('量子史莱姆', 'AI生成的变异史莱姆，具有量子特性。', 'elite', 8, 180, 30, 20, 10, 90, 55, '有15%概率闪现到随机位置，躲避攻击', 8, 25, 1);


-- ============================================================
-- 5. 插入随机事件数据
-- ============================================================
INSERT INTO events (name, description, event_type, trigger_rate, min_floor, max_floor, effect_data, option1_text, option1_effect, option2_text, option2_effect, is_ai_generated) VALUES
-- 宝藏事件
('宝箱发现', '你发现了一个闪闪发光的宝箱，上面镶嵌着宝石。', 'treasure', 15.00, 1, 999, '{"gold": 50}', '打开宝箱', '{"gold": 100, "risk": "可能有陷阱"}', '离开', '{}', 0),

('神秘商人', '一个神秘的商人出现在你面前，他有一些奇特的商品。', 'merchant', 8.00, 3, 999, NULL, '查看商品', '{"action": "open_shop"}', '无视他', '{}', 0),

('治疗泉水', '你发现了一处散发着柔和光芒的泉水。', 'treasure', 12.00, 1, 999, NULL, '饮用泉水', '{"health": 50}', '装瓶带走', '{"item": "health_potion"}', 0),

-- 陷阱事件
('毒针陷阱', '地板上有一个不易察觉的小孔，可能是陷阱。', 'trap', 10.00, 2, 999, NULL, '小心绕过', '{}', '直接踩过去', '{"health": -30, "gold": 20}', 0),

('落石陷阱', '天花板看起来不太稳定，随时可能掉落石块。', 'trap', 8.00, 5, 999, NULL, '快速通过', '{"health": -20}', '寻找安全路线', '{}', 0),

('魔法陷阱', '地面上闪烁着诡异的符文光芒。', 'trap', 6.00, 8, 999, NULL, '尝试解除', '{"success": {"attack": 5}, "fail": {"health": -40}}', '绕道而行', '{}', 0),

-- NPC事件
('受伤的冒险者', '你发现一位受伤的冒险者倒在地上。', 'npc', 10.00, 1, 999, NULL, '帮助他', '{"reputation": 10, "item": "map_fragment"}', '搜刮他的物品', '{"gold": 30, "reputation": -5}', 0),

('神秘老人', '一位白发苍苍的老人坐在路边，似乎在等什么人。', 'npc', 5.00, 5, 999, NULL, '与他交谈', '{"experience": 100}', '离开', '{}', 0),

-- 神秘事件
('神秘祭坛', '你发现了一个散发着强大魔力的祭坛。', 'mystery', 5.00, 10, 999, NULL, '献祭金币', '{"cost": 100, "reward": {"attack": 3}}', '离开', '{}', 0),

('时空裂缝', '一道奇异的裂缝出现在空中，散发着未知的能量。', 'mystery', 3.00, 15, 999, NULL, '进入裂缝', '{"teleport": "random_floor"}', '远离裂缝', '{}', 0),

-- 休息事件
('安全营地', '你发现了一个相对安全的营地，可以休息恢复。', 'rest', 15.00, 1, 999, NULL, '休息一会', '{"health_percent": 30}', '继续前进', '{}', 0),

-- AI生成事件示例
('量子传送门', '一个闪烁着蓝光的传送门出现在眼前，似乎是AI创造的。', 'mystery', 4.00, 5, 50, NULL, '进入传送门', '{"teleport": "boss_room"}', '观察一下', '{"experience": 50}', 1);


-- ============================================================
-- 6. 插入地图数据
-- ============================================================
INSERT INTO maps (name, description, theme, floor_level, width, height, room_count, room_data, monster_spawn_config, event_spawn_config, difficulty, is_ai_generated) VALUES
('新手地牢入口', '地牢的最浅层，光线尚可，危险较小。', 'dungeon', 1, 15, 12, 5,
 '{"rooms": [{"id": 1, "x": 2, "y": 2, "w": 4, "h": 3, "type": "start"}, {"id": 2, "x": 8, "y": 2, "w": 4, "h": 3, "type": "normal"}, {"id": 3, "x": 2, "y": 7, "w": 4, "h": 3, "type": "treasure"}, {"id": 4, "x": 8, "y": 7, "w": 4, "h": 3, "type": "normal"}, {"id": 5, "x": 5, "y": 5, "w": 3, "h": 3, "type": "exit"}]}',
 '{"monsters": [{"id": 1, "count": 3}, {"id": 2, "count": 2}]}',
 '{"events": [{"id": 1, "count": 1}, {"id": 3, "count": 1}]}',
 1, 0),

('黑暗地牢第二层', '光线昏暗，怪物开始增多。', 'dungeon', 2, 18, 14, 6,
 '{"rooms": [{"id": 1, "x": 2, "y": 2, "w": 4, "h": 3, "type": "start"}, {"id": 2, "x": 10, "y": 2, "w": 5, "h": 4, "type": "normal"}, {"id": 3, "x": 2, "y": 8, "w": 4, "h": 4, "type": "monster"}, {"id": 4, "x": 10, "y": 8, "w": 5, "h": 4, "type": "treasure"}, {"id": 5, "x": 6, "y": 5, "w": 4, "h": 3, "type": "normal"}, {"id": 6, "x": 8, "y": 10, "w": 3, "h": 3, "type": "exit"}]}',
 '{"monsters": [{"id": 2, "count": 3}, {"id": 3, "count": 2}, {"id": 4, "count": 2}]}',
 '{"events": [{"id": 4, "count": 1}, {"id": 7, "count": 1}]}',
 2, 0),

('地下洞穴', '自然形成的洞穴，有些地方长满了苔藓。', 'cave', 5, 20, 15, 7,
 '{"rooms": [{"id": 1, "x": 2, "y": 2, "w": 5, "h": 4, "type": "start"}, {"id": 2, "x": 12, "y": 2, "w": 5, "h": 4, "type": "normal"}, {"id": 3, "x": 2, "y": 9, "w": 5, "h": 4, "type": "monster"}, {"id": 4, "x": 12, "y": 9, "w": 5, "h": 4, "type": "treasure"}, {"id": 5, "x": 7, "y": 5, "w": 4, "h": 3, "type": "normal"}, {"id": 6, "x": 7, "y": 10, "w": 4, "h": 3, "type": "normal"}, {"id": 7, "x": 15, "y": 6, "w": 3, "h": 3, "type": "exit"}]}',
 '{"monsters": [{"id": 3, "count": 3}, {"id": 6, "count": 1}, {"id": 5, "count": 2}]}',
 '{"events": [{"id": 3, "count": 1}, {"id": 5, "count": 1}, {"id": 11, "count": 1}]}',
 5, 0),

('古老城堡废墟', '曾经辉煌的城堡，如今只剩下残垣断壁。', 'castle', 10, 22, 16, 8,
 '{"rooms": [{"id": 1, "x": 2, "y": 2, "w": 5, "h": 4, "type": "start"}, {"id": 2, "x": 12, "y": 2, "w": 6, "h": 4, "type": "boss"}, {"id": 3, "x": 2, "y": 10, "w": 5, "h": 4, "type": "treasure"}, {"id": 4, "x": 12, "y": 10, "w": 6, "h": 4, "type": "monster"}, {"id": 5, "x": 8, "y": 5, "w": 4, "h": 3, "type": "normal"}, {"id": 6, "x": 8, "y": 10, "w": 4, "h": 3, "type": "normal"}, {"id": 7, "x": 2, "y": 6, "w": 3, "h": 3, "type": "normal"}, {"id": 8, "x": 18, "y": 6, "w": 3, "h": 3, "type": "exit"}]}',
 '{"monsters": [{"id": 7, "count": 2}, {"id": 8, "count": 1}, {"id": 3, "count": 3}]}',
 '{"events": [{"id": 8, "count": 1}, {"id": 9, "count": 1}, {"id": 11, "count": 1}]}',
 8, 0),

-- AI生成地图示例
('混沌空间', '由AI生成的不稳定空间，布局会随时变化。', 'dungeon', 15, 20, 15, 9,
 '{"rooms": [{"id": 1, "x": 2, "y": 2, "w": 4, "h": 3, "type": "start"}, {"id": 2, "x": 10, "y": 2, "w": 5, "h": 4, "type": "normal"}, {"id": 3, "x": 2, "y": 8, "w": 5, "h": 4, "type": "monster"}, {"id": 4, "x": 10, "y": 8, "w": 5, "h": 4, "type": "treasure"}, {"id": 5, "x": 6, "y": 5, "w": 4, "h": 3, "type": "mystery"}, {"id": 6, "x": 15, "y": 5, "w": 3, "h": 3, "type": "normal"}, {"id": 7, "x": 2, "y": 12, "w": 4, "h": 2, "type": "normal"}, {"id": 8, "x": 10, "y": 12, "w": 5, "h": 2, "type": "monster"}, {"id": 9, "x": 16, "y": 12, "w": 3, "h": 2, "type": "exit"}]}',
 '{"monsters": [{"id": 8, "count": 2}, {"id": 12, "count": 2}, {"id": 7, "count": 1}]}',
 '{"events": [{"id": 10, "count": 1}, {"id": 12, "count": 2}]}',
 10, 1);


-- ============================================================
-- 7. 插入游戏存档示例
-- ============================================================
INSERT INTO game_saves (user_id, save_name, current_floor, player_state, inventory_data, current_map_data, play_time, kill_count, gold_collected, slot_number, is_active) VALUES
(2, '第一次冒险', 3,
 '{"health": 85, "max_health": 100, "attack": 12, "defense": 8, "level": 2, "experience": 150, "gold": 230}',
 '{"weapons": [{"id": 1, "name": "铁剑", "attack_bonus": 5}], "items": [{"name": "生命药水", "count": 3}]}',
 '{"floor": 3, "theme": "dungeon", "explored_rooms": [1, 2, 3]}',
 1800, 25, 230, 1, 1),

(2, '挑战模式', 8,
 '{"health": 45, "max_health": 150, "attack": 28, "defense": 18, "level": 5, "experience": 1200, "gold": 580}',
 '{"weapons": [{"id": 7, "name": "烈焰之剑", "attack_bonus": 25}], "items": [{"name": "生命药水", "count": 1}, {"name": "解毒草", "count": 2}]}',
 '{"floor": 8, "theme": "castle", "explored_rooms": [1, 2, 3, 4, 5]}',
 5400, 120, 580, 2, 1);


-- ============================================================
-- 8. 插入AI生成记录示例
-- ============================================================
INSERT INTO ai_generations (user_id, content_type, model_name, prompt, raw_response, parsed_data, status, request_duration, tokens_used, is_applied, user_rating) VALUES
(1, 'weapon', 'gpt-3.5-turbo',
 '请为Roguelike游戏设计一把稀有级别的剑类武器，要求：1. 有火焰主题 2. 攻击力在20-30之间 3. 有特殊效果 4. 有趣味性的背景故事',
 '{"name": "烈焰之剑", "description": "附有火焰魔法的剑，攻击时附加火焰伤害", "attack_bonus": 25, "special_effect": "攻击附加15点火焰伤害"}',
 '{"name": "烈焰之剑", "attack_bonus": 25, "crit_rate_bonus": 8.00, "special_effect": "攻击附加15点火焰伤害", "rarity": "rare"}',
 'success', 1500, 256, 1, 4),

(2, 'monster', 'gpt-3.5-turbo',
 '请设计一个精英级别的蜘蛛怪物，适合5-10层出现，需要有控制技能',
 '{"name": "巨型蜘蛛", "description": "体型巨大的蜘蛛，能吐出粘稠的蛛丝", "health": 120, "attack": 25, "special_ability": "蛛网束缚"}',
 '{"name": "巨型蜘蛛", "health": 120, "attack": 25, "defense": 15, "special_ability": "有25%概率使目标被蛛网束缚，无法行动1回合"}',
 'success', 1200, 198, 1, 5),

(1, 'event', 'gpt-3.5-turbo',
 '请设计一个神秘主题的随机事件，玩家可以选择冒险或保守',
 '{"name": "时空裂缝", "description": "一道奇异的裂缝出现在空中", "option1": "进入裂缝", "option2": "远离裂缝"}',
 '{"name": "时空裂缝", "event_type": "mystery", "option1_effect": {"teleport": "random_floor"}, "option2_effect": {"experience": 50}}',
 'success', 980, 156, 1, 3),

(1, 'map', 'gpt-4',
 '请设计一个15层的Boss战地图，主题是混沌空间，需要有多个房间和陷阱',
 '{"name": "混沌空间", "theme": "dungeon", "room_count": 9, "difficulty": 10}',
 '{"name": "混沌空间", "floor_level": 15, "room_count": 9, "difficulty": 10}',
 'success', 3500, 512, 1, 4),

(2, 'weapon', 'gpt-3.5-turbo',
 '设计一把传说级别的武器',
 NULL,
 NULL,
 'failed', 5000, 0, 0, NULL);


-- ============================================================
-- 测试数据插入完成
-- ============================================================
-- 已插入的数据:
-- users:            5条记录
-- player_profiles:  4条记录
-- weapons:         13条记录
-- monsters:        12条记录
-- events:          12条记录
-- maps:             5条记录
-- game_saves:       2条记录
-- ai_generations:   5条记录
-- ============================================================
