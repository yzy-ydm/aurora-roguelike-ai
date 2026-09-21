"""
Agnes AI Provider 客户端

实现LLMProvider接口
使用OpenAI Chat Completions API格式调用Agnes AI
API文档: https://apihub.agnes-ai.com/v1

配置方式:
    通过环境变量配置 (禁止硬编码API Key):
    - AGNES_API_KEY: Agnes API密钥
    - AGNES_BASE_URL: API基础地址 (默认: https://apihub.agnes-ai.com/v1)
    - AGNES_MODEL: 模型名称 (默认: agnes-2.5-flash)
    - AGNES_MAX_TOKENS: 最大token数 (默认: 4096)
    - AGNES_TEMPERATURE: 温度参数 (默认: 0.7)
"""

import os
import json
from typing import Dict, Any, Optional

import httpx

from .llm_provider import LLMProvider
from logger.logger import logger, log_timing


class AgnesProvider(LLMProvider):
    """
    Agnes AI OpenAI兼容Provider

    使用OpenAI Chat Completions API格式调用Agnes AI服务。
    与MimoClient的区别:
    - API路径: /v1/chat/completions (vs /v1/messages)
    - 认证: Authorization: Bearer (vs x-api-key)
    - 响应格式: choices[0].message.content (vs content[0].text)
    """

    DEFAULT_BASE_URL = "https://apihub.agnes-ai.com/v1"
    DEFAULT_MODEL = "agnes-2.5-flash"
    DEFAULT_MAX_TOKENS = 4096
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_TIMEOUT = 120.0

    def __init__(
        self,
        api_key: str = "",
        base_url: str = "",
        model: str = "",
        max_tokens: int = 0,
        temperature: float = 0.0,
        timeout: float = 0.0,
    ):
        """
        初始化Agnes AI客户端

        配置优先级: 构造参数 > 环境变量 > 默认值

        Args:
            api_key: API密钥 (优先使用此参数, 否则读环境变量)
            base_url: API基础地址
            model: 模型名称
            max_tokens: 最大token数
            temperature: 温度参数
            timeout: 请求超时时间(秒)
        """
        # API Key: 参数 > 环境变量 (禁止硬编码)
        self.api_key = api_key if api_key else os.getenv("AGNES_API_KEY", "")

        # Base URL: 参数 > 环境变量 > 默认值
        self.base_url = (
            base_url
            if base_url
            else os.getenv("AGNES_BASE_URL", self.DEFAULT_BASE_URL)
        )

        # Model: 参数 > 环境变量 > 默认值
        self.model = model if model else os.getenv("AGNES_MODEL", self.DEFAULT_MODEL)

        # Max tokens: 参数 > 环境变量 > 默认值
        self.max_tokens = (
            max_tokens
            if max_tokens
            else int(os.getenv("AGNES_MAX_TOKENS", str(self.DEFAULT_MAX_TOKENS)))
        )

        # Temperature: 参数 > 环境变量 > 默认值
        self.temperature = (
            temperature
            if temperature
            else float(os.getenv("AGNES_TEMPERATURE", str(self.DEFAULT_TEMPERATURE)))
        )

        # Timeout: 参数 > 环境变量 > 默认值
        self.timeout = (
            timeout
            if timeout
            else float(os.getenv("AGNES_TIMEOUT", str(self.DEFAULT_TIMEOUT)))
        )

        logger.info(
            f"AgnesProvider initialized: model={self.model}, "
            f"endpoint={self.base_url}/chat/completions"
        )

    def is_available(self) -> bool:
        """
        检查Agnes AI是否可用

        Returns:
            True表示已配置且可用, False表示未配置
        """
        return bool(self.api_key and self.api_key != "")

    def get_provider_name(self) -> str:
        """
        获取Provider名称

        Returns:
            "agnes"
        """
        return "agnes"

    def get_config(self) -> Dict[str, Any]:
        """
        获取配置信息 (不包含敏感信息)

        Returns:
            配置信息字典
        """
        return {
            "provider": "agnes",
            "model": self.model,
            "base_url": self.base_url,
            "available": self.is_available(),
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
        }

    @log_timing
    async def generate(self, prompt: str) -> Dict[str, Any]:
        """
        调用Agnes AI生成内容

        使用OpenAI Chat Completions API格式:
        POST {base_url}/chat/completions
        Authorization: Bearer {api_key}

        Args:
            prompt: 提示词

        Returns:
            解析后的JSON数据 (Dict)

        Raises:
            ValueError: API Key未配置
            Exception: API调用失败时抛出
        """
        if not self.is_available():
            raise ValueError("Agnes AI API Key not configured")

        # 构造请求URL
        request_url = f"{self.base_url}/chat/completions"

        # 构造请求头 (OpenAI格式)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }

        # 构造请求体 (OpenAI Chat Completions格式)
        request_body = {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "messages": [{"role": "user", "content": prompt}],
        }

        logger.info(f"Calling Agnes AI API: {request_url}")
        logger.debug(f"Request model: {self.model}")

        # 发送HTTP请求
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    request_url,
                    headers=headers,
                    json=request_body,
                )
            except httpx.TimeoutException:
                logger.error("Agnes AI API request timeout")
                raise Exception("Agnes AI API request timeout")
            except httpx.ConnectError as e:
                logger.error(f"Agnes AI API connection error: {e}")
                raise Exception(f"Agnes AI API connection error: {e}")

        # 检查响应状态
        if response.status_code != 200:
            error_msg = f"Agnes AI API error: {response.status_code} - {response.text}"
            logger.error(error_msg)
            raise Exception(error_msg)

        # 解析响应
        response_data = response.json()
        logger.debug(
            f"Agnes AI response: {json.dumps(response_data, ensure_ascii=False)[:200]}..."
        )

        # 提取AI生成的内容 (OpenAI格式: choices[0].message.content)
        ai_content = self._extract_content(response_data)

        # 解析JSON
        parsed_data = self._parse_json(ai_content)

        logger.info(
            f"Agnes AI call successful, parsed {len(parsed_data)} fields"
        )
        return parsed_data

    def _extract_content(self, response_data: Dict[str, Any]) -> str:
        """
        从OpenAI API响应中提取AI生成的文本内容

        OpenAI格式:
        {
            "choices": [{
                "message": {"role": "assistant", "content": "..."}
            }]
        }

        Args:
            response_data: API响应数据

        Returns:
            AI生成的文本内容

        Raises:
            Exception: 响应格式错误
        """
        if "choices" in response_data:
            choices = response_data["choices"]
            if isinstance(choices, list) and len(choices) > 0:
                message = choices[0].get("message", {})
                if isinstance(message, dict):
                    return message.get("content", "")

        raise Exception(
            f"Invalid Agnes AI response format: "
            f"{json.dumps(response_data, ensure_ascii=False)[:200]}"
        )

    def _parse_json(self, text: str) -> Dict[str, Any]:
        """
        从AI响应文本中解析JSON

        容错策略:
        1. 尝试直接解析
        2. 尝试提取文本中的JSON部分 ({...})
        3. 均失败则抛出异常

        Args:
            text: AI生成的文本

        Returns:
            解析后的字典

        Raises:
            Exception: JSON解析失败
        """
        # 尝试直接解析
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass

        # 尝试提取JSON部分
        json_start = text.find("{")
        json_end = text.rfind("}") + 1

        if json_start >= 0 and json_end > json_start:
            json_str = text[json_start:json_end]
            try:
                return json.loads(json_str)
            except json.JSONDecodeError as e:
                logger.warning(f"JSON parse error: {e}")
                logger.warning(f"Raw content: {text[:500]}")

        raise Exception(
            f"Failed to parse JSON from Agnes AI response: {text[:200]}"
        )
