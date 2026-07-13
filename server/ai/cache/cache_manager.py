"""
缓存管理模块

实现AI生成结果的内存缓存
支持楼层和房间内容缓存
"""

import hashlib
import json
import time
from typing import Optional, Dict, Any
from collections import OrderedDict


class CacheManager:
    """缓存管理器"""

    def __init__(self, max_size: int = 1000, ttl: int = 3600):
        """
        初始化缓存管理器

        Args:
            max_size: 最大缓存条目数
            ttl: 缓存过期时间（秒）
        """
        self.max_size = max_size
        self.ttl = ttl

        # 使用OrderedDict实现LRU缓存
        self._cache: OrderedDict[str, Dict[str, Any]] = OrderedDict()

        # 缓存统计
        self._hits = 0
        self._misses = 0

    def _generate_key(self, prefix: str, params: Dict[str, Any]) -> str:
        """
        生成缓存键

        Args:
            prefix: 键前缀
            params: 参数字典

        Returns:
            缓存键
        """
        # 将参数排序后序列化
        param_str = json.dumps(params, sort_keys=True)
        param_hash = hashlib.md5(param_str.encode()).hexdigest()[:12]

        return f"{prefix}:{param_hash}"

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        """
        获取缓存

        Args:
            key: 缓存键

        Returns:
            缓存数据或None
        """
        if key not in self._cache:
            self._misses += 1
            return None

        entry = self._cache[key]

        # 检查是否过期
        if time.time() > entry["expires_at"]:
            del self._cache[key]
            self._misses += 1
            return None

        # 移到末尾（LRU）
        self._cache.move_to_end(key)
        self._hits += 1

        return entry["data"]

    def set(self, key: str, data: Dict[str, Any], ttl: Optional[int] = None) -> None:
        """
        设置缓存

        Args:
            key: 缓存键
            data: 缓存数据
            ttl: 自定义过期时间（秒）
        """
        # 如果缓存已满，删除最旧的条目
        while len(self._cache) >= self.max_size:
            self._cache.popitem(last=False)

        self._cache[key] = {
            "data": data,
            "created_at": time.time(),
            "expires_at": time.time() + (ttl or self.ttl)
        }

    def delete(self, key: str) -> bool:
        """
        删除缓存

        Args:
            key: 缓存键

        Returns:
            是否成功
        """
        if key in self._cache:
            del self._cache[key]
            return True
        return False

    def clear(self) -> int:
        """
        清空缓存

        Returns:
            清除的条目数
        """
        count = len(self._cache)
        self._cache.clear()
        return count

    def has(self, key: str) -> bool:
        """
        检查缓存是否存在

        Args:
            key: 缓存键

        Returns:
            是否存在
        """
        if key not in self._cache:
            return False

        entry = self._cache[key]

        # 检查是否过期
        if time.time() > entry["expires_at"]:
            del self._cache[key]
            return False

        return True

    def get_stats(self) -> Dict[str, Any]:
        """
        获取缓存统计

        Returns:
            统计数据
        """
        total_requests = self._hits + self._misses
        hit_rate = self._hits / total_requests if total_requests > 0 else 0

        return {
            "size": len(self._cache),
            "max_size": self.max_size,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate": round(hit_rate, 4),
            "ttl": self.ttl
        }

    def cleanup_expired(self) -> int:
        """
        清理过期缓存

        Returns:
            清除的条目数
        """
        current_time = time.time()
        expired_keys = [
            key for key, entry in self._cache.items()
            if current_time > entry["expires_at"]
        ]

        for key in expired_keys:
            del self._cache[key]

        return len(expired_keys)


# ==================== 特化缓存管理器 ====================

class FloorCacheManager(CacheManager):
    """楼层缓存管理器"""

    def __init__(self, max_size: int = 100, ttl: int = 7200):
        super().__init__(max_size, ttl)

    def get_floor(self, floor_level: int, player_level: int) -> Optional[Dict[str, Any]]:
        """获取楼层缓存"""
        key = self._generate_key("floor", {
            "floor_level": floor_level,
            "player_level": player_level
        })
        return self.get(key)

    def set_floor(self, floor_level: int, player_level: int, data: Dict[str, Any]) -> None:
        """设置楼层缓存"""
        key = self._generate_key("floor", {
            "floor_level": floor_level,
            "player_level": player_level
        })
        self.set(key, data)


class RoomCacheManager(CacheManager):
    """房间内容缓存管理器"""

    def __init__(self, max_size: int = 500, ttl: int = 3600):
        super().__init__(max_size, ttl)

    def get_room_content(
        self,
        room_id: int,
        room_type: str,
        floor_level: int,
        player_level: int
    ) -> Optional[Dict[str, Any]]:
        """获取房间内容缓存"""
        key = self._generate_key("room", {
            "room_id": room_id,
            "room_type": room_type,
            "floor_level": floor_level,
            "player_level": player_level
        })
        return self.get(key)

    def set_room_content(
        self,
        room_id: int,
        room_type: str,
        floor_level: int,
        player_level: int,
        data: Dict[str, Any]
    ) -> None:
        """设置房间内容缓存"""
        key = self._generate_key("room", {
            "room_id": room_id,
            "room_type": room_type,
            "floor_level": floor_level,
            "player_level": player_level
        })
        self.set(key, data)


# 全局缓存实例
floor_cache = FloorCacheManager()
room_cache = RoomCacheManager()
