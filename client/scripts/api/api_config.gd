## API配置模块
##
## 负责管理服务器地址和API端点配置
## 作为全局单例使用

extends Node

## ==================== 开发模式配置 ====================

## 开发模式开关
const DEV_MODE: bool = true

## Phase 21.3.1: 自动登录开关（与DEV_MODE分离）
## AUTO_LOGIN=true: 自动登录测试账号，跳过登录界面
## AUTO_LOGIN=false: 显示正常登录界面，但保留DEV_MODE的其他功能
const AUTO_LOGIN: bool = true

## Phase 21.4.1: 使用const确保默认值立即可用
## 环境变量可以覆盖这些值
const DEFAULT_DEV_USERNAME: String = "test001"
const DEFAULT_DEV_PASSWORD: String = "test123456"

## 开发模式测试账号（运行时从环境变量读取）
var DEV_USERNAME: String = DEFAULT_DEV_USERNAME
var DEV_PASSWORD: String = DEFAULT_DEV_PASSWORD

## 游戏服务器基础URL
const BASE_URL: String = "http://127.0.0.1:8000"

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
const AI_GENERATE_EVENT: String = "/api/generate/event"
const AI_GENERATE_DIALOGUE: String = "/api/generate/dialogue"
const AI_GENERATE_UPGRADE: String = "/api/generate/upgrade"
const AI_GENERATE_DIFFICULTY: String = "/api/generate/difficulty"
const AI_GENERATE_ROOM_STRATEGY: String = "/api/generate/room_strategy"
const AI_GENERATE_NPC_MEMORY: String = "/api/generate/npc_memory"
const AI_GENERATE_CONTEXT_EVENT: String = "/api/generate/context_event"
const AI_HEALTH: String = "/health"

## 初始化
func _ready() -> void:
	# 从环境变量读取开发模式配置
	DEV_USERNAME = OS.get_environment("AURORA_DEV_USER")
	DEV_PASSWORD = OS.get_environment("AURORA_DEV_PASS")

	# Phase 21.2.1: 使用固定测试账号test001
	if DEV_USERNAME.is_empty():
		DEV_USERNAME = "test001"
	if DEV_PASSWORD.is_empty():
		DEV_PASSWORD = "test123456"

	if DEV_MODE:
		print("[APIConfig] DEV MODE enabled, username: ", DEV_USERNAME)


## 获取游戏服务器完整URL
func get_full_url(endpoint: String) -> String:
	return BASE_URL + endpoint


## 获取AI服务端完整URL
func get_ai_url(endpoint: String) -> String:
	return AI_BASE_URL + endpoint
