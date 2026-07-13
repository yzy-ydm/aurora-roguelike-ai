---
name: godot4-development
description: Godot 4开发辅助技能，用于GDScript代码审查、Scene结构分析、Node设计、Signal管理
version: 1.0.0
tags: [godot, gamedev, gdscript, scene, signal]
---

# Godot 4 开发辅助技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的 Godot 4 客户端开发辅助。

## GDScript 代码规范

### 命名规范

```gdscript
# 类名：PascalCase
class_name MonsterEntity

# 变量：snake_case
var health: int = 100
var _private_var: String = ""

# 常量：SCREAMING_SNAKE_CASE
const MAX_HEALTH: int = 100

# 函数：snake_case
func take_damage(amount: int) -> void:
    pass

# 信号：snake_case
signal health_changed(old_value: int, new_value: int)
```

### 类型注解

```gdscript
# 变量类型
var health: int = 100
var name: String = ""
var position: Vector2 = Vector2.ZERO

# 函数类型
func get_health() -> int:
    return health

# 数组类型
var items: Array[String] = []
```

## Scene 结构分析

### 节点树最佳实践

```
GameScene (Node2D)
├── GameWorld (Node2D)
│   ├── Player (CharacterBody2D)
│   └── MonsterContainer (Node2D)
├── UI (CanvasLayer)
│   └── HUD (Control)
└── Managers (Node)
    └── CombatManager (Node)
```

### 节点设计原则

1. **单一职责**：每个节点只负责一个功能
2. **组合优于继承**：使用子节点组合功能
3. **信号解耦**：使用信号进行模块间通信

## Signal 管理

### 信号定义

```gdscript
# 定义信号
signal health_changed(old_value: int, new_value: int)
signal died()

# 发送信号
health_changed.emit(old_health, new_health)
died.emit()
```

### 信号连接

```gdscript
# 在_ready中连接
func _ready() -> void:
    health_changed.connect(_on_health_changed)

# 回调函数
func _on_health_changed(old_value: int, new_value: int) -> void:
    print("Health changed: ", old_value, " -> ", new_value)
```

## 项目特定规范

### AI模块结构

```
client/scripts/ai/
├── ai_content_service.gd    # 统一接口
├── fake_ai_service.gd       # 本地模拟
├── ai_validator.gd          # 数据验证
├── ai_quality_checker.gd    # 质量检查
├── ai_cache_manager.gd      # 缓存管理
└── ai_response_parser.gd    # JSON解析
```

### 数据模型结构

```
client/scripts/models/
├── room_content_data.gd     # 房间内容
├── room_node_data.gd        # 房间节点
├── monster_data.gd          # 怪物数据
├── weapon_data.gd           # 武器数据
└── reward_data.gd           # 奖励数据
```

## 使用场景

当需要：
- 审查GDScript代码
- 分析Scene结构
- 设计Node架构
- 管理Signal连接
- 重构游戏代码
