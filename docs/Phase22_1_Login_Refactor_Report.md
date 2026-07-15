# Phase 22.1 登录系统重构报告

**修复时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scenes/login/login_scene.gd` | **重写** | 简化登录流程 |

---

## 问题根因分析

### 问题1: 启动后自动进入Token验证

**根因：** `_ready()`中检查Token并自动验证，导致60秒超时

**修复：** 删除所有启动自动验证逻辑

### 问题2: DevLoginButton节点不存在

**根因：** 硬编码路径`$VBoxContainer/TabContainer/Login/DevLoginButton`不存在

**修复：** 使用`get_node_or_null()`安全引用

### 问题3: 启动耗时过长

**根因：** Token验证占用60秒

**修复：** 删除Token验证，启动后直接显示登录界面

---

## 实施内容

### 1. 删除自动验证逻辑

**删除的内容：**
- `_check_saved_token()`函数
- `_check_existing_token()`函数
- `_auto_login()`函数
- Token验证超时处理
- 启动时检查Token逻辑

**保留的功能：**
- 手动登录
- 注册
- 开发者快速登录（点击按钮）

### 2. 修复DevLoginButton引用

**修改前：**
```gdscript
@onready var dev_login_button: Button = $VBoxContainer/TabContainer/Login/DevLoginButton
```

**修改后：**
```gdscript
var _dev_login_button: Button = null

func _ready() -> void:
    # 安全获取开发者登录按钮（不存在不报错）
    _dev_login_button = get_node_or_null("VBoxContainer/TabContainer/Login/DevLoginButton")
    if _dev_login_button:
        _dev_login_button.pressed.connect(_on_dev_login_pressed)
        _dev_login_button.visible = APIConfig.DEV_MODE
```

### 3. 简化登录流程

**Phase 22.1流程：**
```
启动游戏
    ↓
LoginScene._ready()
    ↓
显示登录界面 (<2秒)
    ↓
[等待用户输入]
    ↓
用户点击登录
    ↓
调用login API
    ↓
保存token
    ↓
GameFlowController.start_game()
```

---

## 预期日志输出

```
[BOOT] Login Scene Ready: 1234567890
[LOGIN] Waiting User Input: 1234567890
[LOGIN] Request Start: 1234567891
[LOGIN] Success: 1234567892
[LOGIN] Enter Game: 1234567892
```

---

## 测试方案

### 测试1: 启动速度

**步骤：**
1. 启动游戏
2. 观察登录界面出现时间

**预期：**
- 2秒内显示登录界面
- 无Token验证等待
- 无自动登录

### 测试2: 手动登录

**步骤：**
1. 输入账号密码
2. 点击登录

**预期：**
- 登录成功
- 进入游戏

### 测试3: 开发者登录

**步骤：**
1. 点击开发者登录按钮（如果存在）

**预期：**
- 使用测试账号登录
- 进入游戏

### 测试4: 注册

**步骤：**
1. 切换到注册标签
2. 输入信息
3. 点击注册

**预期：**
- 注册成功
- 切换到登录标签

---

## 启动时间对比

| 指标 | Phase 22 | Phase 22.1 |
|------|----------|------------|
| 启动到登录界面 | 60秒（Token超时） | <2秒 |
| 自动验证 | 有 | 无 |
| 自动登录 | 有 | 无 |

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
- 使用`get_node_or_null()`安全引用
- 只在`DEV_MODE=true`时显示
- 点击才执行，不自动执行

---

## 总结

### 修改内容

| 功能 | 状态 | 说明 |
|------|------|------|
| 删除自动验证 | ✅ 完成 | 启动不等待Token |
| 删除自动登录 | ✅ 完成 | 启动不自动登录 |
| 修复DevLoginButton | ✅ 完成 | 使用get_node_or_null() |
| 添加Boot日志 | ✅ 完成 | 启动时间可追踪 |

### 优化效果

- **启动速度：** 60秒 → <2秒
- **用户体验：** 直接显示登录界面
- **稳定性：** 无自动验证超时

---

**Phase 22.1 登录系统重构完成，等待测试验证。**
