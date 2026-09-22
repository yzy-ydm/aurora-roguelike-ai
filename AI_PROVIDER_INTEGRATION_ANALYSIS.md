# AI Provider 集成分析

> 生成日期：2026-09-22
> 目的：为 Provider Factory 集成提供技术方案

---

## 一、当前AI调用完整流程

```
Godot Client
  ↓ HTTP POST /api/generate/floor (Bearer Token)
FastAPI AI Service (Port 8001)
  ↓
ai_routes.py → generate_floor()
  ↓
ai_service.py → AIService.generate_floor()
  ↓
┌─ if _should_use_llm(): ───────────────────────┐
│                                                 │
│  _generate_floor_with_llm()                    │
│    → prompt_builder.build_floor_prompt()       │
│    → llm_provider.generate(prompt)             │
│      → MimoClient.generate()  ← 硬编码         │
│        → Anthropic API                          │
│        → JSON parse                             │
│                                                 │
│  validator.validate_floor_data(result)          │
│  quality_checker.check_floor_quality(result)    │
│  cache.set_floor(result)                        │
│                                                 │
└─────────────────────────────────────────────────┘
  ↓ (失败)
_mock_generate_floor() → Mock降级
```

---

## 二、当前Provider加载方式

### 现状代码 (ai_service.py 第42-70行)

```python
def __init__(self):
    # 读取配置
    self.provider_type = os.getenv("LLM_PROVIDER", "mock").lower()

    # 初始化LLM Provider
    self.llm_provider = None
    self.prompt_builder = None

    # 硬编码分支
    if self.provider_type == "mimo":        # ← 只支持mimo
        self.llm_provider = MimoClient()    # ← 直接实例化
        self.prompt_builder = PromptBuilder()
        if self.llm_provider.is_available():
            logger.info(f"AIService initialized with MiMo provider")
        else:
            logger.warning("AIService: MiMo provider not available, will fallback to mock")
    else:
        logger.info("AIService initialized with Mock mode")
```

### 问题

| # | 问题 | 影响 |
|---|------|------|
| 1 | 只有 `if provider_type == "mimo"` 分支 | 无法支持Agnes |
| 2 | 直接 import MimoClient | 违反依赖倒置原则 |
| 3 | 无工厂模式 | 新增Provider需修改ai_service.py |
| 4 | `ai_mode` 字段硬编码 `"mimo"` | 无法区分agnes/mimo |
| 5 | `_should_use_llm()` 检查 `== "mimo"` | 无法判断agnes是否可用 |

---

## 三、存在的问题

### 3.1 代码层面

**硬编码分布（约14处）：**
```
ai_service.py 第60行:  if self.provider_type == "mimo":
ai_service.py 第135行: result["ai_mode"] = "mock_fallback" if self.provider_type == "mimo" else "mock"
ai_service.py 第208行: result["ai_mode"] = "mock_fallback" if self.provider_type == "mimo" else "mock"
ai_service.py 第281行: result["ai_mode"] = "mock_fallback" if self.provider_type == "mimo" else "mock"
ai_service.py 第352行: result["ai_mode"] = "mock_fallback" if self.provider_type == "mimo" else "mock"
ai_service.py 第365行: self.provider_type == "mimo"   (in _should_use_llm)
... (共14处)
```

**Import关系：**
- `ai_service.py:18` → `from .mimo_client import MimoClient`
- 无Provider注册/工厂机制

### 3.2 测试层面

- `test_ai_service.py` 中所有测试均设置 `LLM_PROVIDER=mock` 或 `mimo`
- 无Agnes相关测试
- 无Provider切换集成测试

### 3.3 配置层面

- 当前只读 `LLM_PROVIDER` 环境变量
- 无统一 `AI_PROVIDER` 配置
- Agnes配置已在 `.env.example` 中定义但未使用

---

## 四、本次修改方案

### 4.1 设计目标

```
AIService (不直接依赖具体Provider)
    ↓
ProviderFactory (统一创建入口)
    ↓
├── AgnesProvider  (OpenAI格式)
├── MimoClient     (Anthropic格式)
└── Mock (内建降级)
```

### 4.2 新增文件

**`server/ai/services/provider_factory.py`**
```python
class ProviderFactory:
    """Provider工厂，根据配置创建对应的LLMProvider"""

    _registry = {}  # 注册表

    @classmethod
    def register(cls, name: str, provider_class):
        cls._registry[name] = provider_class

    @classmethod
    def create(cls, provider_type: str, **kwargs):
        if provider_type in cls._registry:
            return cls._registry[provider_type](**kwargs)
        return None

    @classmethod
    def get_available_providers(cls) -> List[str]:
        return list(cls._registry.keys())
```

**注册时机：**
- `services/__init__.py` 中导入所有Provider（触发模块加载）
- 或使用装饰器自动注册

### 4.3 修改 ai_service.py

**修改点清单：**

| 行号范围 | 修改内容 | 风险 |
|----------|----------|------|
| 18 | `from .mimo_client import MimoClient` → 移除直接import | 低 |
| 50 | `os.getenv("LLM_PROVIDER")` → `os.getenv("AI_PROVIDER", os.getenv("LLM_PROVIDER"))` | 无 |
| 60-68 | `if provider_type == "mimo"` → `ProviderFactory.create()` | 低 |
| 362-368 | `_should_use_llm()` → 使用 `llm_provider is not None` | 低 |
| 135/208/281/352等 | `"mimo"` → `llm_provider.get_provider_name()` | 低 |

**修改后 `__init__` 示例：**
```python
def __init__(self):
    self.provider_type = os.getenv(
        "AI_PROVIDER",
        os.getenv("LLM_PROVIDER", "mock")
    ).lower()

    self.llm_provider = None
    self.prompt_builder = None

    # 使用工厂创建Provider
    if self.provider_type != "mock":
        self.llm_provider = ProviderFactory.create(self.provider_type)
        if self.llm_provider and self.llm_provider.is_available():
            self.prompt_builder = PromptBuilder()
            logger.info(f"AIService initialized with {self.llm_provider.get_provider_name()} provider")
        else:
            logger.warning(f"AIService: {self.provider_type} not available, will fallback to mock")
    else:
        logger.info("AIService initialized with Mock mode")
```

### 4.4 配置统一

**环境变量优先级：**
```
AI_PROVIDER > LLM_PROVIDER > "mock" (默认)
```

**Agnes配置：**
```
AGNES_API_KEY
AGNES_BASE_URL
AGNES_MODEL
AGNES_MAX_TOKENS
AGNES_TEMPERATURE
```

**MiMo配置（保留）：**
```
MIMO_API_KEY
MIMO_MODEL
MIMO_ENDPOINT
```

---

## 五、修改风险分析

| # | 风险点 | 等级 | 缓解方案 |
|---|--------|------|----------|
| 1 | 修改`__init__`可能影响已有测试 | 🟡 中 | 先写工厂测试，再改ai_service |
| 2 | `ai_mode` 字段值变化影响Godot解析 | 🟢 低 | Godot端不解析此字段，仅日志用 |
| 3 | Provider Factory引入新依赖链 | 🟢 低 | Factory纯Python代码，无新依赖 |
| 4 | 向后兼容 `LLM_PROVIDER=mimo` | 🟡 中 | 保留旧环境变量支持 |
| 5 | 测试文件中硬编码"mimo"字符串 | 🟢 低 | 仅影响测试数据，不影响逻辑 |

---

## 六、不修改的内容

以下内容**不在本次范围内**：

1. ~~Godot客户端代码~~ — Provider切换对Godot透明
2. ~~PromptBuilder~~ — Prompt独立于Provider
3. ~~AIValidator~~ — 验证逻辑与Provider无关
4. ~~AIQualityChecker~~ — 质量检查与Provider无关
5. ~~缓存机制~~ — 缓存Key保持不变
6. ~~路由层(ai_routes.py)~~ — 接口不变

---

*分析完成，准备开始编码。*
