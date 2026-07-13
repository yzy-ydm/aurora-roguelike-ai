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

# 导入数据库连接模块
from app.database.connection import check_database_connection

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
    健康检查接口 - 包含数据库连接测试

    测试数据库连接是否正常，并返回系统状态信息。

    Returns:
        dict: 包含系统状态和数据库连接信息
            - status: 系统状态 ("ok" 或 "error")
            - database: 数据库连接状态
            - database_info: 数据库详细信息（连接成功时）
    """
    # 检查数据库连接
    db_status = check_database_connection()

    # 构建响应
    response = {
        "status": "ok" if db_status["status"] == "connected" else "error",
        "database": db_status["status"]
    }

    # 连接成功时添加数据库信息
    if db_status["status"] == "connected":
        response["database_info"] = {
            "name": db_status["database"],
            "version": db_status["version"]
        }
    else:
        # 连接失败时添加错误信息
        response["error"] = db_status.get("error", "未知错误")

    return response


# ============================================================
# 路由注册区域
# ============================================================

# 导入认证路由
from app.api.auth.router import router as auth_router
# 导入玩家角色路由
from app.api.player.router import router as player_router
# 导入武器路由
from app.api.weapon.router import router as weapon_router
# 导入怪物路由
from app.api.monster.router import router as monster_router
# 导入游戏存档路由
from app.api.save.router import router as save_router
# 导入地图路由
from app.api.map.router import router as map_router
# 导入事件路由
from app.api.event.router import router as event_router

# 注册路由
app.include_router(auth_router)    # 认证接口: /api/auth/*
app.include_router(player_router)  # 玩家角色接口: /api/player/*
app.include_router(weapon_router)  # 武器接口: /api/weapons/*, /api/player/weapons
app.include_router(monster_router) # 怪物接口: /api/monsters/*
app.include_router(save_router)    # 游戏存档接口: /api/game/save/*
app.include_router(map_router)     # 地图接口: /api/maps/*
app.include_router(event_router)   # 事件接口: /api/events/*


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
