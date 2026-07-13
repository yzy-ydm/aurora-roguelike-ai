"""
数据库管理模块

使用SQLite存储AI生成记录
"""

import sqlite3
import json
import os
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import contextmanager


# 数据库路径
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "ai_generations.db")


class DatabaseManager:
    """数据库管理器"""

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
                CREATE INDEX IF NOT EXISTS idx_request_type
                ON ai_generation_history(request_type)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_create_time
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
        """
        插入AI生成记录

        Args:
            request_type: 请求类型（floor/room/monster/weapon）
            request_data: 请求数据
            response_data: 响应数据
            quality_score: 质量评分
            client_id: 客户端ID
            processing_time: 处理时间（秒）
            status: 状态（success/failed）
            error_message: 错误信息

        Returns:
            记录ID
        """
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

    def get_generation(self, record_id: int) -> Optional[Dict[str, Any]]:
        """
        获取生成记录

        Args:
            record_id: 记录ID

        Returns:
            记录数据
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()

            cursor.execute(
                "SELECT * FROM ai_generation_history WHERE id = ?",
                (record_id,)
            )

            row = cursor.fetchone()
            if row:
                return self._row_to_dict(row)
            return None

    def get_generations(
        self,
        request_type: Optional[str] = None,
        client_id: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        获取生成记录列表

        Args:
            request_type: 请求类型过滤
            client_id: 客户端ID过滤
            limit: 返回数量限制
            offset: 偏移量

        Returns:
            记录列表
        """
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
        """
        获取统计信息

        Returns:
            统计数据
        """
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
        """
        清理旧记录

        Args:
            days: 保留天数

        Returns:
            删除的记录数
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()

            cursor.execute("""
                DELETE FROM ai_generation_history
                WHERE create_time < datetime('now', ? || ' days')
            """, (f"-{days}",))

            deleted_count = cursor.rowcount
            conn.commit()

            return deleted_count

    def _row_to_dict(self, row: sqlite3.Row) -> Dict[str, Any]:
        """将数据库行转换为字典"""
        data = dict(row)

        # 解析JSON字段
        if data.get("request_data"):
            try:
                data["request_data"] = json.loads(data["request_data"])
            except json.JSONDecodeError:
                pass

        if data.get("response_data"):
            try:
                data["response_data"] = json.loads(data["response_data"])
            except json.JSONDecodeError:
                pass

        return data


# 全局数据库实例
db_manager = DatabaseManager()
