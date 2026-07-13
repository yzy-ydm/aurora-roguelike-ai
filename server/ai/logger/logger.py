"""
日志管理模块

记录请求、响应、耗时、异常
支持文件和控制台输出
"""

import os
import logging
import json
import time
from datetime import datetime
from typing import Optional, Dict, Any
from functools import wraps
from contextlib import contextmanager


# 日志目录
LOG_DIR = os.path.join(os.path.dirname(__file__), "..", "logs")


class Logger:
    """日志管理器"""

    def __init__(self, name: str = "ai_service", log_dir: str = LOG_DIR):
        """
        初始化日志管理器

        Args:
            name: 日志名称
            log_dir: 日志目录
        """
        self.name = name
        self.log_dir = log_dir

        # 确保日志目录存在
        os.makedirs(log_dir, exist_ok=True)

        # 创建日志器
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)

        # 避免重复添加处理器
        if not self.logger.handlers:
            self._setup_handlers()

    def _setup_handlers(self):
        """设置日志处理器"""
        # 控制台处理器
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        self.logger.addHandler(console_handler)

        # 文件处理器（按日期）
        today = datetime.now().strftime('%Y-%m-%d')
        log_file = os.path.join(self.log_dir, f"{self.name}_{today}.log")
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)
        file_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_format)
        self.logger.addHandler(file_handler)

    def info(self, message: str, **kwargs):
        """记录信息日志"""
        self.logger.info(message, **kwargs)

    def debug(self, message: str, **kwargs):
        """记录调试日志"""
        self.logger.debug(message, **kwargs)

    def warning(self, message: str, **kwargs):
        """记录警告日志"""
        self.logger.warning(message, **kwargs)

    def error(self, message: str, **kwargs):
        """记录错误日志"""
        self.logger.error(message, **kwargs)

    def log_request(
        self,
        method: str,
        path: str,
        client_id: str,
        request_data: Optional[Dict[str, Any]] = None
    ):
        """
        记录API请求

        Args:
            method: HTTP方法
            path: 请求路径
            client_id: 客户端ID
            request_data: 请求数据
        """
        self.info(f"REQUEST | {method} {path} | Client: {client_id}")
        if request_data:
            self.debug(f"REQUEST DATA | {json.dumps(request_data, ensure_ascii=False)}")

    def log_response(
        self,
        method: str,
        path: str,
        status_code: int,
        processing_time: float,
        response_data: Optional[Dict[str, Any]] = None
    ):
        """
        记录API响应

        Args:
            method: HTTP方法
            path: 请求路径
            status_code: 状态码
            processing_time: 处理时间（秒）
            response_data: 响应数据
        """
        self.info(
            f"RESPONSE | {method} {path} | Status: {status_code} | Time: {processing_time:.3f}s"
        )
        if response_data:
            self.debug(f"RESPONSE DATA | {json.dumps(response_data, ensure_ascii=False)}")

    def log_cache(
        self,
        action: str,
        cache_type: str,
        key: str,
        hit: bool = False
    ):
        """
        记录缓存操作

        Args:
            action: 操作类型（get/set/delete）
            cache_type: 缓存类型（floor/room）
            key: 缓存键
            hit: 是否命中
        """
        status = "HIT" if hit else "MISS"
        self.debug(f"CACHE | {action} | {cache_type} | {key} | {status}")

    def log_error(
        self,
        error: Exception,
        context: Optional[str] = None
    ):
        """
        记录错误

        Args:
            error: 异常对象
            context: 上下文信息
        """
        error_msg = f"ERROR | {type(error).__name__}: {str(error)}"
        if context:
            error_msg = f"ERROR | {context} | {type(error).__name__}: {str(error)}"
        self.error(error_msg)

    def log_generation(
        self,
        request_type: str,
        success: bool,
        quality_score: Optional[float] = None,
        processing_time: Optional[float] = None
    ):
        """
        记录AI生成结果

        Args:
            request_type: 请求类型
            success: 是否成功
            quality_score: 质量评分
            processing_time: 处理时间
        """
        status = "SUCCESS" if success else "FAILED"
        msg = f"GENERATION | {request_type} | {status}"
        if quality_score is not None:
            msg += f" | Quality: {quality_score:.2f}"
        if processing_time is not None:
            msg += f" | Time: {processing_time:.3f}s"
        self.info(msg)


# 全局日志实例
logger = Logger()


# ==================== 性能计时装饰器 ====================

def log_timing(func):
    """
    记录函数执行时间的装饰器
    """
    @wraps(func)
    async def async_wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = await func(*args, **kwargs)
            elapsed = time.time() - start_time
            logger.debug(f"TIMING | {func.__name__} | {elapsed:.3f}s")
            return result
        except Exception as e:
            elapsed = time.time() - start_time
            logger.error(f"TIMING | {func.__name__} | FAILED after {elapsed:.3f}s | {e}")
            raise

    @wraps(func)
    def sync_wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            elapsed = time.time() - start_time
            logger.debug(f"TIMING | {func.__name__} | {elapsed:.3f}s")
            return result
        except Exception as e:
            elapsed = time.time() - start_time
            logger.error(f"TIMING | {func.__name__} | FAILED after {elapsed:.3f}s | {e}")
            raise

    import asyncio
    if asyncio.iscoroutinefunction(func):
        return async_wrapper
    return sync_wrapper


@contextmanager
def timing_context(operation_name: str):
    """
    计时上下文管理器

    Args:
        operation_name: 操作名称
    """
    start_time = time.time()
    try:
        yield
    finally:
        elapsed = time.time() - start_time
        logger.debug(f"TIMING | {operation_name} | {elapsed:.3f}s")
