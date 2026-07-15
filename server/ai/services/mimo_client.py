"""
小米 MiMo API 客户端

实现LLMProvider接口
使用Anthropic Messages API格式调用MiMo API
"""

import os
import json
from typing import Dict, Any, Optional

import httpx

from .llm_provider import LLMProvider
from logger.logger import logger, log_timing


class MimoClient(LLMProvider):
    """
    小米 MiMo API 客户端

    使用Anthropic Messages API格式
    """

    def __init__(
        self,
        api_key: str = "",
        model: str = "mimo-v2.5-pro",
        endpoint: str = "https://token-plan-cn.xiaomimimo.com/anthropic",
        max_tokens: int = 4096,
        temperature: float = 0.7,
        timeout: float = 120.0
    ):
        """
        初始化MiMo客户端

        Args:
            api_key: MiMo API Key
            model: 模型名称
            endpoint: API端点
            max_tokens: 最大token数
            temperature: 温度参数
            timeout: 请求超时时间（秒）
        """
        # 使用传入的参数，如果为空则读取环境变量
        self.api_key = api_key if api_key != "" else os.getenv("MIMO_API_KEY", "")
        self.model = model if model != "mimo-v2.5-pro" else os.getenv("MIMO_MODEL", "mimo-v2.5-pro")
        self.endpoint = endpoint if endpoint != "https://token-plan-cn.xiaomimimo.com/anthropic" else os.getenv("MIMO_ENDPOINT", "https://token-plan-cn.xiaomimimo.com/anthropic")
        self.max_tokens = max_tokens if max_tokens != 4096 else int(os.getenv("MIMO_MAX_TOKENS", "4096"))
        self.temperature = temperature if temperature != 0.7 else float(os.getenv("MIMO_TEMPERATURE", "0.7"))
        self.timeout = timeout

        logger.info(f"MimoClient initialized: model={self.model}, endpoint={self.endpoint}")

    def is_available(self) -> bool:
        """检查MiMo API是否可用"""
        return bool(self.api_key and self.api_key != "")

    def get_provider_name(self) -> str:
        """获取Provider名称"""
        return "mimo"

    def get_config(self) -> Dict[str, Any]:
        """获取配置信息（不包含敏感信息）"""
        return {
            "provider": "mimo",
            "model": self.model,
            "endpoint": self.endpoint,
            "available": self.is_available(),
            "max_tokens": self.max_tokens,
            "temperature": self.temperature
        }

    @log_timing
    async def generate(self, prompt: str) -> Dict[str, Any]:
        """
        调用MiMo API生成内容

        Args:
            prompt: 提示词

        Returns:
            解析后的JSON数据

        Raises:
            Exception: API调用失败时抛出异常
        """
        if not self.is_available():
            raise ValueError("MiMo API Key not configured")

        # 构造请求URL
        request_url = f"{self.endpoint}/v1/messages"

        # 构造请求头
        headers = {
            "Content-Type": "application/json",
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01"
        }

        # 构造请求体
        request_body = {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }

        logger.info(f"Calling MiMo API: {request_url}")
        logger.debug(f"Request model: {self.model}")

        # 发送请求
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    request_url,
                    headers=headers,
                    json=request_body
                )
            except httpx.TimeoutException:
                logger.error("MiMo API request timeout")
                raise Exception("MiMo API request timeout")
            except httpx.ConnectError as e:
                logger.error(f"MiMo API connection error: {e}")
                raise Exception(f"MiMo API connection error: {e}")

        # 检查响应状态
        if response.status_code != 200:
            error_msg = f"MiMo API error: {response.status_code} - {response.text}"
            logger.error(error_msg)
            raise Exception(error_msg)

        # 解析响应
        response_data = response.json()
        logger.debug(f"MiMo API response: {json.dumps(response_data, ensure_ascii=False)[:200]}...")

        # 提取AI生成的内容
        ai_content = self._extract_content(response_data)

        # 解析JSON
        parsed_data = self._parse_json(ai_content)

        logger.info(f"MiMo API call successful, parsed {len(parsed_data)} fields")
        return parsed_data

    def _extract_content(self, response_data: Dict[str, Any]) -> str:
        """
        从API响应中提取内容

        Args:
            response_data: API响应数据

        Returns:
            AI生成的文本内容

        Raises:
            Exception: 响应格式错误
        """
        # Anthropic Messages API格式
        if "content" in response_data:
            content_list = response_data["content"]
            if isinstance(content_list, list) and len(content_list) > 0:
                return content_list[0].get("text", "")

        raise Exception(f"Invalid MiMo API response format: {json.dumps(response_data)[:200]}")

    def _parse_json(self, text: str) -> Dict[str, Any]:
        """
        从文本中解析JSON

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
        json_start = text.find('{')
        json_end = text.rfind('}') + 1

        if json_start >= 0 and json_end > json_start:
            json_str = text[json_start:json_end]
            try:
                return json.loads(json_str)
            except json.JSONDecodeError as e:
                logger.warning(f"JSON parse error: {e}")
                logger.warning(f"Raw content: {text[:500]}")

        raise Exception(f"Failed to parse JSON from AI response: {text[:200]}")
