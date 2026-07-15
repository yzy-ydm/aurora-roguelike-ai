# PROJECT_RESTART_PROTOCOL.md

> Aurora-Roguelike-AI 项目重启协议
> 半年后重新启动项目时的标准操作流程

最后更新：2026-07-16

---

## 启动前检查（5分钟）

1. **确认环境**
   - Godot 4.7 已安装
   - Python 3.12+ 已安装
   - MySQL 8.0 运行中

2. **确认代码**
   ```bash
   git pull origin main
   git status
   ```

3. **确认文档**
   - 阅读 `PROJECT_RECOVERY.md`（第一阅读文件）
   - 阅读 `CLAUDE_CONTEXT.md`（架构原则）
   - 阅读 `PROJECT_STATUS.md`（当前状态）

---

## 启动步骤（10分钟）

### 1. 配置环境
```bash
cd server
cp .env.example .env
# 编辑 .env 配置数据库密码
```

### 2. 启动后端
```bash
# 终端1：AI服务
cd server/ai
python main.py

# 终端2：游戏服务
cd server
python main.py
```

### 3. 启动客户端
```bash
# 打开 Godot 4.7
# File → Open → client/project.godot
# 按 F5 运行
```

### 4. 验证功能
- 登录 test001 / test123456
- 进入游戏
- 移动（WASD）
- 跳跃（空格）
- 攻击（鼠标左键）
- 进入战斗房间
- 击杀怪物
- 进入Boss房间

---

## 开发恢复路径（根据需求选择）

### 路径A：继续开发新功能
参考 `PROJECT_STATUS.md` 中的"未完成模块"列表

### 路径B：修复已知问题
参考 `BALANCE_ANALYSIS.md` 中的数值问题

### 路径C：毕设答辩准备
参考 `README.md` 中的"毕业设计价值体现"

---

## 常见问题

### Q: 数据库连接失败
```bash
mysql -u root -p
CREATE DATABASE IF NOT EXISTS aurora_game;
```

### Q: Godot项目打开失败
```bash
# 检查 .godot 文件夹权限
rm -rf client/.godot
# 重新导入项目
```

### Q: AI服务不可用
```bash
# 确保使用 Mock 模式
# server/.env: LLM_PROVIDER=mock
```

---

## 关键文件索引

| 文件 | 用途 |
|------|------|
| `PROJECT_RECOVERY.md` | 第一阅读文件 |
| `CLAUDE_CONTEXT.md` | AI开发上下文 |
| `PROJECT_STATUS.md` | 项目当前状态 |
| `ARCHITECTURE.md` | 系统架构 |
| `BALANCE_ANALYSIS.md` | 数值分析 |
| `CHANGELOG.md` | 开发历史 |

---

**本协议确保项目半年后可快速恢复开发。**
