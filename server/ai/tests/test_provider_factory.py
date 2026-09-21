"""
ProviderFactory 单元测试

测试Provider工厂的注册、创建和查询功能
"""

import pytest
import os
from unittest.mock import patch, MagicMock

from services.provider_factory import ProviderFactory


class TestProviderFactory:
    """ProviderFactory基础功能测试"""

    def test_get_available_providers(self):
        """测试获取已注册的Provider列表"""
        providers = ProviderFactory.get_available_providers()
        assert "agnes" in providers
        assert "mimo" in providers

    def test_is_registered(self):
        """测试检查Provider是否已注册"""
        assert ProviderFactory.is_registered("agnes") is True
        assert ProviderFactory.is_registered("mimo") is True
        assert ProviderFactory.is_registered("unknown") is False

    def test_create_agnes_provider(self):
        """测试创建Agnes Provider"""
        from services.agnes_provider import AgnesProvider

        provider = ProviderFactory.create("agnes", api_key="test_key")
        assert provider is not None
        assert isinstance(provider, AgnesProvider)
        assert provider.get_provider_name() == "agnes"

    def test_create_mimo_provider(self):
        """测试创建MiMo Provider"""
        from services.mimo_client import MimoClient

        provider = ProviderFactory.create(
            "mimo",
            api_key="test_key",
            endpoint="https://test.example.com/anthropic"
        )
        assert provider is not None
        assert isinstance(provider, MimoClient)
        assert provider.get_provider_name() == "mimo"

    def test_create_unknown_provider_returns_none(self):
        """测试创建未知Provider返回None"""
        provider = ProviderFactory.create("unknown")
        assert provider is None

    def test_create_with_empty_type(self):
        """测试空字符串类型返回None"""
        provider = ProviderFactory.create("")
        assert provider is None

    def test_register_custom_provider(self):
        """测试动态注册自定义Provider"""
        class CustomProvider(MagicMock):
            def get_provider_name(self):
                return "custom"

            def is_available(self):
                return True

        ProviderFactory.register("custom", CustomProvider)
        assert ProviderFactory.is_registered("custom") is True

        provider = ProviderFactory.create("custom")
        assert provider is not None
        assert provider.get_provider_name() == "custom"


class TestProviderFactoryWithEnv:
    """环境变量配置测试"""

    def test_agnes_from_env(self):
        """测试从环境变量创建Agnes Provider"""
        with patch.dict(os.environ, {"AGNES_API_KEY": "env_key"}):
            provider = ProviderFactory.create("agnes")
            assert provider is not None
            assert provider.is_available() is True
            assert provider.api_key == "env_key"

    def test_mimo_from_env(self):
        """测试从环境变量创建MiMo Provider"""
        with patch.dict(os.environ, {
            "MIMO_API_KEY": "env_key",
            "MIMO_ENDPOINT": "https://env.example.com/anthropic"
        }):
            provider = ProviderFactory.create("mimo")
            assert provider is not None
            assert provider.is_available() is True
            assert provider.api_key == "env_key"
            assert provider.endpoint == "https://env.example.com/anthropic"

    def test_both_providers_available(self):
        """测试两个Provider可同时创建"""
        with patch.dict(os.environ, {
            "AGNES_API_KEY": "agnes_key",
            "MIMO_API_KEY": "mimo_key"
        }):
            agnes = ProviderFactory.create("agnes")
            mimo = ProviderFactory.create("mimo")

            assert agnes is not None
            assert mimo is not None
            assert agnes.get_provider_name() == "agnes"
            assert mimo.get_provider_name() == "mimo"
