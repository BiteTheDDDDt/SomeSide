class_name SidePlayerAppearance
extends RefCounted

const Content = preload("res://scripts/content.gd")
const Icons = preload("res://scripts/item_icons.gd")
const MAX_SLOTS: int = 6
const MAX_SCALE: float = 1.12
const MAX_BRIGHTNESS: float = 1.2
const SLOTS: Array[String] = ["back", "shoulder", "chest", "head", "belt", "legs"]
const ITEMS: Dictionary = {
	"feather":"back", "thruster":"back", "phoenix":"back",
	"arc":"shoulder", "echo":"shoulder", "nova":"shoulder", "capacitor":"shoulder",
	"vitality":"chest", "battery":"chest", "glass":"chest", "resonator":"chest",
	"lens":"head", "overclock":"head", "frost":"head", "toxin":"head",
	"coolant":"belt", "ember":"belt", "siphon":"belt", "harvest":"belt", "magnet":"belt",
	"plating":"legs", "moss":"legs", "momentum":"legs", "piercer":"legs",
	"missile_pod":"shoulder", "landing_coil":"legs", "frost_halo":"chest",
}
const INK: Color = Color("424e55")
const WHITE: Color = Color("edf4dc")
static var _definitions: Dictionary = {}

static func _definition(id: String) -> Dictionary:
	if _definitions.is_empty():
		for definition: Dictionary in Content.passives():
			_definitions[str(definition.id)] = definition
	return _definitions.get(id, {})

static func supported_items() -> Dictionary:
	return ITEMS.duplicate()

static func build(items: Dictionary, dead: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if dead:
		return result
	for slot: String in SLOTS:
		var selected: String = ""
		var best_rank: int = -1
		var best_count: int = -1
		for id: String in ITEMS:
			var count: int = maxi(0, int(items.get(id, 0)))
			if str(ITEMS[id]) != slot or count == 0:
				continue
			var rank: int = Content.rarity_rank(str(_definition(id).get("rarity", "common")))
			# Insertion order breaks ties, independent of inventory insertion order.
			if rank > best_rank or (rank == best_rank and count > best_count):
				selected = id
				best_rank = rank
				best_count = count
		if selected.is_empty():
			continue
		var tier: int = 3 if best_count >= 8 else (2 if best_count >= 4 else 1)
		result.append({"slot":slot, "item":selected, "stacks":best_count, "tier":tier,
			"scale":1.0 + (tier - 1) * 0.06, "brightness":1.0 + (tier - 1) * 0.1})
	return result

## Pixel equipment is baked once per item/tier. No canvas filter, player data,
## or animation clock is changed while drawing; six slots cost six texture draws.
const BAKE_SIZE: int = 64
const BAKE_ORIGIN: int = 32
const STEEL: Color = Color("718388")
const STEEL_LIGHT: Color = Color("b0b9aa")
const RUBBER: Color = Color("23343a")
const COPPER: Color = Color("947058")
static var _pieces: Dictionary = {}

static func draw_layer(canvas: Node2D, appearance: Array[Dictionary], behind: bool, _clock: float) -> void:
	for entry: Dictionary in appearance:
		if (str(entry.slot) == "back") != behind:
			continue
		var piece: Dictionary = _piece(entry)
		if not piece.is_empty():
			canvas.draw_texture(piece.texture, piece.origin)

static func cache_stats() -> Dictionary:
	var bytes: int = 0
	for value: Dictionary in _pieces.values(): bytes += int(value.bytes)
	return {"entries": _pieces.size(), "bytes": bytes, "maximum_entries": ITEMS.size() * 3}

static func _piece(entry: Dictionary) -> Dictionary:
	var id: String = str(entry.item)
	if not ITEMS.has(id): return {}
	var tier: int = clampi(int(entry.get("tier", 1)), 1, 3)
	var key: String = id + ":" + str(tier)
	if _pieces.has(key): return _pieces[key]
	var bitmap: Image = Image.create(BAKE_SIZE, BAKE_SIZE, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	var tint: Color = Icons.color(id).lightened((tier - 1) * 0.05)
	_paint(bitmap, id, tint, tier)
	# Growth uses the same capped 1/4/8-stack tiers as build(), but is sampled
	# at a fixed local phase only once. Fractional world movement cannot crawl
	# across source texels, and a million stacks cannot allocate more entries.
	# Plates are smaller than the limbs they protect. This is the authored base
	# size, separate from the unchanged capped stack growth in build(). Keep head
	# and knee parts near those joints instead of shrinking them toward the waist.
	var slot: String = str(ITEMS[id])
	var base_scale: float = {"back":0.78,"shoulder":0.68,"chest":0.68,"head":0.76,"belt":0.75,"legs":0.72}[slot]
	var pivot: Vector2 = Vector2(0,-20) if slot=="head" else (Vector2(0,14) if slot=="legs" else Vector2.ZERO)
	var stack_scale: float = 1.0 + (tier - 1) * 0.06
	var scale_value: float = base_scale * stack_scale
	var extent: int = int(round(BAKE_SIZE * scale_value))
	if extent != BAKE_SIZE: bitmap.resize(extent, extent, Image.INTERPOLATE_NEAREST)
	var used: Rect2i = bitmap.get_used_rect()
	bitmap = bitmap.get_region(used)
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(bitmap)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var anchor: int = int(round(BAKE_ORIGIN * scale_value))
	var offset: Vector2 = (pivot * (1.0-base_scale) * stack_scale).round()
	var result: Dictionary = {"texture": texture, "origin": Vector2(used.position) - Vector2(anchor, anchor) + offset, "bytes": used.size.x * used.size.y * 4}
	_pieces[key] = result
	return result

static func _rect(image: Image, x: int, y: int, width: int, height: int, tint: Color) -> void:
	if width <= 0 or height <= 0: return
	var area: Rect2i = Rect2i(x + BAKE_ORIGIN, y + BAKE_ORIGIN, width, height).intersection(Rect2i(0, 0, BAKE_SIZE, BAKE_SIZE))
	if area.has_area(): image.fill_rect(area, tint)

static func _polygon(image: Image, coordinates: Array[int], tint: Color) -> void:
	var points := PackedVector2Array()
	var bounds := Rect2()
	for index: int in range(0, coordinates.size(), 2):
		var point := Vector2(coordinates[index], coordinates[index + 1])
		points.append(point)
		bounds = Rect2(point, Vector2.ZERO) if index == 0 else bounds.expand(point)
	for y: int in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x: int in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				_rect(image, x, y, 1, 1, tint)

static func _wire(image: Image, points: Array[int], tint: Color) -> void:
	for index: int in range(0, points.size() - 2, 2):
		var start := Vector2(points[index], points[index + 1])
		var end := Vector2(points[index + 2], points[index + 3])
		var steps: int = int(maxf(absf(end.x - start.x), absf(end.y - start.y)))
		for step: int in range(steps + 1):
			var position: Vector2 = start.lerp(end, float(step) / maxf(1.0, steps))
			_rect(image, int(round(position.x)), int(round(position.y)), 1, 1, tint)

static func _plate(image: Image, x: int, y: int, width: int, height: int, metal: Color) -> void:
	_polygon(image, [x+1,y, x+width-1,y, x+width,y+1, x+width,y+height-1, x+width-1,y+height, x+1,y+height, x,y+height-1, x,y+1], INK)
	_rect(image, x+1, y+1, width-2, height-2, metal.darkened(0.15))
	_rect(image, x+2, y+1, width-4, 1, metal.lightened(0.30))
	_rect(image, x+1, y+2, 1, height-4, metal.lightened(0.12))
	_rect(image, x+width-2, y+2, 1, height-3, metal.darkened(0.40))
	_rect(image, x+2, y+height-2, width-4, 1, metal.darkened(0.48))

static func _window(image: Image, x: int, y: int, width: int, height: int, tint: Color) -> void:
	_rect(image, x, y, width, height, tint.darkened(0.65))
	_rect(image, x, y+1, width-1, maxi(1,height-1), tint.darkened(0.18))
	_rect(image, x, y, maxi(1,width-1), 1, tint.lightened(0.32))
	_rect(image, x, y, 1, 1, WHITE)

static func _rivet(image: Image, x: int, y: int) -> void:
	_rect(image, x, y, 2, 2, INK)
	_rect(image, x, y, 1, 1, STEEL_LIGHT)

static func _paint(image: Image, id: String, tint: Color, tier: int) -> void:
	match id:
		"missile_pod":
			_plate(image,-18,-16,14,14,STEEL)
			_rect(image,-16,-12,10,8,RUBBER)
			for x: int in [-15,-10]:
				_plate(image,x,-14,4,9,COPPER)
				_rect(image,x+1,-13,2,2,tint)
				_rect(image,x+1,-10,2,4,STEEL_LIGHT)
			_rivet(image,-17,-4)
			_rivet(image,-7,-4)
		"landing_coil":
			for x: int in [-9,2]:
				_plate(image,x,14,7,8,STEEL)
				_rect(image,x+1,16,5,4,RUBBER)
				_rect(image,x+1,16,5,1,tint)
				_rect(image,x+1,19,5,1,tint)
				_rect(image,x,21,7,2,COPPER)
		"frost_halo":
			_plate(image,-5,-11,11,13,STEEL)
			_rect(image,-3,-8,7,6,RUBBER)
			_window(image,-1,-7,3,4,tint)
			for x: int in [-6,4]:
				_plate(image,x,-8,3,5,STEEL_LIGHT)
				_rect(image,x+1,-6,1,2,tint)
			_rect(image,-1,-12,3,2,COPPER)
			_rect(image,-1,1,3,2,COPPER)
		"feather":
			_plate(image,-19,-13,10,24,RUBBER)
			# Three folded, feather-shaped metal vanes, bolted to a common spine.
			for row: int in range(3):
				var y: int = -15 + row*8
				_polygon(image,[-14,y+1,-25,y-3,-26,y+1,-23,y+7,-14,y+9],INK)
				_polygon(image,[-15,y+2,-23,y-1,-24,y+2,-21,y+6,-15,y+7],STEEL)
				_wire(image,[-23,y+1,-20,y+4,-15,y+5],tint.darkened(0.12))
				_rect(image,-22,y,3,1,WHITE.darkened(0.2))
			_rect(image,-16,-9,3,15,COPPER)
			_rivet(image,-15,-10)
			_rivet(image,-15,7)
		"thruster":
			_plate(image,-22,-15,13,26,STEEL)
			_plate(image,-21,-12,5,18,Color("596675"))
			_plate(image,-15,-12,5,18,Color("596675"))
			for x: int in [-20,-14]:
				_window(image,x,-9,3,5,tint)
				_rect(image,x,-2,3,2,RUBBER)
				_rect(image,x,2,3,1,STEEL_LIGHT)
				_rect(image,x,7,3,3,INK)
				_rect(image,x,9,3,1,Color("b98660"))
				_rect(image,x+1,10,1,2,Color("f4bd78"))
			_rect(image,-19,-15,8,2,RUBBER)
			_rivet(image,-18,4)
		"phoenix":
			_plate(image,-22,-15,13,27,Color("806653"))
			_plate(image,-20,-11,8,15,Color("a76b4a"))
			for row: int in range(3):
				var y: int = -10 + row*7
				_polygon(image,[-19,y,-27,y-2,-25,y+4,-19,y+6],INK)
				_polygon(image,[-20,y+1,-25,y,-23,y+3,-20,y+4],Color("bb7750"))
				_rect(image,-24,y+1,3,1,Color("e4b879"))
			_window(image,-18,-8,4,5,tint)
			_rect(image,-18,0,4,1,INK)
			_rect(image,-18,3,4,1,INK)
			_plate(image,-20,8,9,4,Color("513e36"))
		"arc":
			_plate(image,-17,-14,14,12,Color("667e83"))
			_rect(image,-15,-11,10,6,RUBBER)
			for y: int in [-11,-8,-5]:
				_rect(image,-14,y,8,1,Color("85a9ab"))
				_rect(image,-13,y,6,1,tint.darkened(0.08))
				_rect(image,-15,y+1,1,1,COPPER)
			_rect(image,-12,-14,5,2,Color("8b9693"))
			_rivet(image,-16,-13)
			_rivet(image,-6,-4)
		"capacitor":
			_plate(image,-16,-15,13,12,Color("8c7958"))
			for x: int in [-14,-9]:
				_plate(image,x,-13,4,8,Color("b09a70"))
				_rect(image,x+1,-12,2,2,RUBBER)
				_rect(image,x+1,-9,2,3,tint.darkened(0.1))
			_rect(image,-13,-5,7,1,RUBBER)
			_rivet(image,-16,-6)
		"echo":
			_plate(image,-17,-14,14,12,Color("716c83"))
			_plate(image,-14,-12,8,8,Color("a09aa4"))
			_rect(image,-12,-10,4,4,Color("37353f"))
			_rect(image,-11,-9,2,2,tint.darkened(0.18))
			for y: int in [-11,-8,-5]: _rect(image,-16,y,1,2,Color("ac9db7"))
			_rect(image,-13,-3,7,1,RUBBER)
			_rivet(image,-5,-12)
		"nova":
			_plate(image,-17,-15,14,13,Color("8e806e"))
			_plate(image,-14,-12,8,8,Color("baa58a"))
			_rect(image,-12,-10,4,4,Color("583f60"))
			_rect(image,-11,-10,2,4,Color("d89cca"))
			_rect(image,-12,-9,4,2,Color("edbad1"))
			_rect(image,-11,-9,1,1,WHITE)
			for x: int in [-16,-5]:
				_rect(image,x,-11,1,5,RUBBER)
				_rivet(image,x,-14)
		"vitality":
			_plate(image,-5,-7,11,13,Color("71837b"))
			_plate(image,-3,-5,7,9,Color("3c5b53"))
			_window(image,-1,-4,3,6,tint)
			_rect(image,-3,-1,7,2,tint.darkened(0.15))
			_rect(image,0,-3,1,5,Color("d9e9bc"))
			_rivet(image,-5,3)
		"battery":
			_plate(image,-5,-7,11,13,Color("7d8c83"))
			_rect(image,-2,-8,4,2,RUBBER)
			_rect(image,-3,-4,7,7,RUBBER)
			for y: int in [-3,0]:
				_window(image,-2,y,5,2,tint)
			_rect(image,-3,4,6,1,COPPER)
		"glass":
			_plate(image,-5,-7,11,13,Color("8e8086"))
			_polygon(image,[-2,-5,3,-4,4,1,0,4,-3,1],tint.darkened(0.1))
			_polygon(image,[-2,-5,0,-2,-3,1],Color("f5bccd"))
			_polygon(image,[0,-2,3,-4,4,1,0,4],tint.darkened(0.36))
			_wire(image,[0,-5,-1,-1,2,1,0,4],INK)
			_rect(image,-4,-4,1,7,COPPER)
		"resonator":
			_plate(image,-6,-7,12,13,Color("978262"))
			_plate(image,-4,-5,8,9,Color("c2a575"))
			_plate(image,-2,-3,4,5,Color("555649"))
			_rect(image,-1,-2,2,3,tint.darkened(0.1))
			_rect(image,-5,-1,1,3,RUBBER)
			_rect(image,4,-1,1,3,RUBBER)
			_rivet(image,-4,3)
		"lens":
			_rect(image,-6,-22,12,1,RUBBER)
			_rect(image,-5,-23,6,1,Color("899089"))
			_plate(image,2,-24,6,5,Color("a19689"))
			_window(image,4,-23,2,2,tint.darkened(0.22))
		"overclock":
			_plate(image,-10,-23,7,10,Color("667d80"))
			_rect(image,-8,-21,3,6,RUBBER)
			for y: int in [-20,-18,-16]: _rect(image,-8,y,3,1,tint.darkened(0.08))
			_rect(image,-9,-14,5,1,COPPER)
			_rect(image,-3,-20,3,1,RUBBER)
		"frost":
			_plate(image,-8,-25,14,5,Color("809391"))
			for x: int in [-6,-2,2]:
				_rect(image,x,-24,2,3,Color("c0d2c5"))
				_rect(image,x,-23,1,2,tint)
			_plate(image,-9,-21,4,5,Color("668184"))
			_rect(image,-8,-20,2,2,tint.darkened(0.2))
		"toxin":
			_rect(image,-5,-13,13,1,RUBBER)
			_plate(image,3,-14,9,7,Color("697765"))
			_rect(image,6,-12,3,3,RUBBER)
			_rect(image,7,-12,1,3,Color("a9b993"))
			_plate(image,2,-12,3,4,Color("8d956d"))
			_plate(image,10,-12,3,4,Color("8d956d"))
			_rect(image,3,-11,1,2,tint.darkened(0.1))
			_rect(image,11,-11,1,2,tint.darkened(0.1))
		"coolant":
			_rect(image,-9,3,18,2,Color("526569"))
			for x: int in [-12,4]:
				_plate(image,x,3,6,11,Color("829495"))
				_window(image,x+2,6,2,5,tint)
				_rect(image,x+1,4,4,1,COPPER)
			_wire(image,[-8,4,-8,1,-3,1],Color("748e9a"))
		"ember":
			_plate(image,-13,3,9,12,Color("8a6d55"))
			_rect(image,-11,6,5,6,Color("553831"))
			_polygon(image,[-9,5,-6,9,-9,12,-11,9],tint)
			_rect(image,-9,8,1,3,Color("ffd19a"))
			_rect(image,-12,4,7,1,Color("b49a6f"))
			_rivet(image,-12,12)
		"siphon":
			_plate(image,-13,3,7,12,Color("726777"))
			_window(image,-11,6,3,6,tint)
			_rect(image,-12,4,5,2,Color("b1a3ab"))
			_rect(image,-10,12,1,3,STEEL_LIGHT)
			_wire(image,[-9,4,-9,1,-4,1,-3,4],INK)
			_wire(image,[-9,3,-9,0,-4,0,-3,3],Color("aa8b9d"))
		"harvest":
			_plate(image,-13,3,10,12,Color("887b54"))
			_rect(image,-11,7,6,5,Color("6c624b"))
			_rect(image,-12,5,8,3,Color("b49d68"))
			_rect(image,-9,6,2,3,INK)
			_rect(image,-9,6,1,2,tint)
			_rect(image,-11,11,2,1,Color("c2b083"))
			_rivet(image,-6,11)
		"magnet":
			_plate(image,-14,3,10,12,Color("6e828b"))
			_rect(image,-11,3,4,7,Color.TRANSPARENT)
			_rect(image,-10,10,3,2,STEEL_LIGHT)
			_rect(image,-13,4,2,4,tint.darkened(0.25))
			_rect(image,-7,4,2,4,Color("80adbe"))
			_rect(image,-13,4,2,1,Color("e7b291"))
			_rect(image,-7,4,2,1,Color("c1d8d1"))
			_rivet(image,-12,12)
		"plating":
			for x: int in [-8,3]:
				_plate(image,x,10,6,9,Color("a2aca5"))
				_rect(image,x+2,12,2,4,Color("c7d0bd"))
				_rect(image,x+1,17,4,1,RUBBER)
				_rivet(image,x+1,10)
		"moss":
			for x: int in [-8,3]:
				_plate(image,x,11,6,8,Color("657458"))
				_rect(image,x+1,15,4,2,Color("91aa71"))
				_rect(image,x+1,12,2,3,tint.darkened(0.17))
				_rect(image,x+3,13,2,2,Color("b5c28a"))
				_rect(image,x+2,16,1,1,Color("d4d9a6"))
		"momentum":
			for x: int in [-8,3]:
				_plate(image,x,10,6,9,Color("867f64"))
				_plate(image,x+1,12,4,5,Color("afbe9b"))
				_rect(image,x+2,13,2,3,RUBBER)
				_rect(image,x+2,14,2,1,tint)
				_rect(image,x+1,18,4,1,COPPER)
		"piercer":
			for x: int in [-8,3]:
				_plate(image,x,10,6,10,Color("857b8f"))
				_rect(image,x+2,11,2,7,Color("b9acd0"))
				_rect(image,x+2,12,1,5,tint.darkened(0.12))
				_rect(image,x+1,17,4,1,RUBBER)
	# Extra stacks add at most two tiny service lights, not a new halo or pole.
	if tier > 1:
		match str(ITEMS[id]):
			"back": _rect(image,-12,6,1,tier-1,tint)
			"shoulder": _rect(image,-5,-8,1,tier-1,tint)
			"chest": _rect(image,3,2,1,tier-1,tint)
			"head": _rect(image,-5,-19,1,tier-1,tint)
			"belt": _rect(image,-6,11,1,tier-1,tint)
			"legs": _rect(image,6,16,1,tier-1,tint)
