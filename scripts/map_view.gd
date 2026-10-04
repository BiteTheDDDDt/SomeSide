class_name SideMapView
extends Control

const Icons = preload("res://scripts/item_icons.gd")
const Locale = preload("res://scripts/localization.gd")
var map_font: Font
var _frame: Dictionary = {}
var _local_id: int = 1
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO

func set_frame(snapshot: Dictionary, player_id: int) -> void:
	_frame = snapshot
	_local_id = player_id
	queue_redraw()

func _point(position: Vector2) -> Vector2:
	return _origin + position * _scale

func _draw() -> void:
	if _frame.is_empty():
		return
	var dimensions: Vector2 = _frame.get("world_size", Vector2(3200, 1100))
	_scale = minf((size.x - 52) / maxf(1, dimensions.x), (size.y - 36) / maxf(1, dimensions.y))
	_origin = (size - dimensions * _scale) * 0.5
	var bounds := Rect2(_origin, dimensions * _scale)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b2029"))
	draw_rect(bounds, Color("102b33"))
	for x in range(0, int(dimensions.x), 600):
		draw_line(_point(Vector2(x, 0)), _point(Vector2(x, dimensions.y)), Color(0.35, 0.6, 0.6, 0.08), 1)
	for y in range(0, int(dimensions.y), 450):
		draw_line(_point(Vector2(0, y)), _point(Vector2(dimensions.x, y)), Color(0.35, 0.6, 0.6, 0.08), 1)
	var accents: Array[Color] = [Color("78c3a8"), Color("dca984"), Color("b49fdf")]
	var accent: Color = accents[clampi(int(_frame.get("stage", 1)) - 1, 0, 2)]
	for platform: Rect2 in _frame.get("platforms", []):
		var position: Vector2 = _point(platform.position)
		var extent: Vector2 = Vector2(platform.size.x * _scale, maxf(2.5, platform.size.y * _scale))
		draw_rect(Rect2(position, extent), Color(accent, 0.5))
		draw_line(position, position + Vector2(extent.x, 0), accent, 1)
	var occupied: Array[Rect2] = []
	var gate: Dictionary = _frame.get("gate", {})
	if not gate.is_empty():
		occupied.append(Rect2(_point(gate.get("pos", Vector2.ZERO)) - Vector2(24, 32), Vector2(48, 44)))
	for chest: Dictionary in _frame.get("chests", []):
		occupied.append(Rect2(_point(chest.get("pos", Vector2.ZERO)) - Vector2(9, 16), Vector2(18, 18)))
	for landmark: Dictionary in _frame.get("landmarks", []):
		var p: Vector2 = _point(landmark.get("pos", Vector2.ZERO))
		draw_circle(p, 3, Color(accent, 0.65), true, -1, true)
		if map_font == null:
			continue
		var title: String = Locale.text(str(landmark.get("name", "")))
		var width: float = map_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		for offset: float in [-17.0, 19.0, -32.0, 34.0, -49.0, 51.0]:
			var anchor := Vector2(clampf(p.x - width * 0.5, 8, size.x - width - 8), clampf(p.y + offset, 16, size.y - 5))
			var box := Rect2(anchor - Vector2(4, 13), Vector2(width + 8, 17))
			var available: bool = true
			for other: Rect2 in occupied:
				if other.intersects(box):
					available = false
					break
			if available:
				draw_rect(box, Color(0.025, 0.07, 0.09, 0.85))
				draw_string(map_font, anchor, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("aac5c2"))
				occupied.append(box)
				break
	for chest: Dictionary in _frame.get("chests", []):
		var p: Vector2 = _point(chest.get("pos", Vector2.ZERO))
		var used: bool = bool(chest.get("opened", false))
		var kind: String = str(chest.get("type", "cache"))
		if kind == "equipment":
			kind = "equipment_cache"
		draw_texture_rect(Icons.texture(kind, 32), Rect2(p - Vector2(7, 14), Vector2(14, 14)), false, Color(1, 1, 1, 0.3 if used else 1.0))
	if not gate.is_empty():
		var p: Vector2 = _point(gate.get("pos", Vector2.ZERO))
		draw_circle(p, 10, Color("0b2029"))
		draw_arc(p, 8, 0, TAU, 24, Color("f2b368"), 2, true)
		draw_circle(p, 3, Color("f2b368"))
		if map_font != null:
			draw_string(map_font, p + Vector2(-18, -15), Locale.text("裂隙门"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2b368"))
	var spawn: Vector2 = _point(_frame.get("spawn", Vector2(200, dimensions.y - 101)))
	draw_circle(spawn, 4, Color("789c9e"), false, 1.5, true)
	for id in _frame.get("players", {}):
		var player: Dictionary = _frame.players[id]
		var p: Vector2 = _point(player.pos)
		var color: Color = Color("70dfbd") if id == _local_id else Color("a4c2ff")
		if player.get("dead", false):
			color = Color("ff9993")
		draw_circle(p, 8, Color("071b23"))
		draw_circle(p, 4.5, color, true, -1, true)
		if id == _local_id:
			draw_arc(p, 7, 0, TAU, 20, color, 1.5, true)
			if map_font != null:
				draw_string(map_font, p + Vector2(10, 4), Locale.text("你"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
