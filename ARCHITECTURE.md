# ARCHITECTURE.md

> Aurora-Roguelike-AI 系统架构文档

最后更新：2026-07-13

---

## 系统总览

本系统采用经典的客户端-服务器架构（C/S架构），通过REST API进行通信。

```
┌─────────────────────────────────────────────────────────────┐
│                      Godot Client                           │
│                    (游戏客户端)                               │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ HTTP REST API
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    FastAPI Server                            │
│                    (后端服务器)                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Router    │  │   Router    │  │   Router    │        │
│  │  (API路由)   │  │  (认证)     │  │  (玩家)     │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │
│         ▼                ▼                ▼                │
│  ┌─────────────────────────────────────────────┐           │
│  │              Service Layer                  │           │
│  │             (业务逻辑层)                     │           │
│  └─────────────────────┬───────────────────────┘           │
│                        │                                   │
│                        ▼                                   │
│  ┌─────────────────────────────────────────────┐           │
│  │            SQLAlchemy ORM                   │           │
│  │            (数据访问层)                      │           │
│  └─────────────────────┬───────────────────────┘           │
└────────────────────────┼───────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     MySQL Database                          │
│                    (数据库服务器)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 分层架构详解

### 1. 客户端层 (Client Layer)

**技术：** Godot 4 + GDScript

**职责：**
- 游戏界面渲染
- 玩家输入处理
- 游戏逻辑执行
- 网络请求发送
- 本地状态管理

**通信方式：** HTTP REST API

---

### 2. API路由层 (Router Layer)

**技术：** FastAPI Router

**职责：**
- 接收HTTP请求
- 请求参数验证
- 调用Service层
- 返回HTTP响应

**文件位置：** `server/app/api/*/router.py`

**原则：**
- 不直接操作数据库
- 不包含业务逻辑
- 只做请求/响应处理

**示例：**
```python
@router.post("/api/auth/login")
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    service = AuthService(db)
    return service.authenticate_user(login_data)
```

---

### 3. 业务服务层 (Service Layer)

**技术：** Python类

**职责：**
- 实现业务逻辑
- 数据处理
- 调用ORM层
- 返回结果给Router

**文件位置：** `server/app/services/*.py`

**原则：**
- 包含所有业务逻辑
- 不直接处理HTTP
- 通过依赖注入获取数据库会话

**示例：**
```python
class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def authenticate_user(self, login_data: UserLogin):
        # 业务逻辑
        user = self.db.query(User).filter(...)
        # 验证密码
        # 返回结果
```

---

### 4. 数据模型层 (Model Layer)

**技术：** SQLAlchemy ORM

**职责：**
- 定义数据表结构
- 映射数据库字段
- 提供数据操作方法

**文件位置：** `server/app/models/*.py`

**原则：**
- 每个表对应一个模型类
- 使用ORM操作数据库
- 不包含复杂业务逻辑

**示例：**
```python
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True)
    password_hash = Column(String(255))
```

---

### 5. 数据验证层 (Schema Layer)

**技术：** Pydantic

**职责：**
- 请求数据验证
- 响应数据格式化
- API文档生成

**文件位置：** `server/app/schemas/*.py`

**示例：**
```python
class UserLogin(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
```

---

### 6. 数据库层 (Database Layer)

**技术：** MySQL 8.0

**职责：**
- 数据持久化存储
- 数据关系维护
- 数据完整性保证

**文件位置：** `database/sql/`

---

## 目录结构

```
server/
├── main.py                     # 应用入口
├── requirements.txt            # 依赖配置
├── .env                        # 环境变量
└── app/
    ├── api/                    # API路由层
    │   ├── auth/               # 认证模块
    │   │   └── router.py
    │   ├── player/             # 玩家模块（待开发）
    │   ├── weapon/             # 武器模块（待开发）
    │   └── monster/            # 怪物模块（待开发）
    ├── core/                   # 核心模块
    │   └── security.py         # 安全（JWT、密码）
    ├── database/               # 数据库连接
    │   └── connection.py
    ├── models/                 # ORM模型
    │   └── user.py
    ├── schemas/                # Pydantic模式
    │   └── auth.py
    └── services/               # 业务服务
        └── auth_service.py
```

---

## 请求处理流程

```
1. 客户端发送HTTP请求
        ↓
2. FastAPI接收请求
        ↓
3. Router解析请求
        ↓
4. Schema验证参数
        ↓
5. Service处理业务逻辑
        ↓
6. Model操作数据库
        ↓
7. 返回结果给Service
        ↓
8. 返回结果给Router
        ↓
9. 返回HTTP响应给客户端
```

---

## 认证流程

```
1. 用户登录 → POST /api/auth/login
        ↓
2. Router接收请求
        ↓
3. AuthService验证用户名密码
        ↓
4. 验证通过 → 生成JWT Token
        ↓
5. 返回Token给客户端
        ↓
6. 客户端存储Token
        ↓
7. 后续请求携带Token
        ↓
8. 服务端验证Token
```

---

## 安全架构

### 密码安全
- 使用bcrypt算法加密
- 不存储明文密码
- 每次加密结果不同（含随机盐）

### Token安全
- JWT Token认证
- Token有过期时间
- 敏感操作需要验证

### 接口安全
- CORS跨域配置
- 输入参数验证
- SQL注入防护（ORM）

---

## 未来扩展

### AI模块架构

```
Game Module
      ↓
AI Service Layer
      ↓
Cloud LLM API (DeepSeek/Claude/Gemini)
```

AI模块将独立设计，不与游戏逻辑直接耦合。

---

## 约束规则

1. **禁止** Router直接操作数据库
2. **禁止** 业务逻辑写在API层
3. **禁止** 游戏逻辑直接调用AI
4. **必须** 遵循分层架构
5. **必须** 使用ORM操作数据库
