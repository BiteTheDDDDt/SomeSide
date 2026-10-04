class_name SideEnemyCatalog
extends RefCounted

static func catalog() -> Array:
	return [
		_entry("crawler", "棘背跃兽", "rainforest", "pounce", 36.0, 19.0, 116.0, 250.0, 0.65, 2.8, false, "d3a96c"),
		_entry("spitter", "囊毒喷吐者", "rainforest", "spit", 48.0, 21.0, 78.0, 650.0, 0.75, 2.8, false, "b8d878"),
		_entry("spore_moth", "孢尘夜蛾", "rainforest", "mortar", 30.0, 19.0, 120.0, 610.0, 0.9, 3.5, true, "df9ec8"),
		_entry("drone", "晶翼巡猎者", "canyon", "triple", 28.0, 18.0, 135.0, 600.0, 0.75, 3.0, true, "89d3eb"),
		_entry("charger", "赤岩冲锋兽", "canyon", "charge", 64.0, 24.0, 96.0, 420.0, 0.8, 3.8, false, "e68b63"),
		_entry("burrower", "砂脊潜伏者", "canyon", "burrow", 46.0, 21.0, 64.0, 540.0, 0.9, 4.3, false, "d4b683"),
		_entry("sentinel", "棱镜哨卫", "ruins", "beam", 58.0, 23.0, 55.0, 740.0, 0.9, 3.4, false, "a4c3fa"),
		_entry("skirmisher", "折跃猎手", "ruins", "blink", 42.0, 20.0, 102.0, 620.0, 0.7, 4.2, false, "bf9be7"),
		_entry("conductor", "修复导引者", "ruins", "mend", 52.0, 22.0, 88.0, 620.0, 0.85, 4.0, true, "8ed8b7"),
	]

static func _entry(id: String, title: String, biome: String, attack: String, hp: float, radius: float, speed: float, reach: float, windup: float, cooldown: float, flying: bool, color: String) -> Dictionary:
	return {"id": id, "name": title, "biome": biome, "attack_kind": attack, "health": hp, "radius": radius,
		"speed": speed, "range": reach, "windup": windup, "cooldown": cooldown, "flying": flying, "color": Color(color)}

static func definition(id: String) -> Dictionary:
	for record in catalog():
		if str(record.id) == id:
			return record
	return {}

static func pool(biome: String) -> Array[String]:
	match biome:
		"canyon": return ["charger", "burrower", "drone"]
		"ruins": return ["sentinel", "skirmisher", "conductor"]
		_: return ["crawler", "spitter", "spore_moth"]

static func flying_kind(biome: String) -> String:
	match biome:
		"canyon": return "drone"
		"ruins": return "conductor"
		_: return "spore_moth"

static func boss_definition(biome: String) -> Dictionary:
	match biome:
		"canyon": return {"id": "boss", "name": "裂岩巨像", "boss_style": "stone", "biome": "canyon", "health": 960.0, "radius": 44.0, "flying": false, "color": Color("edaa70")}
		"ruins": return {"id": "boss", "name": "寂光执政官", "boss_style": "prism", "biome": "ruins", "health": 1220.0, "radius": 44.0, "flying": true, "color": Color("b6b9fa")}
		_: return {"id": "boss", "name": "孢冠母巢", "boss_style": "spore", "biome": "rainforest", "health": 700.0, "radius": 44.0, "flying": true, "color": Color("c8db94")}
