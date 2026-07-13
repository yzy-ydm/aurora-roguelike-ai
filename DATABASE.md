# DATABASE.md

> Aurora-Roguelike-AI 数据库设计文档

最后更新：2026-07-13

---

## 数据库概述

| 项目 | 值 |
|------|-----|
| 数据库名称 | aurora_game |
| 数据库类型 | MySQL 8.0 |
| 字符集 | utf8mb4 |
| 排序规则 | utf8mb4_unicode_ci |
| 存储引擎 | InnoDB |

---

## 数据表清单

| 序号 | 表名 | 说明 | 状态 |
|------|------|------|------|
| 1 | users | 用户账号表 | ✅ 已使用 |
| 2 | player_profiles | 玩家角色信息表 | ✅ 已使用 |
| 3 | weapons | 武器数据表 | ✅ 已使用 |
| 4 | monsters | 怪物数据表 | ✅ 已使用 |
| 5 | events | 随机事件表 | ✅ 已使用 |
| 6 | maps | 地图数据表 | ✅ 已使用 |
| 7 | game_saves | 游戏存档表 | ✅ 已使用 |
| 8 | ai_generations | AI生成记录表 | ⬜ 待使用 |
| 9 | player_weapons | 玩家武器关联表 | ✅ 已使用 |

---

## 表结构详细说明

### 1. users - 用户账号表

**用途:** 存储系统用户账号信息

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| username | VARCHAR(50) | 是 | - | 用户名（唯一） |
| password_hash | VARCHAR(255) | 是 | - | 密码哈希 |
| email | VARCHAR(100) | 否 | NULL | 邮箱（唯一） |
| is_active | TINYINT(1) | 否 | 1 | 是否启用 |
| last_login_at | DATETIME | 否 | NULL | 最后登录时间 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | 否 | 自动更新 | 更新时间 |
| is_deleted | TINYINT(1) | 否 | 0 | 软删除标记 |

**索引:**
- PRIMARY KEY (id)
- UNIQUE INDEX (username)
- UNIQUE INDEX (email)
- INDEX (is_active)

**当前状态:** 已使用，存储注册用户数据

---

### 2. player_profiles - 玩家角色信息表

**用途:** 存储玩家游戏角色属性和统计数据

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| user_id | INT | 是 | - | 外键，关联users表 |
| nickname | VARCHAR(50) | 是 | - | 角色昵称 |
| level | INT | 否 | 1 | 等级 |
| experience | INT | 否 | 0 | 当前经验 |
| experience_to_next_level | INT | 否 | 100 | 升级所需经验 |
| max_health | INT | 否 | 100 | 最大生命值 |
| current_health | INT | 否 | 100 | 当前生命值 |
| attack | INT | 否 | 10 | 攻击力 |
| defense | INT | 否 | 5 | 防御力 |
| crit_rate | DECIMAL(5,2) | 否 | 5.00 | 暴击率(%) |
| gold | INT | 否 | 0 | 金币 |
| total_play_time | INT | 否 | 0 | 总游戏时长(秒) |
| max_floor_reached | INT | 否 | 1 | 最高层数 |
| total_kills | INT | 否 | 0 | 击杀数 |
| death_count | INT | 否 | 0 | 死亡次数 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | 否 | 自动更新 | 更新时间 |

**索引:**
- PRIMARY KEY (id)
- UNIQUE INDEX (user_id)
- INDEX (level)

**外键:**
- user_id → users.id (CASCADE)

**当前状态:** 已使用，Phase 4.3 玩家角色系统已实现

---

### 3. weapons - 武器数据表

**用途:** 存储游戏武器基础数据

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| name | VARCHAR(100) | 是 | - | 武器名称 |
| description | TEXT | 否 | - | 武器描述 |
| weapon_type | ENUM | 是 | - | 武器类型 |
| rarity | ENUM | 否 | common | 稀有度 |
| attack_bonus | INT | 否 | 0 | 攻击加成 |
| crit_rate_bonus | DECIMAL(5,2) | 否 | 0.00 | 暴击率加成 |
| special_effect | TEXT | 否 | - | 特殊效果 |
| special_effect_data | JSON | 否 | - | 效果数据 |
| icon_path | VARCHAR(255) | 否 | - | 图标路径 |
| price | INT | 否 | 0 | 价格 |
| is_ai_generated | TINYINT(1) | 否 | 0 | 是否AI生成 |
| ai_generation_id | INT | 否 | - | AI生成记录ID |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |

**枚举值:**
- weapon_type: sword, axe, bow, staff, dagger, spear, hammer
- rarity: common, uncommon, rare, epic, legendary

**当前状态:** 已使用，Phase 4.4 武器系统已实现

---

### 4. monsters - 怪物数据表

**用途:** 存储游戏怪物基础数据

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| name | VARCHAR(100) | 是 | - | 怪物名称 |
| description | TEXT | 否 | - | 怪物描述 |
| monster_type | ENUM | 否 | normal | 怪物类型 |
| level | INT | 否 | 1 | 等级 |
| health | INT | 是 | - | 生命值 |
| attack | INT | 是 | - | 攻击力 |
| defense | INT | 是 | - | 防御力 |
| speed | INT | 否 | 10 | 速度 |
| experience_reward | INT | 否 | 10 | 经验奖励 |
| gold_reward | INT | 否 | 5 | 金币奖励 |
| special_ability | TEXT | 否 | - | 特殊能力 |
| special_ability_data | JSON | 否 | - | 能力数据 |
| min_floor | INT | 否 | 1 | 最小层数 |
| max_floor | INT | 否 | 999 | 最大层数 |
| is_ai_generated | TINYINT(1) | 否 | 0 | 是否AI生成 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |

**枚举值:**
- monster_type: normal, elite, boss

**当前状态:** 已使用，Phase 4.5 怪物系统已实现

---

### 5. events - 随机事件表

**用途:** 存储游戏随机事件数据

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| name | VARCHAR(100) | 是 | - | 事件名称 |
| description | TEXT | 是 | - | 事件描述 |
| event_type | ENUM | 是 | - | 事件类型 |
| trigger_rate | DECIMAL(5,2) | 否 | 10.00 | 触发概率(%) |
| min_floor | INT | 否 | 1 | 最小层数 |
| max_floor | INT | 否 | 999 | 最大层数 |
| effect_data | JSON | 否 | - | 效果数据 |
| option1_text | VARCHAR(200) | 否 | - | 选项1文本 |
| option1_effect | JSON | 否 | - | 选项1效果 |
| option2_text | VARCHAR(200) | 否 | - | 选项2文本 |
| option2_effect | JSON | 否 | - | 选项2效果 |
| is_active | TINYINT(1) | 否 | 1 | 是否启用 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |

**枚举值:**
- event_type: treasure, trap, merchant, npc, mystery, rest, combat

**当前状态:** 已使用，Phase 4.6.3 事件资源接口已实现

---

### 6. maps - 地图数据表

**用途:** 存储Roguelike地图配置数据

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| name | VARCHAR(100) | 是 | - | 地图名称 |
| description | TEXT | 否 | - | 地图描述 |
| theme | ENUM | 否 | dungeon | 地图主题 |
| floor_level | INT | 是 | - | 层数 |
| width | INT | 否 | 20 | 宽度 |
| height | INT | 否 | 15 | 高度 |
| room_count | INT | 否 | 8 | 房间数 |
| room_data | JSON | 否 | - | 房间数据 |
| monster_spawn_config | JSON | 否 | - | 怪物配置 |
| event_spawn_config | JSON | 否 | - | 事件配置 |
| difficulty | INT | 否 | 1 | 难度等级 |
| is_ai_generated | TINYINT(1) | 否 | 0 | 是否AI生成 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |

**枚举值:**
- theme: dungeon, cave, castle, forest, volcano, ice

**当前状态:** 已使用，Phase 4.6.2 地图资源接口已实现

---

### 7. game_saves - 游戏存档表

**用途:** 存储玩家游戏进度

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| user_id | INT | 是 | - | 外键，关联users |
| save_name | VARCHAR(100) | 是 | - | 存档名称 |
| current_floor | INT | 否 | 1 | 当前层数 |
| player_state | JSON | 是 | - | 玩家状态 |
| inventory_data | JSON | 否 | - | 背包数据 |
| current_map_data | JSON | 否 | - | 当前地图 |
| play_time | INT | 否 | 0 | 游戏时长 |
| kill_count | INT | 否 | 0 | 击杀数 |
| gold_collected | INT | 否 | 0 | 收集金币 |
| slot_number | TINYINT | 是 | - | 存档槽位 |
| is_active | TINYINT(1) | 否 | 1 | 是否活跃 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | 否 | 自动更新 | 更新时间 |

**当前状态:** 已使用，Phase 4.6.1 游戏存档系统已实现

---

### 8. ai_generations - AI生成记录表

**用途:** 记录AI内容生成历史

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| user_id | INT | 否 | - | 触发用户 |
| content_type | ENUM | 是 | - | 内容类型 |
| model_name | VARCHAR(100) | 是 | - | AI模型 |
| prompt | TEXT | 是 | - | 提示词 |
| raw_response | TEXT | 否 | - | 原始响应 |
| parsed_data | JSON | 否 | - | 解析数据 |
| status | ENUM | 否 | pending | 生成状态 |
| request_duration | INT | 否 | - | 请求耗时 |
| tokens_used | INT | 否 | - | Token用量 |
| is_applied | TINYINT(1) | 否 | 0 | 是否应用 |
| user_rating | TINYINT | 否 | - | 用户评分 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |

**枚举值:**
- content_type: weapon, monster, event, map, story, dialogue
- status: pending, success, failed

**当前状态:** 待使用

---

### 9. player_weapons - 玩家武器关联表

**用途:** 记录玩家拥有哪些武器

**字段说明:**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | INT | 是 | 自增 | 主键 |
| player_id | INT | 是 | - | 外键，关联player_profiles表 |
| weapon_id | INT | 是 | - | 外键，关联weapons表 |
| is_equipped | TINYINT(1) | 否 | 0 | 是否装备中 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 获取时间 |

**索引:**
- PRIMARY KEY (id)
- INDEX (player_id)
- INDEX (weapon_id)
- INDEX (is_equipped)

**外键:**
- player_id → player_profiles.id (CASCADE)
- weapon_id → weapons.id (CASCADE)

**当前状态:** 已使用，Phase 4.4 武器系统已实现

---

## 表关系图

```
users ──1:1──→ player_profiles ──1:N──→ player_weapons ──N:1──→ weapons
  │
  ├──1:N──→ game_saves
  │
  └──1:N──→ ai_generations ──1:N──→ weapons
                           ──1:N──→ monsters
                           ──1:N──→ events
                           ──1:N──→ maps
```

---

## SQL文件位置

| 文件 | 说明 |
|------|------|
| database/sql/create_database.sql | 创建数据库 |
| database/sql/create_tables.sql | 创建数据表 |
| database/sql/create_player_weapons_table.sql | 玩家武器关联表 |
| database/sql/insert_test_data.sql | 测试数据 |
| database/design/数据库设计说明.md | 设计文档 |
