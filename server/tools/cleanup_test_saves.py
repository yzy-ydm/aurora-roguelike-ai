"""
测试存档清理工具 (TASK-026)

清理指定用户的 game_saves 记录，用于:
- 集成测试运行前重置状态（保证"新槽位保存"走 404→POST 创建路径）
- 验收前把测试账号数据清空，让用户从干净状态开始验收

用法:
    cd server && venv/Scripts/python.exe tools/cleanup_test_saves.py [username] [slot]
    username 默认 test001; slot 可选(1-3)，不传清理该用户全部存档
"""

import os
import sys

import pymysql
from dotenv import load_dotenv

load_dotenv()

DB = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "aurora_game"),
    "charset": "utf8mb4",
}


def main() -> None:
    username = sys.argv[1] if len(sys.argv) > 1 else "test001"
    slot = int(sys.argv[2]) if len(sys.argv) > 2 else None

    conn = pymysql.connect(**DB)
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE username = %s", (username,))
            row = cur.fetchone()
            if not row:
                print(f"用户 {username} 不存在")
                return
            user_id = row[0]
            if slot is None:
                cur.execute("DELETE FROM game_saves WHERE user_id = %s", (user_id,))
                print(f"已删除用户 {username}(id={user_id}) 的全部存档")
            else:
                cur.execute(
                    "DELETE FROM game_saves WHERE user_id = %s AND slot_number = %s",
                    (user_id, slot),
                )
                print(f"已删除用户 {username}(id={user_id}) 槽位 {slot} 的存档")
        conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
