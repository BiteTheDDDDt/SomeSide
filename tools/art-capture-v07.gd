extends SceneTree

const Biomes = preload("res://scripts/biome_renderer.gd")
const Layouts = preload("res://scripts/stage_layouts.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/enemy_catalog.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
var capture_view: SubViewport
var font: Font

class Specimen:
	extends "res://scripts/world_view.gd"
	func _draw() -> void:
		_draw_enemies()
		_draw_players()
		_draw_effects()
		_draw_projectiles()
		_draw_threat_overlays()

class EnvironmentView:
	extends Node2D
	var screen_size: Vector2 = Vector2(1280,720)
	var camera_position: Vector2
	var layout: Dictionary
	func world_to_screen(p: Vector2) -> Vector2:
		return p-camera_position+screen_size*0.5
	func _draw() -> void:
		Biomes.background(self,layout.biome,camera_position,screen_size,layout.world_size,2.7)
		Biomes.landmarks(self,layout.landmarks,layout.biome,2.7)
		for index: int in range(layout.platforms.size()):
			Biomes.platform(self,layout.platforms[index],index,layout.biome,2.7,screen_size,layout.world_size)
		Biomes.atmosphere(self,layout.biome,camera_position,screen_size,2.7)

func _initialize() -> void:
	call_deferred("_run")

func _save(name_value: String) -> void:
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://tools/results/v07-"+name_value+".png")
	assert(capture_view.get_texture().get_image().save_png(path)==OK,"OpenGL capture must save")
	print("ART_V07_CAPTURE ",path)

func _run() -> void:
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(1280,720)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	if OS.get_cmdline_user_args().has("--full"):
		await _full_gallery()
		quit(0)
		return
	var cameras: Array[Vector2] = [Vector2(1940,970),Vector2(1940,2160),Vector2(4210,1550)]
	for stage: int in range(1,4):
		var view: EnvironmentView = EnvironmentView.new()
		view.layout = Layouts.build(stage)
		view.camera_position = cameras[stage-1]
		var original: PackedByteArray = var_to_bytes(view.layout)
		capture_view.add_child(view)
		await _save("environment-"+str(stage))
		if OS.get_cmdline_user_args().has("--sweep"):
			for platform: Rect2 in view.layout.platforms:
				for fraction: float in [0.03,0.97]:
					view.camera_position = Vector2(platform.position.x+platform.size.x*fraction,platform.position.y-165)
					view.camera_position.x = clampf(view.camera_position.x,640,view.layout.world_size.x-640)
					view.camera_position.y = clampf(view.camera_position.y,360,view.layout.world_size.y-330)
					view.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
			print("ART_V07_SWEEP stage=",stage," cameras=",view.layout.platforms.size()*2)
		assert(var_to_bytes(view.layout)==original,"Environment rendering must not alter layout")
		capture_view.remove_child(view)
		view.queue_free()
	print("ART_V07_ENVIRONMENT input_immutable=true layouts=3 viewport=1280x720")
	quit(0)

func _label(parent: Node, message: String, p: Vector2, pixels: int = 18, tint: Color = Color("dbe6df")) -> void:
	var label: Label = Label.new()
	label.text = message
	label.position = p
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)

func _board(title: String, note: String, size_value: Vector2i) -> Control:
	capture_view.size = size_value
	var board: Control = Control.new()
	capture_view.add_child(board)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("091d29")
	bg.size = Vector2(size_value)
	board.add_child(bg)
	_label(board,title,Vector2(30,18),30)
	_label(board,note,Vector2(32,64),17,Color("93acb1"))
	return board

func _picture(parent: Node, viewport: SubViewport, p: Vector2, scale_value: float) -> void:
	var image_rect: TextureRect = TextureRect.new()
	image_rect.texture = viewport.get_texture()
	image_rect.position = p
	image_rect.size = Vector2(viewport.size)*scale_value
	image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(image_rect)

func _specimen(parent: Node, snapshot: Dictionary, size_value: Vector2i, camera: Vector2 = Vector2.INF) -> SubViewport:
	var sub: SubViewport = SubViewport.new()
	sub.size = size_value
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(sub)
	var view: Specimen = Specimen.new()
	sub.add_child(view)
	view.set_process(false)
	view._frame = snapshot
	view._clock = 0.31
	view.screen_size = Vector2(size_value)
	view.camera_position = Vector2(size_value)*0.5 if not camera.is_finite() else camera
	view.queue_redraw()
	return sub

func _full_gallery() -> void:
	var face: FontVariation = FontVariation.new()
	face.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	face.variation_opentype = {2003265652:500.0}
	font = face
	var game: Node = load("res://main.tscn").instantiate()
	capture_view.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.enabled = false
	game.profile.fullscreen = false
	game._begin_local([{"id":1,"name":"旅者","character":"ranger"}],707)
	game.world.shake_enabled = false
	var positions: Array[Vector2] = [Vector2(1800,1079),Vector2(1940,2249),Vector2(4150,1659)]
	var cameras: Array[Vector2] = [Vector2(1960,982),Vector2(2150,2130),Vector2(4350,1544)]
	for stage: int in range(1,4):
		game.sim._build_stage(stage)
		game.sim.state.time = 64.0*stage
		game.sim.state.stage_time = 29.0
		game.sim.state.enemies = []
		game.sim.state.projectiles = []
		game.sim.state.hazards = []
		var p: Dictionary = game.sim.state.players[1]
		p.pos = positions[stage-1]
		p.aim = Vector2(1,-0.14).normalized()
		p.vel = Vector2(55,0)
		p.grounded = true
		p.invuln = 0.0
		p.weapon = ["pulse_rifle","scattergun","storm_staff"][stage-1]
		p.items = {"overclock":2,"feather":1,"lens":1,"battery":2}
		var pool: Array = Catalog.pool(game.sim.state.biome)
		for i: int in range(pool.size()):
			var at: Vector2 = p.pos+Vector2(180+i*150,-2)
			if stage==2: at.y -= 90.0*(i+1)
			if bool(Catalog.definition(pool[i]).flying): at.y -= 115.0
			var enemy: Dictionary = game.sim._spawn_enemy(pool[i],at)
			enemy.grounded = not bool(enemy.get("flying",false))
			enemy.attack_cd = 20.0
			game.sim._begin_enemy_attack(enemy,p)
			if str(enemy.attack_kind) in ["spit","triple","mend"]:
				game.sim._release_enemy_attack(enemy,p)
				enemy.telegraph = 0.0
		var boss: Dictionary = game.sim._spawn_enemy("boss",p.pos+Vector2(530,-184 if stage!=2 else -293))
		boss.grounded = stage==2
		boss.attack_count = 1 if stage==1 else 0
		game.sim._begin_enemy_attack(boss,p)
		game.sim._step_projectiles(0.18)
		game.sim._step_hazards(0.15)
		game.sim.events.clear()
		game.sim._fire_weapon(p)
		game.sim._step_projectiles(0.085)
		game.world._effects.clear()
		game.world._numbers.clear()
		var snapshot: Dictionary = game.sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		game.world.set_frame(snapshot,1,1)
		game.world.camera_position = cameras[stage-1]
		game.world._clock = 2.7
		game.world.push_events(game.sim.events)
		for fx: Dictionary in game.world._effects: fx.age = 0.025
		game._notice_time = 0
		game._notice.hide()
		game._update_hud()
		game.world.queue_redraw()
		await _save("battle-"+str(stage))
		assert(var_to_bytes(snapshot)==before,"Full game rendering must preserve snapshot")
		print("ART_V07_BATTLE stage=",stage," enemies=",snapshot.enemies.size()," hazards=",snapshot.hazards.size()," projectiles=",snapshot.projectiles.size())
	game.sound.shutdown()
	capture_view.remove_child(game)
	game.queue_free()
	await process_frame
	await _actors_gallery()
	await _enemies_gallery()
	await _danger_gallery()
	print("ART_V07_FULL_VERIFIED actual_game_ui=true native_subviewport=true input_immutable=true")

func _actors_gallery() -> void:
	var board: Control = _board("SOMESIDE / 旅者装备与轮廓", "原生 1× 与相同视口最近邻 4×：左右瞄准、轻重角色、饰件和运动姿态。",Vector2i(2048,1120))
	var sim: Variant = Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],708)
	var mixed: Dictionary = {"feather":4,"arc":4,"vitality":4,"lens":4,"magnet":4,"moss":4}
	var full: Dictionary = {}
	for entry: Dictionary in Simulation.item_catalog(): full[entry.id]=99
	for i: int in range(8):
		var p: Dictionary = sim.state.players[1].duplicate(true)
		p.pos = Vector2(67,58)
		p.aim = Vector2.RIGHT if i%2==0 else Vector2.LEFT
		p.character = "ranger" if i<4 else "vanguard"
		p.weapon = "pulse_rifle" if i<4 else "arc_blade"
		p.items = {} if i%4<2 else (mixed if i<4 else full)
		p.invuln = 0
		p.grounded = i%4!=3
		p.vel = Vector2(170,-110) if i%4==3 else Vector2.ZERO
		var origin: Vector2 = Vector2(32+(i%4)*504,114+(i/4)*490)
		_label(board,("游侠" if i<4 else "先锋")+" · "+("向右" if i%2==0 else "向左")+(" / 空装" if i%4<2 else " / 遗物"),origin,21)
		var viewport: SubViewport = _specimen(board,{"players":{1:p},"enemies":[],"projectiles":[],"hazards":[]},Vector2i(124,88))
		_picture(board,viewport,origin+Vector2(128,36),1)
		_picture(board,viewport,origin+Vector2(-2,131),4)
		_label(board,"1×",origin+Vector2(26,74),15,Color("849faa"))
		_label(board,"4×",origin+Vector2(26,122),15,Color("849faa"))
	await _save("players")
	capture_view.remove_child(board)
	board.queue_free()
	await process_frame

func _enemies_gallery() -> void:
	var board: Control = _board("SOMESIDE / 三种生态 · 九种敌人与三位首领", "均由权威模拟器生成。普通敌人原生 1× / 最近邻 3×，首领原生 1× / 最近邻 2×。",Vector2i(2048,1520))
	var sim: Variant = Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],709)
	for stage: int in range(1,4):
		sim._build_stage(stage)
		var kinds: Array = Catalog.pool(sim.state.biome)
		kinds.append("boss")
		for column: int in range(4):
			var boss: bool = column==3
			var size_value: Vector2i = Vector2i(170,154) if boss else Vector2i(124,108)
			var enemy: Dictionary = sim._spawn_enemy(kinds[column],Vector2(85,86) if boss else Vector2(62,57))
			enemy.vel = Vector2.LEFT*20
			var definition: Dictionary = Catalog.boss_definition(sim.state.biome) if boss else Catalog.definition(kinds[column])
			var origin: Vector2 = Vector2(32+column*504,114+(stage-1)*462)
			_label(board,str(definition.name),origin,23)
			_label(board,str(definition.get("attack_kind",definition.get("boss_style",""))),origin+Vector2(0,35),14,Color("95b0b5"))
			var viewport: SubViewport = _specimen(board,{"players":{},"enemies":[enemy],"projectiles":[],"hazards":[]},size_value)
			_picture(board,viewport,origin+Vector2(273,-5),1)
			_picture(board,viewport,origin+Vector2(42,115),2 if boss else 3)
			_label(board,"1×",origin+Vector2(244,33),14,Color("859ba5"))
			_label(board,"2×" if boss else "3×",origin+Vector2(10,119),14,Color("859ba5"))
	await _save("enemies")
	capture_view.remove_child(board)
	board.queue_free()
	await process_frame

func _danger_gallery() -> void:
	var board: Control = _board("SOMESIDE / 弹道与危险预警", "权威攻击锁定目标后形成预警；左列为预警，右列为同一攻击实际生效。完整射线包括两端圆头。",Vector2i(1760,1590))
	var sim: Variant = Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],710)
	var cases: Array = [[1,"spore_moth","孢子落点"],[2,"burrower","破土范围"],[3,"sentinel","定向光束"]]
	for row: int in range(3):
		sim._build_stage(int(cases[row][0]))
		sim.state.enemies = []
		sim.state.hazards = []
		var player: Dictionary = sim.state.players[1]
		player.pos = Vector2(333,float(sim.state.floor_y)-21.0)
		player.invuln = 99
		var enemy: Dictionary = sim._spawn_enemy(cases[row][1],Vector2(50,player.pos.y))
		enemy.grounded = true
		sim._begin_enemy_attack(enemy,player)
		sim._step_hazards(0.1)
		var warning: Dictionary = sim.get_snapshot()
		assert(not warning.hazards.is_empty(),"Actual enemy attack must produce warning")
		for tick: int in range(100):
			if bool(sim.state.hazards[0].active): break
			sim._step_hazards(0.02)
			enemy.telegraph = maxf(0,float(enemy.telegraph)-0.02)
		assert(not sim.state.hazards.is_empty() and bool(sim.state.hazards[0].active),"Actual attack must reach active frame")
		enemy.telegraph = 0.0
		sim._release_enemy_attack(enemy,player)
		var active: Dictionary = sim.get_snapshot()
		for column: int in range(2):
			var snapshot: Dictionary = warning if column==0 else active
			var viewport: SubViewport = _specimen(board,snapshot,Vector2i(820,212),Vector2(410,player.pos.y-8))
			var origin: Vector2 = Vector2(32+column*876,126+row*270)
			_label(board,str(cases[row][2])+(" / 预警" if column==0 else " / 生效"),origin,21)
			_picture(board,viewport,origin+Vector2(0,38),1)
	for column: int in range(2):
		var shots: Array = []
		var kinds: Array = ["bullet","pellet","rail","boomerang","storm","lance"] if column==0 else ["spit","crystal","pulse","energy","boss_spore_orb","boss_orb"]
		var base_y: int = 954+column*308
		_label(board,("玩家弹丸 · 白色硬芯与细尾" if column==0 else "敌方弹丸 · 暖色外壳与暗芯")+"　上 1× / 下 2×",Vector2(32,base_y),21)
		for index: int in range(kinds.size()):
			var p: Vector2 = Vector2(58+index*116,61)
			shots.append({"id":index+1,"pos":p,"origin":p-Vector2(60,0),"travel_distance":60.0,"vel":Vector2.RIGHT*1000,"kind":kinds[index],"team":"player" if column==0 else "enemy","radius":4.0 if column==0 else 6.0})
		var viewport: SubViewport = _specimen(board,{"players":{},"enemies":[],"projectiles":shots,"hazards":[]},Vector2i(740,112))
		_picture(board,viewport,Vector2(32,base_y+25),1)
		_picture(board,viewport,Vector2(32,base_y+114),2)
		for index: int in range(kinds.size()): _label(board,kinds[index],Vector2(105+index*232,base_y+280),15,Color("a4bcb7"))
	await _save("danger")
	capture_view.remove_child(board)
	board.queue_free()
	await process_frame
