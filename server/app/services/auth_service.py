"""
认证服务模块

本模块提供用户认证相关的业务逻辑，包括：
- 用户注册
- 用户认证（登录）
- Token生成

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
"""

from datetime import datetime
from typing import Optional, Tuple

from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.user import User
from app.schemas.auth import UserRegister, UserLogin, TokenResponse, UserInfo
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token
)


class AuthService:
    """
    认证服务类

    提供用户认证相关的业务逻辑方法。

    使用方式：
        # 在API路由中通过Depends注入
        def register(user_data: UserRegister, db: Session = Depends(get_db)):
            service = AuthService(db)
            return service.register_user(user_data)
    """

    def __init__(self, db: Session):
        """
        初始化认证服务

        Args:
            db: SQLAlchemy数据库会话
        """
        self.db = db

    def register_user(self, user_data: UserRegister) -> Tuple[bool, str, Optional[UserInfo]]:
        """
        注册新用户

        流程：
        1. 检查用户名是否已存在
        2. 检查邮箱是否已被使用
        3. 对密码进行bcrypt哈希加密
        4. 创建用户记录
        5. 返回用户信息

        Args:
            user_data: 用户注册数据（用户名、密码、邮箱）

        Returns:
            Tuple[bool, str, Optional[UserInfo]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[UserInfo]: 用户信息（成功时）

        示例:
            >>> service = AuthService(db)
            >>> success, msg, user = service.register_user(UserRegister(
            ...     username="player1",
            ...     password="password123",
            ...     email="player1@example.com"
            ... ))
        """
        # 1. 检查用户名是否已存在
        existing_user = self.db.query(User).filter(
            User.username == user_data.username,
            User.is_deleted == False
        ).first()

        if existing_user:
            return False, "用户名已存在", None

        # 2. 检查邮箱是否已被使用（如果提供了邮箱）
        if user_data.email:
            existing_email = self.db.query(User).filter(
                User.email == user_data.email,
                User.is_deleted == False
            ).first()

            if existing_email:
                return False, "邮箱已被注册", None

        # 3. 对密码进行bcrypt哈希加密
        hashed_password = hash_password(user_data.password)

        # 4. 创建用户记录
        new_user = User(
            username=user_data.username,
            password_hash=hashed_password,
            email=user_data.email,
            is_active=True,
            is_deleted=False
        )

        # 添加到数据库
        self.db.add(new_user)
        self.db.commit()
        self.db.refresh(new_user)  # 刷新以获取自增ID等

        # 5. 构建返回的用户信息
        user_info = UserInfo(
            id=new_user.id,
            username=new_user.username,
            email=new_user.email,
            is_active=new_user.is_active,
            created_at=new_user.created_at
        )

        return True, "注册成功", user_info

    def authenticate_user(self, login_data: UserLogin) -> Tuple[bool, str, Optional[User]]:
        """
        验证用户身份（登录）

        流程：
        1. 根据用户名查找用户
        2. 验证密码是否匹配
        3. 检查账号是否启用
        4. 更新最后登录时间

        Args:
            login_data: 用户登录数据（用户名、密码）

        Returns:
            Tuple[bool, str, Optional[User]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[User]: 用户对象（成功时）

        示例:
            >>> service = AuthService(db)
            >>> success, msg, user = service.authenticate_user(UserLogin(
            ...     username="player1",
            ...     password="password123"
            ... ))
        """
        # 1. 根据用户名查找用户
        user = self.db.query(User).filter(
            User.username == login_data.username,
            User.is_deleted == False
        ).first()

        # 用户不存在
        if not user:
            return False, "用户名或密码错误", None

        # 2. 验证密码是否匹配
        if not verify_password(login_data.password, user.password_hash):
            return False, "用户名或密码错误", None

        # 3. 检查账号是否启用
        if not user.is_active:
            return False, "账号已被禁用", None

        # 4. 更新最后登录时间
        user.last_login_at = datetime.utcnow()
        self.db.commit()

        return True, "登录成功", user

    def create_access_token(self, user: User) -> TokenResponse:
        """
        为用户创建JWT访问令牌

        将用户ID和用户名编码到Token中。

        Args:
            user: 用户对象

        Returns:
            TokenResponse: 包含Token和用户信息的响应

        示例:
            >>> service = AuthService(db)
            >>> token_response = service.create_access_token(user)
            >>> print(token_response.access_token)
        """
        # 构建Token载荷
        token_data = {
            "sub": str(user.id),      # 用户ID（subject）
            "username": user.username  # 用户名
        }

        # 生成Token
        access_token = create_access_token(token_data)

        # 构建用户信息
        user_info = UserInfo(
            id=user.id,
            username=user.username,
            email=user.email,
            is_active=user.is_active,
            created_at=user.created_at
        )

        # 返回Token响应
        return TokenResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_info
        )

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        """
        根据用户ID获取用户

        Args:
            user_id: 用户ID

        Returns:
            Optional[User]: 用户对象，不存在时返回None
        """
        return self.db.query(User).filter(
            User.id == user_id,
            User.is_deleted == False
        ).first()

    def get_user_by_username(self, username: str) -> Optional[User]:
        """
        根据用户名获取用户

        Args:
            username: 用户名

        Returns:
            Optional[User]: 用户对象，不存在时返回None
        """
        return self.db.query(User).filter(
            User.username == username,
            User.is_deleted == False
        ).first()
