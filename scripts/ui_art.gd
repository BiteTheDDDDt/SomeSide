class_name SideUIArt
extends Control

const IllustratedPlayers = preload("res://scripts/illustrated_player_renderer.gd")
const Weapons = preload("res://scripts/weapon_art.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Icons = preload("res://scripts/item_icons.gd")
const TEAL := Color("94cabb")
const GOLD := Color("d2b787")
const PAPER := Color("e8ede5")
const EDGE := Color("3d6064")
const DARK := Color("263941")
var mode: String = "frame"
var character: String = "ranger"
var stage: int = 1
var victorious: bool = false
var tint: Color = TEAL
var button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	if is_instance_valid(button):
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)

func _draw() -> void:
	match mode:
		"wordmark": _wordmark()
		"frame": _frame()
		"button": _button()
		"scene": _scene()
		"portrait": _portrait()
		"divider": _divider()
		"route": _route()
		"regions": _regions()

func _wordmark() -> void:
	var font: Font=get_theme_font("font","Label")
	var font_size: int=clampi(int(size.x/5.6),26,76)
	var text_width: float=font.get_string_size("SOMESIDE",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	if text_width>size.x: font_size=int(font_size*size.x/text_width)
	draw_string(font,Vector2(0,font_size),"SOMESIDE",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,PAPER)
	var y: float=font_size+10
	draw_line(Vector2(0,y),Vector2(size.x,y),Color("52646a"),1,true)
	draw_line(Vector2(0,y),Vector2(size.x*.28,y),GOLD,3,true)


func _frame() -> void:
	var w: float = size.x
	var h: float = size.y
	var points := PackedVector2Array([Vector2(11, 1), Vector2(w - 22, 1), Vector2(w - 1, 22), Vector2(w - 1, h - 11), Vector2(w - 11, h - 1), Vector2(22, h - 1), Vector2(1, h - 22), Vector2(1, 11), Vector2(11, 1)])
	draw_polyline(points, EDGE, 1.0)
	draw_line(Vector2(22, 5), Vector2(w - 32, 5), Color("233e45"), 1)
	draw_rect(Rect2(23, 0, minf(90, w * 0.22), 3), tint)
	draw_rect(Rect2(w - 70, h - 3, 38, 3), GOLD.darkened(0.35))
	for p: Vector2 in [Vector2(10, 20), Vector2(w - 11, 31), Vector2(10, h - 31), Vector2(w - 20, h - 11)]:
		draw_rect(Rect2(p - Vector2.ONE * 2, Vector2(4, 4)), Color("57706e"))
		draw_line(p + Vector2(-1, 0), p + Vector2(1, 0), DARK, 1)
	for index in range(6):
		var x: float = w - 110 + index * 8
		draw_line(Vector2(x, 12), Vector2(x + 3, 9), Color("355158"), 1)

func _button() -> void:
	if not is_instance_valid(button): return
	var primary: bool = bool(button.get_meta("art_primary", false))
	var focused: bool = button.has_focus() or button.is_hovered()
	var ink: Color = Color("64472e") if primary else (TEAL if focused else Color("527477"))
	if button.disabled: ink = Color("304249")
	var y: float = roundf(size.y / 2.0)
	draw_line(Vector2(7, 9), Vector2(7, size.y - 9), ink, 2)
	draw_line(Vector2(9, 8), Vector2(size.x - 13, 8), Color(ink, 0.18), 1)
	if primary or focused:
		draw_polyline(PackedVector2Array([Vector2(size.x - 18, y - 4), Vector2(size.x - 14, y), Vector2(size.x - 18, y + 4)]), ink, 2)
	else:
		draw_rect(Rect2(size.x - 15, y - 1, 3, 3), ink)

func _divider() -> void:
	var y: float = floorf(size.y / 2)
	draw_line(Vector2(0, y), Vector2(size.x, y), Color("29454d"), 1)
	draw_rect(Rect2(0, y - 1, 24, 3), tint.darkened(0.2))
	for index in range(3): draw_rect(Rect2(size.x - 16 + index * 6, y - 1, 2, 3), Color("486164"))

func _portrait() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color("081b22"))
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x*.7,0),Vector2(size.x*.35,size.y),Vector2(0,size.y)]),Color("263b43"))
	draw_line(Vector2(5, size.y - 7), Vector2(size.x - 5, size.y - 7), tint, 2)
	draw_rect(Rect2(5, 5, 7, 2), tint)
	draw_rect(Rect2(size.x - 12, 5, 7, 2), tint)

func _scene() -> void:
	# Static composition shares player and weapon assets with the game.
	# No continuous redraw or additional offscreen viewport.
	var scale_value: float = minf(size.x / 500.0, size.y / 610.0)
	draw_set_transform(Vector2((size.x - 500 * scale_value) / 2, 0), 0, Vector2.ONE * scale_value)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(476, 0), Vector2(500, 24), Vector2(500, 580), Vector2(472, 610), Vector2(0, 610), Vector2(0, 22)]), Color(0.026, 0.075, 0.086, 0.88))
	# Broken architectural ribs frame a luminous, angular rift.
	for index in range(5):
		var x: float = 30 + index * 102
		var h: float = 110 + (index * 53) % 135
		draw_rect(Rect2(x, 450 - h, 30, h), Color("12343b"))
		draw_rect(Rect2(x + 4, 452 - h, 4, h - 20), Color("20464b"))
	var ring := PackedVector2Array()
	var inside := PackedVector2Array()
	for index in range(65):
		var angle: float = TAU * index / 64.0 - PI / 8.0
		ring.append(Vector2(258, 262) + Vector2(cos(angle) * 171, sin(angle) * 205))
		inside.append(Vector2(258, 262) + Vector2(cos(angle) * 150, sin(angle) * 184))
	draw_colored_polygon(inside, Color("102d34"))
	draw_polyline(ring, Color("345758"), 16)
	draw_polyline(ring, Color("769184"), 2)
	draw_polyline(inside, Color("347970"), 4)
	for index in [0, 16, 32, 48]:
		var a: Vector2 = inside[index]
		var b: Vector2 = inside[index + 8]
		draw_line(a.lerp(b, 0.22), a.lerp(b, 0.78), TEAL, 3)
	# A narrow hard-edge passage preserves the directional composition.
	draw_colored_polygon(PackedVector2Array([Vector2(257, 84), Vector2(274, 160), Vector2(259, 223), Vector2(275, 300), Vector2(258, 408), Vector2(247, 304), Vector2(233, 229), Vector2(250, 174)]), Color("25705f"))
	draw_polyline(PackedVector2Array([Vector2(257, 90), Vector2(262, 165), Vector2(249, 229), Vector2(262, 300), Vector2(258, 400)]), TEAL, 4)
	for index in range(7):
		var x: float = 119 + index * 43
		var y: float = 170 + (index * 79) % 209
		draw_rect(Rect2(x, y, 3, 6), TEAL.darkened(0.25))
	# A foreground landing platform gives the original hero a physical anchor.
	draw_colored_polygon(PackedVector2Array([Vector2(60, 490), Vector2(395, 490), Vector2(448, 522), Vector2(430, 548), Vector2(69, 548), Vector2(41, 523)]), Color("0a2028"))
	draw_polyline(PackedVector2Array([Vector2(60, 490), Vector2(395, 490), Vector2(448, 522)]), Color("527276"), 3)
	draw_line(Vector2(66, 529), Vector2(423, 529), Color("29474c"), 2)
	for index in range(8): draw_line(Vector2(90 + index * 16, 536), Vector2(98 + index * 16, 536), GOLD.darkened(0.4), 3)
	_draw_hero(Vector2(185, 415), 5.0)
	var gear: Array = ["pulse_rifle", "grenade"] if character == "ranger" else ["arc_blade", "shockwave"]
	for index in range(2):
		var p := Vector2(376, 365 + index * 58)
		draw_rect(Rect2(p, Vector2(46, 46)), Color("09212a"))
		draw_rect(Rect2(p, Vector2(46, 46)), Color("53716d"), false, 1)
		draw_rect(Rect2(p + Vector2(0, 7), Vector2(2, 32)), TEAL if index == 0 else GOLD)
		draw_texture_rect(Icons.texture(gear[index], 48), Rect2(p + Vector2(5, 5), Vector2(36, 36)), false)
	draw_line(Vector2(34, 578), Vector2(466, 578), Color("385156"), 1)
	for index in range(3):
		var x: float = 37 + index * 22
		draw_rect(Rect2(x, 591, 12, 3), TEAL if index < stage else Color("2b454c"))
	draw_rect(Rect2(435, 590, 30, 4), GOLD)
	draw_set_transform(Vector2.ZERO)

func _draw_hero(position_value: Vector2, scale_value: float) -> void:
	var frame: Dictionary = IllustratedPlayers.frame(character)
	if frame.is_empty(): return
	draw_set_transform(position_value * minf(size.x / 500.0, size.y / 610.0) + Vector2((size.x - 500 * minf(size.x / 500.0, size.y / 610.0)) / 2, 0), 0, Vector2.ONE * scale_value * minf(size.x / 500.0, size.y / 610.0))
	IllustratedPlayers.portrait(self,character)
	draw_polyline(PackedVector2Array([Vector2(0,-5),Vector2(3,0),Vector2(8,-5)]),Color("424e55"),5,true)
	draw_polyline(PackedVector2Array([Vector2(0,-5),Vector2(3,0),Vector2(8,-5)]),Color("b4a798") if character=="vanguard" else Color("c6c7aa"),3,true)
	var scene_scale: float=minf(size.x/500.0,size.y/610.0)
	draw_set_transform((position_value+Vector2(0,-5)*scale_value)*scene_scale+Vector2((size.x-500*scene_scale)/2,0),0,Vector2(.68,.72)*scale_value*scene_scale)
	Weapons.draw(self,"arc_blade" if character=="vanguard" else "pulse_rifle")
	var scale_scene: float = minf(size.x / 500.0, size.y / 610.0)
	draw_set_transform(Vector2((size.x - 500 * scale_scene) / 2, 0), 0, Vector2.ONE * scale_scene)

func _route() -> void:
	var y: float = size.y / 2
	var step: float = (size.x - 50) / 2
	draw_line(Vector2(25, y), Vector2(size.x - 25, y), Color("345058"), 2)
	for index in range(3):
		var p := Vector2(25 + index * step, y)
		var color: Color = GOLD if index < stage else Color("3b5359")
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0)]), DARK)
		draw_polyline(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0), p + Vector2(0, -8)]), color, 2)
		if index < stage: draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), color)

func _regions() -> void:
	for index in range(3):
		var x: float = index * 166
		var color: Color = [TEAL, GOLD, Color("a995d8")][index]
		draw_rect(Rect2(x, 0, 148, 65), Color("0a1b23"))
		draw_line(Vector2(x, 64), Vector2(x + 148, 64), color.darkened(0.5), 1)
		draw_rect(Rect2(x + 6, 6, 3, 3), color)
		if index == 0:
			for tree in range(3):
				var p := Vector2(x + 40 + tree * 33, 55 - (tree % 2) * 9)
				draw_line(p, p + Vector2(0, -35), color.darkened(0.5), 5)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-17, -23), p + Vector2(-10, -37), p + Vector2(10, -40), p + Vector2(18, -26)]), color.darkened(0.65))
				draw_line(p + Vector2(-12, -26), p + Vector2(10, -29), color.darkened(0.25), 2)
		elif index == 1:
			for cliff in range(3):
				var p := Vector2(x + 29 + cliff * 37, 60)
				var height_value: float = 19 + cliff * 12
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(0, -height_value), p + Vector2(21, -height_value - 5), p + Vector2(25, 0)]), color.darkened(0.65))
				draw_line(p + Vector2(0, -height_value), p + Vector2(21, -height_value - 5), color.darkened(0.2), 2)
		else:
			for ring in range(2):
				var center := Vector2(x + 59 + ring * 31, 34)
				var points := PackedVector2Array()
				for step in range(9): points.append(center + Vector2.from_angle(TAU * step / 8) * 22)
				draw_polyline(points, color.darkened(0.55), 4)
				draw_polyline(points, color.darkened(0.1), 1)
		if index < 2:
			draw_polyline(PackedVector2Array([Vector2(x + 153, 29), Vector2(x + 157, 33), Vector2(x + 153, 37)]), EDGE, 1)
