# AI内容生成质量保障体系分析

> 生成日期：2026-09-22
> 目的：为质量保障体系建设提供设计基础

---

## 一、当前AI生成流程

```
AI Provider.generate(prompt)
    ↓
返回 JSON 文本
    ↓
_parse_json() → Dict[str, Any]
    ↓
AIValidator.validate_*()
    ├─ 检查必需字段
    ├─ 检查类型
    └─ 修复缺失字段
    ↓
AIQualityChecker.check_*()
    ├─ 检查数值范围
    └─ 裁剪越界值
    ↓
缓存 + 返回
```

### 各生成方法的验证链路

| 方法 | 验证器 | 质量检查器 |
|------|--------|-----------|
| `generate_floor()` | `validate_floor_data()` | `check_floor_quality()` |
| `generate_room_content()` | `validate_room_content()` | `check_room_content_quality()` |
| `generate_monsters()` | `validate_monster_data()` | `check_monster_quality()` |
| `generate_weapon()` | `validate_weapon_data()` | `check_weapon_quality()` |
| `generate_event()` | 无 | 无 |
| `generate_dialogue()` | 无 | 无 |
| `generate_upgrade()` | 无 | 无 |
| `generate_difficulty()` | 无 | 无 |

---

## 二、当前验证机制分析

### 2.1 AIValidator (现有)

**覆盖内容：**
- ✅ JSON结构合法性
- ✅ 必需字段检查
- ✅ 类型检查
- ✅ 基础默认值修复

**缺失内容：**
- ❌ 数值范围验证（HP/Attack/Defense无上限检查）
- ❌ 游戏平衡性检查（数值合理性）
- ❌ 枚举值验证（房间类型/稀有度）
- ❌ 跨字段关联验证（如total_count与monsters长度）

### 2.2 AIQualityChecker (现有)

**覆盖内容：**
- ✅ difficulty范围 (1-10)
- ✅ monster count范围 (1-10)
- ✅ reward quality范围 (0.1-3.0)
- ✅ weapon damage范围 (1-999)
- ✅ weapon rarity枚举
- ✅ monster level范围 (相对玩家等级)

**缺失内容：**
- ❌ HP范围验证（Monster HP无检查！）
- ❌ Attack范围验证（Monster Attack无检查！）
- ❌ Defense范围验证（Monster Defense无检查！）
- ❌ 综合质量评分
- ❌ 多样性检查
- ❌ 失败率统计

---

## 三、存在风险分析

### 3.1 高风险问题

| # | 风险 | 影响 | 优先级 |
|---|------|------|--------|
| 1 | Monster HP无范围验证 | AI可能生成HP=999999的怪物 | 🔴 P0 |
| 2 | Monster Attack无范围验证 | AI可能生成Attack=9999的怪物 | 🔴 P0 |
| 3 | Monster Defense无范围验证 | AI可能生成Defense=9999的怪物 | 🔴 P0 |
| 4 | 无质量评分 | 无法量化AI生成质量 | 🟡 P1 |
| 5 | 部分接口无验证 | event/dialogue/upgrade无校验 | 🟡 P1 |

### 3.2 已观测问题

用户验收时发现：**部分AI生成怪物存在血量过高问题**

这证明现有的QualityChecker缺少对Monster HP的验证！

---

## 四、增强方案

### 4.1 Validator增强

**新增验证规则：**
```python
# 怪物属性范围
MONSTER_HP_MIN = 10
MONSTER_HP_MAX = 500    # 当前MAX_HEALTH=9999过高
MONSTER_ATTACK_MIN = 1
MONSTER_ATTACK_MAX = 100
MONSTER_DEFENSE_MIN = 0
MONSTER_DEFENSE_MAX = 50

# 房间枚举验证
VALID_ROOM_TYPES = {"start", "combat", "elite", "boss", "reward", "treasure", "shop", "event"}

# 武器稀有度验证
VALID_RARITIES = {"common", "uncommon", "rare", "epic", "legendary"}
```

### 4.2 QualityChecker增强

**新增评分维度：**
```python
# 四维度评分模型
DIMENSIONS = {
    "legality":    {"weight": 0.30, "desc": "字段完整性和格式正确性"},
    "balance":     {"weight": 0.30, "desc": "数值在游戏平衡范围内"},
    "diversity":   {"weight": 0.20, "desc": "与历史生成的差异化程度"},
    "completeness":{"weight": 0.20, "desc": "必需字段齐全度"}
}

# 返回 quality_score (0-100)
# 例如: 85/100
```

### 4.3 生成记录增强

**新增记录字段：**
```python
# ai_generations表新增
- provider_name: str         # "agnes" / "mimo" / "mock"
- quality_score: int         # 0-100
- validation_passed: bool    # 是否通过所有验证
- dimension_scores: JSON     # 各维度得分
```

---

## 五、实现策略

### 5.1 不改动的部分

- ❌ 不修改Provider架构（Agnes/Mimo保持）
- ❌ 不修改AIService核心生成逻辑
- ❌ 不修改Godot客户端
- ❌ 不修改现有测试（114个必须保持通过）

### 5.2 新增/修改的部分

| 操作 | 文件 | 说明 |
|------|------|------|
| **修改** | `ai_validator.py` | 增加数值范围验证 |
| **修改** | `ai_quality_checker.py` | 增加质量评分系统 |
| **新增** | `content_validator.py` | 通用内容验证器 |
| **新增** | `generation_logger.py` | 生成记录工具 |
| **新增** | `test_content_validator.py` | 验证器测试 |
| **新增** | `test_quality_checker.py` | 质量检查器测试 |

---

## 六、向后兼容性保证

| 场景 | 行为 |
|------|------|
| AI生成合法数据 | 通过验证，quality_score正常 |
| AI生成越界数据 | 自动裁剪到合理范围 |
| AI生成缺失字段 | 自动填充默认值 |
| AI生成完全非法 | 降级到Mock |
| 无API Key时 | 继续使用Mock |

---

*分析完成，准备开始编码实现。*
