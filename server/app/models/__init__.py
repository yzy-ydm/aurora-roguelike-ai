"""
数据模型模块初始化文件

导出所有数据模型，方便其他模块导入使用。
"""

from app.models.user import User

__all__ = [
    "User"
]
