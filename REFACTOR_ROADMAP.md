# Aurora-Roguelike-AI 重构路线图 (V2 修订版)

> 修订日期：2026-09-21
> 基于：PROJECT_AUDIT_REPORT.md + CURRENT_SYSTEM_DOCUMENT.md
> 目标：本科毕业设计级高质量项目
> 状态：**等待用户确认**

---

## 执行原则

1. **一次只做一件事** — 每个任务独立可验收
2. **完成即提交** — 每完成一个任务立即commit + push GitHub
3. **必须等验收** — 每阶段完成后等待用户确认再进入下一阶段
4. **不破坏现有功能** — 在现有可运行代码上增强，不重写已有系统
5. **项目定位优先** — 重点不是商业游戏，而是"AI内容生成+算法约束+C/S架构"的软件系统

---

## 总体阶段规划

```
Phase -1: 项目保护     → [已完成] 备份tag + 系统文档
Phase  0: AI引擎升级   → Agnes API接入 + Provider抽象层 + Prompt系统
Phase  1: 算法增强     → 地图验证 + 掉落算法 + 难度算法 + 质量评价
Phase  2: 工程完善     → 测试框架 + 清理代码 + 小地图
Phase  3: 验收交付     → 审计 + 测试 + 报告
```

---

## 关键发现（影响路线图）

### 发现1: MiMo API已配置且可用

```
.env中已有:
  LLM_PROVIDER=mimo
  MIMO_API_KEY=tp-cf4dal6g... (真实Key)
  MIMO_ENDPOINT=https://token-plan-cn.xiaomimimo.com/anthropic
```

**结论：** 服务端AI能力已基本可用，只需要切换到Agnes即可。

### 发现2: 客户端已设为REAL模式

```
game_scene.gd:310:
  _ai_content_service.set_service_type(_ai_content_service.AIServiceType.REAL)
```

**结论：** 游戏会尝试连接真实AI服务，不会退化为Mock。

### 发现3: MimoClient使用Anthropic格式

```python
# mimo_client.py
request_url = f"{self.endpoint}/v1/messages"
headers = {"x-api-key": self.api_key, "anthropic-version": "..."}
```

**结论：** Agnes使用OpenAI格式(`/v1/chat/completions`)，需要新的Provider。

### 发现4: 已有LLMProvider抽象基类

```python
# llm_provider.py
class LLMProvider(ABC):
    """所有LLM提供商必须实现此接口"""
```

**结论：** 抽象层已存在，只需要新增Agnes实现。

---

# ═══════════════════════════════════════════════════════════
# Phase 0: AI引擎升级 (核心任务)
# ═══════════════════════════════════════════════════════════

## 任务 0.1: 切换AI配置为Agnes + 保留MiMo作为降级

### 目标
将默认AI Provider从MiMo切换为Agnes AI，同时保留MiMo作为降级方案。

### 配置变更

**.env 新增Agnes配置：**
```bash
# ==================== AI Provider配置 ====================
# AI_PROVIDER: agnes, mimo, mock, auto
AI_PROVIDER=agnes

# Agnes AI配置 (OpenAI兼容)
AGNES_API_KEY=your_agnes_key_here
AGNES_BASE_URL=https://apihub.agnes-ai.com/v1
AGNES_MODEL=agnes-2.5-flash
AGNES_MAX_TOKENS=4096
AGNES_TEMPERATURE=0.7

# MiMo配置 (保留作为降级)
LLM_PROVIDER=mimo
MIMO_API_KEY=tp-cf4dal6goppw7ftajdkp8468fxe9rhovv72boi7p250vnyt1
MIMO_MODEL=mimo-v2.5-pro
MIMO_ENDPOINT=https://token-plan-cn.xiaomimimo.com/anthropic
```

### 修改方案
1. 更新 `server/.env.example` — 添加Agnes配置段
2. 更新 `server/ai/config/config.py` (新建或修改) — 支持AI_PROVIDER切换
3. 修改 `server/ai/services/provider_factory.py` — 添加Agnes分支

### 影响范围
- `.env.example` — 新增配置
- `provider_factory.py` — 新增Agnes分支
- `ai_service.py` — 适配新Provider接口

### 测试方式
```bash
# 验证配置加载
python -c "from config.config import AI_PROVIDER; print(AI_PROVIDER)"
# 预期: agnes
```

### 预计工时
1小时

---

## 任务 0.2: 实现AgnesAIProvider

### 目标
创建Agnes AI的OpenAI兼容接口实现。

### 技术规格
- **Base URL:** `https://apihub.agnes-ai.com/v1`
- **API路径:** `/v1/chat/completions`
- **模型:** `agnes-2.5-flash`
- **认证:** `Authorization: Bearer <API_KEY>`
- **请求格式:** OpenAI Chat Completions
- **响应格式:** OpenAI Chat Completions

### 代码设计
```python
# server/ai/services/agnes_provider.py
class AgnesProvider(LLMProvider):
    """Agnes AI OpenAI兼容Provider"""

    def __init__(self, api_key, base_url, model, max_tokens, temperature):
        ...

    async def generate(self, prompt: str) -> Dict[str, Any]:
        """调用OpenAI兼容接口"""
        url = f"{self.base_url}/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        body = {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "messages": [{"role": "user", "content": prompt}]
        }
        # ... HTTP调用 + JSON解析
```

### 依赖
- `openai` Python SDK (可选，也可用httpx手动调用)
- 或继续使用 httpx

### 影响范围
- 新增：`agnes_provider.py`
- 修改：`provider_factory.py` — 添加Agnes注册
- 修改：`requirements.txt` — 添加openai (可选)

### 测试方式
- 单元测试：验证请求格式正确
- Mock测试：用responses库拦截HTTP验证逻辑
- 真实测试：配置API Key后端到端测试

### 预计工时
1.5小时

---

## 任务 0.3: 建立Prompt工程系统

### 目标
将所有AI提示词集中管理，形成可维护的Prompt工程系统。

### 目录结构
```
server/ai/prompts/
├── __init__.py
├── base.py              # PromptBuilder基类
├── floor_prompt.py      # 楼层生成Prompt
├── room_prompt.py       # 房间内容Prompt
├── monster_prompt.py    # 怪物生成Prompt
├── weapon_prompt.py     # 武器生成Prompt
├── event_prompt.py      # 事件生成Prompt
├── upgrade_prompt.py    # 升级选项Prompt
├── difficulty_prompt.py # 难度调整Prompt
└── shared.py            # 共享Prompt片段
```

### 设计原则
1. **结构化输出** — 要求AI返回严格JSON
2. **角色设定** — 系统Prompt定义AI角色
3. **约束明确** — 明确的数值范围和游戏约束
4. **Few-shot** — 关键Prompt包含示例

### 示例Prompt (floor_prompt.py)
```python
FLOOR_SYSTEM_PROMPT = """\
你是Aurora地下城的设计师。你负责生成Roguelike游戏的楼层结构。
要求：
1. 输出严格的JSON格式
2. 楼层必须包含起始房间和Boss房间
3. 房间数量8-12个
4. 房间类型包括：combat, reward, elite, event, treasure, boss, start
5. 每个房间必须有id、type、connections字段
"""

FLOOR_USER_TEMPLATE = """\
楼层级别: {floor_level}
玩家等级: {player_level}
玩家属性: {player_stats}
请生成楼层结构JSON...
"""
```

### 影响范围
- 新增：`prompts/` 目录（9个文件）
- 修改：`prompt_builder.py` — 迁移到统一系统
- 修改：各Provider — 使用新Prompt

### 测试方式
- 验证每个Prompt模板正确渲染
- 验证Prompt长度在API限制内

### 预计工时
2小时

---

## 任务 0.4: 增强AI内容验证管道

### 目标
建立完整的AI内容验证管道：生成→解析→验证→评分→应用。

### 当前流程
```
AI生成 → JSON解析 → 基础验证 → 缓存 → 返回
```

### 增强后流程
```
AI生成
  ↓
JSON解析 (容错：提取代码块、去除前后文本)
  ↓
结构验证 (AIValidator - 已有，增强)
  ↓
范围验证 (新增：数值边界检查)
  ↓
平衡性验证 (新增：游戏平衡检查)
  ↓
质量评分 (AIQualityChecker - 已有，增强)
  ↓
降级决策 (评分<阈值→Mock)
  ↓
缓存 → 返回
```

### 新增验证规则

**数值范围验证：**
```python
# 楼层验证
ROOM_COUNT_MIN = 8
ROOM_COUNT_MAX = 15
MONSTER_COUNT_MIN = 0
MONSTER_COUNT_MAX = 8
REWARD_QUALITY_MIN = 0.5
REWARD_QUALITY_MAX = 5.0

# 怪物验证
HP_RANGE = (10, 10000)
ATTACK_RANGE = (1, 500)
DEFENSE_RANGE = (0, 200)

# 奖励验证
GOLD_RANGE = (10, 1000)
STAT_BONUS_RANGE = (1, 100)
```

**游戏平衡验证：**
```python
def validate_floor_balance(floor_data, player_level):
    """验证楼层难度曲线是否合理"""
    rooms = floor_data.get("rooms", [])
    # Boss房间应在最后
    assert rooms[-1]["type"] == "boss"
    # 战斗房间不应超过总房间的70%
    combat_ratio = sum(1 for r in rooms if r["type"] == "combat") / len(rooms)
    assert combat_ratio <= 0.7
```

### 影响范围
- 修改：`ai_validator.py` — 增强验证规则
- 新增：`ai_range_checker.py` — 数值范围验证
- 新增：`ai_balance_checker.py` — 游戏平衡验证
- 修改：`ai_service.py` — 整合验证管道

### 测试方式
- 用正常/异常AI输出测试验证管道
- 验证降级决策逻辑

### 预计工时
2小时

---

## 任务 0.5: 优化缓存策略

### 目标
改进AI生成缓存，支持不同内容类型的差异化TTL。

### 修改方案
1. 楼层缓存TTL: 30分钟 (内容相对稳定)
2. 房间内容缓存TTL: 5分钟 (内容较动态)
3. 难度调整缓存TTL: 10分钟
4. 添加缓存预热 (启动时预生成常见楼层)
5. 添加缓存统计 (命中率、过期数)

### 影响范围
- 修改：`cache/cache_manager.py`

### 测试方式
- 验证缓存命中/失效
- 验证统计信息准确

### 预计工时
1小时

---

## 任务 0.6: AI服务质量监控

### 目标
建立AI生成质量的可观测性，用于论文数据支撑。

### 监控指标
| 指标 | 说明 | 存储 |
|------|------|------|
| 请求延迟 | 从请求到响应的时间 | ai_generations表 |
| 成功率 | 成功生成的比例 | 日志 |
| 缓存命中率 | 缓存命中的比例 | 缓存统计 |
| 降级率 | 回退到Mock的比例 | 日志 |
| 质量分分布 | 生成内容的质量评分分布 | 日志 |
| Token使用量 | 每次请求的token消耗 | ai_generations表 |

### 修改方案
1. 完善 `ai_generations` 表的字段（添加quality_score, tokens_used等）
2. 在AI路由中添加质量分记录
3. 添加 `/api/stats/ai-quality` 端点

### 影响范围
- 修改：`ai_routes.py` — 记录质量数据
- 修改：`ai_service.py` — 传递质量分
- 修改：数据库 — 添加字段

### 测试方式
- 运行AI生成请求，验证数据正确记录

### 预计工时
1.5小时

---

# ═══════════════════════════════════════════════════════════
# Phase 1: 算法增强 (论文核心)
# ═══════════════════════════════════════════════════════════

## 任务 1.1: 地图生成算法增强

### 目标
增强地图生成算法的可玩性和论文论述深度。

### 新增功能
1. **BFS连通性验证** — 证明所有房间可达
2. **重叠检测** — 检测并修复房间坐标重叠
3. **最短路径分析** — 统计玩家到达Boss的最短路径
4. **布局评分** — 量化评估房间分布的均匀性

### 实现方案
在 `floor_generator.gd` 中新增：
```gdscript
# BFS连通性验证
func verify_connectivity() -> Dictionary
# 重叠检测
func detect_overlaps() -> Array
# 最短路径统计
func analyze_paths() -> Dictionary
# 布局评分
func calculate_layout_score() -> float
```

### 论文支撑
- 时间复杂度分析：O(R²) where R=房间数
- 空间复杂度：O(R)
- 正确性证明：树结构保证连通性

### 预计工时
2小时

---

## 任务 1.2: 完整掉落概率算法

### 目标
建立有理论依据的掉落系统。

### 算法设计

**加权随机模型：**
```
P(item_i) = weight_i / Σ(weight_j)

掉落权重表:
| 类型         | 基础权重 | 稀有度加成公式        |
|-------------|---------|---------------------|
| GOLD        | 40      | ×1.0                |
| ATTACK_UP   | 20      | ×rarity_multiplier  |
| HEALTH_UP   | 20      | ×rarity_multiplier  |
| HEAL        | 10      | ×1.0                |
| WEAPON_UPG  | 5       | ×rarity_multiplier² |
| PASSIVE_ITEM| 3       | ×rarity_multiplier³ |
| ATTRIBUTE   | 2       | ×rarity_multiplier⁴ |

rarity_multiplier: common=1.0, uncommon=1.5, rare=2.0, epic=3.0, legendary=5.0
quality_multiplier = 1.0 + (floor_level - 1) × 0.08
```

### 实现方案
1. 创建 `client/scripts/drop/drop_table.gd` — 权重表定义
2. 修改 `drop_manager.gd` — 使用加权随机
3. 创建 `tests/test_drop_algorithm.tscn` — 验证概率分布

### 论文支撑
- 概率论基础：加权随机抽样
- 数值分析：10000次模拟验证偏差<5%

### 预计工时
2.5小时

---

## 任务 1.3: 动态难度调整算法增强

### 目标
从规则引擎升级为基于统计学的动态难度调整。

### 算法设计

**数据采集（已有BehaviorAnalyzer）：**
- 击杀率 K = kills / time
- 死亡率 D = deaths / runs  
- 无伤率 N = rooms_cleared_without_damage / total_rooms
- DPS率 S = damage_dealt / time

**反馈控制算法：**
```
difficulty_score = 0.4 × D + 0.3 × (1-N) + 0.3 × clamp(S/expected_S, 0, 2)

if difficulty_score > 1.3:  # 太简单
    HP_multiplier *= 1.1
    Damage_multiplier *= 1.05
elif difficulty_score < 0.7:  # 太难
    HP_multiplier *= 0.9
    Reward_multiplier *= 1.1

clamped: [0.5, 2.0] for all multipliers
```

### 实现方案
1. 修改 `ai_service.py` → `_mock_generate_difficulty()`
2. 增强 `behavior_analyzer.gd` — 更多维度数据采集
3. 添加难度调整日志（论文截图用）

### 论文支撑
- 控制理论：PID反馈控制思想
- 量化指标：明确的难度评分公式

### 预计工时
2小时

---

## 任务 1.4: AI内容质量评价算法

### 目标
建立可量化的AI生成内容质量评估体系。

### 评价模型

**四维度评分：**
| 维度 | 指标 | 权重 | 计算方式 |
|------|------|------|----------|
| 完整性 | 必需字段齐全度 | 0.3 | 已填充字段数/总字段数 |
| 合理性 | 数值范围合规率 | 0.3 | 合规字段数/总数值字段数 |
| 多样性 | 与历史差异度 | 0.2 | 文本哈希差异 |
| 平衡性 | 游戏平衡符合度 | 0.2 | 难度曲线偏差度 |

**综合评分：**
```
score = 0.3 × completeness + 0.3 ×合理性 + 0.2 ×多样性 + 0.2 ×平衡性
```

### 实现方案
1. 修改 `ai_quality_checker.py` — 增强评价维度
2. 创建 `ai_content_evaluator.py` — 综合评价器
3. 添加质量分到AI响应

### 论文支撑
- 多指标综合评价方法
- 可解释的评分体系

### 预计工时
1.5小时

---

# ═══════════════════════════════════════════════════════════
# Phase 2: 工程完善
# ═══════════════════════════════════════════════════════════

## 任务 2.1: 建立测试框架

### 目标
建立完整的测试基础设施。

### 服务端测试
```bash
# 创建目录结构
server/tests/
├── conftest.py
├── test_auth_service.py
├── test_security.py
├── test_ai_validator.py
├── test_ai_quality_checker.py
├── test_agnes_provider.py
└── test_drop_algorithm.py
```

### 客户端测试
```
client/tests/
├── test_damage_system.tscn
├── test_drop_prob.tscn
└── test_map_connectivity.tscn
```

### 预计工时
3小时

---

## 任务 2.2: 清理调试代码

### 目标
移除生产环境的调试print，提升代码质量。

### 清理清单
| 文件 | 操作 |
|------|------|
| `auth_service.py` | 移除[AUTH TIMER]调试计时 |
| `main.py` (server) | 移除请求计时print |
| `damage_system.gd` | 移除debug print |
| `floor_generator.gd` | 移除debug print |
| `room_renderer.gd` | 移除debug print |
| `ai_content_service.gd` | 移除冗余print |

### 预计工时
1小时

---

## 任务 2.3: 实现小地图系统

### 目标
为Roguelike游戏添加标配的小地图UI。

### 设计
- 显示当前楼层的房间图（简化版）
- 已访问房间：显示为已点亮
- 当前房间：高亮标记
- 未访问房间：显示为问号
- Boss房间：特殊标记

### 预计工时
2小时

---

## 任务 2.4: 数据库索引优化

### 目标
优化数据库查询性能。

### 修改方案
1. 为 `ai_generations` 表添加复合索引
2. 为常用查询添加索引
3. 添加查询视图

### 预计工时
1小时

---

# ═══════════════════════════════════════════════════════════
# Phase 3: 验收交付
# ═══════════════════════════════════════════════════════════

## 任务 3.1: 最终项目审计

### 目标
执行全面审计，输出FINAL_PROJECT_AUDIT.md。

### 预计工时
2小时

---

## 任务 3.2: 完整功能测试

### 目标
端到端测试整个游戏流程。

### 测试流程
1. 启动MySQL → FastAPI主服务 → AI服务 → Godot
2. 注册 → 登录 → 游戏
3. 战斗 → Boss → 下一层 → 重复
4. 存档 → 加载
5. AI生成 → 验证 → 质量监控

### 预计工时
2小时

---

## 任务 3.3: 输出完成报告

### 目标
创建FINAL_COMPLETION_REPORT.md。

### 预计工时
1小时

---

## 任务 3.4: Git同步

### 目标
推送所有修改到GitHub。

### 操作
```bash
git add -A
git commit -m "feat: complete refactoring for graduation project"
git tag v1.0.0
git push origin main --tags
```

### 预计工时
30分钟

---

# 任务优先级总览

```
P0 (必须完成)                         P1 (质量提升)                P2 (锦上添花)
─────────────────────                 ──────────────────         ──────────────────
0.1 切换AI配置为Agnes                  1.1 地图生成算法增强         2.3 小地图系统
0.2 实现AgnesAIProvider                1.2 掉落概率算法             2.4 数据库优化
0.3 建立Prompt系统                     1.3 动态难度算法增强
0.4 增强AI验证管道                     1.4 AI质量评价算法
0.5 优化缓存策略                       2.1 测试框架
0.6 AI质量监控                         2.2 清理调试代码
─────────────────────                  ──────────────────         ──────────────────
Phase 0 完成后可演示真实AI生成          Phase 1 完成可写入论文       Phase 2-3 完成后可答辩
```

---

# 关键里程碑

| 里程碑 | 完成阶段 | 验收标准 |
|--------|----------|----------|
| M0: AI引擎就绪 | Phase 0部分完成 | Agnes可调用，游戏使用真实AI |
| M1: 算法论文化 | Phase 1完成 | 4个算法有代码+文档+测试 |
| M2: 工程完整 | Phase 2完成 | 测试通过，代码整洁 |
| M3: 毕业就绪 | Phase 3完成 | 完整测试通过，报告输出 |

---

# 预计总工时

| Phase | 任务数 | 预计工时 |
|-------|--------|----------|
| Phase 0 | 6 | ~9小时 |
| Phase 1 | 4 | ~7.5小时 |
| Phase 2 | 4 | ~6.5小时 |
| Phase 3 | 4 | ~4.5小时 |
| **总计** | **18** | **~27.5小时** |

---

# 第一个开发任务

**任务 0.1: 切换AI配置为Agnes**

这是最关键的第一步，决定了后续所有任务的基础。

**具体操作：**
1. 更新 `.env.example` — 添加Agnes配置段
2. 修改 `server/ai/config/config.py` — 支持AI_PROVIDER切换
3. 修改 `server/.env` — 添加AGNES_API_KEY（用户提供）

**验收标准：**
- `AI_PROVIDER=agnes` 时能正确加载Agnes配置
- `AI_PROVIDER=mimo` 时仍能使用MiMo（向后兼容）
- `AI_PROVIDER=mock` 时回退到Mock

---

**请确认调整后路线图后，我将开始执行第一个任务。**
