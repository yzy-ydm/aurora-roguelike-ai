"""
Pydantic模式模块初始化文件

导出所有数据验证模式。
"""

from app.schemas.auth import (
    UserRegister,
    UserLogin,
    TokenResponse,
    UserInfo
)
from app.schemas.player import (
    PlayerCreate,
    PlayerUpdate,
    PlayerResponse
)
from app.schemas.weapon import (
    WeaponResponse,
    PlayerWeaponResponse,
    WeaponCreate,
    AddPlayerWeaponRequest
)
from app.schemas.monster import (
    MonsterResponse
)
from app.schemas.save import (
    SaveCreate,
    SaveUpdate,
    SaveResponse
)
from app.schemas.map import (
    MapResponse
)

__all__ = [
    "UserRegister",
    "UserLogin",
    "TokenResponse",
    "UserInfo",
    "PlayerCreate",
    "PlayerUpdate",
    "PlayerResponse",
    "WeaponResponse",
    "PlayerWeaponResponse",
    "WeaponCreate",
    "AddPlayerWeaponRequest",
    "MonsterResponse",
    "SaveCreate",
    "SaveUpdate",
    "SaveResponse",
    "MapResponse"
]
