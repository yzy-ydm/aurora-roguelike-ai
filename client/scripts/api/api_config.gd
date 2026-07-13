## API配置模块
##
## 负责管理服务器地址和API端点配置
## 作为全局单例使用

extends Node

## 服务器基础URL
const BASE_URL: String = "http://localhost:8000"

## API端点常量
const AUTH_REGISTER: String = "/api/auth/register"
const AUTH_LOGIN: String = "/api/auth/login"
const PLAYER_PROFILE: String = "/api/player/profile"
const WEAPONS_LIST: String = "/api/weapons"
const MONSTERS_LIST: String = "/api/monsters"
const MAPS_LIST: String = "/api/maps"
const EVENTS_LIST: String = "/api/events"
const GAME_SAVE: String = "/api/game/save"

## 获取完整URL
func get_full_url(endpoint: String) -> String:
	return BASE_URL + endpoint
