---
name: markdown-docs
description: Markdown文档工程技能，用于维护项目文档、规范文档格式、文档版本管理
version: 1.0.0
tags: [markdown, documentation, docs]
---

# Markdown 文档工程技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的文档维护，确保文档质量和一致性。

## 项目文档结构

```
d:/GraduationProject/
├── PROJECT_STATUS.md        # 项目状态
├── ARCHITECTURE.md          # 系统架构
├── AI_SERVICE_DESIGN.md     # AI服务设计
├── API_REFERENCE.md         # API参考
├── README.md                # 项目说明
├── CHANGELOG.md             # 变更日志
├── DATABASE.md              # 数据库设计
├── DEPLOYMENT.md            # 部署文档
├── DEVELOPMENT_GUIDE.md     # 开发指南
├── FEATURE_SPEC.md          # 功能规格
├── ROADMAP.md               # 路线图
└── docs/                    # 详细文档目录
```

## 文档规范

### 标题层级

```markdown
# 一级标题（文档标题）

## 二级标题（章节）

### 三级标题（子章节）

#### 四级标题（小节）
```

### 列表格式

```markdown
# 无序列表
- 项目1
- 项目2
  - 子项目

# 有序列表
1. 第一步
2. 第二步
3. 第三步
```

### 表格格式

```markdown
| 列1 | 列2 | 列3 |
|------|------|------|
| 数据1 | 数据2 | 数据3 |
| 数据4 | 数据5 | 数据6 |
```

### 代码块

```markdown
# 行内代码
使用 `variable` 表示变量

# 代码块
```python
def function():
    pass
```

# 带语言标记
```gdscript
func _ready() -> void:
    pass
```
```

## 文档模板

### 模块文档模板

```markdown
# 模块名称

> 模块简要说明

最后更新：YYYY-MM-DD

---

## 概述

模块概述说明。

## 功能

- 功能1
- 功能2

## 使用方法

```python
# 示例代码
pass
```

## 注意事项

- 注意事项1
- 注意事项2
```

### API文档模板

```markdown
# API名称

```http
POST /api/endpoint
Authorization: Bearer <token>
Content-Type: application/json
```

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| param1 | string | 是 | 参数说明 |

## 响应格式

```json
{
    "key": "value"
}
```
```

## 项目特定文档

### PROJECT_STATUS.md 更新规范

```markdown
## 当前阶段

**Phase X.Y 已完成**（阶段名称） → 准备进入 **Phase X.Z 下一阶段**

---

## 项目完成度

| 阶段 | 内容 | 状态 | 完成度 |
|------|------|------|--------|
| Phase X.Y | 阶段内容 | ✅ 完成 | 100% |
```

### CHANGELOG.md 更新规范

```markdown
## [版本号] - YYYY-MM-DD

### Added
- 新增功能1
- 新增功能2

### Changed
- 修改功能1

### Fixed
- 修复问题1

### Removed
- 移除功能1
```

## 文档检查清单

- [ ] 标题层级正确
- [ ] 表格格式正确
- [ ] 代码块有语言标记
- [ ] 链接有效
- [ ] 图片显示正常
- [ ] 无拼写错误
- [ ] 日期格式统一

## 使用场景

当需要：
- 创建新文档
- 更新现有文档
- 规范文档格式
- 检查文档质量
- 维护文档版本
