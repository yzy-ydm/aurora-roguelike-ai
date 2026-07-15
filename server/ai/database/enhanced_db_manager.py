"""
增强数据库管理模块

使用SQLite存储用户数据、AI请求记录、玩家数据
"""

import sqlite3
import json
import os
import hashlib
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import contextmanager


# 数据库路径
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "aurora.db")


class EnhancedDatabaseManager:
    """增强数据库管理器"""

    def __init__(self, db_path: str = DB_PATH):
        """
        初始化数据库管理器

        Args:
            db_path: 数据库文件路径
        """
        self.db_path = db_path
        self._ensure_data_dir()
        self._init_database()

    def _ensure_data_dir(self):
        """确保数据目录存在"""
        data_dir = os.path.dirname(self.db_path)
        os.makedirs(data_dir, exist_ok=True)

    def _init_database(self):
        """初始化数据库表"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 创建用户表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    email TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1
                )
            """)

            # 创建AI请求表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS ai_requests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_id TEXT UNIQUE NOT NULL,
                    user_id INTEGER,
                    endpoint TEXT NOT NULL,
                    request_data TEXT,
                    response_data TEXT,
                    response_time REAL,
                    success BOOLEAN DEFAULT 0,
                    fallback_used BOOLEAN DEFAULT 0,
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id)
                )
            """)

            # 创建玩家数据表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS player_profiles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER UNIQUE NOT NULL,
                    level INTEGER DEFAULT 1,
                    experience INTEGER DEFAULT 0,
                    health INTEGER DEFAULT 100,
                    attack INTEGER DEFAULT 10,
                    defense INTEGER DEFAULT 5,
                    gold INTEGER DEFAULT 0,
                    behavior_data TEXT,
                    upgrade_history TEXT,
                    event_history TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id)
                )
            """)

            # 创建AI生成历史表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS ai_generation_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_type TEXT NOT NULL,
                    request_data TEXT NOT NULL,
                    response_data TEXT,
                    quality_score REAL,
                    client_id TEXT,
                    processing_time REAL,
                    status TEXT DEFAULT 'success',
                    error_message TEXT,
                    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # 创建索引
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_users_username
                ON users(username)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_ai_requests_user_id
                ON ai_requests(user_id)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_ai_requests_endpoint
                ON ai_requests(endpoint)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_ai_requests_created_at
                ON ai_requests(created_at)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_player_profiles_user_id
                ON player_profiles(user_id)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_ai_generation_history_request_type
                ON ai_generation_history(request_type)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_ai_generation_history_create_time
                ON ai_generation_history(create_time)
            """)

            conn.commit()

    @contextmanager
    def _get_connection(self):
        """获取数据库连接（上下文管理器）"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    # ==================== 用户管理 ====================

    def create_user(
        self,
        username: str,
        password: str,
        email: Optional[str] = None
    ) -> Optional[int]:
        """
        创建用户

        Args:
            username: 用户名
            password: 密码
            email: 邮箱

        Returns:
            用户ID或None
        """
        password_hash = hashlib.sha256(password.encode()).hexdigest()

        with self._get_connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "INSERT INTO users (username, password_hash, email) VALUES (?, ?, ?)",
                    (username, password_hash, email)
                )
                conn.commit()
                return cursor.lastrowid
            except sqlite3.IntegrityError:
                return None

    def verify_user(
        self,
        username: str,
        password: str
    ) -> Optional[Dict[str, Any]]:
        """
        验证用户

        Args:
            username: 用户名
            password: 密码

        Returns:
            用户信息或None
        """
        password_hash = hashlib.sha256(password.encode()).hexdigest()

        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM users WHERE username = ? AND password_hash = ? AND is_active = 1",
                (username, password_hash)
            )
            row = cursor.fetchone()

            if row:
                # 更新最后登录时间
                cursor.execute(
                    "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?",
                    (row["id"],)
                )
                conn.commit()
                return dict(row)

            return None

    def get_user(self, user_id: int) -> Optional[Dict[str, Any]]:
        """获取用户信息"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
            row = cursor.fetchone()
            return dict(row) if row else None

    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        """根据用户名获取用户"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
            row = cursor.fetchone()
            return dict(row) if row else None

    # ==================== AI请求记录 ====================

    def insert_ai_request(
        self,
        request_id: str,
        user_id: Optional[int],
        endpoint: str,
        request_data: Dict[str, Any],
        response_data: Optional[Dict[str, Any]] = None,
        response_time: float = 0.0,
        success: bool = False,
        fallback_used: bool = False,
        error_message: Optional[str] = None
    ) -> int:
        """插入AI请求记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO ai_requests
                (request_id, user_id, endpoint, request_data, response_data,
                 response_time, success, fallback_used, error_message)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                request_id,
                user_id,
                endpoint,
                json.dumps(request_data),
                json.dumps(response_data) if response_data else None,
                response_time,
                success,
                fallback_used,
                error_message
            ))
            conn.commit()
            return cursor.lastrowid

    def get_ai_requests(
        self,
        user_id: Optional[int] = None,
        endpoint: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """获取AI请求记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            query = "SELECT * FROM ai_requests WHERE 1=1"
            params = []

            if user_id:
                query += " AND user_id = ?"
                params.append(user_id)

            if endpoint:
                query += " AND endpoint = ?"
                params.append(endpoint)

            query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
            params.extend([limit, offset])

            cursor.execute(query, params)
            rows = cursor.fetchall()
            return [self._row_to_dict(row) for row in rows]

    def get_ai_request_statistics(self) -> Dict[str, Any]:
        """获取AI请求统计"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 总请求数
            cursor.execute("SELECT COUNT(*) FROM ai_requests")
            total_count = cursor.fetchone()[0]

            # 成功请求数
            cursor.execute(
                "SELECT COUNT(*) FROM ai_requests WHERE success = 1"
            )
            success_count = cursor.fetchone()[0]

            # 降级请求数
            cursor.execute(
                "SELECT COUNT(*) FROM ai_requests WHERE fallback_used = 1"
            )
            fallback_count = cursor.fetchone()[0]

            # 各端点请求数
            cursor.execute("""
                SELECT endpoint, COUNT(*) as count
                FROM ai_requests
                GROUP BY endpoint
            """)
            endpoint_counts = {row[0]: row[1] for row in cursor.fetchall()}

            # 平均响应时间
            cursor.execute(
                "SELECT AVG(response_time) FROM ai_requests WHERE response_time > 0"
            )
            avg_time = cursor.fetchone()[0] or 0

            return {
                "total_requests": total_count,
                "success_requests": success_count,
                "failed_requests": total_count - success_count,
                "fallback_requests": fallback_count,
                "endpoint_counts": endpoint_counts,
                "average_response_time": round(avg_time, 3)
            }

    # ==================== 玩家数据 ====================

    def create_player_profile(self, user_id: int) -> Optional[int]:
        """创建玩家档案"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "INSERT INTO player_profiles (user_id) VALUES (?)",
                    (user_id,)
                )
                conn.commit()
                return cursor.lastrowid
            except sqlite3.IntegrityError:
                return None

    def get_player_profile(self, user_id: int) -> Optional[Dict[str, Any]]:
        """获取玩家档案"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM player_profiles WHERE user_id = ?",
                (user_id,)
            )
            row = cursor.fetchone()
            if row:
                data = dict(row)
                # 解析JSON字段
                for field in ["behavior_data", "upgrade_history", "event_history"]:
                    if data.get(field):
                        try:
                            data[field] = json.loads(data[field])
                        except json.JSONDecodeError:
                            pass
                return data
            return None

    def update_player_profile(
        self,
        user_id: int,
        **kwargs
    ) -> bool:
        """更新玩家档案"""
        if not kwargs:
            return False

        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 构建更新语句
            set_clauses = []
            params = []

            for key, value in kwargs.items():
                if key in ["level", "experience", "health", "attack", "defense", "gold"]:
                    set_clauses.append(f"{key} = ?")
                    params.append(value)
                elif key in ["behavior_data", "upgrade_history", "event_history"]:
                    set_clauses.append(f"{key} = ?")
                    params.append(json.dumps(value) if value else None)

            if not set_clauses:
                return False

            set_clauses.append("updated_at = CURRENT_TIMESTAMP")
            params.append(user_id)

            query = f"UPDATE player_profiles SET {', '.join(set_clauses)} WHERE user_id = ?"
            cursor.execute(query, params)
            conn.commit()

            return cursor.rowcount > 0

    # ==================== AI生成历史 ====================

    def insert_generation(
        self,
        request_type: str,
        request_data: Dict[str, Any],
        response_data: Optional[Dict[str, Any]] = None,
        quality_score: Optional[float] = None,
        client_id: Optional[str] = None,
        processing_time: Optional[float] = None,
        status: str = "success",
        error_message: Optional[str] = None
    ) -> int:
        """插入AI生成记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO ai_generation_history
                (request_type, request_data, response_data, quality_score,
                 client_id, processing_time, status, error_message)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                request_type,
                json.dumps(request_data),
                json.dumps(response_data) if response_data else None,
                quality_score,
                client_id,
                processing_time,
                status,
                error_message
            ))
            conn.commit()
            return cursor.lastrowid

    def get_generations(
        self,
        request_type: Optional[str] = None,
        client_id: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """获取生成记录列表"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            query = "SELECT * FROM ai_generation_history WHERE 1=1"
            params = []

            if request_type:
                query += " AND request_type = ?"
                params.append(request_type)

            if client_id:
                query += " AND client_id = ?"
                params.append(client_id)

            query += " ORDER BY create_time DESC LIMIT ? OFFSET ?"
            params.extend([limit, offset])

            cursor.execute(query, params)
            rows = cursor.fetchall()
            return [self._row_to_dict(row) for row in rows]

    def get_statistics(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 总请求数
            cursor.execute("SELECT COUNT(*) FROM ai_generation_history")
            total_count = cursor.fetchone()[0]

            # 成功请求数
            cursor.execute(
                "SELECT COUNT(*) FROM ai_generation_history WHERE status = 'success'"
            )
            success_count = cursor.fetchone()[0]

            # 各类型请求数
            cursor.execute("""
                SELECT request_type, COUNT(*) as count
                FROM ai_generation_history
                GROUP BY request_type
            """)
            type_counts = {row[0]: row[1] for row in cursor.fetchall()}

            # 平均质量评分
            cursor.execute(
                "SELECT AVG(quality_score) FROM ai_generation_history WHERE quality_score IS NOT NULL"
            )
            avg_quality = cursor.fetchone()[0] or 0

            # 平均处理时间
            cursor.execute(
                "SELECT AVG(processing_time) FROM ai_generation_history WHERE processing_time IS NOT NULL"
            )
            avg_time = cursor.fetchone()[0] or 0

            return {
                "total_requests": total_count,
                "success_requests": success_count,
                "failed_requests": total_count - success_count,
                "type_counts": type_counts,
                "average_quality_score": round(avg_quality, 2),
                "average_processing_time": round(avg_time, 3)
            }

    def cleanup_old_records(self, days: int = 30) -> int:
        """清理旧记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            cursor.execute("""
                DELETE FROM ai_generation_history
                WHERE create_time < datetime('now', ? || ' days')
            """, (f"-{days}",))
            deleted_count = cursor.rowcount

            cursor.execute("""
                DELETE FROM ai_requests
                WHERE created_at < datetime('now', ? || ' days')
            """, (f"-{days}",))
            deleted_count += cursor.rowcount

            conn.commit()
            return deleted_count

    def _row_to_dict(self, row: sqlite3.Row) -> Dict[str, Any]:
        """将数据库行转换为字典"""
        data = dict(row)

        # 解析JSON字段
        for field in ["request_data", "response_data", "behavior_data", "upgrade_history", "event_history"]:
            if data.get(field):
                try:
                    data[field] = json.loads(data[field])
                except json.JSONDecodeError:
                    pass

        return data


# 全局数据库实例
enhanced_db_manager = EnhancedDatabaseManager()
