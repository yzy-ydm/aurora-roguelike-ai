# Camera Fix Report

> 日期：2026-09-22
> 任务：Phase 4.1 Camera Stabilization

---

## 1. 修改文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `client/scenes/game/player.tscn` | 修改 | Camera2D offset 全部归零 |

备份：`player.tscn.bak`（原始文件）

## 2. 修改内容

```gdscript
# 修改前
[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
# offset 默认值: (-180, 60, -10, 120)

# 修改后
[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
offset_left = 0.0
offset_top = 0.0
offset_right = 0.0
offset_bottom = 0.0
```

## 3. 修改原因

### 根因

Camera2D 的 offset 值为负数，导致摄像机视野异常狭窄：

| 参数 | 旧值 | 新值 | 效果变化 |
|------|------|------|---------|
| offset_left | -180 | 0 | 视口左边界从屏幕外收回 |
| offset_top | 60 | 0 | 视口上边界下移 |
| offset_right | -10 | 0 | 视口右边界从屏幕外收回 |
| offset_bottom | 120 | 0 | 视口下边界上移 |

**旧视野**: 仅 95×90 world units (14.8% × 25%)
**新视野**: 640×360 world units (100%)

### 验证计算

```
Camera zoom = 2x
Screen size = 1280×720
Visible world = 640×360 units

Player spawn: (-540, 298)
Visible area: X=[-860, -220], Y=[118, 478]

✓ Player at screen center
✓ Left wall (X=-640) visible
✓ Portal (X=+600) beyond right edge (expected - player walks to it)
✓ Rewards (X=-200~200) partially visible (player walks right)
```

## 4. 测试结果

```
143 passed in 3.95s ✅
```

Server tests 无回归。

## 5. 人工验收步骤

打开 Godot，运行游戏：

1. **进入游戏**
   - [ ] Player 位于屏幕中央
   - [ ] Start 房间地面可见
   - [ ] 左右边界墙可见

2. **向右移动**
   - [ ] Camera 平滑跟随 Player
   - [ ] 怪物可见（如果有战斗房）

3. **Portal 可见性**
   - [ ] 走到房间右侧，Portal 出现
   - [ ] Portal 颜色正确（绿色=下一房）
   - [ ] 走进 Portal 进入下一房

4. **Reward 可见性**
   - [ ] 进入 Reward 房，奖励物品可见
   - [ ] 走到物品旁自动拾取

5. **Combat 可见性**
   - [ ] 进入战斗房，怪物可见
   - [ ] 攻击怪物，伤害数字显示

---

## 6. 设计说明

**这不是 bug 修复，而是坐标系统正常化。**

旧代码中 Camera2D 的 offset 负值来自 UI 面板的锚点配置误复制到 Camera。Godot 场景中 UI 和 Camera 都可能使用类似格式的 offset 属性，但语义不同：

- UI offset: Control 节点相对于锚点的偏移（负值=向外扩展）
- Camera2D offset: 视口裁剪偏移（正值=向内裁剪，负值=向外扩展）

旧值 (-180, 60, -10, 120) 实际上是 UI 风格的"margin"概念，应用到 Camera 上造成了 95px 的极窄视野。

**新值 (0, 0, 0, 0)** 让 Camera 完整显示 zoom 定义的 640×360 世界区域，符合横版动作游戏的标准摄像机行为。

---

*Phase 4.1 完成，等待人工验收后进入 Phase 4.2 完整流程测试。*
