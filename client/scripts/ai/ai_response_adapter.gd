## AI响应适配层 (TASK-023)
##
## AI 服务返回的 JSON（JSON.parse 后为未类型化 Variant）到 Godot 强类型的统一转换层。
## 所有 AI 响应字段的转换必须经过本层，禁止在业务代码中直接传递未类型化 Array。
##
## 原则:
## - 保持 Godot 4 强类型安全（返回类型化数组/字典）
## - 禁止强制 cast（逐项类型验证，非法项跳过）
## - 禁止降低类型声明

class_name AIResponseAdapter
extends RefCounted


## JSON Array → Array[String]
## 逐项验证类型，非法项（非 String）跳过；非 Array 输入返回空数组
static func to_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for item in raw:
			if item is String:
				result.append(item)
	return result


## JSON Array → Array[Dictionary]
## 逐项验证类型，非法项（非 Dictionary）跳过；非 Array 输入返回空数组
static func to_dictionary_array(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				result.append(item)
	return result


## Variant → Dictionary
## 非 Dictionary 输入返回空字典（防御 AI 返回非对象结构）
static func to_safe_dictionary(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw
	return {}


## Variant → float
## 接受 int/float/数字字符串；其他类型或解析失败返回默认值
static func to_float(raw: Variant, default_value: float = 0.0) -> float:
	if raw is float:
		return raw
	if raw is int:
		return float(raw)
	if raw is String and raw.is_valid_float():
		return raw.to_float()
	return default_value


## Variant → int
## 接受 int/float（截断）/数字字符串；其他类型或解析失败返回默认值
static func to_int(raw: Variant, default_value: int = 0) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and raw.is_valid_int():
		return raw.to_int()
	return default_value
