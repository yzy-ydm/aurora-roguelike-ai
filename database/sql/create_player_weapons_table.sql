-- ============================================================
-- 基于云端AI动态内容生成的Roguelike游戏系统
-- 玩家武器关联表创建脚本
-- ============================================================
-- 文件: create_player_weapons_table.sql
-- 说明: 创建玩家武器关联表，记录玩家拥有的武器
-- 数据库: MySQL 8.0
-- ============================================================

-- 使用数据库
USE aurora_game;

-- ============================================================
-- 玩家武器关联表 (player_weapons)
-- 说明: 记录玩家拥有哪些武器
-- ============================================================
CREATE TABLE IF NOT EXISTS player_weapons (
    -- 主键ID
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '记录ID',

    -- 玩家档案ID（关联player_profiles表）
    player_id INT NOT NULL COMMENT '玩家档案ID',

    -- 武器ID（关联weapons表）
    weapon_id INT NOT NULL COMMENT '武器ID',

    -- 是否装备中
    is_equipped TINYINT(1) DEFAULT 0 COMMENT '是否装备中: 0-未装备, 1-已装备',

    -- 获取时间
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '获取时间',

    -- 外键约束
    CONSTRAINT fk_player_weapons_player FOREIGN KEY (player_id) REFERENCES player_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_weapons_weapon FOREIGN KEY (weapon_id) REFERENCES weapons(id) ON DELETE CASCADE,

    -- 唯一约束：同一玩家不能重复拥有同一武器（但可以有多个记录用于未来扩展）
    -- 这里使用组合索引而非唯一约束，允许未来扩展
    INDEX idx_player_id (player_id),
    INDEX idx_weapon_id (weapon_id),
    INDEX idx_is_equipped (is_equipped)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='玩家武器关联表';
