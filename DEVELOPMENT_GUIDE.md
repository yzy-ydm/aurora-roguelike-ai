# DEVELOPMENT_GUIDE.md

> Aurora-Roguelike-AI 开发规范指南

最后更新：2026-07-13

---

## 总体原则

1. **先分析，后开发** - 不要看到需求立即写代码
2. **保持架构一致** - 遵循分层设计
3. **模块化开发** - 每个功能独立模块
4. **文档同步** - 代码变更必须更新文档

---

## 后端开发规范

### 目录结构规范

新增功能必须遵循以下结构：

```
server/app/
├── api/
│   └── {module}/
│       ├── __init__.py
│       └── router.py        # API路由
├── models/
│   └── {module}.py          # ORM模型
├── schemas/
│   └── {module}.py          # Pydantic模式
└── services/
    └── {module}_service.py  # 业务服务
```

### 分层职责规范

| 层 | 职责 | 禁止 |
|----|------|------|
| Router | 处理HTTP请求/响应 | 直接操作数据库 |
| Service | 处理业务逻辑 | 直接返回HTTP响应 |
| Model | 操作数据库 | 包含复杂业务逻辑 |
| Schema | 数据验证 | 包含业务逻辑 |

### 代码示例

**Router示例：**
```python
# server/app/api/auth/router.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.connection import get_db
from app.schemas.auth import UserLogin, TokenResponse
from app.services.auth_service import AuthService

router = APIRouter(prefix="/api/auth", tags=["认证"])

@router.post("/login", response_model=TokenResponse)
async def login(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    service = AuthService(db)
    return service.authenticate_user(login_data)
```

**Service示例：**
```python
# server/app/services/auth_service.py
from sqlalchemy.orm import Session
from app.models.user import User
from app.core.security import verify_password

class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def authenticate_user(self, login_data):
        user = self.db.query(User).filter(
            User.username == login_data.username
        ).first()

        if not user:
            return None

        if not verify_password(login_data.password, user.password_hash):
            return None

        return user
```

**Model示例：**
```python
# server/app/models/user.py
from sqlalchemy import Column, Integer, String
from app.database.connection import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
```

**Schema示例：**
```python
# server/app/schemas/auth.py
from pydantic import BaseModel, Field

class UserLogin(BaseModel):
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="密码")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
```

---

## Python代码规范

### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 模块名 | 小写下划线 | `auth_service.py` |
| 类名 | 大驼峰 | `AuthService` |
| 函数名 | 小写下划线 | `get_user_by_id` |
| 变量名 | 小写下划线 | `user_name` |
| 常量名 | 大写下划线 | `MAX_RETRY_COUNT` |

### 注释规范

```python
def function_name(param1: str, param2: int) -> bool:
    """
    函数功能简述

    详细描述（如果需要）

    Args:
        param1: 参数1说明
        param2: 参数2说明

    Returns:
        bool: 返回值说明

    Raises:
        ValueError: 异常说明
    """
    pass
```

### 导入规范

```python
# 1. 标准库
import os
from datetime import datetime

# 2. 第三方库
from fastapi import APIRouter
from sqlalchemy.orm import Session

# 3. 本地模块
from app.models.user import User
from app.core.security import hash_password
```

---

## 数据库规范

### 模型定义规范

```python
class TableName(Base):
    """表说明"""

    __tablename__ = "table_name"

    # 主键
    id = Column(Integer, primary_key=True, autoincrement=True, comment="ID")

    # 字段
    field_name = Column(String(50), nullable=False, comment="字段说明")

    # 时间字段
    created_at = Column(DateTime, default=func.now(), comment="创建时间")
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now(), comment="更新时间")

    # 索引
    __table_args__ = (
        Index("idx_field_name", "field_name"),
        {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4"}
    )
```

### 数据库修改规范

1. 修改SQL脚本：`database/sql/`
2. 更新ORM模型：`server/app/models/`
3. 更新文档：`DATABASE.md`
4. 更新变更记录：`CHANGELOG.md`

---

## API开发规范

### 接口设计规范

```
POST   /api/{resource}          # 创建
GET    /api/{resource}          # 列表
GET    /api/{resource}/{id}     # 详情
PUT    /api/{resource}/{id}     # 更新
DELETE /api/{resource}/{id}     # 删除
```

### 响应格式规范

**成功响应：**
```json
{
    "code": 200,
    "message": "success",
    "data": {}
}
```

**错误响应：**
```json
{
    "code": 400,
    "message": "错误信息",
    "detail": "详细错误"
}
```

### 状态码规范

| 状态码 | 含义 | 使用场景 |
|--------|------|----------|
| 200 | 成功 | 正常响应 |
| 201 | 已创建 | 资源创建成功 |
| 400 | 请求错误 | 参数错误 |
| 401 | 未认证 | 未登录或Token无效 |
| 403 | 禁止访问 | 权限不足 |
| 404 | 未找到 | 资源不存在 |
| 422 | 验证失败 | 数据验证失败 |
| 500 | 服务器错误 | 内部错误 |

---

## Git提交规范

### 提交格式

```
<type>(<scope>): <subject>
```

### 类型说明

| 类型 | 说明 | 示例 |
|------|------|------|
| feat | 新功能 | feat(auth): add login endpoint |
| fix | 修复 | fix(api): fix token validation |
| docs | 文档 | docs(readme): update description |
| style | 格式 | style: fix code indentation |
| refactor | 重构 | refactor(service): simplify logic |
| test | 测试 | test(auth): add unit tests |
| chore | 构建 | chore: update dependencies |

---

## 文档维护规范

### 必须同步更新的文档

| 变更类型 | 需要更新的文档 |
|----------|----------------|
| 任何变更 | PROJECT_STATUS.md, TODO.md, CHANGELOG.md |
| 新增API | API_DOCUMENT.md |
| 修改数据库 | DATABASE.md |
| 架构变更 | ARCHITECTURE.md |
| 功能变更 | FEATURE_SPEC.md |

---

## 测试规范

### 测试内容

1. **接口测试**：测试API正常响应
2. **参数验证**：测试边界条件
3. **错误处理**：测试异常情况
4. **数据库测试**：测试数据操作

### 测试方法

```bash
# 启动服务
python main.py

# 使用curl测试
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123456"}'

# 使用Swagger测试
# 访问 http://localhost:8000/docs
```

---

## 禁止事项

1. **禁止** Router直接操作数据库
2. **禁止** 密码明文存储
3. **禁止** SQL字符串拼接
4. **禁止** 不测试直接提交
5. **禁止** 不更新文档就提交
6. **禁止** 修改已有架构而不确认
