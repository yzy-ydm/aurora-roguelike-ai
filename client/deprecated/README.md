# deprecated/ — 废弃代码归档（Phase 18.2）

> 原则：确认废弃的代码**移动**到这里而不是直接删除（可追溯、可恢复）。
> 每个文件标注：来源文件、废弃原因、移除时间。

| 文件 | 来源 | 原因 |
|---|---|---|
| player_controller_revive.gd.txt | client/scripts/player/player_controller.gd | revive() 零调用点（restart_run 改用 reset_stats_to 重建全新 PlayerStats，TASK-028） |
| room_spawner_apply_level_modifier.gd.txt | client/scripts/world/room_spawner.gd | 自标注"已废弃"，怪物数值统一由 MonsterBalanceConfig 生成后钳制 |
| game_scene_boss_controller_var.txt | client/scenes/game/game_scene.gd | `var _boss_controller` 声明后零使用（Boss 控制器由 room_spawner 内部创建） |
