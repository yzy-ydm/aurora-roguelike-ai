"""
AI请求管理模块

负责AI请求记录和性能分析
"""

import time
import uuid
from typing import Optional, Dict, Any, List
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum


class RequestStatus(Enum):
    """请求状态"""
    PENDING = "pending"
    SUCCESS = "success"
    FAILED = "failed"
    FALLBACK = "fallback"


@dataclass
class AIRequestRecord:
    """AI请求记录"""
    request_id: str
    user_id: str
    endpoint: str
    timestamp: float
    request_data: Dict[str, Any]
    response_time: float = 0.0
    success: bool = False
    fallback_used: bool = False
    error_message: Optional[str] = None
    response_data: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)


class AIRequestManager:
    """AI请求管理器"""

    def __init__(self, max_history: int = 10000):
        """
        初始化请求管理器

        Args:
            max_history: 最大历史记录数
        """
        self.max_history = max_history
        self._requests: List[AIRequestRecord] = []
        self._active_requests: Dict[str, AIRequestRecord] = {}

        # 统计数据
        self._total_requests = 0
        self._success_requests = 0
        self._failed_requests = 0
        self._fallback_requests = 0
        self._total_response_time = 0.0

    def start_request(
        self,
        user_id: str,
        endpoint: str,
        request_data: Dict[str, Any]
    ) -> str:
        """
        开始记录请求

        Args:
            user_id: 用户ID
            endpoint: API端点
            request_data: 请求数据

        Returns:
            请求ID
        """
        request_id = str(uuid.uuid4())

        record = AIRequestRecord(
            request_id=request_id,
            user_id=user_id,
            endpoint=endpoint,
            timestamp=time.time(),
            request_data=request_data
        )

        self._active_requests[request_id] = record
        self._total_requests += 1

        return request_id

    def end_request(
        self,
        request_id: str,
        success: bool,
        response_data: Optional[Dict[str, Any]] = None,
        error_message: Optional[str] = None,
        fallback_used: bool = False
    ) -> Optional[AIRequestRecord]:
        """
        结束记录请求

        Args:
            request_id: 请求ID
            success: 是否成功
            response_data: 响应数据
            error_message: 错误信息
            fallback_used: 是否使用了降级

        Returns:
            请求记录
        """
        if request_id not in self._active_requests:
            return None

        record = self._active_requests.pop(request_id)
        record.response_time = time.time() - record.timestamp
        record.success = success
        record.response_data = response_data
        record.error_message = error_message
        record.fallback_used = fallback_used

        # 更新统计
        if success:
            self._success_requests += 1
        else:
            self._failed_requests += 1

        if fallback_used:
            self._fallback_requests += 1

        self._total_response_time += record.response_time

        # 添加到历史记录
        self._requests.append(record)

        # 清理旧记录
        if len(self._requests) > self.max_history:
            self._requests = self._requests[-self.max_history:]

        return record

    def get_request(self, request_id: str) -> Optional[AIRequestRecord]:
        """获取请求记录"""
        # 先查找活跃请求
        if request_id in self._active_requests:
            return self._active_requests[request_id]

        # 再查找历史记录
        for record in self._requests:
            if record.request_id == request_id:
                return record

        return None

    def get_user_requests(
        self,
        user_id: str,
        limit: int = 100
    ) -> List[AIRequestRecord]:
        """获取用户请求历史"""
        user_requests = [
            r for r in self._requests
            if r.user_id == user_id
        ]
        return user_requests[-limit:]

    def get_endpoint_stats(self) -> Dict[str, Dict[str, Any]]:
        """获取各端点统计"""
        endpoint_stats: Dict[str, Dict[str, Any]] = {}

        for record in self._requests:
            endpoint = record.endpoint
            if endpoint not in endpoint_stats:
                endpoint_stats[endpoint] = {
                    "total": 0,
                    "success": 0,
                    "failed": 0,
                    "fallback": 0,
                    "total_time": 0.0,
                    "avg_time": 0.0
                }

            stats = endpoint_stats[endpoint]
            stats["total"] += 1

            if record.success:
                stats["success"] += 1
            else:
                stats["failed"] += 1

            if record.fallback_used:
                stats["fallback"] += 1

            stats["total_time"] += record.response_time

        # 计算平均时间
        for endpoint, stats in endpoint_stats.items():
            if stats["total"] > 0:
                stats["avg_time"] = stats["total_time"] / stats["total"]
                stats["success_rate"] = stats["success"] / stats["total"]
            else:
                stats["avg_time"] = 0.0
                stats["success_rate"] = 0.0

        return endpoint_stats

    def get_statistics(self) -> Dict[str, Any]:
        """获取总体统计"""
        avg_time = (
            self._total_response_time / self._total_requests
            if self._total_requests > 0
            else 0.0
        )

        return {
            "total_requests": self._total_requests,
            "success_requests": self._success_requests,
            "failed_requests": self._failed_requests,
            "fallback_requests": self._fallback_requests,
            "active_requests": len(self._active_requests),
            "history_size": len(self._requests),
            "average_response_time": round(avg_time, 3),
            "success_rate": (
                self._success_requests / self._total_requests
                if self._total_requests > 0
                else 0.0
            ),
            "fallback_rate": (
                self._fallback_requests / self._total_requests
                if self._total_requests > 0
                else 0.0
            )
        }

    def get_recent_requests(self, limit: int = 50) -> List[Dict[str, Any]]:
        """获取最近的请求记录"""
        recent = self._requests[-limit:]
        return [r.to_dict() for r in reversed(recent)]

    def cleanup_old_requests(self, max_age_hours: int = 24) -> int:
        """清理旧请求记录"""
        cutoff_time = time.time() - (max_age_hours * 3600)
        original_count = len(self._requests)

        self._requests = [
            r for r in self._requests
            if r.timestamp > cutoff_time
        ]

        return original_count - len(self._requests)


# 全局请求管理器实例
request_manager = AIRequestManager()
