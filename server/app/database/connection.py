"""
数据库连接模块

本模块负责：
- 加载环境变量配置
- 创建SQLAlchemy引擎（Engine）
- 创建数据库会话工厂（SessionLocal）
- 提供数据库会话依赖注入（get_db）
- 提供数据库连接健康检查

技术栈：
- SQLAlchemy 2.x（ORM框架）
- PyMySQL（MySQL驱动）
- python-dotenv（环境变量管理）
"""

import os
from typing import Generator

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base, Session

# ============================================================
# 加载环境变量
# ============================================================
# 从 .env 文件加载配置
load_dotenv()

# ============================================================
# 数据库配置
# ============================================================
MYSQL_HOST = os.getenv("MYSQL_HOST", "localhost")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "")
MYSQL_DATABASE = os.getenv("MYSQL_DATABASE", "aurora_game")

# ============================================================
# 构建数据库连接URL
# ============================================================
# 格式: mysql+pymysql://用户名:密码@主机:端口/数据库名
DATABASE_URL = (
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}"
    f"@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}"
    f"?charset=utf8mb4"
)

# ============================================================
# 创建SQLAlchemy引擎
# ============================================================
# Engine 是 SQLAlchemy 的核心接口，负责管理数据库连接池
engine = create_engine(
    DATABASE_URL,
    # 连接池配置
    pool_size=5,          # 连接池大小
    max_overflow=10,      # 超出pool_size后最多可创建的连接数
    pool_timeout=30,      # 获取连接的超时时间（秒）
    pool_recycle=1800,    # 连接回收时间（秒），避免MySQL超时断开
    # echo=True,          # 是否打印SQL语句（调试时开启）
    echo=False
)

# ============================================================
# 创建数据库会话工厂
# ============================================================
# SessionLocal 是一个工厂类，每次调用时创建一个新的数据库会话
SessionLocal = sessionmaker(
    autocommit=False,     # 不自动提交
    autoflush=False,      # 不自动刷新
    bind=engine           # 绑定到引擎
)

# ============================================================
# 创建模型基类
# ============================================================
# 所有数据模型都应继承此基类
Base = declarative_base()


# ============================================================
# 数据库会话依赖注入
# ============================================================
def get_db() -> Generator[Session, None, None]:
    """
    获取数据库会话的依赖注入函数

    用于FastAPI的Depends()注入，确保每个请求使用独立的数据库会话，
    并在请求结束后自动关闭会话。

    Yields:
        Session: SQLAlchemy数据库会话

    使用示例:
        @app.get("/users")
        def get_users(db: Session = Depends(get_db)):
            users = db.query(User).all()
            return users
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ============================================================
# 数据库连接健康检查
# ============================================================
def check_database_connection() -> dict:
    """
    检查数据库连接是否正常

    执行简单的SQL查询来验证数据库连接。

    Returns:
        dict: 包含连接状态和数据库信息的字典
            - status: "connected" 或 "disconnected"
            - database: 数据库名称
            - version: MySQL版本信息
            - error: 错误信息（如果连接失败）

    示例返回值:
        {
            "status": "connected",
            "database": "aurora_game",
            "version": "8.0.36"
        }
    """
    try:
        # 创建临时会话执行查询
        with engine.connect() as connection:
            # 执行简单查询测试连接
            result = connection.execute(text("SELECT 1"))

            # 获取MySQL版本信息
            version_result = connection.execute(text("SELECT VERSION()"))
            mysql_version = version_result.scalar()

            # 获取当前数据库名
            db_result = connection.execute(text("SELECT DATABASE()"))
            db_name = db_result.scalar()

            return {
                "status": "connected",
                "database": db_name,
                "version": mysql_version
            }

    except Exception as e:
        return {
            "status": "disconnected",
            "database": MYSQL_DATABASE,
            "version": None,
            "error": str(e)
        }


# ============================================================
# 初始化数据库表（如果不存在）
# ============================================================
def init_database():
    """
    初始化数据库表结构

    检查所有继承自Base的模型，并在数据库中创建不存在的表。
    注意：此函数不会修改已存在的表结构。

    使用场景：
    - 开发环境快速初始化
    - 测试环境自动建表
    - 生产环境建议使用Alembic迁移
    """
    # 导入所有模型以确保它们被注册到Base.metadata
    # 后续添加模型时在此处导入
    # from app.models import user, game, weapon, monster

    # 创建所有表
    Base.metadata.create_all(bind=engine)
    print("数据库表初始化完成")


# ============================================================
# 模块信息
# ============================================================
if __name__ == "__main__":
    # 直接运行此文件时，测试数据库连接
    print("=" * 50)
    print("数据库连接测试")
    print("=" * 50)
    print(f"数据库URL: {MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}")
    print(f"用户名: {MYSQL_USER}")
    print("-" * 50)

    result = check_database_connection()

    if result["status"] == "connected":
        print(f"✅ 连接成功!")
        print(f"   数据库: {result['database']}")
        print(f"   MySQL版本: {result['version']}")
    else:
        print(f"❌ 连接失败!")
        print(f"   错误: {result.get('error', '未知错误')}")

    print("=" * 50)
