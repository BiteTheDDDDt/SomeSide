class_name SideStageLayouts
extends RefCounted

## Deliberately authored topologies. Every rectangle is a real reachable
## one-way surface; tall visual scenery belongs to the renderer only.
static func build(stage: int) -> Dictionary:
	match stage:
		2: return _canyon()
		3: return _ruins()
		_: return _rainforest()

static func _base(size: Vector2, spawn_x: float, title: String, biome: String) -> Dictionary:
	var floor_y: float = size.y - 80.0
	return {"world_size": size, "floor_y": floor_y, "spawn": Vector2(spawn_x, floor_y - 21.0),
		"stage_name": title, "biome": biome, "platforms": [Rect2(0.0, floor_y, size.x, 80.0)],
		"gate": Vector2.ZERO, "landmarks": [], "facility_sites": []}

static func _surface(layout: Dictionary, x: float, y: float, width: float) -> int:
	var platforms: Array = layout["platforms"]
	platforms.append(Rect2(x, y, width, 28.0))
	return platforms.size() - 1

static func _stairs(layout: Dictionary, start: Vector2, count: int, horizontal: float, vertical: float = -90.0, width: float = 380.0) -> Array:
	var indices: Array = []
	for index in range(count):
		indices.append(_surface(layout, start.x + index * horizontal, start.y + index * vertical, width))
	return indices

static func _mark(layout: Dictionary, position: Vector2, title: String, kind: String, scale: float = 1.0) -> void:
	layout["landmarks"].append({"pos": position, "name": title, "kind": kind, "style": kind, "scale": scale})

static func _site(layout: Dictionary, platform_index: int, type: String, offset: float = 0.0) -> void:
	var platform: Rect2 = layout["platforms"][platform_index]
	layout["facility_sites"].append({"pos": Vector2(platform.get_center().x + offset, platform.position.y - 17.0), "type": type})

static func _facilities(layout: Dictionary, anchors: Array) -> void:
	# 18 interactables: six caches, two three-choice groups, two sacrifice
	# altars, two explicit trials and two equipment vaults.
	layout["facility_sites"].append({"pos": Vector2(Vector2(layout["spawn"]).x + 225.0, float(layout["floor_y"]) - 17.0), "type": "cache", "starter": true})
	for index in [0, 2, 5, 8, 11]:
		_site(layout, int(anchors[index]), "cache")
	for index in [1, 7]:
		_site(layout, int(anchors[index]), "blood")
	for index in [3, 9]:
		_site(layout, int(anchors[index]), "combat")
	for index in [4, 10]:
		_site(layout, int(anchors[index]), "equipment")
	for choice_index in [6, 12]:
		for offset in [-112.0, 0.0, 112.0]:
			_site(layout, int(anchors[choice_index]), "choice", offset)
			layout["facility_sites"].back()["group"] = choice_index

static func _rainforest() -> Dictionary:
	var layout: Dictionary = _base(Vector2(7200, 1900), 220.0, "巨木雨林", "rainforest")
	var roots: Array = _stairs(layout, Vector2(350, 1730), 8, 200.0)
	var low_canopy: int = _surface(layout, 950, 1100, 950)
	var bridge: int = _surface(layout, 1870, 1100, 1250)
	var lookout: Array = _stairs(layout, Vector2(980, 1010), 4, -150.0)
	var nest: int = _surface(layout, 260, 740, 620)
	var valley_steps: Array = _stairs(layout, Vector2(3090, 1190), 3, 220.0, 90.0)
	var lagoon: int = _surface(layout, 3650, 1370, 1000)
	var sunward: Array = _stairs(layout, Vector2(2800, 1010), 6, 220.0)
	var observatory: int = _surface(layout, 4020, 560, 800)
	var canopy_return: int = _surface(layout, 4770, 650, 540)
	var return_lower: int = _surface(layout, 5260, 740, 500)
	var crown_steps: Array = _stairs(layout, Vector2(4510, 1280), 6, 190.0)
	var crown: int = _surface(layout, 5720, 830, 1250)
	var fern_steps: Array = _stairs(layout, Vector2(3250, 1730), 4, 190.0)
	# The lower loop reaches the lagoon without forcing the upper canopy.
	var fern_shelf: int = _surface(layout, 3820, 1460, 680)
	var east_roots: Array = _stairs(layout, Vector2(5350, 1730), 6, 170.0)
	var east_den: int = _surface(layout, 6200, 1280, 650)
	layout["gate"] = Vector2(6680, 780)
	_mark(layout, Vector2(1700, 1370), "空心巨木", "hollow_tree", 1.8)
	_mark(layout, Vector2(3580, 1680), "银雾瀑布", "waterfall", 1.7)
	_mark(layout, Vector2(4450, 550), "树冠观测台", "observatory", 1.4)
	_mark(layout, Vector2(6460, 1060), "共鸣花冠", "crown", 1.9)
	_facilities(layout, [roots[3], low_canopy, nest, bridge, sunward[3], observatory,
		lagoon, crown_steps[2], canopy_return, crown, east_den, fern_shelf, return_lower])
	return layout

static func _canyon() -> Dictionary:
	var layout: Dictionary = _base(Vector2(5600, 2800), 420.0, "折光断崖", "canyon")
	var landing: int = _surface(layout, 280, 2630, 900)
	var first: Array = _stairs(layout, Vector2(1050, 2540), 7, 230.0)
	var lower_station: int = _surface(layout, 2380, 2000, 900)
	var reverse: Array = _stairs(layout, Vector2(2200, 1910), 7, -230.0)
	var west_station: int = _surface(layout, 500, 1370, 950)
	var final_ascent: Array = _stairs(layout, Vector2(1330, 1280), 8, 220.0)
	var sky_bridge: int = _surface(layout, 2870, 650, 1000)
	var peak_steps: Array = _stairs(layout, Vector2(3770, 560), 2, 240.0)
	var summit: int = _surface(layout, 4300, 470, 1000)
	var east_cave_path: Array = _stairs(layout, Vector2(3250, 1910), 4, 230.0)
	var east_cave: int = _surface(layout, 4090, 1640, 1000)
	var west_spire_path: Array = _stairs(layout, Vector2(340, 1280), 3, -130.0)
	var west_spire: int = _surface(layout, 20, 1100, 450)
	var quarry_steps: Array = _stairs(layout, Vector2(3500, 2630), 5, 230.0)
	var quarry: int = _surface(layout, 4420, 2270, 900)
	layout["gate"] = Vector2(4930, 420)
	_mark(layout, Vector2(1710, 2360), "废弃升降井", "elevator", 1.7)
	_mark(layout, Vector2(2710, 1780), "回声裂谷", "chasm", 2.1)
	_mark(layout, Vector2(560, 1200), "风蚀方尖碑", "obelisk", 1.3)
	_mark(layout, Vector2(4730, 1690), "蓝晶矿洞", "crystal_cave", 1.8)
	_mark(layout, Vector2(4800, 500), "风暴灯塔", "beacon", 1.6)
	_facilities(layout, [landing, first[3], reverse[2], lower_station, east_cave_path[2], east_cave,
		west_station, west_spire, final_ascent[4], sky_bridge, summit, quarry, quarry_steps[2]])
	return layout

static func _ruins() -> Dictionary:
	var layout: Dictionary = _base(Vector2(8400, 2300), 4200.0, "双环遗迹", "ruins")
	var hub: int = _surface(layout, 3760, 2130, 880)
	var left_arm: Array = _stairs(layout, Vector2(3540, 2040), 8, -220.0)
	var west_hall: int = _surface(layout, 830, 1410, 1500)
	var west_tower: Array = _stairs(layout, Vector2(1110, 1320), 6, 200.0)
	var west_gallery: int = _surface(layout, 2100, 870, 1600)
	var inner_ascent: Array = _stairs(layout, Vector2(3580, 780), 3, 265.0, -90.0, 440.0)
	var crown: int = _surface(layout, 3920, 600, 1120)
	var right_arm: Array = _stairs(layout, Vector2(4600, 2040), 7, 220.0)
	var east_hall: int = _surface(layout, 6020, 1500, 1800)
	var east_tower: Array = _stairs(layout, Vector2(7260, 1410), 6, -200.0)
	var east_gallery: int = _surface(layout, 5000, 960, 1650)
	var east_return: Array = _stairs(layout, Vector2(5050, 870), 3, -230.0)
	var lower_ring: int = _surface(layout, 3650, 1950, 1100)
	var west_crossing: int = _surface(layout, 2980, 1680, 1120)
	var east_crossing: int = _surface(layout, 4060, 1680, 1480)
	var middle_ring: int = _surface(layout, 3740, 1320, 1200)
	var west_crypt_path: Array = _stairs(layout, Vector2(700, 2130), 4, 230.0)
	var west_crypt: int = _surface(layout, 500, 1860, 1080)
	var east_crypt_path: Array = _stairs(layout, Vector2(6500, 2130), 4, 230.0)
	var east_crypt: int = _surface(layout, 7160, 1860, 850)
	layout["gate"] = Vector2(4440, 550)
	_mark(layout, Vector2(4180, 1760), "沉睡的共鸣环", "resonance_ring", 2.2)
	_mark(layout, Vector2(1520, 1510), "西翼记忆大厅", "archive", 1.8)
	_mark(layout, Vector2(7000, 1540), "东翼反应炉", "reactor", 1.9)
	_mark(layout, Vector2(1010, 2080), "埋藏墓室", "crypt", 1.4)
	_mark(layout, Vector2(4450, 680), "双环之心", "core", 2.0)
	_facilities(layout, [hub, left_arm[3], west_hall, east_hall, west_tower[3], west_gallery,
		lower_ring, right_arm[3], east_gallery, crown, east_crypt, west_crypt, middle_ring])
	return layout
