# TASK-028_IMPLEMENTATION_REPORT — 稳定性修复第二阶段

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**（按要求未提交 git）
> 触发：TASK-027 人工验收失败——ESC→保存永久"保存中..."、死亡后重开 HP 异常、怪物攻击过低

---

## 1. 修改文件列表

| # | 文件 | 改动 |
|---|---|---|
| 1 | client/scripts/services/save_service.gd | **状态机重设计**（见问题1） |
| 2 | client/scripts/player/player_controller.gd | 新增 reset_stats_to（全新 PlayerStats）+ reset_weapon_to_default；默认武器成长 5→8 |
| 3 | client/scenes/game/game_scene.gd | restart_run 重写为"全新 run"；Boss 攻击 30-50 |
| 4 | client/scripts/player/player_stats.gd | take_damage 移除二次减伤（flat defense） |
| 5 | client/scripts/combat/damage_system.gd | 子弹命中武器伤害只计一次（修复双重计入） |
| 6 | client/scripts/models/monster_balance_config.gd | 普通怪分层基准（F1: 80-150/10-20，F2: 120-220/15-30）；Boss ATK 30-50 |
| 7 | client/tests/test_save_paused.gd | **新增**：真实暂停场景保存 4 检查项（复现用户卡死） |
| 8 | client/tests/test_save_failure.gd | **新增**：保存失败释放锁 7 检查项（401 路径） |
| 9 | client/tests/test_new_run_after_death.gd | **新增**：死亡重开 11 检查项（全新对象/HP/等级/金币/武器） |
| 10 | client/tests/test_damage_formula.gd | **新增**：武器伤害公式 8 检查项 |
| 11 | client/tests/test_monster_selection.gd | 更新第一层数值断言（80-150/10-20） |

## 2. 问题根因

### 问题1: SaveService 卡死（ESC→保存→"保存中..."永不结束）

**根因（无头复现实锤，探针日志完整证据链）**：
- 游戏暂停时 `SceneTree.paused=true`，SaveService 的 HTTPRequest 子节点默认 `process_mode` 继承父节点（PAUSABLE）→ **暂停期间 Godot 停止轮询 HTTP 连接** → `request_completed` 永不发射 → `await` 永不恢复 → 状态锁永久卡死。
- 复现日志：暂停中 `LOAD_START op=save` 后无任何完成日志；**取消暂停的瞬间** HTTP 才完成（"LOAD_SUCCESS"）——锁定案。
- 次级问题：忙时静默跳过（`load_saves() skipped`）→ 存档面板永久"加载存档中"无法退出。

**修改方案（状态机重设计，无任何 delay）**：
```
SAVE_START → 创建独立HTTPRequest(process_mode=ALWAYS) → 发送
→ 收到response(或10s超时) → 验证HTTP状态 → 更新memory cache
→ 释放lock → 通知UI
```
- SaveService 与所有 HTTPRequest 节点 **PROCESS_MODE_ALWAYS**（暂停期间照常完成请求）；
- 每个操作**单一释放出口** `_release_lock()`（GDScript 无 finally，所有失败路径手动收敛：网络失败/超时/HTTP错误/解析错误/404→POST 均走同一释放点）；
- 忙时**拒绝但通知**（save→save_error 提示；load→以内存缓存应答 saves_loaded），UI 不再永久卡住；
- 新增日志：`[SAVE] START / REQUEST_SENT / SUCCESS / FAILED / LOCK_RELEASED`（加载沿用 LOAD_START/LOAD_SUCCESS/LOAD_FAILED/LOAD_RESET）。

### 问题2: 死亡状态污染（重开 HP 不是 100）

**根因**：
1. 旧 `restart_run()` 用 `player.revive()`——只把 hp 回满到 **max_health**（升级后 >100），等级/金币/攻击/百分比加成全部残留；
2. `GameStateManager._runtime_stats` 引用旧场景 PlayerStats 对象，跨 run 泄漏。

**修改方案**：
- `player_controller.reset_stats_to(data)`：**新建全新 PlayerStats 实例**（禁止复用旧对象），并清除死亡锁 `_is_dying`/无敌/击退（否则新 run 死亡时 GameOver 不触发——连带修复的隐藏 bug）；
- `player_controller.reset_weapon_to_default()`：武器重置为初始默认武器 Lv1；
- `game_scene.restart_run()` 重写：reset_run_state（清 run 临时状态，保留 profile 基线）→ reset_stats_to(profile) → 武器重置 → 战斗/房间清理 → 楼层从第 1 层生成；
- 验证目标全部达成：**HP=100、Level=1、Gold=0、武器=初始武器**。

### 问题3: 第一层战斗平衡

**根因**：普通怪 ATK 5-15 偏低 + 玩家防御**双重减伤**（DamageSystem 百分比 + PlayerStats flat 再减）→ 实际伤害 1-9 → 站撸无压力。

**修改方案**：
- MonsterBalanceConfig 普通怪**分层基准**：第一层 HP 80-150 / ATK 10-20；第二层 HP 120-220 / ATK 15-30；第三层起在第二层基准上 +15%/层（封顶 3.0）；
- Boss：HP 500-800（上轮已调）+ **ATK 30-50**（配置与 game_scene 生成双处）；
- 玩家侧防御**只减伤一次**（移除 PlayerStats.take_damage 的 flat 减伤，统一由 DamageSystem 的 def/(def+100) 处理）；
- 效果：第一层普通怪单次攻击 9.5-19 伤害（def0），玩家 100HP 承受 5-10 次——不能站撸，符合目标。

### 问题4: 武器伤害倍率审计

**审计结论**：
| 项 | 旧 | 新 |
|---|---|---|
| 子弹命中 | base = (攻击+武器) + bullet.weapon → **武器计两次**（线性重复叠加） | base = 攻击（get_attack 已含武器）→ 武器计一次 |
| 成长公式 | base + growth×(Lv-1)，**线性无指数** ✓ | 不变；默认武器 growth 5→8（Lv10=92） |
| 玩家受击 | 防御减伤两次（百分比 + flat） | 百分比一次 |

**修复后 TTK（实测公式推演）**：
- 前期：攻击10+武器20=30/发 vs 80-150HP → **3-5 击** ✓（目标 2-5）
- 后期：Lv20 攻击48+武器92=140/发 vs 360-660HP（封顶3.0）→ **3-5 击**，暴击接线（后续任务）后可入 2-4 区间
- 无指数增长路径；暴击目前硬编码 10%×1.5（成长接线留后续任务）

### 问题5: 代码清理

| 检查项 | 结论 |
|---|---|
| 仓库内临时/探针文件 | ✅ 无（本次所有探针均在系统临时目录，未入库） |
| 重复保存逻辑 | save_system.gd（本地 JSON）实例化但零调用——按约束保留（论文"双方案"素材） |
| 死代码 | 引用 DEAD_CODE_AUDIT.md 清单；本轮新增死调用点 0 个 |
| 未使用变量 | game_scene._boss_controller（声明零使用）——保留记录 |
| 废弃代码 | revive() 现零调用（restart_run 改用 reset_stats_to）；_apply_level_modifier 仅被死代码 monster_spawner 调用——均保留 |
| debug 代码 | 上轮已清跳跃/子弹刷屏；本轮保留 [SAVE]/LOAD_*/[HTTP DEBUG]（验收排障证据） |
| AI/存档/分析系统 | ✅ 未删除任何相关代码 |

## 3. 测试结果（全部真实运行）

| 套件 | 结果 |
|---|---|
| test_save_paused（新，真实暂停场景） | ✅ 4/4 |
| test_save_failure（新，401 失败释放锁） | ✅ 7/7 |
| test_new_run_after_death（新） | ✅ 11/11 |
| test_damage_formula（新） | ✅ 8/8 |
| test_monster_selection（更新断言） | ✅ 6/6 |
| test_save_integration（真实 HTTP） | ✅ 12/12 |
| 其余 11 套回归（16/2001/20/13/11/12/35/19/11/8/8） | ✅ 全绿 |
| 服务端 pytest app/tests + ai/tests | ✅ 5 + 143 |
| Godot headless 启动 | ✅ 0 脚本错误 |

> 测试脚手架记录：①测试辅助登录必须把响应 token 写入 TokenManager（真实游戏由 login_scene 完成，测试易漏）；②--script 模式 `--path` 必须指向 client 目录，cwd 漂移会静默跑到错误项目；③测试中 `:=` 推断 Variant 返回值仍会解析失败，动态脚本调用须显式类型。

## 4. 下一阶段建议

1. **人工验收**（本任务验收步骤见下）。
2. 验收通过后：git 全量提交 + GitHub 同步（TASK-025 至今全部改动仍未提交，版本保护优先）。
3. 剩余 P0/P1（按 FINAL_DEVELOPMENT_PLAN.md）：房间生成顺序（B）、暴击成长接线、AI 内容真实生效（finalize 时序）、难度消费点、NPC 对白显示。
4. 数值后续微调建议（实测后）：若第一层仍偏难/偏易，优先调 MonsterBalanceConfig 常量（已集中管理）；Boss 攻击 30-50 请重点实测手感。

## 5. 人工验收步骤（服务端已运行、存档已清空）

**验收1（ESC 保存——本任务核心）**：
1. 新游戏 → 打到第 2 层 → **ESC 暂停 → 点"保存"** → 1-2 秒内显示"保存成功"（**不再永久"保存中..."**）。
2. 再 ESC → "退出到主菜单" → 存档面板点槽位 1 → "保存成功！" → 回主菜单。
3. 断网场景（可选）：停掉服务端 → ESC 保存 → 10 秒内显示"保存失败: 网络请求失败或超时"（不卡死）→ 重启服务端后再保存成功。

**验收2（死亡重开）**：
1. 新游戏 → 升级到 Lv2+、吃攻击/生命强化、捡金币 → 故意死亡 → GameOver。
2. 点"重新开始" → **HP=100/100、Lv1、金币 0、武器为初始武器**（HUD 与属性面板确认）。
3. 再死一次 → GameOver 面板仍正常弹出（死亡锁已清）。
4. 点"返回主菜单" → 直接回菜单 → "继续游戏" → 显示"没有有效存档"（或上一次手动保存的旧档）。

**验收3（第一层战斗）**：
1. 新游戏战斗房：普通怪 HP 80-150（血条可感）、攻击 10-20/次——**站撸会死**，需要走位/风筝。
2. 普通怪 3-5 枪击杀；Boss 房 Boss HP 500-800、攻击 30-50，走位可过。

**通过标准**：三项全部符合预期、无脚本报错、无永久"保存中/加载存档中"。

---

**TASK-028 实施完成。按流程停止，未提交 git，等待人工验收。**
