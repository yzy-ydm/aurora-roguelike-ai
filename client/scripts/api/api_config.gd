## API配置模块
##
## 负责管理服务器地址和API端点配置
## 作为全局单例使用

extends Node

## 游戏服务器基础URL
const BASE_URL: String = "http://localhost:8000"

## AI内容生成服务器基础URL
const AI_BASE_URL: String = "http://localhost:8001"

## 游戏服务器API端点常量
const AUTH_REGISTER: String = "/api/auth/register"
const AUTH_LOGIN: String = "/api/auth/login"
const PLAYER_PROFILE: String = "/api/player/profile"
const WEAPONS_LIST: String = "/api/weapons"
const PLAYER_WEAPONS: String = "/api/player/weapons"
const MONSTERS_LIST: String = "/api/monsters"
const MAPS_LIST: String = "/api/maps"
const EVENTS_LIST: String = "/api/events"
const GAME_SAVE: String = "/api/game/save"

## AI服务端API端点常量
const AI_AUTH_TOKEN: String = "/api/auth/token"
const AI_GENERATE_FLOOR: String = "/api/generate/floor"
const AI_GENERATE_ROOM: String = "/api/generate/room"
const AI_GENERATE_MONSTER: String = "/api/generate/monster"
const AI_GENERATE_WEAPON: String = "/api/generate/weapon"
const AI_HEALTH: String = "/health"

## 获取游戏服务器完整URL
func get_full_url(endpoint: String) -> String:
	return BASE_URL + endpoint


## 获取AI服务端完整URL
func get_ai_url(endpoint: String) -> String:
	return AI_BASE_URL + endpoint
