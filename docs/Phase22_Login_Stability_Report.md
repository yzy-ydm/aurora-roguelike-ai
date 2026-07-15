# Phase 22 登录系统稳定化报告

**修复时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scenes/login/login_scene.gd` | **重写** | 重构登录流程 |

---

## 问题根因分析

### 问题1: 自动登录导致无法输入

**根因：** 之前的`AUTO_LOGIN`逻辑在`_ready()`中自动执行，跳过登录界面

**修复：** 删除自动登录逻辑，默认显示登录界面

### 问题2: 重复登录请求

**根因：** `_is_processing`状态管理不当，多次触发API请求

**修复：** 严格管理`_is_processing`状态，防止重复请求

### 问题3: Token过期处理异常

**根因：** Token验证失败后状态未正确重置

**修复：** 在`_on_api_error()`中正确重置所有状态

---

## 实施内容

### 1. 重构login_scene.gd

**核心改动：**

```gdscript
func _ready() -> void:
    print("[BOOT] Login UI Ready: ", Time.get_ticks_msec())

    # 连接信号
    # ...

    # Phase 22: 默认显示登录界面，禁止自动登录
    _show_login_interface()
```

**删除的内容：**
- `AUTO_LOGIN`相关逻辑
- `_auto_login()`函数
- 缓存自动登录逻辑

**保留的功能：**
- 开发者快速登录按钮（`dev_login_button`）
- Token验证
- 登录/注册功能

### 2. 添加开发者快速登录按钮

```gdscript
## 开发者快速登录按钮（如果存在）
@onready var dev_login_button: Button = $VBoxContainer/TabContainer/Login/DevLoginButton

func _ready() -> void:
    # 开发者快速登录按钮（如果存在）
    if dev_login_button:
        dev_login_button.pressed.connect(_on_dev_login_pressed)
        # 只在开发模式显示
        dev_login_button.visible = APIConfig.DEV_MODE

## 开发者快速登录
func _on_dev_login_pressed() -> void:
    if _is_processing:
        return
    if not APIConfig.DEV_MODE:
        status_label.text = "非开发模式"
        return

    print("[LoginScene] DEV LOGIN: Using test account")
    _is_processing = true
    _set_buttons_enabled(false)
    status_label.text = "开发者登录中..."

    var data = {
        "username": APIConfig.DEV_USERNAME,
        "password": APIConfig.DEV_PASSWORD
    }
    ApiClient.post_request(APIConfig.AUTH_LOGIN, data)
```

### 3. 添加Boot耗时日志

**日志点：**

| 日志 | 位置 | 说明 |
|------|------|------|
| `[BOOT] Login UI Ready` | `_ready()` | 登录界面就绪 |
| `[BOOT] Login Request` | `_on_login_pressed()` | 发起登录请求 |
| `[BOOT] Login Success` | `_handle_login_success()` | 登录成功 |
| `[BOOT] Player Loaded` | `GameFlowController` | 玩家数据加载完成 |
| `[BOOT] Save Loaded` | `GameFlowController` | 存档加载完成 |
| `[BOOT] Game Enter` | `_on_flow_completed()` | 进入游戏 |

---

## 登录流程

### Phase 22 流程

```
启动游戏
    ↓
LoginScene._ready()
    ↓
显示登录界面
    ↓
[用户选择]
├── 手动登录 → 输入账号密码 → 点击登录
├── 开发者登录 → 点击开发者登录按钮
└── Token验证 → 自动验证已保存的Token
    ↓
API验证
    ↓
登录成功
    ↓
GameFlowController.start_game()
    ↓
加载玩家数据
    ↓
加载存档
    ↓
加载资源
    ↓
进入游戏
```

### 删除的流程

```
AUTO_LOGIN=true → 自动登录 → ❌ 已删除
缓存自动登录 → ❌ 已删除
```

---

## 测试方案

### 测试1: 正常登录

**步骤：**
1. 启动游戏
2. 输入账号密码
3. 点击登录

**预期：**
- 显示登录界面
- 登录按钮可点击
- 登录成功进入游戏

### 测试2: Token验证

**步骤：**
1. 保存有效Token
2. 启动游戏

**预期：**
- 自动验证Token
- 验证成功进入游戏

### 测试3: Token过期

**步骤：**
1. 保存过期Token
2. 启动游戏

**预期：**
- Token验证失败
- 显示登录界面
- 可以重新登录

### 测试4: 开发者登录

**步骤：**
1. 启动游戏
2. 点击开发者登录按钮

**预期：**
- 使用测试账号登录
- 进入游戏

---

## Boot耗时日志

### 预期日志输出

```
[BOOT] Login UI Ready: 1234567890
[BOOT] Login Request: 1234567891
[BOOT] Login Success: 1234567892
[BOOT] Player Load Start: 1234567892
[BOOT] Player Loaded: 1234567893
[BOOT] Save Loaded: 1234567894
[BOOT] Game Enter: 1234567895
```

---

## 配置说明

### api_config.gd

```gdscript
## 开发模式开关
const DEV_MODE: bool = true

## 测试账号
const DEFAULT_DEV_USERNAME: String = "test001"
const DEFAULT_DEV_PASSWORD: String = "test123456"
```

### 登录界面

**开发者登录按钮：**
- 只在`DEV_MODE=true`时显示
- 使用`APIConfig.DEV_USERNAME`和`APIConfig.DEV_PASSWORD`

---

## 总结

### 修改内容

| 功能 | 状态 | 说明 |
|------|------|------|
| 删除自动登录 | ✅ 完成 | 默认显示登录界面 |
| 防止重复登录 | ✅ 完成 | 严格状态管理 |
| Token过期处理 | ✅ 完成 | 正确重置状态 |
| 开发者快速登录 | ✅ 完成 | 保留按钮逻辑 |
| Boot耗时日志 | ✅ 完成 | 添加日志点 |

### 优化效果

- **登录流程清晰：** 默认显示登录界面
- **无自动登录干扰：** 删除AUTO_LOGIN逻辑
- **开发者友好：** 保留快速登录按钮
- **可追踪：** Boot耗时日志

---

**Phase 22 登录系统稳定化完成，等待测试验证。**
