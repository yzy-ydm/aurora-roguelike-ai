"""
AI Provider 工厂

根据配置动态创建对应的LLM Provider实例。
支持: agnes, mimo, mock (内建降级)
所有Provider必须实现 LLMProvider 接口。
"""

from typing import Dict, List, Optional, Type

from .llm_provider import LLMProvider


class ProviderFactory:
    """
    AI Provider 工厂类

    职责:
    - 根据 AI_PROVIDER 环境变量创建对应的 LLMProvider 实例
    - 维护 Provider 注册表，支持动态扩展
    - 提供可用 Provider 列表查询

    使用方式:
        provider = ProviderFactory.create("agnes")
        # 或
        provider = ProviderFactory.create(os.getenv("AI_PROVIDER", "mock"))
    """

    # Provider 注册表
    _registry: Dict[str, Type[LLMProvider]] = {}

    @classmethod
    def register(cls, name: str, provider_class: Type[LLMProvider]) -> None:
        """
        注册一个 Provider 类

        Args:
            name: Provider 名称 (对应 AI_PROVIDER 环境变量值)
            provider_class: Provider 类 (必须继承 LLMProvider)
        """
        cls._registry[name] = provider_class

    @classmethod
    def create(cls, provider_type: str, **kwargs) -> Optional[LLMProvider]:
        """
        根据 Provider 名称创建实例

        Args:
            provider_type: Provider 名称 (agnes/mimo)
            **kwargs: 构造参数

        Returns:
            LLMProvider 实例，如果未注册则返回 None
        """
        provider_class = cls._registry.get(provider_type)
        if provider_class is None:
            return None
        return provider_class(**kwargs)

    @classmethod
    def get_available_providers(cls) -> List[str]:
        """
        获取所有已注册的 Provider 名称列表

        Returns:
            Provider 名称列表
        """
        return list(cls._registry.keys())

    @classmethod
    def is_registered(cls, provider_type: str) -> bool:
        """
        检查 Provider 是否已注册

        Args:
            provider_type: Provider 名称

        Returns:
            True 表示已注册
        """
        return provider_type in cls._registry


# ==================== 自动注册 ====================
# 导入所有 Provider 以确保它们被注册到工厂

from .agnes_provider import AgnesProvider  # noqa: E402
from .mimo_client import MimoClient         # noqa: E402

# 注册 Agnes Provider
ProviderFactory.register("agnes", AgnesProvider)

# 注册 MiMo Provider
ProviderFactory.register("mimo", MimoClient)
