"""
AgnesProvider单元测试

测试Agnes AI Provider的功能
包括: 初始化, 可用性检查, JSON解析, 异常处理
"""

import pytest
import asyncio
import os
from unittest.mock import patch, AsyncMock, MagicMock

# 设置测试环境
os.environ["LLM_PROVIDER"] = "mock"

from services.agnes_provider import AgnesProvider


class TestAgnesProviderInit:
    """AgnesProvider初始化测试"""

    def test_init_with_api_key(self):
        """测试使用API Key初始化"""
        provider = AgnesProvider(api_key="test_key")
        assert provider.is_available() is True
        assert provider.get_provider_name() == "agnes"
        assert provider.model == "agnes-2.5-flash"
        assert provider.base_url == "https://apihub.agnes-ai.com/v1"

    def test_init_without_api_key(self):
        """测试不使用API Key初始化"""
        provider = AgnesProvider()
        assert provider.is_available() is False

    def test_init_with_env_vars(self):
        """测试从环境变量读取配置"""
        with patch.dict(os.environ, {
            "AGNES_API_KEY": "env_key",
            "AGNES_BASE_URL": "https://test.example.com/v1",
            "AGNES_MODEL": "test-model",
            "AGNES_MAX_TOKENS": "2048",
            "AGNES_TEMPERATURE": "0.5",
        }):
            provider = AgnesProvider()
            assert provider.api_key == "env_key"
            assert provider.base_url == "https://test.example.com/v1"
            assert provider.model == "test-model"
            assert provider.max_tokens == 2048
            assert provider.temperature == 0.5

    def test_init_with_parameters_override_env(self):
        """测试构造参数优先于环境变量"""
        with patch.dict(os.environ, {"AGNES_API_KEY": "env_key"}):
            provider = AgnesProvider(api_key="param_key")
            assert provider.api_key == "param_key"

    def test_get_config(self):
        """测试get_config方法"""
        provider = AgnesProvider(api_key="test_key")
        config = provider.get_config()
        assert config["provider"] == "agnes"
        assert config["model"] == "agnes-2.5-flash"
        assert config["available"] is True
        assert "api_key" not in config  # 敏感信息不应包含

    def test_default_values(self):
        """测试默认值"""
        provider = AgnesProvider(api_key="test")
        assert provider.max_tokens == 4096
        assert provider.temperature == 0.7
        assert provider.timeout == 120.0


class TestAgnesProviderJSONParse:
    """JSON解析测试"""

    def test_parse_valid_json(self):
        """测试解析有效JSON"""
        provider = AgnesProvider(api_key="test")
        result = provider._parse_json('{"floor": 1, "rooms": []}')
        assert result["floor"] == 1
        assert result["rooms"] == []

    def test_parse_json_with_surrounding_text(self):
        """测试解析含前后文本的JSON"""
        provider = AgnesProvider(api_key="test")
        text = "Here is the result: {\"floor\": 2}"
        result = provider._parse_json(text)
        assert result["floor"] == 2

    def test_parse_json_with_markdown_codeblock(self):
        """测试解析含markdown代码块的JSON"""
        provider = AgnesProvider(api_key="test")
        text = "```json\n{\"floor\": 3}\n```"
        result = provider._parse_json(text)
        assert result["floor"] == 3

    def test_parse_invalid_json_raises(self):
        """测试解析无效JSON抛出异常"""
        provider = AgnesProvider(api_key="test")
        with pytest.raises(Exception):
            provider._parse_json("not valid json")


class TestAgnesProviderContentExtract:
    """内容提取测试"""

    def test_extract_openai_format(self):
        """测试提取OpenAI格式响应"""
        provider = AgnesProvider(api_key="test")
        response = {
            "choices": [{
                "message": {"role": "assistant", "content": '{"floor": 1}'}
            }]
        }
        content = provider._extract_content(response)
        assert content == '{"floor": 1}'

    def test_extract_empty_choices(self):
        """测试空choices响应"""
        provider = AgnesProvider(api_key="test")
        response = {"choices": []}
        with pytest.raises(Exception):
            provider._extract_content(response)

    def test_extract_invalid_format(self):
        """测试无效格式响应"""
        provider = AgnesProvider(api_key="test")
        response = {"data": "invalid"}
        with pytest.raises(Exception):
            provider._extract_content(response)


class TestAgnesProviderAvailability:
    """可用性检查测试"""

    def test_available_with_key(self):
        """测试有API Key时可用"""
        provider = AgnesProvider(api_key="test_key")
        assert provider.is_available() is True

    def test_not_available_without_key(self):
        """测试无API Key时不可用"""
        provider = AgnesProvider()
        assert provider.is_available() is False

    def test_not_available_with_empty_key(self):
        """测试空字符串API Key时不可用"""
        provider = AgnesProvider(api_key="")
        assert provider.is_available() is False


class TestAgnesProviderGenerateIntegration:
    """集成测试 - 使用Mock验证请求格式"""

    @pytest.mark.asyncio
    async def test_generate_request_format(self):
        """测试生成请求格式正确"""
        provider = AgnesProvider(api_key="test_key")

        # Mock httpx.AsyncClient
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "choices": [{
                "message": {"content": '{"floor": 1, "rooms": []}'}
            }]
        }

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.post = AsyncMock(return_value=mock_response)

        with patch("services.agnes_provider.httpx.AsyncClient", return_value=mock_client):
            result = await provider.generate("test prompt")
            assert result["floor"] == 1
            assert result["rooms"] == []

            # 验证请求格式
            call_args = mock_client.post.call_args
            assert call_args[0][0] == "https://apihub.agnes-ai.com/v1/chat/completions"
            headers = call_args[1]["headers"]
            assert headers["Authorization"] == "Bearer test_key"
            assert headers["Content-Type"] == "application/json"

            body = call_args[1]["json"]
            assert body["model"] == "agnes-2.5-flash"
            assert body["max_tokens"] == 4096
            assert body["temperature"] == 0.7
            assert body["messages"] == [{"role": "user", "content": "test prompt"}]

    @pytest.mark.asyncio
    async def test_generate_timeout_handling(self):
        """测试超时异常处理"""
        provider = AgnesProvider(api_key="test_key")

        import httpx
        with patch("services.agnes_provider.httpx.AsyncClient") as mock_client_class:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client_class.return_value = mock_client

            with pytest.raises(Exception, match="timeout"):
                await provider.generate("test prompt")

    @pytest.mark.asyncio
    async def test_generate_connection_error(self):
        """测试连接错误处理"""
        provider = AgnesProvider(api_key="test_key")

        import httpx
        with patch("services.agnes_provider.httpx.AsyncClient") as mock_client_class:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(side_effect=httpx.ConnectError("conn error"))
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client_class.return_value = mock_client

            with pytest.raises(Exception, match="conn error"):
                await provider.generate("test prompt")

    @pytest.mark.asyncio
    async def test_generate_api_error(self):
        """测试API错误响应处理"""
        provider = AgnesProvider(api_key="test_key")

        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.text = "Unauthorized"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.post = AsyncMock(return_value=mock_response)

        with patch("services.agnes_provider.httpx.AsyncClient", return_value=mock_client):
            with pytest.raises(Exception, match="401"):
                await provider.generate("test prompt")

    @pytest.mark.asyncio
    async def test_generate_no_api_key(self):
        """测试无API Key时抛出异常"""
        provider = AgnesProvider(api_key="")
        with pytest.raises(ValueError, match="API Key not configured"):
            await provider.generate("test prompt")
