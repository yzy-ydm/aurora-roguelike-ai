"""
AI内容生成路由

提供Roguelike游戏内容生成API
集成认证、缓存、日志、数据库记录
"""

import time
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

# 导入服务
from services.ai_service import AIService

# 导入新模块
from security.auth import verify_api_key
from database.db_manager import db_manager
from cache.cache_manager import floor_cache, room_cache
from logger.logger import logger

# 创建路由器
router = APIRouter(tags=["AI内容生成"])

# 创建AI服务实例
ai_service = AIService()


# ==================== 请求模型 ====================

class FloorGenerateRequest(BaseModel):
    """楼层生成请求"""
    floor_level: int = Field(..., ge=1, le=100, description="楼层级别")
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")
    player_stats: Optional[Dict[str, Any]] = Field(None, description="玩家属性")

    class Config:
        json_schema_extra = {
            "example": {
                "floor_level": 1,
                "player_level": 1,
                "player_stats": {
                    "health": 100,
                    "attack": 10,
                    "defense": 5
                }
            }
        }


class RoomContentRequest(BaseModel):
    """房间内容生成请求"""
    room_id: int = Field(..., ge=0, description="房间ID")
    room_type: str = Field(..., description="房间类型")
    floor_level: int = Field(..., ge=1, le=100, description="楼层级别")
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")

    class Config:
        json_schema_extra = {
            "example": {
                "room_id": 1,
                "room_type": "combat",
                "floor_level": 1,
                "player_level": 1
            }
        }


class MonsterGenerateRequest(BaseModel):
    """怪物生成请求"""
    room_type: str = Field(..., description="房间类型")
    floor_level: int = Field(..., ge=1, le=100, description="楼层级别")
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")
    monster_count: Optional[int] = Field(None, ge=1, le=20, description="怪物数量")

    class Config:
        json_schema_extra = {
            "example": {
                "room_type": "combat",
                "floor_level": 1,
                "player_level": 1,
                "monster_count": 3
            }
        }


class WeaponGenerateRequest(BaseModel):
    """武器生成请求"""
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")
    rarity: Optional[str] = Field(None, description="稀有度")
    weapon_type: Optional[str] = Field(None, description="武器类型")

    class Config:
        json_schema_extra = {
            "example": {
                "player_level": 1,
                "rarity": "common",
                "weapon_type": "sword"
            }
        }


# ==================== 响应模型 ====================

class FloorResponse(BaseModel):
    """楼层生成响应"""
    floor: int
    player_level: int
    room_count: int
    rooms: List[Dict[str, Any]]
    ai_mode: str = "mock"
    from_cache: bool = False


class RoomContentResponse(BaseModel):
    """房间内容响应"""
    room_id: int
    room_type: str
    floor_level: int
    player_level: int
    difficulty: int
    monsters: List[Dict[str, Any]]
    rewards: Dict[str, Any]
    chests: int
    ai_mode: str = "mock"
    from_cache: bool = False


class MonsterResponse(BaseModel):
    """怪物生成响应"""
    monsters: List[Dict[str, Any]]
    total_count: int
    ai_mode: str = "mock"


class WeaponResponse(BaseModel):
    """武器生成响应"""
    weapon: Dict[str, Any]
    ai_mode: str = "mock"


# ==================== API路由 ====================

@router.post("/generate/floor", response_model=FloorResponse)
async def generate_floor(
    request: FloorGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成楼层内容

    根据楼层级别和玩家等级生成完整的楼层结构
    包含房间列表、连接关系、怪物配置等
    """
    start_time = time.time()

    try:
        # 检查缓存
        cached_data = floor_cache.get_floor(request.floor_level, request.player_level)
        if cached_data:
            logger.log_cache("get", "floor", f"{request.floor_level}:{request.player_level}", hit=True)
            return FloorResponse(**cached_data, from_cache=True)

        logger.log_cache("get", "floor", f"{request.floor_level}:{request.player_level}", hit=False)

        # 生成新内容
        result = await ai_service.generate_floor(
            floor_level=request.floor_level,
            player_level=request.player_level,
            player_stats=request.player_stats
        )

        # 设置缓存
        floor_cache.set_floor(request.floor_level, request.player_level, result)

        # 记录到数据库
        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="floor",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        # 记录日志
        logger.log_generation("floor", True, processing_time=processing_time)

        return FloorResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_floor")

        # 记录失败到数据库
        db_manager.insert_generation(
            request_type="floor",
            request_data=request.dict(),
            client_id=client_id,
            processing_time=processing_time,
            status="failed",
            error_message=str(e)
        )

        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate/room", response_model=RoomContentResponse)
async def generate_room_content(
    request: RoomContentRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成房间内容

    根据房间类型和难度生成房间内部内容
    包含怪物配置、奖励配置等
    """
    start_time = time.time()

    try:
        # 检查缓存
        cached_data = room_cache.get_room_content(
            request.room_id,
            request.room_type,
            request.floor_level,
            request.player_level
        )
        if cached_data:
            logger.log_cache("get", "room", f"{request.room_id}:{request.room_type}", hit=True)
            return RoomContentResponse(**cached_data, from_cache=True)

        logger.log_cache("get", "room", f"{request.room_id}:{request.room_type}", hit=False)

        # 生成新内容
        result = await ai_service.generate_room_content(
            room_id=request.room_id,
            room_type=request.room_type,
            floor_level=request.floor_level,
            player_level=request.player_level
        )

        # 设置缓存
        room_cache.set_room_content(
            request.room_id,
            request.room_type,
            request.floor_level,
            request.player_level,
            result
        )

        # 记录到数据库
        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="room",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        # 记录日志
        logger.log_generation("room", True, processing_time=processing_time)

        return RoomContentResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_room_content")

        # 记录失败到数据库
        db_manager.insert_generation(
            request_type="room",
            request_data=request.dict(),
            client_id=client_id,
            processing_time=processing_time,
            status="failed",
            error_message=str(e)
        )

        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate/monster", response_model=MonsterResponse)
async def generate_monsters(
    request: MonsterGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成怪物配置

    根据房间类型和难度生成怪物列表
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_monsters(
            room_type=request.room_type,
            floor_level=request.floor_level,
            player_level=request.player_level,
            monster_count=request.monster_count
        )

        # 记录到数据库
        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="monster",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        # 记录日志
        logger.log_generation("monster", True, processing_time=processing_time)

        return MonsterResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_monsters")

        # 记录失败到数据库
        db_manager.insert_generation(
            request_type="monster",
            request_data=request.dict(),
            client_id=client_id,
            processing_time=processing_time,
            status="failed",
            error_message=str(e)
        )

        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate/weapon", response_model=WeaponResponse)
async def generate_weapon(
    request: WeaponGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成武器配置

    根据玩家等级和稀有度生成武器数据
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_weapon(
            player_level=request.player_level,
            rarity=request.rarity,
            weapon_type=request.weapon_type
        )

        # 记录到数据库
        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="weapon",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        # 记录日志
        logger.log_generation("weapon", True, processing_time=processing_time)

        return WeaponResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_weapon")

        # 记录失败到数据库
        db_manager.insert_generation(
            request_type="weapon",
            request_data=request.dict(),
            client_id=client_id,
            processing_time=processing_time,
            status="failed",
            error_message=str(e)
        )

        raise HTTPException(status_code=500, detail=str(e))


@router.get("/generate/test")
async def test_generation():
    """
    测试生成接口（无需认证）

    快速测试AI生成功能
    """
    try:
        # 生成测试楼层
        floor_result = await ai_service.generate_floor(
            floor_level=1,
            player_level=1
        )

        # 生成测试房间内容
        room_result = await ai_service.generate_room_content(
            room_id=1,
            room_type="combat",
            floor_level=1,
            player_level=1
        )

        return {
            "status": "ok",
            "message": "AI生成测试成功",
            "floor_sample": floor_result,
            "room_sample": room_result,
            "ai_mode": "mock"
        }
    except Exception as e:
        logger.log_error(e, "test_generation")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/history")
async def get_generation_history(
    request_type: Optional[str] = None,
    limit: int = 50,
    client_id: str = Depends(verify_api_key)
):
    """
    获取生成历史

    Args:
        request_type: 请求类型过滤
        limit: 返回数量
    """
    try:
        records = db_manager.get_generations(
            request_type=request_type,
            client_id=client_id,
            limit=limit
        )

        return {
            "records": records,
            "total": len(records)
        }

    except Exception as e:
        logger.log_error(e, "get_generation_history")
        raise HTTPException(status_code=500, detail=str(e))
