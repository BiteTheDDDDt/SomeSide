class_name SidePlayerAppearance
extends RefCounted

const Content = preload("res://scripts/content.gd")
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
}
const INK: Color = Color("07171e")
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

static func draw_layer(canvas: Node2D, appearance: Array[Dictionary], behind: bool, clock: float) -> void:
	for entry: Dictionary in appearance:
		if (str(entry.slot) == "back") != behind:
			continue
		_draw_piece(canvas, entry, clock)

static func _line(c: Node2D, points: Array, tint: Color, width: float = 2.0) -> void:
	var path: PackedVector2Array = PackedVector2Array(points)
	c.draw_polyline(path, INK, width + 2.0, true)
	c.draw_polyline(path, tint, width, true)

static func _gem(c: Node2D, center: Vector2, radius: float, tint: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([center+Vector2(-radius,0),center+Vector2(0,-radius-2),center+Vector2(radius,0),center+Vector2(0,radius+2)]), INK)
	c.draw_colored_polygon(PackedVector2Array([center+Vector2(-radius+1.5,0),center+Vector2(0,-radius),center+Vector2(radius-1.5,0),center+Vector2(0,radius)]), tint)
	c.draw_line(center+Vector2(0,-radius+1),center+Vector2(0,radius-1),WHITE,1.0,true)

static func _draw_piece(c: Node2D, entry: Dictionary, clock: float) -> void:
	var id: String = entry.item
	var definition: Dictionary = _definition(id)
	var tint: Color = Color(definition.get("theme_color", WHITE)).lightened((float(entry.brightness)-1.0)*0.5)
	var growth: float = float(entry.scale)
	var pulse: float = 0.8 + 0.2 * sin(clock * 3.0)
	match id:
		"feather":
			for i: int in range(3):
				var tip: Vector2 = Vector2(-30.0 + i * 5.0, -25.0 + i * 10.0) * growth
				c.draw_colored_polygon(PackedVector2Array([Vector2(-8,-5),tip,tip+Vector2(4,9),Vector2(-12,6)]), INK)
				_line(c,[Vector2(-11,2),tip+Vector2(3,5)],tint,3.0)
		"thruster":
			c.draw_rect(Rect2(-21,-14,12,25),INK)
			c.draw_rect(Rect2(-19,-12,8,19),Color("73809b"))
			c.draw_line(Vector2(-15,-10),Vector2(-15,5),tint,2.0,true)
			for x: float in [-18.0,-12.0]:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x-2,8),Vector2(x+2,8),Vector2(x,16+3*pulse)]),tint)
		"phoenix":
			for i: int in range(3):
				var tip: Vector2 = Vector2(-30+i*4,-24+i*12) * growth
				_line(c,[Vector2(-9,4),Vector2(-20,-3+i*2),tip],Color("e87a56"),4.0)
				_line(c,[Vector2(-18,0+i),tip+Vector2(3,3)],Color("ffd38a"),1.3)
		"arc":
			_line(c,[Vector2(-10,-8),Vector2(-17,-15),Vector2(-17,-23)],Color("91a9b1"),4.0)
			for i: int in range(3):
				c.draw_line(Vector2(-22,-14-i*4),Vector2(-12,-14-i*4),tint,2.0,true)
			c.draw_circle(Vector2(-17,-26),2.5,tint,true,-1,true)
		"capacitor":
			c.draw_rect(Rect2(-16,-15,12,10),INK)
			c.draw_rect(Rect2(-14,-13,8,6),Color("837253"))
			for x: float in [-12.0,-8.0]: c.draw_line(Vector2(x,-16),Vector2(x,-8),tint,2.0,true)
		"echo":
			_line(c,[Vector2(-8,-8),Vector2(-15,-12),Vector2(-15,-23)],Color("8b8199"),3.0)
			for i: int in range(3): c.draw_arc(Vector2(-15,-20),3+i*3,PI*0.65,PI*1.8,14,tint,1.3,true)
		"nova":
			_gem(c,Vector2(-15,-15),6.5*growth,Color("ffb7ed"))
			for i: int in range(4):
				var ray: Vector2 = Vector2.from_angle(i*PI*0.5+PI*0.25)
				c.draw_line(Vector2(-15,-15)+ray*8,Vector2(-15,-15)+ray*11,tint,1.5,true)
		"vitality":
			c.draw_circle(Vector2(0,1),6,INK,true,-1,true)
			c.draw_circle(Vector2(0,1),4.5,tint,true,-1,true)
			c.draw_line(Vector2(-3,1),Vector2(3,1),WHITE,1.5,true)
			c.draw_line(Vector2(0,-2),Vector2(0,4),WHITE,1.5,true)
		"battery":
			c.draw_rect(Rect2(-6,-6,12,13),INK)
			c.draw_rect(Rect2(-4,-4,8,9),Color("334f53"))
			for i: int in range(3): c.draw_line(Vector2(-2,-2+i*3),Vector2(2,-2+i*3),Color("9ce5df"),1.8,true)
		"glass":
			_gem(c,Vector2(0,0),6*growth,tint)
			c.draw_polyline(PackedVector2Array([Vector2(0,-5),Vector2(-2,-1),Vector2(2,2),Vector2(0,5)]),INK,1.0,true)
		"resonator":
			c.draw_arc(Vector2(0,0),7*growth,0,TAU,20,INK,4.0,true)
			c.draw_arc(Vector2(0,0),6*growth,0,TAU,20,Color("f6cc7a"),1.8,true)
			c.draw_circle(Vector2(0,0),2.5,WHITE,true,-1,true)
		"lens":
			c.draw_circle(Vector2(7,-15),5.5,INK,true,-1,true)
			c.draw_circle(Vector2(7,-15),3.7,tint,true,-1,true)
			c.draw_circle(Vector2(8,-16),1.2,WHITE,true,-1,true)
		"overclock":
			c.draw_rect(Rect2(-8,-23,6,8),INK)
			c.draw_rect(Rect2(-7,-22,4,6),Color("4d777f"))
			for i: int in range(3): c.draw_line(Vector2(-9,-22+i*3),Vector2(-12,-22+i*3),tint,1.6,true)
		"frost":
			for i: int in range(3): _gem(c,Vector2(-5+i*5,-23),2.7,Color("acdeef"))
		"toxin":
			c.draw_rect(Rect2(1,-15,12,8),INK)
			c.draw_rect(Rect2(2,-14,9,6),Color("7b9563"))
			for x: float in [3.0,10.0]: c.draw_circle(Vector2(x,-10),2.5,Color("bdde86"),true,-1,true)
		"coolant":
			for x: float in [-8.0,5.0]:
				c.draw_rect(Rect2(x,3,6,10),INK)
				c.draw_rect(Rect2(x+1,5,4,6),Color("91cbef"))
			_line(c,[Vector2(-5,3),Vector2(-5,-2),Vector2(0,-4)],tint,1.5)
		"ember":
			_gem(c,Vector2(-8,7),5,Color("fb9061"))
			c.draw_line(Vector2(-10,8),Vector2(-7,3),Color("ffdeb4"),2,true)
		"siphon":
			_line(c,[Vector2(-8,1),Vector2(-13,6),Vector2(-9,13),Vector2(-3,9)],tint,2.5)
			c.draw_rect(Rect2(-13,6,6,8),INK)
			c.draw_rect(Rect2(-11,7,2,5),tint)
		"harvest":
			c.draw_rect(Rect2(-13,3,10,12),INK)
			c.draw_rect(Rect2(-11,5,7,8),Color("a78b54"))
			c.draw_circle(Vector2(-7.5,8),2.0,Color("ffd071"),true,-1,true)
		"magnet":
			_line(c,[Vector2(-13,3),Vector2(-13,12),Vector2(-5,12),Vector2(-5,3)],Color("b5c5d0"),3.0)
			c.draw_line(Vector2(-13,2),Vector2(-13,6),Color("fa8e74"),3,true)
			c.draw_line(Vector2(-5,2),Vector2(-5,6),Color("91cced"),3,true)
		"plating":
			for x: float in [-6.0,3.0]:
				c.draw_rect(Rect2(x-2,10,7,9),INK)
				c.draw_rect(Rect2(x-1,11,5,6),Color("c7d0d5"))
		"moss":
			for i: int in range(4):
				var p: Vector2 = Vector2(-7+i*4,14+(i%2)*3)
				c.draw_colored_polygon(PackedVector2Array([p+Vector2(-4,3),p+Vector2(-3,-4),p+Vector2(2,-1),p+Vector2(3,4)]),Color("9cce83"))
		"momentum":
			for x: float in [-6.0,5.0]:
				c.draw_arc(Vector2(x,14),4.8,0,TAU,14,INK,4.0,true)
				c.draw_arc(Vector2(x,14),3.9,0,TAU,14,Color("9de0bd"),1.8,true)
				c.draw_line(Vector2(x-2,14),Vector2(x+2,14),WHITE,1.0,true)
		"piercer":
			for x: float in [-7.0,5.0]:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x-3,9),Vector2(x+2,10),Vector2(x+5,20),Vector2(x-2,18)]),INK)
				c.draw_line(Vector2(x,11),Vector2(x+3,18),Color("bdacf0"),2.0,true)
