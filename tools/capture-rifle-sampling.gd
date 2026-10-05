extends SceneTree

## Direct native comparisons: no rendered screenshots are enlarged or retouched.
const Art = preload("res://scripts/weapon_art.gd")
const Simulation = preload("res://scripts/simulation.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const DIRECTORY: String = "res://tools/results/rifle-sampling/"
const ANGLES: Array[float] = [0.0,-PI/6,-PI/3,PI]
const CAPTIONS: Array[String] = ["水平", "上抬 30°", "上抬 60°", "朝左"]
var legacy_texture: CanvasTexture
var snapshot: Dictionary

class CharacterLane extends "res://scripts/world_view.gd":
	var legacy: bool = false
	var original: Texture2D
	func _ready() -> void:
		set_process(false)
		_font = ThemeDB.fallback_font
	func _draw_weapon(weapon: String, mechanism: float = 0.0, energy: float = 0.0) -> void:
		if legacy and weapon == "pulse_rifle":
			draw_texture_rect(original, Rect2(-6,-18,66,36), false)
		else:
			super._draw_weapon(weapon,mechanism,energy)
	func _draw() -> void:
		var ground: float = world_to_screen(Vector2(2000,600)).y
		draw_rect(Rect2(0,ground,screen_size.x,maxf(0,screen_size.y-ground)),Color("233a40"))
		draw_line(Vector2(0,ground),Vector2(screen_size.x,ground),Color("4c6864"),1.0)
		_draw_players()

class Gun extends Node2D:
	const WeaponArt = preload("res://scripts/weapon_art.gd")
	var original: Texture2D
	var legacy: bool = false
	var aim_angle: float = 0.0
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,aim_angle,Vector2(1,1 if cos(aim_angle)>=0 else -1))
		if legacy: draw_texture_rect(original, Rect2(-6,-18,66,36),false)
		else: WeaponArt.draw(self,"pulse_rifle")

class Page extends Node2D:
	var size: Vector2
	var title: String
	var subtitle: String
	var labels: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("0c1d26"))
		draw_string(FONT,Vector2(32,43),title,HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("e1e8d9"))
		draw_string(FONT,Vector2(32,77),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9eb7b4"))
		for entry: Array in labels:
			draw_string(FONT,entry[0],entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,int(entry[2]),Color("c7d9cf"))

func _initialize() -> void: _run.call_deferred()

func _viewport(size: Vector2i) -> SubViewport:
	var result := SubViewport.new()
	result.size = size
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(result)
	return result

func _page(view: SubViewport, title: String, subtitle: String) -> Page:
	var result := Page.new()
	result.size = Vector2(view.size)
	result.title = title
	result.subtitle = subtitle
	view.add_child(result)
	return result

func _lane(view: SubViewport, position: Vector2, physical_size: Vector2, zoom: float, legacy: bool, angle: float) -> CharacterLane:
	var clip := Control.new()
	clip.position = position
	clip.size = physical_size
	clip.clip_contents = true
	view.add_child(clip)
	var lane := CharacterLane.new()
	lane.legacy = legacy
	lane.original = legacy_texture
	lane.screen_size = physical_size / zoom
	lane.scale = Vector2(zoom,zoom)
	lane.scenery_cache_enabled = false
	lane._frame = snapshot.duplicate(true)
	lane._frame.players[1].aim = Vector2.from_angle(angle)
	lane._local_id = 99
	lane._clock = 0.7
	lane.camera_position = Vector2(2000,568)
	clip.add_child(lane)
	return lane

func _gun(view: SubViewport, position: Vector2, zoom: float, legacy: bool, angle: float) -> Gun:
	var gun := Gun.new()
	gun.position = position
	gun.scale = Vector2(zoom,zoom)
	gun.legacy = legacy
	gun.original = legacy_texture
	gun.aim_angle = angle
	view.add_child(gun)
	return gun

func _save(view: SubViewport, filename: String) -> void:
	for tick: int in range(2): await process_frame
	await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(DIRECTORY+filename) == OK)

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY+"frames/")
	# The exact prior implementation: crispEdges SVG, one texel per logical
	# pixel, nearest sampling. It does not depend on the new production cache.
	var bitmap := Image.new()
	assert(bitmap.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="66" height="36" viewBox="-6 -18 66 36" shape-rendering="crispEdges">'+Art._body("pulse_rifle")+'</svg>') == OK)
	legacy_texture = CanvasTexture.new()
	legacy_texture.diffuse_texture = ImageTexture.create_from_image(bitmap)
	legacy_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sim = Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],18019)
	sim.state.enemies.clear()
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(2000,579)
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 0.0
	player.weapon = "pulse_rifle"
	snapshot = sim.get_snapshot()
	var comparison := _viewport(Vector2i(1600,780))
	var page := _page(comparison,"初始步枪 · 渲染对照","同一造型、角色与瞄准角度；以下倍率直接在最终画布渲染，未放大截图。")
	page.labels.append([Vector2(116,125),"原版 · 像素采样",22])
	page.labels.append([Vector2(864,125),"试验 · 平滑采样",22])
	var rows: Array = [[1.0,166.0,126.0],[1.5,332.0,150.0],[2.0,523.0,191.0]]
	for entry: Array in rows:
		var zoom: float = entry[0]
		var y: float = entry[1]
		page.labels.append([Vector2(22,y+39),"%s×"%str(zoom),20])
		for side: int in range(2):
			for index: int in range(4):
				var x: float = 110+side*748+index*175
				page.labels.append([Vector2(x+42,y-12),CAPTIONS[index],14])
				_lane(comparison,Vector2(x,y),Vector2(168,entry[2]),zoom,side==0,ANGLES[index])
	page.queue_redraw()
	await _save(comparison,"comparison.png")
	comparison.queue_free()
	await process_frame
	var details := _viewport(Vector2i(1600,710))
	page = _page(details,"初始步枪 · 6× 局部放大","直接以 6 倍绘制原武器，用于看清轮廓与斜边；不代表正常游戏尺寸。")
	page.labels.append([Vector2(120,125),"原版 · 像素采样",22])
	page.labels.append([Vector2(868,125),"试验 · 平滑采样",22])
	for side: int in range(2):
		for index: int in range(4):
			var x: float = 120+side*748+(index%2)*350
			var y: float = 300+(index/2)*285
			page.labels.append([Vector2(x,y-120),CAPTIONS[index],15])
			var origin: Vector2 = Vector2(x+36,y)
			if index==3: origin.x+=180
			_gun(details,origin,6.0,side==0,ANGLES[index])
	page.queue_redraw()
	await _save(details,"detail-6x.png")
	details.queue_free()
	await process_frame
	var motion := _viewport(Vector2i(1100,900))
	page = _page(motion,"初始步枪 · 转动对照","上方：角色 2×　下方：武器 6×　两列始终使用相同角度。")
	var lanes: Array[CharacterLane] = []
	var guns: Array[Gun] = []
	for side: int in range(2):
		page.labels.append([Vector2(150+side*550,130),"原版 · 像素采样" if side==0 else "试验 · 平滑采样",22])
		lanes.append(_lane(motion,Vector2(125+side*550,155),Vector2(300,185),2.0,side==0,0))
		guns.append(_gun(motion,Vector2(260+side*550,620),6.0,side==0,0))
	page.queue_redraw()
	for tick: int in range(60):
		var angle: float = deg_to_rad(-60.0+270.0*float(tick)/59.0)
		for side: int in range(2):
			lanes[side]._frame.players[1].aim = Vector2.from_angle(angle)
			lanes[side].queue_redraw()
			guns[side].aim_angle = angle
			guns[side].queue_redraw()
		await _save(motion,"frames/turn-%03d.png"%tick)
	var current: CanvasTexture = Art._texture("pulse_rifle",Art._body("pulse_rifle"))
	var report: Dictionary = {"legacy_texture":str(legacy_texture.diffuse_texture.get_size()),"production_texture":str(current.diffuse_texture.get_size()),"legacy_sampler":legacy_texture.texture_filter,"production_sampler":current.texture_filter,"native_render_scales":[1,1.5,2,6],"angles_degrees":[0,-30,-60,180],"comparison_uses_shared_snapshot":true,"screenshots_resized":false,"frames":60,"frame_rate":30}
	FileAccess.open(DIRECTORY+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RIFLE_SAMPLING_CAPTURE_RESULT ",JSON.stringify(report))
	quit(0)
