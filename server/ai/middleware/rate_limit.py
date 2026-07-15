"""
API限流中间件

实现用户请求限制
防止AI接口滥用
"""

import time
from typing import Dict, Optional
from collections import defaultdict
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class RateLimitConfig:
    """限流配置"""
    # 普通接口限制 (requests/min)
    DEFAULT_RATE_LIMIT = 60

    # AI接口限制 (requests/min)
    AI_RATE_LIMIT = 10

    # 健康检查不限制
    EXEMPT_PATHS = ["/health", "/", "/docs", "/redoc", "/openapi.json"]

    # AI接口路径前缀
    AI_PATH_PREFIX = "/api/generate/"


class RateLimitEntry:
    """限流记录"""

    def __init__(self, limit: int, window: int = 60):
        self.limit = limit
        self.window = window
        self.requests: list = []

    def add_request(self) -> bool:
        """
        添加请求记录

        Returns:
            是否允许请求
        """
        now = time.time()

        # 清理过期记录
        self.requests = [t for t in self.requests if now - t < self.window]

        # 检查是否超过限制
        if len(self.requests) >= self.limit:
            return False

        # 记录请求
        self.requests.append(now)
        return True

    def get_remaining(self) -> int:
        """获取剩余请求次数"""
        now = time.time()
        self.requests = [t for t in self.requests if now - t < self.window]
        return max(0, self.limit - len(self.requests))

    def get_reset_time(self) -> float:
        """获取重置时间"""
        if not self.requests:
            return 0
        now = time.time()
        oldest = min(self.requests)
        return max(0, self.window - (now - oldest))


class RateLimitMiddleware(BaseHTTPMiddleware):
    """限流中间件"""

    def __init__(self, app, config: Optional[RateLimitConfig] = None):
        super().__init__(app)
        self.config = config or RateLimitConfig()
        self.clients: Dict[str, Dict[str, RateLimitEntry]] = defaultdict(
            lambda: {
                "default": RateLimitEntry(self.config.DEFAULT_RATE_LIMIT),
                "ai": RateLimitEntry(self.config.AI_RATE_LIMIT)
            }
        )

    def _get_client_id(self, request: Request) -> str:
        """获取客户端标识"""
        # 优先使用认证的客户端ID
        if hasattr(request.state, "client_id"):
            return request.state.client_id

        # 使用IP地址
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()

        return request.client.host if request.client else "unknown"

    def _is_ai_endpoint(self, path: str) -> bool:
        """检查是否是AI接口"""
        return path.startswith(self.config.AI_PATH_PREFIX)

    def _is_exempt(self, path: str) -> bool:
        """检查是否豁免"""
        return path in self.config.EXEMPT_PATHS

    async def dispatch(self, request: Request, call_next):
        """处理请求"""
        path = request.url.path

        # 检查是否豁免
        if self._is_exempt(path):
            return await call_next(request)

        # 获取客户端ID
        client_id = self._get_client_id(request)

        # 获取限流记录
        client_limits = self.clients[client_id]

        # 检查AI接口限制
        if self._is_ai_endpoint(path):
            rate_entry = client_limits["ai"]
            limit_type = "AI"
        else:
            rate_entry = client_limits["default"]
            limit_type = "default"

        # 检查是否超过限制
        if not rate_entry.add_request():
            remaining = rate_entry.get_remaining()
            reset_time = rate_entry.get_reset_time()

            return JSONResponse(
                status_code=429,
                content={
                    "detail": f"Rate limit exceeded ({limit_type})",
                    "retry_after": int(reset_time),
                    "limit": rate_entry.limit,
                    "remaining": remaining
                },
                headers={
                    "X-RateLimit-Limit": str(rate_entry.limit),
                    "X-RateLimit-Remaining": str(remaining),
                    "X-RateLimit-Reset": str(int(reset_time)),
                    "Retry-After": str(int(reset_time))
                }
            )

        # 处理请求
        response = await call_next(request)

        # 添加限流响应头
        remaining = rate_entry.get_remaining()
        response.headers["X-RateLimit-Limit"] = str(rate_entry.limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)

        return response


class RateLimitManager:
    """限流管理器（用于查询限流状态）"""

    def __init__(self):
        self._middleware: Optional[RateLimitMiddleware] = None

    def set_middleware(self, middleware: RateLimitMiddleware):
        """设置中间件引用"""
        self._middleware = middleware

    def get_client_status(self, client_id: str) -> Dict:
        """获取客户端限流状态"""
        if not self._middleware:
            return {"error": "Rate limit middleware not initialized"}

        if client_id not in self._middleware.clients:
            return {
                "client_id": client_id,
                "default_remaining": self._middleware.config.DEFAULT_RATE_LIMIT,
                "ai_remaining": self._middleware.config.AI_RATE_LIMIT
            }

        client_limits = self._middleware.clients[client_id]
        return {
            "client_id": client_id,
            "default_remaining": client_limits["default"].get_remaining(),
            "ai_remaining": client_limits["ai"].get_remaining(),
            "default_limit": self._middleware.config.DEFAULT_RATE_LIMIT,
            "ai_limit": self._middleware.config.AI_RATE_LIMIT
        }

    def get_all_status(self) -> Dict:
        """获取所有客户端限流状态"""
        if not self._middleware:
            return {"error": "Rate limit middleware not initialized"}

        return {
            "total_clients": len(self._middleware.clients),
            "config": {
                "default_rate_limit": self._middleware.config.DEFAULT_RATE_LIMIT,
                "ai_rate_limit": self._middleware.config.AI_RATE_LIMIT
            }
        }


# 全局限流管理器实例
rate_limit_manager = RateLimitManager()
