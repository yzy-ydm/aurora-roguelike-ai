# Phase 0: AI系统升级计划

> 生成日期：2026-09-21
> 基于：AI_CURRENT_ARCHITECTURE.md
> 目标：安全、可扩展地接入Agnes AI，不破坏现有功能

---

## 执行原则

1. **扩展而非重写** — 保留所有现有代码，新增Agnes实现
2. **向后兼容** — `LLM_PROVIDER=mimo` 仍然工作
3. **最小改动** — 只修改必须修改的地方
4. **测试先行** — 每个改动前确保有测试覆盖

---

# 任务0.1: 全面检查现有AI架构

## 检查结果（已完成）

### 当前AI调用链

```
Godot Client (game_scene.gd:310)
  → set_service_type(AIServiceType.REAL)
  → AIContentService._call_cloud_ai_floor()
  → HTTP POST to FastAPI AI Service (port 8001)
  → ai_routes.py /api/generate/floor
  → ai_service.py generate_floor()
  → _should_use_llm() → llm_provider.generate(prompt)
  → MimoClient.generate() 或 Mock fallback
  → validator.validate() + quality_checker.check()
  → 缓存 → 返回JSON
```

### Provider抽象层

| 组件 | 文件 | 行数 | 状态 |
|------|------|------|------|
| LLMProvider (抽象基类) | `services/llm_provider.py` | 66 | ✅ 完善 |
| MimoClient (Anthropic格式) | `services/mimo_client.py` | 203 | ✅ 完整 |
| PromptBuilder | `services/prompt_builder.py` | 662 | ✅ 10个Prompt方法 |
| AIValidator | `services/ai_validator.py` | 299 | ✅ 基础验证 |
| AIQualityChecker | `services/ai_quality_checker.py` | 228 | ✅ 范围检查 |
| AIService (核心) | `services/ai_service.py` | 1472 | ⚠️ 硬编码"Mimo" |

### 关键发现

1. **LLMProvider抽象层已存在** — 无需重新设计
2. **MimoClient是LLMProvider的实现** — Agnes只需实现同一接口
3. **ai_service.py硬编码"Mimo"** — 仅6行需要修改
4. **已有LLMProvider抽象层** — 无需重新设计
5. **PromptBuilder独立于Provider** — 可复用
6. **测试框架已部分存在** — test_ai_service.py已覆盖Mock和Mimo
7. **JSON解析逻辑在MimoClient中** — Agnes需重写_extract_content

### 需要修改的位置

| 文件 | 修改量 | 风险 |
|------|--------|------|
| `ai_service.py` | ~6行 | 低 — 替换初始化逻辑 |
| `.env.example` | +10行 | 无 — 仅文档 |
| `requirements.txt` | +1行(可选) | 无 |
| **新增** `agnes_provider.py` | ~150行 | 无 — 新文件 |
| **新增** `config/config.py` | ~50行 | 无 — 新文件 |

### 风险分析

| 风险 | 等级 | 缓解方案 |
|------|------|----------|
| 硬编码"Mimo"替换不当 | 🟡 中 | 用工厂模式，保留if/elif分支 |
| Agnes API响应格式不同 | 🟡 中 | 独立_parse_json逻辑 |
| Prompt与模型不兼容 | 🟢 低 | 先用Mock验证，再接入真实 |
| 缓存key不含Provider | 🟢 低 | 修改缓存key加入provider标识 |

---

# 任务0.2: Agnes接入方案设计

## 配置管理

### 环境变量设计

```bash
# .env
# ==================== AI Provider配置 ====================
# AI_PROVIDER: agnes, mimo, mock, auto
# auto = 尝试Agnes，失败则降级MiMo，再失败则Mock
AI_PROVIDER=agnes

# Agnes AI配置 (OpenAI兼容格式)
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
MIMO_MAX_TOKENS=4096
MIMO_TEMPERATURE=0.7
```

### 配置优先级

```
AI_PROVIDER (新) > LLM_PROVIDER (旧，向后兼容)
AGNES_API_KEY > AGNES_API_KEY (默认值)
MIMO_API_KEY > MIMO_API_KEY (已有)
```

## AgnesProvider实现设计

### 类图

```
LLMProvider (ABC)
├── MimoClient (Anthropic格式) — 保留
└── AgnesProvider (OpenAI格式) — 新增
    ├── __init__(api_key, base_url, model, max_tokens, temperature, timeout)
    ├── is_available() -> bool
    ├── get_provider_name() -> str      # "agnes"
    ├── get_config() -> Dict            # 配置信息
    └── generate(prompt) -> Dict        # 核心方法
        ├── 构造OpenAI请求体
        ├── HTTP POST {base_url}/chat/completions
        ├── 提取 choices[0].message.content
        └── _parse_json(text) -> Dict   # 复用MimoClient的JSON解析逻辑
```

### 关键差异处理

| 特性 | Agnes (OpenAI) | MiMo (Anthropic) |
|------|---------------|------------------|
| API路径 | `/v1/chat/completions` | `/v1/messages` |
| 认证 | `Authorization: Bearer` | `x-api-key` |
| 请求字段 | `model, messages, max_tokens, temperature` | 同 |
| 响应路径 | `choices[0].message.content` | `content[0].text` |
| JSON解析 | 相同逻辑 | 相同逻辑 |

### 代码复用策略

```python
# agnes_provider.py
from .mimo_client import MimoClient  # 复用_parse_json方法
# 或直接复制_parse_json逻辑（避免循环依赖）

class AgnesProvider(LLMProvider):
    def __init__(self, ...):
        # 类似MimoClient的初始化模式
        self.api_key = os.getenv("AGNES_API_KEY", "")
        self.base_url = os.getenv("AGNES_BASE_URL", "https://apihub.agnes-ai.com/v1")
        ...

    def get_provider_name(self) -> str:
        return "agnes"

    async def generate(self, prompt: str) -> Dict[str, Any]:
        # 1. 构造OpenAI格式请求
        # 2. POST {base_url}/chat/completions
        # 3. 提取 choices[0].message.content
        # 4. 复用JSON解析逻辑
        ...
```

### ai_service.py 修改方案

```python
# 修改前 (第18行和第60-68行):
from .mimo_client import MimoClient
...
if self.provider_type == "mimo":
    self.llm_provider = MimoClient()
    self.prompt_builder = PromptBuilder()
    if self.llm_provider.is_available():
        logger.info(f"AIService initialized with MiMo provider")
    else:
        logger.warning("AIService: MiMo provider not available, will fallback to mock")
else:
    logger.info("AIService initialized with Mock mode")

# 修改后:
from .mimo_client import MimoClient
from .agnes_provider import AgnesProvider
...
if self.provider_type == "agnes":
    self.llm_provider = AgnesProvider()
    self.prompt_builder = PromptBuilder()
    if self.llm_provider.is_available():
        logger.info(f"AIService initialized with {self.llm_provider.get_provider_name()} provider")
    else:
        logger.warning(f"AIService: {self.llm_provider.get_provider_name()} not available, will fallback")
elif self.provider_type == "mimo":
    self.llm_provider = MimoClient()
    self.prompt_builder = PromptBuilder()
    if self.llm_provider.is_available():
        logger.info(f"AIService initialized with MiMo provider")
    else:
        logger.warning("AIService: MiMo provider not available, will fallback to mock")
else:
    logger.info("AIService initialized with Mock mode")
```

### ai_mode 标签修改

当前 `ai_mode` 字段值：`"mock"`, `"mimo"`, `"mock_fallback"`
修改为：`"mock"`, `"agnes"`, `"mimo"`, `"mock_fallback"`, `"mimo_fallback"`

---

# 任务0.3: 测试方案设计

## 测试分层

```
测试类型                    位置                    覆盖率目标
─────────────────────────────────────────────────────────────
Provider单元测试         server/ai/tests/     100%
API连接测试              server/ai/tests/     100%
AI生成流程集成测试       server/ai/tests/     80%
Godot客户端测试          client/tests/        可选
```

## 测试清单

### 服务端测试

| # | 测试名 | 测试内容 | 预期结果 |
|---|--------|----------|----------|
| T1 | `test_agnes_provider_init` | 无API Key时is_available() | False |
| T2 | `test_agnes_provider_init_with_key` | 有API Key时is_available() | True |
| T3 | `test_agnes_provider_name` | get_provider_name() | "agnes" |
| T4 | `test_agnes_generate_request_format` | 验证请求URL和Header | 正确格式 |
| T5 | `test_agnes_generate_response_parse` | 验证OpenAI响应解析 | 正确提取content |
| T6 | `test_agnes_generate_json_extract` | AI返回含markdown包裹 | 正确提取JSON |
| T7 | `test_agnes_timeout_handling` | 超时异常处理 | 抛出Exception |
| T8 | `test_aiservice_init_agnes` | AI_PROVIDER=agnes初始化 | llm_provider为AgnesProvider |
| T9 | `test_aiservice_init_mimo_fallback` | AGNES_API_KEY为空时 | 回退到Mimo或Mock |
| T10 | `test_aiservice_generate_floor_agnes` | 完整楼层生成流程 | 返回正确结构 |
| T11 | `test_aiservice_agnes_fallback_to_mock` | Agnes异常时降级 | ai_mode="mock_fallback" |
| T12 | `test_config_loader` | 环境变量加载 | 正确读取各配置项 |
| T13 | `test_backward_compat_mimo` | LLM_PROVIDER=mimo | 仍然工作 |
| T14 | `test_cache_key_with_provider` | 缓存key含provider | agnes/mimo隔离 |

### Godot端测试

| # | 测试名 | 测试内容 | 预期结果 |
|---|--------|----------|----------|
| G1 | `test_ai_content_service_real_mode` | 连接真实AI服务 | 返回有效数据 |
| G2 | `test_ai_content_service_fallback` | AI服务不可用时 | 使用Mock降级 |
| G3 | `test_ai_request_timeout` | 请求超时场景 | 正确触发降级 |
| G4 | `test_ai_token_flow` | Token获取流程 | 正确获取并缓存 |

## Mock测试策略

不使用真实API的情况下验证代码逻辑：

```python
# 使用responses库拦截HTTP请求
import responses

@responses.activate
def test_agnes_generate():
    responses.add(
        responses.POST,
        "https://apihub.agnes-ai.com/v1/chat/completions",
        json={
            "choices": [{
                "message": {"content": '{"floor": 1, "rooms": []}'}
            }]
        },
        status=200
    )
    provider = AgnesProvider(api_key="test_key")
    result = asyncio.run(provider.generate("test prompt"))
    assert result["floor"] == 1
```

---

# Phase 0 任务执行顺序

```
Step 1: 新建 config/config.py        (配置管理)       0.5h
Step 2: 新建 agnes_provider.py       (Agnes Provider) 1.5h
Step 3: 修改 ai_service.py           (切换Provider)   0.5h
Step 4: 修改 .env.example            (添加Agnes配置)  0.5h
Step 5: 运行现有测试                  (确认不破坏)     0.5h
Step 6: 编写 Agnes Provider测试      (T1-T7)         1.5h
Step 7: 编写 集成测试                 (T8-T14)        1.5h
Step 8: 端到端验证                    (Godot连接)     1.0h
────────────────────────────────────────────────────────
总计:                                                                7.5h
```

---

# 验收标准

## Step 5 前（代码改动完成）
- [ ] `AI_PROVIDER=agnes` 时AIService正确初始化AgnesProvider
- [ ] `AI_PROVIDER=mimo` 时AIService仍正确初始化MimoClient
- [ ] `AI_PROVIDER=mock` 时AIService使用Mock模式
- [ ] 现有测试全部通过（`pytest server/ai/tests/`）
- [ ] 不引入任何新的依赖（暂不添加openai SDK）

## Step 8 后（端到端验证）
- [ ] Agnes API可成功调用并返回有效JSON
- [ ] 游戏可正常运行AI生成内容
- [ ] Fallback机制正常工作（Agnes失败→Mock）
- [ ] 缓存隔离正确（agnes/mimo不使用相同缓存）
- [ ] 所有14个服务端测试通过
- [ ] 日志正确显示"agnes"而非"mimo"

---

# 不做的变更

以下内容**不在Phase 0范围内**：

1. ~~修改PromptBuilder~~ — 保持现有Prompt，后续Phase 1优化
2. ~~修改AIValidator~~ — 保持现有验证逻辑，后续Phase 1增强
3. ~~修改AIQualityChecker~~ — 保持现有质量检查，后续Phase 1增强
4. ~~修改Godot客户端~~ — AI格式变化对Godot透明
5. ~~修改数据库~~ — ai_generations表无需变更
6. ~~添加新功能~~ — 仅替换Provider实现

---

*本文档为Phase 0执行计划，等待用户确认后开始编码。*
