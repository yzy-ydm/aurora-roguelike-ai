# 项目任务跟踪

## 当前阶段

**阶段**: P0 Bug 修复 + 最小可玩版本验证  
**目标**: 确保核心战斗闭环、平台碰撞、存档系统全部可用

---

## 已完成任务

| ID | 任务 | 状态 | 日期 |
|---|---|---|---|
| TASK-001~006 | 奖励系统/楼层生成基础 | ✅ 已提交 (62df83c→84eecb3) | 2026-09-23 |
| TASK-017~018 | 怪物AI坐标修复/速度平衡 | ✅ 已提交 | 2026-09-24 |
| TASK-019~030 | 存档系统/AI内容闭环/生命周期 | ✅ 已提交 | 2026-09-24 |
| **TASK-fix-C01** | **平台单向碰撞修复** | ✅ 已完成 | 2026-10-18 |
| **TASK-fix-C02** | **商店/事件/宝箱房平台Y坐标修复** | ✅ 已完成 | 2026-10-18 |
| **TASK-fix-B03** | **怪物碰撞掩码修复（移除无效256位）** | ✅ 已完成 | 2026-10-18 |
| **TASK-fix-CONTACT** | **怪物接触伤害兜底系统** | ✅ 已完成 | 2026-10-18 |
| **TASK-fix-AUDIT** | **全面审计 + 修复额外发现问题** | ✅ 已完成 | 2026-10-18 |

---

## 待验收任务（本次新增）

### TASK-fix-C01: 平台单向碰撞
- **问题**: C-01 — 平台使用普通 CollisionShape2D，玩家无法从下方跳上
- **修复**: 实现自定义单向碰撞系统（Godot 4.7 不支持 OneWayCollisionShape2D）
  - 平台 StaticBody2D 添加 `is_one_way = true` meta
  - 玩家物理帧检测接触的平台
  - 上升时禁用碰撞形状，离开时恢复
- **修改文件**: `client/scripts/world/room_renderer.gd`, `client/scripts/player/player_controller.gd`
- **验收方式**: 游戏中尝试从平台下方跳跃 → 能跳上平台

### TASK-fix-C02: 特殊房间平台位置
- **问题**: C-03 — 商店/事件/宝箱房平台Y坐标为旧俯视角残留值（y=15~20），远低于地面(y=296)
- **修复**: 使用 `GROUND_Y - 50` 等合理值
- **修改文件**: `client/scripts/world/room_renderer.gd`
- **验收方式**: 进入商店/事件/宝箱房，平台在地面附近可见

### TASK-fix-B03: 怪物碰撞掩码
- **问题**: B-03 — 怪物 collision_mask=263 含无效 256 位（应为 8）
- **修复**: 改为 15 (1+2+4+8)，同时修正碰撞层 4→8
- **修改文件**: `client/scripts/enemy/monster_node.gd`
- **验收方式**: 怪物碰撞检测更准确

### TASK-fix-CONTACT: 怪物接触伤害
- **问题**: B-02c — 怪物攻击只有技能伤害，无接触兜底
- **修复**: 添加 `_try_contact_damage()`，范围 40px，冷却 0.5s
- **修改文件**: `client/scripts/enemy/monster_ai.gd`
- **验收方式**: 怪物贴脸时玩家也会受伤

---

## 尚未完成（P1 优先级）

| ID | 任务 | 阻塞原因 |
|---|---|---|
| P1-1 | 武器伤害双计 + 玩家双重减伤修复 | 需要数值联动实测 |
| P1-2 | 暴击成长接线 | 低优先级 |
| P1-4 | context_event 面板接线 | 低优先级 |
| P1-5 | Boss 多阶段技能决策 | 需评估风险 |

---

## 已知问题

| ID | 问题 | 影响等级 | 状态 |
|---|---|---|---|
| S-05 | save_system.gd 本地存档死代码 | P2 | 已在 TASK-030 删除 |
| S-06 | kill_count/gold_collected 无累加 | P2 | 非阻断性 |
| P-01 | 玩家出生点 y=298 嵌入地面 18px | P2 | 物理自动推出，可忽略 |

---

## 已执行的测试

### Godot 无头启动验证
```
命令: D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe --headless --path D:/GraduationProject/client --quit
结果: ✅ 0 脚本错误，正常启动到登录界面
```

### Godot 编辑器启动验证
```
命令: Godot_v4.7-stable_win64_console.exe --headless --editor --path D:/GraduationProject/client --quit
结果: ✅ 0 解析错误，编辑器布局正常加载
```

### 服务端测试
```
命令: cd D:/GraduationProject/server/ai && venv/Scripts/python.exe -m pytest tests/ -q
        cd D:/GraduationProject/server/app && venv/Scripts/python.exe -m pytest tests/ -q
结果: ✅ 143 ai + 5 app = 148 passed
```

---

## 当前项目结构

```
D:\GraduationProject\
├── client/                      # Godot 4.7 客户端
│   ├── project.godot            # 项目名称: Aurora Roguelike AI
│   ├── scenes/                  # 场景文件
│   ├── scripts/                 # GDScript 脚本
│   │   ├── enemy/               # 怪物 AI（已修复）
│   │   ├── world/               # 房间渲染（已修复 C-01/C-03）
│   │   ├── combat/              # 战斗系统
│   │   ├── services/            # 存档服务（已修复 S-01/S-02）
│   │   └── managers/            # 游戏流程管理
│   └── tests/                   # 50 个测试文件
├── server/                      # FastAPI 服务端
│   ├── app/                     # 游戏 API
│   └── ai/                      # AI 服务（143 项测试通过）
├── database/                    # MySQL 数据库
├── docs/                        # 架构文档
├── AUDIT_REPORT_2026-10-18.md   # 本次审计报告
└── TASK-*-REPORT.md             # 各任务报告
```

---

## 重要技术决策

1. **平台碰撞**: 实现自定义单向碰撞系统（Godot 4.7 不支持 OneWayCollisionShape2D），通过 meta 标记 + 动态禁用碰撞形状实现
2. **怪物 AI**: 已使用 `global_position` 统一坐标系（TASK-017.7）
3. **速度钳制**: `_do_chase` 和 `_do_attack` 中 `clampf(speed, 60, 150)` 确保合理移动速度
4. **接触伤害**: 作为攻击前摇/CD 的兜底机制，0.5s 冷却防止秒杀
5. **碰撞层**: 统一使用 Layer 8 作为 Enemy/PlayerBullet，Layer 16 作为 EnemyBullet

---

## 下一步实际行动

1. **等待用户人工验收** 以下 4 项修复：
   - 进入战斗房 → 怪物应追击并攻击玩家
   - 尝试从平台下方跳跃 → 应能跳上平台
   - 进入商店/事件房 → 平台应在合理高度
   - 怪物贴脸 → 玩家应受到接触伤害

2. 验收通过后：
   - 提交本次修复到 git
   - 更新 PROJECT_CURRENT_STATUS.md
   - 继续 P1 优先级任务或论文文档工作
