"""
LLM Provider 抽象接口

定义大语言模型提供商的统一接口
所有LLM Provider必须实现此接口
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional


class LLMProvider(ABC):
    """
    LLM Provider 抽象基类

    所有LLM提供商（MiMo、OpenAI、Claude等）必须实现此接口
    """

    @abstractmethod
    async def generate(self, prompt: str) -> Dict[str, Any]:
        """
        调用LLM生成内容

        Args:
            prompt: 提示词

        Returns:
            生成的内容（字典格式）

        Raises:
            Exception: API调用失败时抛出异常
        """
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """
        检查Provider是否可用

        Returns:
            True表示可用，False表示不可用
        """
        pass

    @abstractmethod
    def get_provider_name(self) -> str:
        """
        获取Provider名称

        Returns:
            Provider名称字符串
        """
        pass

    def get_config(self) -> Dict[str, Any]:
        """
        获取Provider配置信息（用于日志）

        Returns:
            配置信息字典（不包含敏感信息）
        """
        return {
            "provider": self.get_provider_name(),
            "available": self.is_available()
        }
