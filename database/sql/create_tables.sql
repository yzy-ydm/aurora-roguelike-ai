-- ============================================================
-- 基于云端AI动态内容生成的Roguelike游戏系统
-- 数据表创建脚本
-- ============================================================
-- 文件: create_tables.sql
-- 说明: 创建所有数据表、索引和外键约束
-- 数据库: MySQL 8.0
-- 引擎: InnoDB
-- 字符集: utf8mb4
-- ============================================================

-- 使用数据库
USE aurora_game;

-- ============================================================
-- 1. 用户账号表 (users)
-- 说明: 存储系统用户的基本账号信息
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    -- 主键ID，自增
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',

    -- 用户名，唯一，用于登录
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',

    -- 密码哈希值（使用bcrypt等算法加密存储）
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希',

    -- 邮箱地址，唯一，用于找回密码等
    email VARCHAR(100) UNIQUE COMMENT '邮箱地址',

    -- 账号状态：0-禁用，1-启用
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用: 0-禁用, 1-启用',

    -- 最后登录时间
    last_login_at DATETIME COMMENT '最后登录时间',

    -- 记录创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 记录更新时间（自动更新）
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    -- 软删除标记
    is_deleted TINYINT(1) DEFAULT 0 COMMENT '是否删除: 0-正常, 1-已删除',

    -- 索引
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户账号表';


-- ============================================================
-- 2. 玩家角色信息表 (player_profiles)
-- 说明: 存储玩家的游戏角色属性和状态
-- ============================================================
CREATE TABLE IF NOT EXISTS player_profiles (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '档案ID',

    -- 关联用户ID
    user_id INT NOT NULL COMMENT '用户ID',

    -- 角色昵称
    nickname VARCHAR(50) NOT NULL COMMENT '角色昵称',

    -- 角色等级
    level INT DEFAULT 1 COMMENT '角色等级',

    -- 当前经验值
    experience INT DEFAULT 0 COMMENT '当前经验',

    -- 升级所需经验
    experience_to_next_level INT DEFAULT 100 COMMENT '升级所需经验',

    -- 最大生命值
    max_health INT DEFAULT 100 COMMENT '最大生命值',

    -- 当前生命值
    current_health INT DEFAULT 100 COMMENT '当前生命值',

    -- 基础攻击力
    attack INT DEFAULT 10 COMMENT '基础攻击力',

    -- 基础防御力
    defense INT DEFAULT 5 COMMENT '基础防御力',

    -- 暴击率（百分比，0-100）
    crit_rate DECIMAL(5,2) DEFAULT 5.00 COMMENT '暴击率',

    -- 金币数量
    gold INT DEFAULT 0 COMMENT '金币数量',

    -- 总游戏时长（秒）
    total_play_time INT DEFAULT 0 COMMENT '总游戏时长(秒)',

    -- 最高到达层数
    max_floor_reached INT DEFAULT 1 COMMENT '最高到达层数',

    -- 击杀怪物总数
    total_kills INT DEFAULT 0 COMMENT '击杀怪物总数',

    -- 死亡次数
    death_count INT DEFAULT 0 COMMENT '死亡次数',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 更新时间
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    -- 外键约束：关联到用户表
    CONSTRAINT fk_player_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    -- 唯一约束：每个用户只能有一个角色档案
    UNIQUE KEY uk_user_id (user_id),

    -- 索引
    INDEX idx_level (level),
    INDEX idx_nickname (nickname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='玩家角色信息表';


-- ============================================================
-- 3. 武器数据表 (weapons)
-- 说明: 存储游戏中所有武器的基础数据
-- ============================================================
CREATE TABLE IF NOT EXISTS weapons (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '武器ID',

    -- 武器名称
    name VARCHAR(100) NOT NULL COMMENT '武器名称',

    -- 武器描述
    description TEXT COMMENT '武器描述',

    -- 武器类型：sword-剑, axe-斧, bow-弓, staff-法杖, dagger-匕首
    weapon_type ENUM('sword', 'axe', 'bow', 'staff', 'dagger', 'spear', 'hammer') NOT NULL COMMENT '武器类型',

    -- 稀有度：common-普通, uncommon-优秀, rare-稀有, epic-史诗, legendary-传说
    rarity ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') DEFAULT 'common' COMMENT '稀有度',

    -- 攻击力加成
    attack_bonus INT DEFAULT 0 COMMENT '攻击力加成',

    -- 暴击率加成（百分比）
    crit_rate_bonus DECIMAL(5,2) DEFAULT 0.00 COMMENT '暴击率加成',

    -- 特殊效果描述
    special_effect TEXT COMMENT '特殊效果',

    -- 特殊效果数值（JSON格式存储）
    special_effect_data JSON COMMENT '特殊效果数据',

    -- 武器图标路径
    icon_path VARCHAR(255) COMMENT '图标路径',

    -- 武器价格（商店售价）
    price INT DEFAULT 0 COMMENT '武器价格',

    -- 是否为AI生成的内容
    is_ai_generated TINYINT(1) DEFAULT 0 COMMENT '是否AI生成',

    -- AI生成记录ID（关联ai_generations表）
    ai_generation_id INT COMMENT 'AI生成记录ID',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 索引
    INDEX idx_weapon_type (weapon_type),
    INDEX idx_rarity (rarity),
    INDEX idx_is_ai_generated (is_ai_generated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='武器数据表';


-- ============================================================
-- 4. 怪物数据表 (monsters)
-- 说明: 存储游戏中所有怪物的基础数据
-- ============================================================
CREATE TABLE IF NOT EXISTS monsters (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '怪物ID',

    -- 怪物名称
    name VARCHAR(100) NOT NULL COMMENT '怪物名称',

    -- 怪物描述
    description TEXT COMMENT '怪物描述',

    -- 怪物类型：normal-普通, elite-精英, boss-首领
    monster_type ENUM('normal', 'elite', 'boss') DEFAULT 'normal' COMMENT '怪物类型',

    -- 怪物等级
    level INT DEFAULT 1 COMMENT '怪物等级',

    -- 生命值
    health INT NOT NULL COMMENT '生命值',

    -- 攻击力
    attack INT NOT NULL COMMENT '攻击力',

    -- 防御力
    defense INT NOT NULL COMMENT '防御力',

    -- 速度
    speed INT DEFAULT 10 COMMENT '速度',

    -- 经验奖励
    experience_reward INT DEFAULT 10 COMMENT '经验奖励',

    -- 金币奖励
    gold_reward INT DEFAULT 5 COMMENT '金币奖励',

    -- 特殊能力描述
    special_ability TEXT COMMENT '特殊能力',

    -- 特殊能力数据（JSON格式）
    special_ability_data JSON COMMENT '特殊能力数据',

    -- 怪物图标路径
    icon_path VARCHAR(255) COMMENT '图标路径',

    -- 出现的最小层数
    min_floor INT DEFAULT 1 COMMENT '最小出现层数',

    -- 出现的最大层数
    max_floor INT DEFAULT 999 COMMENT '最大出现层数',

    -- 是否为AI生成的内容
    is_ai_generated TINYINT(1) DEFAULT 0 COMMENT '是否AI生成',

    -- AI生成记录ID
    ai_generation_id INT COMMENT 'AI生成记录ID',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 索引
    INDEX idx_monster_type (monster_type),
    INDEX idx_level (level),
    INDEX idx_min_floor (min_floor),
    INDEX idx_is_ai_generated (is_ai_generated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='怪物数据表';


-- ============================================================
-- 5. 随机事件表 (events)
-- 说明: 存储游戏中可能触发的随机事件
-- ============================================================
CREATE TABLE IF NOT EXISTS events (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '事件ID',

    -- 事件名称
    name VARCHAR(100) NOT NULL COMMENT '事件名称',

    -- 事件描述（玩家看到的文本）
    description TEXT NOT NULL COMMENT '事件描述',

    -- 事件类型：treasure-宝藏, trap-陷阱, merchant-商人, npc-NPC, mystery-神秘事件
    event_type ENUM('treasure', 'trap', 'merchant', 'npc', 'mystery', 'rest', 'combat') NOT NULL COMMENT '事件类型',

    -- 事件触发概率（百分比，0-100）
    trigger_rate DECIMAL(5,2) DEFAULT 10.00 COMMENT '触发概率',

    -- 触发的最小层数
    min_floor INT DEFAULT 1 COMMENT '最小触发层数',

    -- 触发的最大层数
    max_floor INT DEFAULT 999 COMMENT '最大触发层数',

    -- 事件效果（JSON格式存储）
    -- 示例：{"health": -20, "gold": 50, "item_id": 1}
    effect_data JSON COMMENT '事件效果数据',

    -- 选项1文本
    option1_text VARCHAR(200) COMMENT '选项1文本',

    -- 选项1效果（JSON格式）
    option1_effect JSON COMMENT '选项1效果',

    -- 选项2文本
    option2_text VARCHAR(200) COMMENT '选项2文本',

    -- 选项2效果（JSON格式）
    option2_effect JSON COMMENT '选项2效果',

    -- 事件图标路径
    icon_path VARCHAR(255) COMMENT '图标路径',

    -- 是否为AI生成的内容
    is_ai_generated TINYINT(1) DEFAULT 0 COMMENT '是否AI生成',

    -- AI生成记录ID
    ai_generation_id INT COMMENT 'AI生成记录ID',

    -- 是否启用
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 索引
    INDEX idx_event_type (event_type),
    INDEX idx_trigger_floor (min_floor, max_floor),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='随机事件表';


-- ============================================================
-- 6. Roguelike地图数据表 (maps)
-- 说明: 存储地图配置和房间布局数据
-- ============================================================
CREATE TABLE IF NOT EXISTS maps (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '地图ID',

    -- 地图名称
    name VARCHAR(100) NOT NULL COMMENT '地图名称',

    -- 地图描述
    description TEXT COMMENT '地图描述',

    -- 地图主题：dungeon-地牢, cave-洞穴, castle-城堡, forest-森林
    theme ENUM('dungeon', 'cave', 'castle', 'forest', 'volcano', 'ice') DEFAULT 'dungeon' COMMENT '地图主题',

    -- 地图对应的层数
    floor_level INT NOT NULL COMMENT '层数',

    -- 地图宽度（格子数）
    width INT DEFAULT 20 COMMENT '地图宽度',

    -- 地图高度（格子数）
    height INT DEFAULT 15 COMMENT '地图高度',

    -- 房间数量
    room_count INT DEFAULT 8 COMMENT '房间数量',

    -- 房间数据（JSON格式存储房间位置和类型）
    room_data JSON COMMENT '房间数据',

    -- 走廊数据（JSON格式）
    corridor_data JSON COMMENT '走廊数据',

    -- 怪物生成配置（JSON格式）
    monster_spawn_config JSON COMMENT '怪物生成配置',

    -- 事件生成配置（JSON格式）
    event_spawn_config JSON COMMENT '事件生成配置',

    -- 宝箱位置（JSON格式）
    treasure_positions JSON COMMENT '宝箱位置',

    -- 出口位置（JSON格式）
    exit_position JSON COMMENT '出口位置',

    -- 难度等级（1-10）
    difficulty INT DEFAULT 1 COMMENT '难度等级',

    -- 是否为AI生成的地图
    is_ai_generated TINYINT(1) DEFAULT 0 COMMENT '是否AI生成',

    -- AI生成记录ID
    ai_generation_id INT COMMENT 'AI生成记录ID',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 索引
    INDEX idx_floor_level (floor_level),
    INDEX idx_theme (theme),
    INDEX idx_difficulty (difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Roguelike地图数据表';


-- ============================================================
-- 7. 游戏存档表 (game_saves)
-- 说明: 存储玩家的游戏进度存档
-- ============================================================
CREATE TABLE IF NOT EXISTS game_saves (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '存档ID',

    -- 关联用户ID
    user_id INT NOT NULL COMMENT '用户ID',

    -- 存档名称
    save_name VARCHAR(100) NOT NULL COMMENT '存档名称',

    -- 当前层数
    current_floor INT DEFAULT 1 COMMENT '当前层数',

    -- 玩家状态数据（JSON格式）
    -- 包含：生命值、攻击力、防御力、金币、经验值等
    player_state JSON NOT NULL COMMENT '玩家状态数据',

    -- 背包数据（JSON格式）
    -- 包含：武器、道具列表
    inventory_data JSON COMMENT '背包数据',

    -- 当前地图数据（JSON格式）
    current_map_data JSON COMMENT '当前地图数据',

    -- 已探索的地图历史（JSON格式）
    explored_maps JSON COMMENT '已探索地图',

    -- 游戏时长（秒）
    play_time INT DEFAULT 0 COMMENT '游戏时长(秒)',

    -- 击杀怪物数
    kill_count INT DEFAULT 0 COMMENT '击杀怪物数',

    -- 收集金币总数
    gold_collected INT DEFAULT 0 COMMENT '收集金币总数',

    -- 存档槽位（1-3，支持多个存档）
    slot_number TINYINT NOT NULL COMMENT '存档槽位',

    -- 是否为当前活跃存档
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否活跃存档',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 更新时间
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    -- 外键约束
    CONSTRAINT fk_game_saves_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    -- 唯一约束：每个用户每个槽位只能有一个存档
    UNIQUE KEY uk_user_slot (user_id, slot_number),

    -- 索引
    INDEX idx_user_id (user_id),
    INDEX idx_current_floor (current_floor),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='游戏存档表';


-- ============================================================
-- 8. AI动态内容生成记录表 (ai_generations)
-- 说明: 记录所有AI内容生成的请求和结果
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_generations (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '生成记录ID',

    -- 关联用户ID（可为空，系统生成时不关联用户）
    user_id INT COMMENT '用户ID',

    -- 生成内容类型：weapon-武器, monster-怪物, event-事件, map-地图, story-剧情
    content_type ENUM('weapon', 'monster', 'event', 'map', 'story', 'dialogue') NOT NULL COMMENT '内容类型',

    -- AI模型名称
    model_name VARCHAR(100) NOT NULL COMMENT 'AI模型名称',

    -- 发送给AI的提示词（Prompt）
    prompt TEXT NOT NULL COMMENT '提示词',

    -- AI返回的原始响应
    raw_response TEXT COMMENT '原始响应',

    -- 解析后的结构化数据（JSON格式）
    parsed_data JSON COMMENT '解析后数据',

    -- 生成状态：pending-待处理, success-成功, failed-失败
    status ENUM('pending', 'success', 'failed') DEFAULT 'pending' COMMENT '生成状态',

    -- 错误信息（如果生成失败）
    error_message TEXT COMMENT '错误信息',

    -- 请求耗时（毫秒）
    request_duration INT COMMENT '请求耗时(毫秒)',

    -- 使用的Token数量
    tokens_used INT COMMENT 'Token使用量',

    -- 是否已应用到游戏中
    is_applied TINYINT(1) DEFAULT 0 COMMENT '是否已应用',

    -- 应用到的游戏存档ID
    applied_save_id INT COMMENT '应用的存档ID',

    -- 用户评分（1-5，用于评估AI生成质量）
    user_rating TINYINT COMMENT '用户评分',

    -- 用户反馈
    user_feedback TEXT COMMENT '用户反馈',

    -- 创建时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    -- 外键约束
    CONSTRAINT fk_ai_generations_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_ai_generations_save FOREIGN KEY (applied_save_id) REFERENCES game_saves(id) ON DELETE SET NULL,

    -- 索引
    INDEX idx_user_id (user_id),
    INDEX idx_content_type (content_type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI动态内容生成记录表';


-- ============================================================
-- 添加外键约束（weapons和monsters表引用ai_generations）
-- ============================================================

-- 武器表的AI生成记录外键
ALTER TABLE weapons
    ADD CONSTRAINT fk_weapons_ai_generation
    FOREIGN KEY (ai_generation_id) REFERENCES ai_generations(id)
    ON DELETE SET NULL;

-- 怪物表的AI生成记录外键
ALTER TABLE monsters
    ADD CONSTRAINT fk_monsters_ai_generation
    FOREIGN KEY (ai_generation_id) REFERENCES ai_generations(id)
    ON DELETE SET NULL;

-- 事件表的AI生成记录外键
ALTER TABLE events
    ADD CONSTRAINT fk_events_ai_generation
    FOREIGN KEY (ai_generation_id) REFERENCES ai_generations(id)
    ON DELETE SET NULL;

-- 地图表的AI生成记录外键
ALTER TABLE maps
    ADD CONSTRAINT fk_maps_ai_generation
    FOREIGN KEY (ai_generation_id) REFERENCES ai_generations(id)
    ON DELETE SET NULL;


-- ============================================================
-- 数据表创建完成
-- ============================================================
-- 已创建的表:
-- 1. users             - 用户账号表
-- 2. player_profiles   - 玩家角色信息表
-- 3. weapons           - 武器数据表
-- 4. monsters          - 怪物数据表
-- 5. events            - 随机事件表
-- 6. maps              - 地图数据表
-- 7. game_saves        - 游戏存档表
-- 8. ai_generations    - AI生成记录表
-- ============================================================
