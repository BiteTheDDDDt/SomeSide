class_name SideChestRules
extends RefCounted
const TIERS: Array[String]=["small","medium","large"]
static func tier(chest: Dictionary) -> String:
	var value: String=str(chest.get("tier","small"))
	return value if value in TIERS else "small"
static func label(chest: Dictionary) -> String:
	match str(chest.get("type","cache")):
		"choice": return "三选一商店"
		"blood": return "生命献祭"
		"combat": return "试炼信标"
		"equipment": return "装备仓"
	return {"small":"小型补给箱","medium":"中型补给箱","large":"大型补给箱"}[tier(chest)]
static func weights(value: String, stage: int) -> Array:
	var step: int=clampi(stage,1,3)-1
	if value=="large": return [12.0-step*3,35.0-step*2,40.0+step*2,13.0+step*3]
	if value=="medium": return [40.0-step*6,34.0+step,21.0+step*3,5.0+step*2]
	return [65.0-step*11,26.0+step*4,8.0+step*5,1.0+step*2]
