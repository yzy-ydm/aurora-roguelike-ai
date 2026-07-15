"""
Aurora-Roguelike-AI 内容生成服务

基于FastAPI的AI服务端
负责生成Roguelike游戏内容
集成认证、缓存、限流、日志、数据库

启动方式:
    cd server/ai
    python main.py
    或
    uvicorn main:app --reload --host 0.0.0.0 --port 8001
"""

import time
import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# 导入路由
from api.ai_routes import router as ai_router

# 导入模块
from security.auth import get_auth_status, generate_token
from database.db_manager import db_manager
from database.enhanced_db_manager import enhanced_db_manager
from cache.cache_manager import floor_cache, room_cache, monster_cache, weapon_cache
from logger.logger import logger
from monitoring.logger import logger as enhanced_logger
from middleware.rate_limit import RateLimitMiddleware, rate_limit_manager
from services.request_manager import request_manager

# 创建FastAPI应用
app = FastAPI(
    title="Aurora-Roguelike-AI 内容生成服务",
    description="基于AI的Roguelike游戏内容生成API",
    version="1.1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许Godot客户端访问
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 添加限流中间件
rate_limit_middleware = RateLimitMiddleware(app)
app.add_middleware(RateLimitMiddleware)
rate_limit_manager.set_middleware(rate_limit_middleware)


# ==================== 中间件 ====================

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """请求日志中间件"""
    start_time = time.time()

    # 获取客户端ID（从Header或默认）
    client_id = request.headers.get("X-Client-ID", "unknown")

    # 记录请求
    logger.log_request(
        method=request.method,
        path=str(request.url.path),
        client_id=client_id
    )

    # 处理请求
    try:
        response = await call_next(request)
        processing_time = time.time() - start_time

        # 记录响应
        logger.log_response(
            method=request.method,
            path=str(request.url.path),
            status_code=response.status_code,
            processing_time=processing_time
        )

        # 添加自定义响应头
        response.headers["X-Processing-Time"] = str(round(processing_time, 3))
        response.headers["X-Server-Version"] = "1.1.0"

        return response
    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, f"{request.method} {request.url.path}")
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )


# 注册路由
app.include_router(ai_router, prefix="/api")


# ==================== 系统接口 ====================

@app.get("/", tags=["系统"])
async def root():
    """
    根路径 - 健康检查
    """
    return {
        "code": 200,
        "message": "Aurora-Roguelike-AI 内容生成服务运行中",
        "version": "1.1.0",
        "ai_mode": "mock"
    }


@app.get("/health", tags=["系统"])
async def health_check():
    """
    健康检查接口

    用于部署检查和监控
    """
    # 检查数据库连接
    db_status = True
    try:
        db_manager.get_statistics()
    except Exception:
        db_status = False

    # 检查AI服务状态
    ai_status = True  # 当前使用Mock模式，始终可用

    return {
        "status": "running",
        "version": "1.1.0",
        "ai_service": ai_status,
        "database": db_status,
        "timestamp": time.time(),
        "uptime": time.time() - app.state.start_time if hasattr(app.state, "start_time") else 0
    }


@app.get("/api/info", tags=["系统"])
async def api_info():
    """
    API信息
    """
    return {
        "service": "Aurora-Roguelike-AI Content Generator",
        "version": "1.1.0",
        "endpoints": [
            {
                "method": "POST",
                "path": "/api/generate/floor",
                "description": "生成楼层内容",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/room",
                "description": "生成房间内容",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/monster",
                "description": "生成怪物配置",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/weapon",
                "description": "生成武器配置",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/event",
                "description": "生成房间事件",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/dialogue",
                "description": "生成NPC对话",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/upgrade",
                "description": "生成升级强化选项",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/difficulty",
                "description": "生成难度调整建议",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/room_strategy",
                "description": "生成房间策略建议",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/npc_memory",
                "description": "生成NPC记忆响应",
                "auth_required": True
            },
            {
                "method": "POST",
                "path": "/api/generate/context_event",
                "description": "生成上下文事件",
                "auth_required": True
            }
        ],
        "ai_mode": "mock",
        "note": "当前使用Mock AI，未来将接入真实大语言模型"
    }


@app.get("/api/stats", tags=["系统"])
async def get_stats():
    """
    获取服务统计信息
    """
    # 认证状态
    auth_status = get_auth_status()

    # 数据库统计
    db_stats = db_manager.get_statistics()

    # 增强数据库统计
    enhanced_db_stats = enhanced_db_manager.get_statistics()

    # 缓存统计
    floor_cache_stats = floor_cache.get_stats()
    room_cache_stats = room_cache.get_stats()
    monster_cache_stats = monster_cache.get_stats()
    weapon_cache_stats = weapon_cache.get_stats()

    # 请求管理器统计
    request_stats = request_manager.get_statistics()

    # 限流状态
    rate_limit_stats = rate_limit_manager.get_all_status()

    return {
        "auth": auth_status,
        "database": {
            "legacy": db_stats,
            "enhanced": enhanced_db_stats
        },
        "cache": {
            "floor": floor_cache_stats,
            "room": room_cache_stats,
            "monster": monster_cache_stats,
            "weapon": weapon_cache_stats
        },
        "requests": request_stats,
        "rate_limit": rate_limit_stats
    }


@app.get("/api/auth/token", tags=["认证"])
async def get_token(client_id: str = "godot_client"):
    """
    获取API Token

    Args:
        client_id: 客户端ID

    Returns:
        Token信息
    """
    token = generate_token(client_id)
    logger.info(f"Token generated for client: {client_id}")

    return {
        "token": token,
        "client_id": client_id,
        "expires_in": 86400  # 24小时
    }


@app.get("/api/rate-limit/status", tags=["系统"])
async def get_rate_limit_status(client_id: str = "unknown"):
    """
    获取限流状态

    Args:
        client_id: 客户端ID

    Returns:
        限流状态信息
    """
    return rate_limit_manager.get_client_status(client_id)


@app.get("/api/requests/recent", tags=["系统"])
async def get_recent_requests(limit: int = 50):
    """
    获取最近的AI请求记录

    Args:
        limit: 返回数量限制

    Returns:
        请求记录列表
    """
    return {
        "requests": request_manager.get_recent_requests(limit),
        "statistics": request_manager.get_statistics()
    }


# ==================== 启动事件 ====================

@app.on_event("startup")
async def startup_event():
    """应用启动事件"""
    app.state.start_time = time.time()

    logger.info("=" * 60)
    logger.info("Aurora-Roguelike-AI 内容生成服务启动")
    logger.info("=" * 60)
    logger.info(f"API文档: http://localhost:8001/docs")
    logger.info(f"AI模式: Mock")
    logger.info(f"数据库: SQLite")
    logger.info(f"缓存: 内存缓存")
    logger.info(f"限流: 启用")
    logger.info("=" * 60)

    enhanced_logger.log_server_start("0.0.0.0", 8001, "mock")


@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭事件"""
    logger.info("Aurora-Roguelike-AI 内容生成服务关闭")
    enhanced_logger.log_server_stop()

    # 清理旧记录
    deleted = db_manager.cleanup_old_records(days=30)
    logger.info(f"清理旧记录: {deleted} 条")


# 启动入口
if __name__ == "__main__":
    print("=" * 60)
    print("Aurora-Roguelike-AI 内容生成服务启动中...")
    print("=" * 60)
    print(f"API文档地址: http://localhost:8001/docs")
    print(f"ReDoc文档地址: http://localhost:8001/redoc")
    print(f"AI模式: Mock (本地模拟)")
    print(f"认证: 启用")
    print(f"数据库: SQLite")
    print(f"缓存: 内存缓存")
    print(f"限流: 启用 (普通: 60/min, AI: 10/min)")
    print("=" * 60)

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=True
    )
