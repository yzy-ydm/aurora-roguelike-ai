"""
安全模块

本模块提供密码加密和JWT Token相关的安全功能。

功能：
1. 密码哈希（bcrypt算法）
2. 密码验证
3. JWT Token生成
4. JWT Token解码验证

依赖：
- passlib: 密码哈希库
- python-jose: JWT处理库
"""

import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

from dotenv import load_dotenv
from passlib.context import CryptContext
from jose import JWTError, jwt

# ============================================================
# 加载环境变量
# ============================================================
load_dotenv()

# ============================================================
# JWT配置
# ============================================================
# 从环境变量读取JWT密钥（生产环境应使用强密钥）
JWT_SECRET_KEY = os.getenv(
    "JWT_SECRET_KEY",
    "aurora-roguelike-secret-key-change-in-production"
)

# JWT签名算法
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

# Token过期时间（分钟）
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))  # 默认24小时

# ============================================================
# 密码哈希配置
# ============================================================
# 使用bcrypt算法进行密码哈希
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)


# ============================================================
# 密码相关函数
# ============================================================

def hash_password(password: str) -> str:
    """
    将明文密码转换为bcrypt哈希值

    使用bcrypt算法对密码进行单向哈希加密，
    每次加密同一密码会产生不同的哈希值（因为包含随机盐值）。

    Args:
        password: 明文密码

    Returns:
        str: bcrypt哈希值

    示例:
        >>> hash_password("mypassword")
        '$2b$12$LJ3m4ys3Lz0YBNOURq0Y3OjCfKJmKPOJYqDTPVCKzLOBhZMHfWO6e'
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    验证明文密码是否与哈希值匹配

    Args:
        plain_password: 用户输入的明文密码
        hashed_password: 数据库中存储的哈希值

    Returns:
        bool: 密码匹配返回True，否则返回False

    示例:
        >>> verify_password("mypassword", "$2b$12$...")
        True
        >>> verify_password("wrongpassword", "$2b$12$...")
        False
    """
    return pwd_context.verify(plain_password, hashed_password)


# ============================================================
# JWT Token相关函数
# ============================================================

def create_access_token(
    data: Dict[str, Any],
    expires_delta: Optional[timedelta] = None
) -> str:
    """
    创建JWT访问令牌

    将用户信息编码到JWT Token中，并设置过期时间。

    Args:
        data: 要编码到Token中的数据（通常是用户信息）
            示例: {"sub": "1", "username": "player1"}
        expires_delta: 自定义过期时间间隔（可选）
            如果不提供，使用默认的JWT_EXPIRE_MINUTES

    Returns:
        str: 编码后的JWT Token字符串

    示例:
        >>> token = create_access_token({"sub": "1", "username": "player1"})
        >>> print(token)
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    """
    # 复制数据，避免修改原始数据
    to_encode = data.copy()

    # 计算过期时间
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=JWT_EXPIRE_MINUTES)

    # 添加过期时间声明
    to_encode.update({"exp": expire})

    # 添加签发时间
    to_encode.update({"iat": datetime.utcnow()})

    # 编码生成Token
    encoded_jwt = jwt.encode(
        to_encode,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM
    )

    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """
    解码并验证JWT访问令牌

    解码JWT Token，验证签名和过期时间。

    Args:
        token: JWT Token字符串

    Returns:
        Optional[Dict]: 解码后的Token数据
            - 成功时返回包含用户信息的字典
            - 失败时返回None

    示例:
        >>> payload = decode_access_token("eyJhbGciOiJIUzI1NiIs...")
        >>> print(payload)
        {"sub": "1", "username": "player1", "exp": 1234567890}
    """
    try:
        # 解码Token
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM]
        )
        return payload

    except JWTError:
        # Token无效或已过期
        return None


# ============================================================
# 模块信息
# ============================================================
if __name__ == "__main__":
    # 直接运行此文件时，测试安全功能
    print("=" * 50)
    print("安全模块测试")
    print("=" * 50)

    # 测试密码哈希
    test_password = "test123456"
    hashed = hash_password(test_password)
    print(f"原始密码: {test_password}")
    print(f"哈希值: {hashed}")

    # 测试密码验证
    is_valid = verify_password(test_password, hashed)
    print(f"验证结果: {is_valid}")

    # 测试JWT生成
    token = create_access_token({"sub": "1", "username": "testuser"})
    print(f"\nJWT Token: {token[:50]}...")

    # 测试JWT解码
    payload = decode_access_token(token)
    print(f"解码结果: {payload}")

    print("=" * 50)
