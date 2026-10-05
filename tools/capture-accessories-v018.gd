extends SceneTree

## Actual WorldView player rendering at 1x and 4x. No simulated state edits are
## performed by drawing. --audit-only exercises all 72 baked equipment variants.
const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const Appearance = preload("res://scripts/player_appearance.gd")
var capture_view: SubViewport
var board: Control
var font: Font
var templates: Dictionary
var sources: Array[Dictionary] = []
var source_bytes: Array[PackedByteArray] = []
var passed: int = 0
var failed: int = 0

class Specimen:
	extends "res://scripts/world_view.gd"
	func _draw() -> void:
		_draw_players()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(message)

func _audit_cache() -> void:
	for id: String in Appearance.supported_items():
		var unique: Dictionary = {}
		for stack: int in [1,4,8,1000000]:
			var descriptor: Dictionary = Appearance.build({id:stack})[0]
			var original: PackedByteArray = var_to_bytes(descriptor)
			var piece: Dictionary = Appearance._piece(descriptor)
			var bitmap: Image = piece.texture.diffuse_texture.get_image()
			var used: Rect2i = bitmap.get_used_rect()
			_check(used.position==Vector2i.ZERO and used.size==bitmap.get_size() and used.has_area(), id+" cache is cropped to painted pixels")
			_check(var_to_bytes(descriptor)==original, id+" bake leaves descriptor unchanged")
			_check(piece.texture.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST, id+" equipment has its own nearest sampler")
			if stack==1000000:
				_check(unique[3]==piece.texture.get_instance_id(), id+" extreme stack reuses tier three")
			unique[int(descriptor.tier)] = piece.texture.get_instance_id()
		var low: Dictionary = Appearance._piece(Appearance.build({id:1})[0])
		var rect := Rect2(low.origin, Vector2(low.texture.get_size()))
		_check(rect.position.x>=-28.0 and rect.end.x<=13.0 and rect.position.y>=-26.0 and rect.end.y<=22.0, id+" stays attached to the original actor silhouette")
	var stats: Dictionary = Appearance.cache_stats()
	_check(stats.entries==72 and stats.maximum_entries==72, "The 24 items use exactly three bounded cached variants")
	_check(stats.bytes<150000, "Cropped equipment uses under 150kB across every item and tier")
	print("ACCESSORY_CACHE ", JSON.stringify(stats))

func _label(parent: Node, text_value: String, position: Vector2, size_value: int, tint: Color=Color("e3ecda")) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)

func _page(title: String, subtitle: String) -> void:
	if is_instance_valid(board):
		capture_view.remove_child(board)
		board.queue_free()
	board = Control.new()
	capture_view.add_child(board)
	var background := ColorRect.new()
	background.size = Vector2(capture_view.size)
	background.color = Color("081e28")
	board.add_child(background)
	_label(board,title,Vector2(32,20),32)
	_label(board,subtitle,Vector2(34,66),18,Color("96b4b2"))

func _player(character: String, items: Dictionary, aim: Vector2=Vector2.RIGHT) -> Dictionary:
	var player: Dictionary = templates[character].duplicate(true)
	player.pos = Vector2(45,47)
	player.aim = aim
	player.items = items.duplicate(true)
	player.vel = Vector2.ZERO
	player.invuln = 0.0
	player.grounded = true
	player.name = ""
	return player

func _card(index: int, title: String, player: Dictionary, note: String="") -> void:
	var card := Panel.new()
	card.position = Vector2(28+(index%4)*500,110+int(index/4)*474)
	card.size = Vector2(486,455)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102b34")
	style.border_color = Color("29464d")
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel",style)
	board.add_child(card)
	_label(card,title,Vector2(16,10),21)
	_label(card,"1×",Vector2(18,49),14,Color("90aba9"))
	_label(card,"4×",Vector2(18,134),14,Color("90aba9"))
	_label(card,note,Vector2(190,62),14,Color("a7c5b7"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(112,80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	card.add_child(viewport)
	var specimen := Specimen.new()
	viewport.add_child(specimen)
	specimen.set_process(false)
	specimen.screen_size = Vector2(viewport.size)
	specimen.camera_position = Vector2(viewport.size)*0.5
	specimen._local_id = 999
	specimen._clock = 0.125
	specimen._frame = {"players":{int(player.id):player},"enemies":[],"projectiles":[]}
	sources.append(specimen._frame)
	source_bytes.append(var_to_bytes(specimen._frame))
	specimen.queue_redraw()
	for zoom: int in [1,4]:
		var picture := TextureRect.new()
		picture.texture = viewport.get_texture()
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.position = Vector2(52,39) if zoom==1 else Vector2(20,126)
		picture.size = Vector2(viewport.size)*float(zoom)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.add_child(picture)

func _capture(name: String) -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = capture_view.get_texture().get_image()
	var path: String = "res://tools/results/v018-accessories-"+name+".png"
	_check(image.save_png(path)==OK,"Native contact sheet saved: "+name)
	for index: int in range(sources.size()):
		_check(var_to_bytes(sources[index])==source_bytes[index],"Actual WorldView draw is read-only for specimen "+str(index))
	sources.clear()
	source_bytes.clear()
	print("ACCESSORY_CAPTURE ",ProjectSettings.globalize_path(path))

func _run() -> void:
	_audit_cache()
	if "--audit-only" in OS.get_cmdline_user_args():
		print("ACCESSORY_ART_RESULT passed=",passed," failed=",failed)
		quit(0 if failed==0 else 1)
		return
	root.size = Vector2i(1280,720)
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(2048,1080)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	font = load("res://assets/fonts/NotoSansSC.ttf")
	var simulation = Simulation.new()
	simulation.start_run([{"id":1,"name":"","character":"ranger"},{"id":2,"name":"","character":"vanguard"}],18181)
	templates = {"ranger":simulation.state.players[1],"vanguard":simulation.state.players[2]}
	var full: Dictionary = {}
	for definition: Dictionary in Content.passives(): full[str(definition.id)]=99
	var mixed: Dictionary = {"feather":1,"arc":1,"vitality":1,"lens":1,"magnet":1,"moss":1}
	_page("SomeSide / 贴身拾荒装备", "真实 WorldView 角色：原生 1× 与最近邻 4×，裸装、六槽和极限叠层保持相同脸部与持械轮廓。")
	for character: String in ["ranger","vanguard"]:
		var base: int = 0 if character=="ranger" else 4
		var name_value: String = "游侠" if character=="ranger" else "先锋"
		_card(base,name_value+" · 裸装",_player(character,{}),"原始角色")
		_card(base+1,name_value+" · 六槽组合",_player(character,mixed),"贴身装备 · 每件 1 层")
		_card(base+2,name_value+" · 全遗物 ×99",_player(character,full),"仍只有 6 个饰件")
		var left: Dictionary = _player(character,full,Vector2(-1,-0.28).normalized())
		left.pos.x = 70.0
		_card(base+3,name_value+" · 转向",left,"镜像与斜向持械")
	await _capture("comparison")
	var ids: Array = Appearance.supported_items().keys()
	for page: int in range(3):
		_page("SomeSide / 24 件遗物 · "+str(page+1)+" / 3", "同一真实玩家与主武器；装备功能色沿用图标。背部/肩部/头盔均无悬浮光球或高立杆。")
		for index: int in range(8):
			var id: String = str(ids[page*8+index])
			var character: String = "ranger" if index<4 else "vanguard"
			var definition: Dictionary = Content.definition(id)
			_card(index,str(definition.name),_player(character,{id:1}),id+" · 1 层")
		await _capture("catalog-"+str(page+1))
	print("ACCESSORY_ART_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
