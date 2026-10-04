extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
var board: Control
var capture_view: SubViewport
var font: Font
var roster: Dictionary
var specimen_size: Vector2i = Vector2i(112,80)
var card_height: float = 455.0
var row_pitch: float = 474.0
var zoom_y: float = 126.0

class Specimen:
	extends "res://scripts/world_view.gd"
	var mark_muzzle: bool = false
	func _draw() -> void:
		_draw_players()
		_draw_projectiles()
		_draw_effects()
		if mark_muzzle:
			var player: Dictionary = _frame.players[1]
			var tip: Vector2 = world_to_screen(weapon_draw_pose(player).muzzle)
			draw_circle(tip,2.0,Color("f785b2"),false,0.75,true)

func _initialize() -> void:
	call_deferred("_run")

func _label(parent: Node, text: String, position: Vector2, size: int, tint: Color = Color("e3ecda")) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)

func _page(title: String, subtitle: String) -> void:
	if is_instance_valid(board):
		capture_view.remove_child(board)
		board.queue_free()
	board = Control.new()
	capture_view.add_child(board)
	var background := ColorRect.new()
	background.color = Color("081e28")
	background.size = Vector2(capture_view.size)
	board.add_child(background)
	_label(board,title,Vector2(32,20),32)
	_label(board,subtitle,Vector2(34,64),17,Color("99b7b4"))

func _player(weapon: String, items: Dictionary = {}, aim: Vector2 = Vector2.RIGHT) -> Dictionary:
	var player: Dictionary = roster.duplicate(true)
	player.pos = Vector2(40,47)
	player.aim = aim
	player.weapon = weapon
	player.items = items.duplicate(true)
	player.vel = Vector2.ZERO
	player.invuln = 0.0
	player.grounded = true
	return player

func _specimen(parent: Node, player: Dictionary, show_flash: bool = false, remote: bool = false) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = specimen_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var view := Specimen.new()
	view.screen_size = Vector2(viewport.size)
	view.camera_position = Vector2(viewport.size) * 0.5
	viewport.add_child(view)
	view.set_process(false)
	view._clock = 0.125
	view._local_id = 1
	view._frame = {"players":{1:player},"enemies":[],"projectiles":[]}
	if remote:
		view.interpolate_remote_entities = true
		view._local_id = 99
		view._render_positions = {"p1":Vector2(player.pos)+Vector2(6,0)}
	if show_flash:
		view.mark_muzzle = true
		var weapon: String = player.weapon
		var kind: String = {"pulse_rifle":"bullet","scattergun":"scattergun","railgun":"railgun","flamethrower":"flame","boomerang":"boomerang","storm_staff":"storm","sun_lance":"lance","arc_blade":"arc_blade"}[weapon]
		view.push_events([{"type":"slash" if weapon in ["arc_blade","flamethrower"] else "shoot","kind":kind,"weapon":weapon,"player":1,"pos":Pose.muzzle_position(player),"aim":player.aim,"radius":170.0 if weapon == "flamethrower" else 105.0}])
		# Keep the short flash visible at a fixed post-shot time for inspection.
		for effect: Dictionary in view._effects: effect.age = 0.025
		if weapon not in ["arc_blade","flamethrower","boomerang"]:
			var muzzle: Vector2 = view.weapon_draw_pose(player).muzzle
			var velocity: Vector2 = Vector2(player.aim)*1100.0
			view._frame.projectiles = [{"id":1,"pos":muzzle+player.aim*8.0,"origin":muzzle,"travel_distance":8.0,"vel":velocity,"team":"player","kind":"lance" if weapon=="sun_lance" else ("rail" if weapon=="railgun" else "bullet"),"radius":3.0,"owner":1}]
	view.queue_redraw()
	return viewport

func _card(index: int, title: String, player: Dictionary, note: String = "", flash: bool = false, remote: bool = false) -> void:
	var x: float = 28.0 + (index % 4)*500.0
	var y: float = 110.0 + (index / 4)*row_pitch
	var card := Panel.new()
	card.position = Vector2(x,y)
	card.size = Vector2(486,card_height)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102b34")
	style.border_color = Color("29464d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	card.add_theme_stylebox_override("panel",style)
	board.add_child(card)
	_label(card,title,Vector2(16,10),21)
	_label(card,"1×",Vector2(18,48),14,Color("91a9a9"))
	_label(card,"4×",Vector2(18,zoom_y+8),14,Color("91a9a9"))
	if not note.is_empty(): _label(card,note,Vector2(184,61),14,Color("a7c5b7"))
	var viewport: SubViewport = _specimen(card,player,flash,remote)
	for entry: Array in [[Vector2(52,39),Vector2(specimen_size)],[Vector2(20,zoom_y),Vector2(specimen_size)*4.0]]:
		var picture := TextureRect.new()
		picture.texture = viewport.get_texture()
		picture.position = entry[0]
		picture.size = entry[1]
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.add_child(picture)

func _capture(name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/results/v06-"+name+".png"
	capture_view.get_texture().get_image().save_png(path)
	print("APPEARANCE_CAPTURE ",path)

func _run() -> void:
	root.size = Vector2i(1280,720)
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(2048,1080)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	var face := FontVariation.new()
	face.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	face.variation_opentype = {2003265652:500.0}
	font = face
	var simulation = Simulation.new()
	simulation.start_run([{"id":1,"name":"","character":"ranger"}],606)
	roster = simulation.state.players[1]
	_page("SomeSide / 八种主武器", "同一个旅者、实际 112×80 视口；上方原生 1×，下方最近邻放大 4×。武器轮廓与材质使用独立功能色。")
	var weapons: Array = Content.weapons()
	for index: int in range(weapons.size()):
		_card(index,str(weapons[index].name),_player(str(weapons[index].id)))
	await _capture("weapons")
	var mixed: Dictionary = {"feather":1,"arc":1,"vitality":1,"lens":1,"magnet":1,"moss":1}
	var full: Dictionary = {}
	for entry: Dictionary in Content.passives(): full[entry.id]=99
	_page("SomeSide / 遗物成为装备的一部分", "背、肩、胸、头、腰、腿最多六槽；同槽按稀有度与层数选择，99 层也保持小尺寸角色轮廓。")
	var appearances: Array = [
		["空装旅者",{},"基础轮廓"], ["跃迁羽翼",{"feather":1},"背部 · 单件"],
		["矢量推进器",{"thruster":4},"背部 · 4 层"], ["电弧线圈",{"arc":1},"肩部 · 单件"],
		["目镜与共生核心",{"lens":1,"vitality":1},"头部 / 胸部"], ["磁环与星苔",{"magnet":1,"moss":1},"腰部 / 腿部"],
		["六槽混合",mixed,"六件分布可辨"], ["全道具 ×99",full,"尺寸增长封顶 12%"],
	]
	for index: int in range(appearances.size()):
		_card(index,appearances[index][0],_player("pulse_rifle",appearances[index][1]),appearances[index][2])
	await _capture("appearance")
	capture_view.size = Vector2i(2048,1420)
	specimen_size = Vector2i(112,112)
	card_height = 624.0
	row_pitch = 645.0
	zoom_y = 170.0
	_page("SomeSide / 枪口、准线与弹尾", "粉色小圈是共享枪口位置；左右与上下瞄准、运动姿态、远端插值均共用同一肩点。弹尾只显示已飞行距离。")
	var directions: Array = [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,0.6).normalized(),Vector2(-1,0.6).normalized()]
	var direction_weapons: Array = ["pulse_rifle","scattergun","railgun","flamethrower","storm_staff","sun_lance","arc_blade","boomerang"]
	for index: int in range(8):
		var player: Dictionary = _player(direction_weapons[index],mixed if index>=4 else {},directions[index])
		player.pos = Vector2(56,60)
		if index==2: player.pos.y=84
		if index==0 or index==4: player.vel=Vector2(180,0)
		if index>=4: player.character="vanguard"
		_card(index,str(Content.definition(direction_weapons[index]).name),player,"远端插值" if index==4 else ("运动中" if index==0 else "共用枪口"),true,index==4)
	await _capture("muzzles")
	quit()
