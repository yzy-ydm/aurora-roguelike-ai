"""
用户数据模型

本模块定义 users 表的 SQLAlchemy ORM 模型。

数据库表结构：
- id: 用户ID（主键，自增）
- username: 用户名（唯一）
- password_hash: 密码哈希值
- email: 邮箱地址（唯一）
- is_active: 是否启用
- last_login_at: 最后登录时间
- created_at: 创建时间
- updated_at: 更新时间
- is_deleted: 软删除标记
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Index
)
from sqlalchemy.sql import func

from app.database.connection import Base


class User(Base):
    """
    用户模型类

    映射到数据库 users 表，存储用户账号信息。

    Attributes:
        id: 用户唯一标识（主键）
        username: 用户名，用于登录
        password_hash: 密码的bcrypt哈希值
        email: 用户邮箱地址
        is_active: 账号是否启用（0-禁用，1-启用）
        last_login_at: 最后一次登录时间
        created_at: 记录创建时间
        updated_at: 记录最后更新时间
        is_deleted: 是否已软删除（0-正常，1-已删除）
    """

    # 表名
    __tablename__ = "users"

    # ==================== 字段定义 ====================

    # 主键ID，自增
    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        comment="用户ID"
    )

    # 用户名，唯一，不可为空
    username = Column(
        String(50),
        unique=True,
        nullable=False,
        comment="用户名"
    )

    # 密码哈希值（使用bcrypt加密）
    password_hash = Column(
        String(255),
        nullable=False,
        comment="密码哈希"
    )

    # 邮箱地址，唯一
    email = Column(
        String(100),
        unique=True,
        nullable=True,
        comment="邮箱地址"
    )

    # 账号状态：0-禁用，1-启用
    is_active = Column(
        Boolean,
        default=True,
        comment="是否启用"
    )

    # 最后登录时间
    last_login_at = Column(
        DateTime,
        nullable=True,
        comment="最后登录时间"
    )

    # 记录创建时间，自动填充
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="创建时间"
    )

    # 记录更新时间，自动更新
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )

    # 软删除标记
    is_deleted = Column(
        Boolean,
        default=False,
        comment="是否删除"
    )

    # ==================== 索引定义 ====================
    __table_args__ = (
        Index("idx_username", "username"),
        Index("idx_email", "email"),
        Index("idx_is_active", "is_active"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_unicode_ci"
        }
    )

    # ==================== 方法 ====================

    def __repr__(self) -> str:
        """返回用户对象的字符串表示"""
        return f"<User(id={self.id}, username='{self.username}')>"

    def to_dict(self) -> dict:
        """
        将用户对象转换为字典

        注意：不包含 password_hash 等敏感信息

        Returns:
            dict: 用户信息字典
        """
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "is_active": self.is_active,
            "last_login_at": self.last_login_at.isoformat() if self.last_login_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
