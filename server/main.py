"""
基于云端AI动态内容生成的Roguelike游戏系统 - 服务端入口

本文件是FastAPI应用的入口点，负责：
- 初始化FastAPI应用
- 配置中间件
- 注册路由
- 启动服务

使用方式：
    python main.py
    或
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# 创建FastAPI应用实例
app = FastAPI(
    title="Roguelike游戏系统API",
    description="基于云端AI动态内容生成的Roguelike游戏系统后端服务",
    version="1.0.0",
    docs_url="/docs",      # Swagger UI文档地址
    redoc_url="/redoc"     # ReDoc文档地址
)

# 配置CORS中间件（允许跨域请求）
# Godot客户端需要跨域访问API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],           # 允许的来源（生产环境应限制）
    allow_credentials=True,
    allow_methods=["*"],           # 允许的HTTP方法
    allow_headers=["*"],           # 允许的请求头
)


@app.get("/", tags=["系统"])
async def root():
    """
    根路径 - 健康检查接口

    Returns:
        dict: 包含系统状态信息
    """
    return {
        "code": 200,
        "message": "Roguelike游戏系统API服务运行中",
        "version": "1.0.0"
    }


@app.get("/health", tags=["系统"])
async def health_check():
    """
    健康检查接口

    用于监控系统运行状态

    Returns:
        dict: 系统健康状态
    """
    return {
        "code": 200,
        "status": "healthy",
        "service": "roguelike-game-api"
    }


# ============================================================
# 路由注册区域
# 后续开发时在此处注册各模块的路由
# ============================================================

# 示例（后续开发时取消注释并导入）：
# from app.api.auth.router import router as auth_router
# from app.api.user.router import router as user_router
# from app.api.game.router import router as game_router
# from app.api.ai.router import router as ai_router
#
# app.include_router(auth_router, prefix="/api/auth", tags=["认证"])
# app.include_router(user_router, prefix="/api/users", tags=["用户"])
# app.include_router(game_router, prefix="/api/game", tags=["游戏"])
# app.include_router(ai_router, prefix="/api/ai", tags=["AI生成"])


# 启动入口
if __name__ == "__main__":
    print("=" * 50)
    print("Roguelike游戏系统API服务启动中...")
    print("=" * 50)
    print(f"API文档地址: http://localhost:8000/docs")
    print(f"ReDoc文档地址: http://localhost:8000/redoc")
    print("=" * 50)

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True           # 开发模式下启用热重载
    )
