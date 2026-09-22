# Aurora-Roguelike-AI AI系统当前架构分析

> 生成日期：2026-09-21
> 目的：为Agnes AI接入提供架构分析基础

---

## 一、当前AI调用流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        Godot客户端                              │
│                                                                 │
│  game_scene.gd                                                 │
│  └─ AIContentService._ready() → _initialize_async()            │
│       ├─ FakeAIService (FAKE模式)                               │
│       └─ HTTPRequest → AI服务端                                  │
│                                                                     │
│  set_service_type(AIServiceType.REAL)  ← game_scene.gd:310      │
│                                                                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP POST
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI AI服务 (Port 8001)                    │
│                                                                 │
│  ai_routes.py                                                    │
│  ├─ POST /api/generate/floor     → ai_service.generate_floor()  │
│  ├─ POST /api/generate/room      → ai_service.generate_room()   │
│  ├─ POST /api/generate/monster   → ai_service.generate_monster()│
│  ├─ POST /api/generate/weapon    → ai_service.generate_weapon() │
│  ├─ POST /api/generate/event     → ai_service.generate_event()  │
│  ├─ POST /api/generate/dialogue  → ai_service.generate_dialogue()│
│  ├─ POST /api/generate/upgrade   → ai_service.generate_upgrade()│
│  ├─ POST /api/generate/difficulty→ ai_service.generate_difficulty()│
│  ├─ POST /api/generate/room_strategy → ai_service.generate_room_strategy()│
│  ├─ POST /api/generate/npc_memory → ai_service.generate_npc_memory()│
│  └─ POST /api/generate/context_event → ai_service.generate_context_event()│
│                                                                 │
│  ai_service.py (1472行)                                         │
│  ├─ __init__()                                                  │
│  │   ├─ self.provider_type = os.getenv("LLM_PROVIDER", "mock") │
│  │   └─ if provider_type == "mimo":                             │
│  │         self.llm_provider = MimoClient()                     │
│  │         self.prompt_builder = PromptBuilder()                │
│  │                                                               │
│  ├─ _should_use_llm() → 检查provider是否可用                    │
│  ├─ _generate_*_with_llm() → prompt_builder.build_*(...)        │
│  │                          → llm_provider.generate(prompt)      │
│  ├─ _mock_generate_*() → 本地降级生成                            │
│  └─ validator + quality_checker 处理                             │
│                                                                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              ┌─────────┐ ┌─────────┐ ┌─────────┐
              │MimoClient│ │PromptBuilder│ │Validator│
              │Anthropic │ │10个Prompt │ │JSON校验 │
              │格式      │ │生成方法   │ │范围验证 │
              └─────────┘ └─────────┘ └─────────┘
```

---

## 二、Provider设计分析

### 2.1 现有抽象层

**文件：** `server/ai/services/llm_provider.py`

```python
class LLMProvider(ABC):
    """所有LLM提供商必须实现此接口"""

    @abstractmethod
    async def generate(self, prompt: str) -> Dict[str, Any]:
        """调用LLM生成内容"""
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """检查Provider是否可用"""
        pass

    @abstractmethod
    def get_provider_name(self) -> str:
        """获取Provider名称"""
        pass

    def get_config(self) -> Dict[str, Any]:
        """获取配置信息（不包含敏感信息）"""
        return {
            "provider": self.get_provider_name(),
            "available": self.is_available()
        }
```

**评价：** 设计合理，职责清晰，支持多Provider扩展。

### 2.2 MimoClient实现

**文件：** `server/ai/services/mimo_client.py` (203行)

```python
class MimoClient(LLMProvider):
    """小米 MiMo API 客户端 — Anthropic Messages API格式"""

    # 关键特征：
    # 1. 使用 httpx.AsyncClient 异步HTTP
    # 2. Endpoint: /v1/messages (Anthropic格式)
    # 3. Header: x-api-key, anthropic-version
    # 4. 响应解析: content[0].text → JSON.parse
    # 5. JSON容错: 提取{...}部分
    # 6. 错误处理: TimeoutException, ConnectError
    # 7. 装饰器: @log_timing 计时
```

**关键点：**
- `generate()` 返回 `Dict[str, Any]`
- `_parse_json()` 已有JSON容错逻辑（可复用）
- `_extract_content()` 是Anthropic格式专用（Agnes需要修改）

### 2.3 PromptBuilder设计

**文件：** `server/ai/services/prompt_builder.py` (662行)

| 方法 | 用途 |
|------|------|
| `build_floor_prompt()` | 楼层生成 |
| `build_room_content_prompt()` | 房间内容 |
| `build_monster_prompt()` | 怪物配置 |
| `build_weapon_prompt()` | 武器生成 |
| `build_event_prompt()` | 事件生成 |
| `build_dialogue_prompt()` | NPC对话 |
| `build_upgrade_prompt()` | 升级选项 |
| `build_difficulty_prompt()` | 难度调整 |
| `build_room_strategy_prompt()` | 房间策略 |
| `build_npc_memory_prompt()` | NPC记忆 |
| `build_context_event_prompt()` | 上下文事件 |
| `parse_ai_response()` | JSON解析（已有容错） |

**特点：**
- 系统Prompt定义格式约束
- 用户Prompt包含上下文参数
- 返回标准JSON格式要求
- 所有Prompt已嵌入代码（无外部文件）

### 2.4 AIService核心逻辑

**文件：** `server/ai/services/ai_service.py` (1472行)

**初始化流程（第42-70行）：**
```python
def __init__(self):
    self.provider_type = os.getenv("LLM_PROVIDER", "mock").lower()

    self.llm_provider = None
    self.prompt_builder = None

    self.validator = AIValidator()
    self.quality_checker = AIQualityChecker()

    if self.provider_type == "mimo":        # ← 硬编码"mimo"
        self.llm_provider = MimoClient()    # ← 硬编码MimoClient
        self.prompt_builder = PromptBuilder()
        # ... 日志和警告
    else:
        logger.info("AIService initialized with Mock mode")
```

**生成流程（以楼层为例）：**
```python
async def generate_floor(self, floor_level, player_level, player_stats):
    # 1. 缓存检查
    cached = floor_cache.get_floor(floor_level, player_level)
    if cached: return cached

    # 2. LLM调用
    if self._should_use_llm():
        try:
            result = await self._generate_floor_with_llm(...)
            result = self.validator.validate_floor_data(result)
            result = self.quality_checker.check_floor_quality(result, ...)
            result["ai_mode"] = "mimo"         # ← 硬编码"mimo"
            floor_cache.set_floor(...)
            return result
        except Exception:
            # 重试一次
            ...
            # 仍失败则fallback

    # 3. Mock降级
    result = self._mock_generate_floor(...)
    result["ai_mode"] = "mock_fallback" if self.provider_type == "mimo" else "mock"
    return result
```

**发现：** `ai_mode` 字段硬编码为 `"mimo"` 或 `"mock"`，需要扩展为通用值。

---

## 三、需要修改的位置

### 3.1 必须修改的文件

| 文件 | 修改内容 | 原因 |
|------|----------|------|
| `server/ai/services/ai_service.py` | 替换硬编码"MimoClient" | 支持Agnes Provider |
| `server/.env.example` | 添加Agnes配置段 | 环境变量管理 |
| `server/requirements.txt` | 添加 openai (可选) | 依赖管理 |

### 3.2 新增的文件

| 文件 | 内容 | 说明 |
|------|------|------|
| `server/ai/services/agnes_provider.py` | Agnes AI Provider | OpenAI格式兼容 |
| `server/ai/config/config.py` | 统一配置管理 | 支持多Provider切换 |

### 3.3 可能需要修改的文件

| 文件 | 修改内容 | 原因 |
|------|----------|------|
| `server/ai/services/__init__.py` | 导出AgnesProvider | 模块导入 |
| `server/ai/tests/test_ai_service.py` | 添加Agnes测试 | 测试覆盖 |
| `server/ai/tests/test_mimo_client.py` | 保持不变 | 向后兼容 |
| `server/ai/services/ai_service.py` | 修改ai_mode标签 | 区分agnes/mimo/mock |

---

## 四、风险分析

### 4.1 高风险点

| # | 风险 | 影响 | 缓解方案 |
|---|------|------|----------|
| 1 | **ai_service.py硬编码"mimo"** | 直接替换可能破坏现有功能 | 使用工厂模式，保留Mimo分支 |
| 2 | **PromptBuilder格式假设** | Prompt中包含"只返回JSON"指令，不同模型响应格式可能有差异 | 先用Mock验证，再接入真实API |
| 3 | **MimoClient的_extract_content()** | 解析Anthropic响应格式（content[0].text） | AgnesProvider需解析OpenAI格式（choices[0].message.content） |
| 4 | **14处"Mimo"日志文本** | 日志显示"Mimo"会误导 | 全部替换为通用日志 |

### 4.2 中风险点

| # | 风险 | 影响 | 缓解方案 |
|---|------|------|----------|
| 5 | **缓存key不含Provider信息** | 切换Provider后可能使用旧的缓存结果 | 缓存key加入Provider标识 |
| 6 | **测试中的环境设置** | test_ai_service.py中os.environ设置可能相互干扰 | 使用patch.dict隔离测试 |
| 7 | **ai_mode字段语义** | "mimo" vs "agnes" 对前端/Godot端无影响 | 仅影响日志和统计，向后兼容 |

### 4.3 低风险点

| # | 风险 | 影响 | 缓解方案 |
|---|------|------|----------|
| 8 | **requirements添加新依赖** | openai SDK可能增加安装复杂度 | 优先使用httpx（已有），仅在需要时添加openai |
| 9 | **Prompt模板兼容性** | 不同模型可能对相同Prompt有不同响应质量 | PromptBuilder独立于Provider，可单独优化 |

---

## 五、修改策略（扩展而非重写）

### 原则
1. **不删除任何现有代码** — MimoClient完整保留
2. **最小化改动** — 只在ai_service.py的__init__和_should_use_llm中修改
3. **向后兼容** — `LLM_PROVIDER=mimo` 仍然工作
4. **新增文件** — AgnesProvider作为新文件添加

### 改动点清单

**ai_service.py 需要修改的行（约6行）：**
```python
# 修改前：
from .mimo_client import MimoClient
self.provider_type = os.getenv("LLM_PROVIDER", "mock").lower()
if self.provider_type == "mimo":
    self.llm_provider = MimoClient()

# 修改后：
from .mimo_client import MimoClient
from .agnes_provider import AgnesProvider
self.provider_type = os.getenv("AI_PROVIDER", os.getenv("LLM_PROVIDER", "mock")).lower()
if self.provider_type in ("mimo", "agnes"):
    if self.provider_type == "agnes":
        self.llm_provider = AgnesProvider()
    else:
        self.llm_provider = MimoClient()
    self.prompt_builder = PromptBuilder()
```

**新增 config/config.py：**
```python
# 统一配置读取
AI_PROVIDER = os.getenv("AI_PROVIDER", os.getenv("LLM_PROVIDER", "mock")).lower()
AGNES_API_KEY = os.getenv("AGNES_API_KEY", "")
AGNES_BASE_URL = os.getenv("AGNES_BASE_URL", "https://apihub.agnes-ai.com/v1")
AGNES_MODEL = os.getenv("AGNES_MODEL", "agnes-2.5-flash")
```

---

## 六、Agnes Provider技术规格

### API格式对比

| 特性 | MiMo (Anthropic) | Agnes (OpenAI) |
|------|-------------------|----------------|
| 路径 | `/v1/messages` | `/v1/chat/completions` |
| Header | `x-api-key` | `Authorization: Bearer` |
| Version | `anthropic-version` | 无 |
| 请求体 | `messages: [{role, content}]` | `messages: [{role, content}]` |
| 响应 | `content: [{type, text}]` | `choices: [{message: {role, content}}]` |
| JSON解析 | `content[0].text` | `choices[0].message.content` |

### 关键差异
1. **认证头不同** — `x-api-key` vs `Bearer Token`
2. **响应结构不同** — `content[]` vs `choices[]`
3. **JSON解析路径不同** — 需要分别处理

---

*本文档仅分析，不包含代码修改。*
