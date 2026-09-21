"""
AIService Provider 切换测试

测试AIService可以根据配置正确加载和使用不同的Provider
"""

import pytest
import os
from unittest.mock import patch, MagicMock, AsyncMock
import pytest_asyncio

from services.ai_service import AIService
from cache.cache_manager import floor_cache, room_cache, monster_cache, weapon_cache


@pytest.fixture(autouse=True)
def clear_caches():
    """每个测试前清除所有缓存"""
    floor_cache.clear()
    room_cache.clear()
    monster_cache.clear()
    weapon_cache.clear()
    yield
    floor_cache.clear()
    room_cache.clear()
    monster_cache.clear()
    weapon_cache.clear()


class TestAIServiceProviderSwitch:
    """AIService Provider切换测试"""

    def test_init_mock_mode(self):
        """测试Mock模式初始化"""
        with patch.dict(os.environ, {"AI_PROVIDER": "mock"}):
            service = AIService()
            assert service.provider_type == "mock"
            assert service.llm_provider is None
            assert service._is_llm_mode() is False
            assert service._get_ai_mode() == "mock"

    def test_init_mimo_mode(self):
        """测试MiMo模式初始化（使用Test Key）"""
        with patch.dict(os.environ, {
            "AI_PROVIDER": "mimo",
            "MIMO_API_KEY": "test_key"
        }):
            service = AIService()
            assert service.provider_type == "mimo"
            assert service.llm_provider is not None
            assert service._is_llm_mode() is True
            assert service._get_ai_mode() == "mimo"

    def test_init_agnes_mode_with_key(self):
        """测试Agnes模式初始化（有API Key）"""
        with patch.dict(os.environ, {
            "AI_PROVIDER": "agnes",
            "AGNES_API_KEY": "test_key"
        }):
            service = AIService()
            assert service.provider_type == "agnes"
            assert service.llm_provider is not None
            assert service._is_llm_mode() is True
            assert service._get_ai_mode() == "agnes"

    def test_init_agnes_mode_without_key(self):
        """测试Agnes模式初始化（无API Key）"""
        with patch.dict(os.environ, {"AI_PROVIDER": "agnes"}):
            service = AIService()
            assert service.provider_type == "agnes"
            # 无API Key时，provider创建但不可用，AIService会设置为None
            assert service.llm_provider is None or not service.llm_provider.is_available()

    def test_backward_compat_llm_provider(self):
        """测试向后兼容：LLM_PROVIDER环境变量仍然有效"""
        with patch.dict(os.environ, {
            "LLM_PROVIDER": "mimo",
            "MIMO_API_KEY": "test_key"
        }):
            service = AIService()
            assert service.provider_type == "mimo"
            assert service.llm_provider is not None

    def test_ai_provider_overrides_llm_provider(self):
        """测试AI_PROVIDER优先级高于LLM_PROVIDER"""
        with patch.dict(os.environ, {
            "AI_PROVIDER": "mock",
            "LLM_PROVIDER": "mimo",
            "MIMO_API_KEY": "test_key"
        }):
            service = AIService()
            # AI_PROVIDER应该优先
            assert service.provider_type == "mock"
            assert service.llm_provider is None

    @pytest.mark.asyncio
    async def test_generate_floor_with_agnes(self):
        """测试使用Agnes Provider生成楼层"""
        mock_result = {
            "floor": 1,
            "room_count": 5,
            "rooms": []
        }

        with patch.dict(os.environ, {
            "AI_PROVIDER": "agnes",
            "AGNES_API_KEY": "test_key"
        }):
            service = AIService()

            # Mock Agnes provider
            service.llm_provider = MagicMock()
            service.llm_provider.is_available.return_value = True
            service.llm_provider.get_provider_name.return_value = "agnes"
            service.llm_provider.generate = AsyncMock(return_value=mock_result)

            result = await service.generate_floor(1, 1)
            assert result["ai_mode"] == "agnes"
            assert result["floor"] == 1

    @pytest.mark.asyncio
    async def test_generate_room_with_agnes(self):
        """测试使用Agnes Provider生成房间内容"""
        mock_result = {
            "room_id": 1,
            "room_type": "combat",
            "monsters": [],
            "rewards": {}
        }

        with patch.dict(os.environ, {
            "AI_PROVIDER": "agnes",
            "AGNES_API_KEY": "test_key"
        }):
            service = AIService()

            # Mock Agnes provider
            service.llm_provider = MagicMock()
            service.llm_provider.is_available.return_value = True
            service.llm_provider.get_provider_name.return_value = "agnes"
            service.llm_provider.generate = AsyncMock(return_value=mock_result)

            result = await service.generate_room_content(1, "combat", 1, 1)
            assert result["ai_mode"] == "agnes"

    @pytest.mark.asyncio
    async def test_fallback_to_mock_when_provider_unavailable(self):
        """测试Provider不可用时降级到Mock"""
        with patch.dict(os.environ, {
            "AI_PROVIDER": "agnes",
            "AGNES_API_KEY": ""  # 空API Key
        }):
            service = AIService()
            # 由于没有API Key，应该降级到Mock
            result = await service.generate_floor(1, 1)
            assert result["ai_mode"] == "mock_fallback"
            assert "rooms" in result

    @pytest.mark.asyncio
    async def test_fallback_to_mock_on_provider_error(self):
        """测试Provider异常时降级到Mock"""
        with patch.dict(os.environ, {
            "AI_PROVIDER": "agnes",
            "AGNES_API_KEY": "test_key"
        }):
            service = AIService()

            # Mock Agnes provider抛出异常
            service.llm_provider = MagicMock()
            service.llm_provider.is_available.return_value = True
            service.llm_provider.get_provider_name.return_value = "agnes"
            service.llm_provider.generate = AsyncMock(side_effect=Exception("API Error"))

            result = await service.generate_floor(1, 1)
            assert result["ai_mode"] == "mock_fallback"
            assert "rooms" in result
