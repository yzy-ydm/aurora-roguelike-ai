---
name: python-testing
description: Python测试技能，用于pytest测试编写、测试覆盖率、测试最佳实践
version: 1.0.0
tags: [python, testing, pytest, unittest]
---

# Python 测试技能

## 技能说明

本技能用于 Aurora-Roguelike-AI 项目的 Python 测试编写，支持 pytest 框架。

## 测试目录结构

```
server/ai/
├── tests/
│   ├── __init__.py
│   ├── conftest.py              # 测试配置
│   ├── test_ai_service.py       # AI服务测试
│   ├── test_auth.py             # 认证测试
│   ├── test_cache.py            # 缓存测试
│   └── test_api.py              # API测试
└── ...
```

## pytest 基础

### 测试文件命名

```python
# test_ai_service.py
def test_generate_floor():
    # 测试逻辑
    pass

def test_generate_room():
    # 测试逻辑
    pass
```

### 测试函数命名

```python
def test_generate_floor_with_valid_input():
    """测试有效输入的楼层生成"""
    pass

def test_generate_floor_with_invalid_input():
    """测试无效输入的楼层生成"""
    pass
```

### 断言

```python
def test_generate_floor():
    result = generate_floor(1, 1)
    assert result is not None
    assert "floor" in result
    assert result["floor"] == 1
    assert len(result["rooms"]) > 0
```

## 测试夹具

### conftest.py

```python
import pytest
from services.ai_service import AIService

@pytest.fixture
def ai_service():
    """创建AI服务实例"""
    return AIService()

@pytest.fixture
def sample_floor_request():
    """示例楼层请求"""
    return {
        "floor_level": 1,
        "player_level": 1
    }
```

### 使用夹具

```python
def test_generate_floor(ai_service, sample_floor_request):
    result = await ai_service.generate_floor(
        sample_floor_request["floor_level"],
        sample_floor_request["player_level"]
    )
    assert result is not None
```

## 异步测试

```python
import pytest

@pytest.mark.asyncio
async def test_generate_floor_async(ai_service):
    result = await ai_service.generate_floor(1, 1)
    assert result is not None
```

## 测试覆盖率

### 运行覆盖率测试

```bash
pytest --cov=services --cov-report=html
```

### 覆盖率配置

```ini
# pytest.ini
[pytest]
testpaths = tests
python_files = test_*.py
python_functions = test_*
```

## 项目特定测试

### AI服务测试

```python
# test_ai_service.py
import pytest
from services.ai_service import AIService

@pytest.fixture
def ai_service():
    return AIService()

def test_generate_floor(ai_service):
    result = await ai_service.generate_floor(1, 1)
    assert "floor" in result
    assert "rooms" in result
    assert len(result["rooms"]) > 0

def test_generate_room_content(ai_service):
    result = await ai_service.generate_room_content(1, "combat", 1, 1)
    assert "room_id" in result
    assert "monsters" in result
    assert "rewards" in result
```

### API测试

```python
# test_api.py
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_generate_floor():
    response = client.post(
        "/api/generate/floor",
        json={"floor_level": 1, "player_level": 1}
    )
    assert response.status_code == 200
    assert "floor" in response.json()
```

## 使用场景

当需要：
- 编写单元测试
- 编写集成测试
- 测试API接口
- 测试AI服务
- 提高测试覆盖率
