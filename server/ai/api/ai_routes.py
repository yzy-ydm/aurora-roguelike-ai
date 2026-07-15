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
from cache.cache_manager import floor_cache, room_cache, monster_cache, weapon_cache
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


class EventGenerateRequest(BaseModel):
    """事件生成请求"""
    room_type: str = Field(..., description="房间类型")
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")
    context: Optional[Dict[str, Any]] = Field(None, description="上下文信息")

    class Config:
        json_schema_extra = {
            "example": {
                "room_type": "combat",
                "player_level": 1,
                "context": {"room_id": 1}
            }
        }


class DialogueGenerateRequest(BaseModel):
    """对话生成请求"""
    npc_type: str = Field(..., description="NPC类型")
    room_environment: str = Field(..., description="房间环境")
    player_state: Optional[Dict[str, Any]] = Field(None, description="玩家状态")

    class Config:
        json_schema_extra = {
            "example": {
                "npc_type": "merchant",
                "room_environment": "shop",
                "player_state": {"health": 80, "gold": 100}
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


class EventResponse(BaseModel):
    """事件生成响应"""
    title: str
    description: str
    choices: List[Dict[str, Any]]
    ai_mode: str = "mock"


class DialogueResponse(BaseModel):
    """对话生成响应"""
    dialogue: List[str]
    ai_mode: str = "mock"


class UpgradeGenerateRequest(BaseModel):
    """升级强化生成请求"""
    player_level: int = Field(..., ge=1, le=100, description="玩家等级")
    player_stats: Optional[Dict[str, Any]] = Field(None, description="玩家属性")

    class Config:
        json_schema_extra = {
            "example": {
                "player_level": 5,
                "player_stats": {
                    "health": 150,
                    "attack": 20,
                    "defense": 10
                }
            }
        }


class UpgradeResponse(BaseModel):
    """升级强化生成响应"""
    upgrades: List[Dict[str, Any]]
    ai_mode: str = "mock"


class DifficultyGenerateRequest(BaseModel):
    """难度调整生成请求"""
    context: Optional[Dict[str, Any]] = Field(None, description="游戏上下文")

    class Config:
        json_schema_extra = {
            "example": {
                "context": {
                    "player_level": 5,
                    "combat_style": "balanced",
                    "death_rate": 1.5,
                    "damage_rate": 3.0
                }
            }
        }


class DifficultyResponse(BaseModel):
    """难度调整生成响应"""
    enemy_hp_multiplier: float = 1.0
    enemy_damage_multiplier: float = 1.0
    elite_spawn_rate: float = 0.1
    reward_multiplier: float = 1.0
    ai_mode: str = "mock"


class RoomStrategyGenerateRequest(BaseModel):
    """房间策略生成请求"""
    context: Optional[Dict[str, Any]] = Field(None, description="游戏上下文")

    class Config:
        json_schema_extra = {
            "example": {
                "context": {
                    "player_level": 5,
                    "combat_style": "aggressive",
                    "upgrade_preference": "attack",
                    "current_health_percent": 0.8
                }
            }
        }


class RoomStrategyResponse(BaseModel):
    """房间策略生成响应"""
    preferred_room_types: List[str]
    avoid_room_types: List[str]
    recommended_difficulty: str = "normal"
    ai_mode: str = "mock"


class NPCMemoryGenerateRequest(BaseModel):
    """NPC记忆生成请求"""
    npc_id: str = Field(..., description="NPC ID")
    context: Optional[Dict[str, Any]] = Field(None, description="NPC记忆上下文")

    class Config:
        json_schema_extra = {
            "example": {
                "npc_id": "merchant_001",
                "context": {
                    "interaction_count": 3,
                    "relationship": 0.5,
                    "player_choices": ["帮助", "购买物品"]
                }
            }
        }


class NPCMemoryResponse(BaseModel):
    """NPC记忆生成响应"""
    dialogue: List[str]
    interaction_count: int = 0
    relationship: float = 0.0
    ai_mode: str = "mock"


class ContextEventGenerateRequest(BaseModel):
    """上下文事件生成请求"""
    context: Optional[Dict[str, Any]] = Field(None, description="游戏上下文")

    class Config:
        json_schema_extra = {
            "example": {
                "context": {
                    "player_level": 5,
                    "combat_style": "expert",
                    "upgrade_preference": "attack",
                    "current_health_percent": 0.9
                }
            }
        }


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


@router.post("/generate/event", response_model=EventResponse)
async def generate_event(
    request: EventGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成房间事件

    根据房间类型和玩家等级生成随机事件
    包含事件标题、描述、选项
    """
    start_time = time.time()

    try:
        # 生成事件
        result = await ai_service.generate_event(
            room_type=request.room_type,
            player_level=request.player_level,
            context=request.context
        )

        # 记录到数据库
        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="event",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("event", True, processing_time=processing_time)

        return EventResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_event")

        db_manager.insert_generation(
            request_type="event",
            request_data=request.dict(),
            response_data={},
            client_id=client_id,
            processing_time=processing_time,
            status="failed",
            error_message=str(e)
        )

        # 返回mock数据作为fallback
        return EventResponse(
            title="神秘事件",
            description="你遇到了一个奇怪的情况。",
            choices=[
                {"text": "探索", "reward": {"gold": 20}, "risk": {}},
                {"text": "离开", "reward": {}, "risk": {}}
            ],
            ai_mode="mock_fallback"
        )


@router.post("/generate/dialogue", response_model=DialogueResponse)
async def generate_dialogue(
    request: DialogueGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成NPC对话

    根据NPC类型和环境生成动态对话
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_dialogue(
            npc_type=request.npc_type,
            room_environment=request.room_environment,
            player_state=request.player_state
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="dialogue",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("dialogue", True, processing_time=processing_time)

        return DialogueResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_dialogue")

        # 返回mock数据作为fallback
        return DialogueResponse(
            dialogue=["...", "你好，旅行者。"],
            ai_mode="mock_fallback"
        )


@router.post("/generate/upgrade", response_model=UpgradeResponse)
async def generate_upgrade(
    request: UpgradeGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成升级强化选项

    根据玩家等级和属性生成个性化的强化选项
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_upgrade(
            player_level=request.player_level,
            player_stats=request.player_stats
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="upgrade",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("upgrade", True, processing_time=processing_time)

        return UpgradeResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_upgrade")

        # 返回mock数据作为fallback
        return UpgradeResponse(
            upgrades=[
                {
                    "id": "mock_attack",
                    "name": "攻击强化",
                    "description": "攻击力 +10",
                    "type": "stat_boost",
                    "rarity": "common",
                    "modifiers": {"attack": 10},
                    "percent_modifiers": {}
                },
                {
                    "id": "mock_health",
                    "name": "生命强化",
                    "description": "最大生命 +30",
                    "type": "stat_boost",
                    "rarity": "common",
                    "modifiers": {"max_health": 30},
                    "percent_modifiers": {}
                },
                {
                    "id": "mock_speed",
                    "name": "速度强化",
                    "description": "移动速度 +15%",
                    "type": "stat_boost",
                    "rarity": "uncommon",
                    "modifiers": {},
                    "percent_modifiers": {"move_speed": 0.15}
                }
            ],
            ai_mode="mock_fallback"
        )


@router.post("/generate/difficulty", response_model=DifficultyResponse)
async def generate_difficulty(
    request: DifficultyGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成难度调整建议

    根据玩家行为数据动态调整游戏难度
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_difficulty(
            context=request.context
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="difficulty",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("difficulty", True, processing_time=processing_time)

        return DifficultyResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_difficulty")

        return DifficultyResponse(
            enemy_hp_multiplier=1.0,
            enemy_damage_multiplier=1.0,
            elite_spawn_rate=0.1,
            reward_multiplier=1.0,
            ai_mode="mock_fallback"
        )


@router.post("/generate/room_strategy", response_model=RoomStrategyResponse)
async def generate_room_strategy(
    request: RoomStrategyGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成房间策略建议

    根据玩家状态推荐房间组合
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_room_strategy(
            context=request.context
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="room_strategy",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("room_strategy", True, processing_time=processing_time)

        return RoomStrategyResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_room_strategy")

        return RoomStrategyResponse(
            preferred_room_types=["combat", "reward", "event"],
            avoid_room_types=[],
            recommended_difficulty="normal",
            ai_mode="mock_fallback"
        )


@router.post("/generate/npc_memory", response_model=NPCMemoryResponse)
async def generate_npc_memory(
    request: NPCMemoryGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成NPC记忆响应

    根据NPC记忆生成个性化对话
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_npc_memory(
            npc_id=request.npc_id,
            context=request.context
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="npc_memory",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("npc_memory", True, processing_time=processing_time)

        return NPCMemoryResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_npc_memory")

        return NPCMemoryResponse(
            dialogue=["你好，旅行者。"],
            interaction_count=0,
            relationship=0.0,
            ai_mode="mock_fallback"
        )


@router.post("/generate/context_event", response_model=EventResponse)
async def generate_context_event(
    request: ContextEventGenerateRequest,
    client_id: str = Depends(verify_api_key)
):
    """
    生成上下文事件

    根据玩家状态和历史生成个性化事件
    """
    start_time = time.time()

    try:
        result = await ai_service.generate_context_event(
            context=request.context
        )

        processing_time = time.time() - start_time
        db_manager.insert_generation(
            request_type="context_event",
            request_data=request.dict(),
            response_data=result,
            client_id=client_id,
            processing_time=processing_time,
            status="success"
        )

        logger.log_generation("context_event", True, processing_time=processing_time)

        return EventResponse(**result)

    except Exception as e:
        processing_time = time.time() - start_time
        logger.log_error(e, "generate_context_event")

        return EventResponse(
            title="神秘事件",
            description="你遇到了一个奇怪的情况。",
            choices=[
                {"text": "探索", "reward": {"gold": 20}, "risk": {}},
                {"text": "离开", "reward": {}, "risk": {}}
            ],
            ai_mode="mock_fallback"
        )


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
