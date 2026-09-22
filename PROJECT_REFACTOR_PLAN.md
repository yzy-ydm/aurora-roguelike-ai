# Aurora-Roguelike-AI 项目重构方案

**日期**: 2026-09-22
**目标**: 建立稳定可玩的 Demo 闭环

---

## 已修复问题 (Phase 23)

| ID | 问题 | 修复文件 | 状态 |
|-----|------|---------|------|
| P0-1 | MonsterData.max_health 赋值错误 | room_spawner.gd | ✅ 已修复 |
| P0-2 | 奖励坐标系统 | room_spawner.gd | ✅ 已修复 |
| P1-1 | 敌人子弹碰撞层 | bullet.gd, player_controller.gd | ✅ 已修复 |
| P1-2 | 存档 slot=-1 风险 | game_flow_controller.gd | ✅ 已修复 |
| P1-4 | AI 内容无客户端钳制 | ai_response_parser.gd | ✅ 已修复 |

---

## 待修复问题

### P1-3: FloorManager AI 后台覆盖问题

**现状**: `_request_room_content_ai()` 在 AI 生成完成后可能覆盖正在战斗的房间内容。

**修复方案**: 在 `FloorManager._request_room_content_ai()` 中增加二次检查，确保 AI 结果不覆盖已 spawn_monsters 的房间。

---

### P2-6: 废弃文件清理

**需删除**:
- `client/scripts/enemy/monster_spawner.gd` (已被 RoomSpawner 替代)
- `client/scripts/world/room_manager.gd` (已被 FloorManager 替代)
- `client/scripts/entity/entity_manager.gd` (未被使用)
- `client/scripts/managers/resource_manager.gd` (已被 ResourceService 替代)

**需检查引用**: 删除前先 grep 确认无引用。

---

### P2-7: HTTP 请求模式统一

**现状**: 
- `ApiClient.gd` 使用信号驱动队列
- `AIContentService.gd` 手动轮询 HTTPRequest 状态

**修复方案**: 将 `AIContentService` 的 HTTP 调用也改为信号驱动方式，或使用 `ApiClient` 作为统一入口。

---

### P2-8: 数据模型去重

**现状**: 存在两套房间数据模型 `RoomNodeData` 和 `NewRoomData`，以及 `RoomData`。

**修复方案**: 
- 保留 `NewRoomData` 作为唯一房间模型
- 在 `FloorGenerator` 中直接使用 `NewRoomData`
- 移除 `RoomNodeData` 的转换层

---

## 重构执行计划

### Step 1: 清理废弃代码 (P2-6)
1. 搜索所有废弃文件的引用
2. 删除无引用的废弃文件
3. 运行项目验证无编译错误

### Step 2: 统一 HTTP 请求 (P2-7)
1. 将 `AIContentService._send_ai_request()` 改为使用 `ApiClient`
2. 移除手动轮询代码
3. 测试 AI 内容生成流程

### Step 3: 修复 AI 覆盖问题 (P1-3)
1. 在 `_request_room_content_ai()` 中增加 `room.content.is_finalized` 二次检查
2. 添加日志确认 AI 结果是否被接受/忽略
3. 测试房间进入流程

### Step 4: 数据模型统一 (P2-8)
1. 修改 `FloorGenerator` 直接生成 `NewRoomData`
2. 移除 `_convert_to_floor_data()` 转换函数
3. 更新所有引用 `RoomNodeData` 的地方

### Step 5: 完整流程测试
1. 启动服务器
2. 登录
3. 进入游戏
4. 完成一个完整楼层
5. 退出并验证存档
6. 重新加载验证

---

## 风险控制

- 每步修改后运行项目验证
- 保持向后兼容，不破坏现有 API
- 添加详细的日志输出用于调试
- 不删除任何可能被外部引用的文件（先标记为 @deprecated）
