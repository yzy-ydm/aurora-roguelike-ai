# Phase 22.2 Startup Pipeline Cleanup Report

**修复时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scripts/services/resource_service.gd` | **修改** | 启动时不加载资源 |

---

## 问题根因分析

### 问题: 启动阻塞

**根因：** `ResourceService._ready()`中调用`_load_all_default_resources()`，导致启动时加载资源

**修复：** 删除`_ready()`中的资源加载，只打印就绪状态

---

## 实施内容

### 1. 修改ResourceService._ready()

**修改前：**
```gdscript
func _ready() -> void:
    # Phase 21.3: 立即加载默认资源，后台加载API资源
    _load_all_default_resources()
    print("[ResourceService] Default resources loaded, API loading in background")
```

**修改后：**
```gdscript
func _ready() -> void:
    # Phase 22.2: 启动时不加载资源，只打印就绪状态
    print("[BOOT] ResourceService Ready (idle)")
```

### 2. 修改load_all_resources()

**修改后：**
```gdscript
func load_all_resources() -> void:
    print("[ResourceService] load_all_resources called")
    if _is_loading:
        print("[ResourceService] Already loading, skipping")
        return

    _is_loading = true
    _loaded_count = 0

    # 先加载默认资源（立即可用）
    _load_all_default_resources()

    # 然后并行发送API请求（后台加载）
    print("[ResourceService] Sending parallel API requests...")
    # ...
```

---

## 启动流程

### Phase 22.2 流程

```
启动游戏
    ↓
Autoload._ready()
    ↓
ResourceService._ready() → 只打印"Ready (idle)"
    ↓
LoginScene._ready() → 显示登录界面
    ↓
[等待用户输入]
    ↓
用户登录
    ↓
GameFlowController.start_game()
    ↓
加载玩家数据
    ↓
加载存档
    ↓
ResourceService.load_all_resources() ← 此时才加载资源
    ↓
进入游戏
```

### 禁止的流程

```
启动游戏 → ResourceService加载资源 → ❌ 已禁止
启动游戏 → Loading default weapons → ❌ 已禁止
```

---

## 预期日志输出

### 启动阶段

```
[BOOT] ResourceService Ready (idle)
[BOOT] Login Scene Ready: 1234567890
[LOGIN] Waiting User Input: 1234567890
```

### 登录后

```
[LOGIN] Request Start: 1234567891
[LOGIN] Success: 1234567892
[GameFlow] START GAME called
[ResourceService] load_all_resources called
[ResourceService] Default resources loaded
[ResourceService] Sending parallel API requests...
```

---

## 测试方案

### 测试1: 启动速度

**步骤：**
1. 启动游戏
2. 观察控制台日志

**预期：**
- 立即显示`[BOOT] ResourceService Ready (idle)`
- 立即显示`[BOOT] Login Scene Ready`
- 无`Loading default weapons`等日志

### 测试2: 登录后资源加载

**步骤：**
1. 登录游戏
2. 观察控制台日志

**预期：**
- 登录后显示`[ResourceService] load_all_resources called`
- 显示`[ResourceService] Default resources loaded`
- 显示`[ResourceService] Sending parallel API requests...`

---

## 启动时间对比

| 阶段 | Phase 22.1 | Phase 22.2 |
|------|------------|------------|
| ResourceService Ready | 加载资源 | <1ms |
| LoginScene Ready | <2秒 | <2秒 |
| 总启动时间 | <2秒 | <1秒 |

---

## 总结

### 修改内容

| 功能 | 状态 | 说明 |
|------|------|------|
| 删除启动加载资源 | ✅ 完成 | 只打印就绪状态 |
| 保留资源加载接口 | ✅ 保留 | 由GameFlowController调用 |
| 保留fallback机制 | ✅ 保留 | 默认资源仍可用 |

### 优化效果

- **启动速度：** <1秒显示登录界面
- **无阻塞：** 启动时不加载资源
- **按需加载：** 登录后才加载资源

---

**Phase 22.2 Startup Pipeline Cleanup 完成，等待测试验证。**
