"""
认证服务模块

本模块提供用户认证相关的业务逻辑，包括：
- 用户注册（自动创建玩家角色）
- 用户认证（登录，兼容已有用户）
- Token生成

设计原则：
- 服务层只处理业务逻辑
- 不直接处理HTTP请求/响应
- 通过依赖注入获取数据库会话
"""

from datetime import datetime
from typing import Optional, Tuple
import time

from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.user import User
from app.models.player_profile import PlayerProfile
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
        5. 自动创建玩家角色档案
        6. 返回用户信息

        Args:
            user_data: 用户注册数据（用户名、密码、邮箱）

        Returns:
            Tuple[bool, str, Optional[UserInfo]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[UserInfo]: 用户信息（成功时）
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
        self.db.flush()  # 刷新以获取自增ID

        # 5. 自动创建玩家角色档案
        print(f"[AuthService] Creating player profile for user_id: {new_user.id}")
        new_profile = PlayerProfile(
            user_id=new_user.id,
            nickname=user_data.username,
            level=1,
            experience=0,
            experience_to_next_level=100,
            max_health=100,
            current_health=100,
            attack=10,
            defense=5,
            crit_rate=5.00,
            gold=0,
            total_play_time=0,
            max_floor_reached=1,
            total_kills=0,
            death_count=0
        )
        self.db.add(new_profile)

        # 提交事务
        self.db.commit()
        self.db.refresh(new_user)

        # 6. 构建返回的用户信息
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
        4. 确保玩家角色档案存在（兼容已有用户）
        5. 更新最后登录时间

        Args:
            login_data: 用户登录数据（用户名、密码）

        Returns:
            Tuple[bool, str, Optional[User]]:
                - bool: 是否成功
                - str: 消息说明
                - Optional[User]: 用户对象（成功时）
        """
        print("[LOGIN TRACE] auth service entered")
        total_start = time.time()
        print(f"[AUTH TIMER] login start: {login_data.username}")

        # 1. 根据用户名查找用户
        t0 = time.time()
        user = self.db.query(User).filter(
            User.username == login_data.username,
            User.is_deleted == False
        ).first()
        t1 = time.time()
        print(f"[AUTH TIMER] query_user: {(t1-t0)*1000:.1f} ms")

        # 用户不存在
        if not user:
            total_end = time.time()
            print(f"[AUTH TIMER] total: {(total_end-total_start)*1000:.1f} ms (user not found)")
            return False, "用户名或密码错误", None

        # 2. 验证密码是否匹配
        t2 = time.time()
        password_valid = verify_password(login_data.password, user.password_hash)
        t3 = time.time()
        print(f"[AUTH TIMER] verify_password: {(t3-t2)*1000:.1f} ms")

        if not password_valid:
            total_end = time.time()
            print(f"[AUTH TIMER] total: {(total_end-total_start)*1000:.1f} ms (wrong password)")
            return False, "用户名或密码错误", None

        # 3. 检查账号是否启用
        if not user.is_active:
            total_end = time.time()
            print(f"[AUTH TIMER] total: {(total_end-total_start)*1000:.1f} ms (account disabled)")
            return False, "账号已被禁用", None

        # 4. 确保玩家角色档案存在（兼容已有用户）
        t4 = time.time()
        profile_exists = self._ensure_player_profile(user.id, user.username)
        t5 = time.time()
        print(f"[AUTH TIMER] ensure_profile: {(t5-t4)*1000:.1f} ms (exists={profile_exists})")

        # 5. 更新最后登录时间
        user.last_login_at = datetime.utcnow()

        # 统一提交事务
        t6 = time.time()
        self.db.commit()
        t7 = time.time()
        print(f"[AUTH TIMER] commit: {(t7-t6)*1000:.1f} ms")

        total_end = time.time()
        print(f"[AUTH TIMER] total: {(total_end-total_start)*1000:.1f} ms")
        print("[LOGIN TRACE] login response generated")

        return True, "登录成功", user

    def _ensure_player_profile(self, user_id: int, username: str) -> bool:
        """
        确保玩家角色档案存在

        如果用户没有角色档案，自动创建一个。
        用于兼容注册时未创建角色档案的已有用户。

        注意：此方法只负责添加到session，不负责commit。
        commit由调用方（authenticate_user）统一处理。

        Args:
            user_id: 用户ID
            username: 用户名（用作默认昵称）

        Returns:
            bool: 是否已存在角色档案（True=已存在，False=新创建）
        """
        existing_profile = self.db.query(PlayerProfile).filter(
            PlayerProfile.user_id == user_id
        ).first()

        if existing_profile:
            print(f"[AuthService] Player profile already exists for user_id: {user_id}")
            return True

        # 创建新角色档案
        print(f"[AuthService] Creating player profile for user_id: {user_id}")
        new_profile = PlayerProfile(
            user_id=user_id,
            nickname=username,
            level=1,
            experience=0,
            experience_to_next_level=100,
            max_health=100,
            current_health=100,
            attack=10,
            defense=5,
            crit_rate=5.00,
            gold=0,
            total_play_time=0,
            max_floor_reached=1,
            total_kills=0,
            death_count=0
        )
        self.db.add(new_profile)
        # 不在这里commit，由调用方统一处理
        return False

    def create_access_token(self, user: User) -> TokenResponse:
        """
        为用户创建JWT访问令牌

        Args:
            user: 用户对象

        Returns:
            TokenResponse: 包含Token和用户信息的响应
        """
        # 构建Token载荷
        token_data = {
            "sub": str(user.id),
            "username": user.username
        }

        # 生成Token
        t0 = time.time()
        access_token = create_access_token(token_data)
        t1 = time.time()
        print(f"[AUTH TIMER] jwt: {(t1-t0)*1000:.1f} ms")

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
