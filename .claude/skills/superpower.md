---
name: superpower
description: 超级开发流程管理技能，用于任务拆解、修改前规划、修改后验证
version: 1.0.0
tags: [workflow, planning, verification, project-management]
---

# Superpower 开发流程管理技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的开发流程管理，确保代码修改的质量和可追溯性。

## 核心原则

### 1. 修改前规划

**任何代码修改前，必须先输出 Implementation Plan**

### 2. 任务拆解

**复杂任务必须拆解为可验证的小步骤**

### 3. 修改后验证

**每次修改后必须输出修改报告**

---

## 工作流程

### Phase 任务执行流程

```
1. 分析当前代码状态
   ↓
2. 输出 Implementation Plan
   ↓
3. 获取确认
   ↓
4. 执行代码修改
   ↓
5. 输出 Modification Report
   ↓
6. 测试验证
```

---

## Implementation Plan 模板

```markdown
# Implementation Plan

## 任务名称
[Phase X.Y 任务名称]

## 当前代码状态
- 涉及文件：[文件列表]
- 现有逻辑：[简述]
- 问题/需求：[说明]

## 实现方案
1. [步骤1]
2. [步骤2]
3. [步骤3]

## 影响文件
| 文件 | 修改类型 | 风险 |
|------|----------|------|
| file1.gd | 修改 | 低 |
| file2.gd | 新增 | 无 |

## 风险点
- [风险1]
- [风险2]

## 预期结果
- [结果1]
- [结果2]
```

---

## Modification Report 模板

```markdown
# Modification Report

## 修改概述
[简述本次修改]

## 修改文件
| 文件 | 修改行数 | 修改原因 |
|------|----------|----------|
| file1.gd | +10/-5 | 添加功能X |
| file2.gd | +20 | 新增模块Y |

## 修改内容
### file1.gd
```gdscript
# 修改前
旧代码

# 修改后
新代码
```

## 测试方法
1. [测试步骤1]
2. [测试步骤2]

## 潜在风险
- [风险1]
- [风险2]

## 验证清单
- [ ] 功能正常
- [ ] 无破坏性修改
- [ ] 日志正常
```

---

## 任务拆解规范

### 大任务拆解

```
Phase 7.4: AI房间内容数据驱动增强
├── 7.4.1: AI楼层生成接管
│   ├── 修改room_graph.gd
│   ├── 修改game_scene.gd
│   └── 测试验证
├── 7.4.2: AI奖励策略生成
│   ├── 修改RoomContentData
│   ├── 修改AIParser
│   ├── 修改DropManager
│   └── 测试验证
└── 7.4.3: AI怪物配置生成
    ├── 修改MonsterSpawner
    └── 测试验证
```

### 小任务验证

每个小任务完成后：
1. 确认功能正常
2. 检查日志输出
3. 验证无破坏性修改

---

## 与现有 Skills 协同

### 协同矩阵

| 场景 | Superpower | 其他Skill |
|------|------------|-----------|
| Phase开发 | 任务拆解 + 流程管理 | godot4-development / fastapi-backend |
| 架构调整 | 风险评估 + 修改规划 | godot4-development |
| Bug修复 | 问题分析 + 修复验证 | python-testing |
| Git提交 | 修改报告 + 提交规范 | github-project-manager |
| 文档同步 | 内容规划 + 质量检查 | markdown-docs |
| AI接入 | 方案设计 + 输出验证 | ai-prompt-engineering |

### 工作流示例

**Phase开发流程**：
1. Superpower: 输出 Implementation Plan
2. godot4-development: 审查GDScript代码
3. Superpower: 输出 Modification Report
4. github-project-manager: 规范Git提交

---

## 使用场景

### 场景1: Phase开发

```
用户: 执行 Phase 8.1

Superpower:
1. 分析当前代码状态
2. 输出 Implementation Plan
3. 等待确认
4. 执行修改
5. 输出 Modification Report
```

### 场景2: Bug修复

```
用户: 修复HTTP超时问题

Superpower:
1. 分析问题根因
2. 输出修复方案
3. 执行修复
4. 输出验证报告
```

### 场景3: 架构调整

```
用户: 重构AI服务架构

Superpower:
1. 分析现有架构
2. 输出调整方案
3. 评估风险
4. 分步执行
5. 输出完成报告
```

---

## 检查清单

### 修改前

- [ ] 已分析当前代码状态
- [ ] 已输出 Implementation Plan
- [ ] 已识别风险点
- [ ] 已获得确认

### 修改中

- [ ] 按计划执行
- [ ] 记录修改内容
- [ ] 处理异常情况

### 修改后

- [ ] 输出 Modification Report
- [ ] 执行测试验证
- [ ] 确认无破坏性修改
- [ ] 更新文档（如需要）

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-07-14 | 初始版本 |
