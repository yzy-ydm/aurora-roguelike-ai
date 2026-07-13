---
name: github-project-manager
description: GitHub项目管理技能，用于Git提交规范、分支管理、PR检查、Release管理
version: 1.0.0
tags: [git, github, project-management, version-control]
---

# GitHub 项目管理技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的 GitHub 项目管理，确保版本控制规范。

## Git 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug修复 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 构建/工具相关 |

### 示例

```
feat(ai): implement AI floor generation

- Add AIContentService integration to RoomGraph
- Add fallback to local FloorGenerator
- Keep existing procedural generation

Closes #123
```

## 分支管理

### 分支命名

```
feature/phase-7.3-ai-connect
fix/http-timeout-issue
docs/update-architecture
release/v1.0.0
```

### 分支策略

- `main` - 稳定版本
- `feature/*` - 功能开发
- `fix/*` - Bug修复
- `release/*` - 发布准备

## PR 检查清单

- [ ] 代码符合项目规范
- [ ] 无破坏性修改
- [ ] 文档已更新
- [ ] 测试通过

## 使用场景

当需要：
- 创建规范的Git提交
- 管理分支
- 创建PR
- 发布Release
