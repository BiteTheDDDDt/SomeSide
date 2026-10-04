extends SceneTree

const Locale = preload("res://scripts/localization.gd")
var capture_view: SubViewport
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(1280,720)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke","localization-capture")
	capture_view.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	game.profile.name = "Pilot"
	game.profile.runs = 0
	game.call("_set_language","en")
	game.call("_show_menu")
	game.world.set_frame(game.sim.get_snapshot(),1,1)
	game.world.queue_redraw()
	await _save("en-menu")
	game.call("_show_settings")
	await _save("en-settings")
	game.call("_show_guide")
	await _save("en-guide")
	game.call("_show_characters")
	await _save("en-characters")
	game.roster = []
	for id: int in range(1,5): game.roster.append({"id":id,"name":"WWWWWWWWWWWWWWWWWW","character":"vanguard","ready":id%2==0})
	game.hosting = true
	game.call("_show_lobby")
	await _save("en-lobby")
	game.hosting = false
	game.online = false
	game.call("_begin_local",[{"id":1,"name":"Pilot","character":"ranger"}],808)
	var player: Dictionary = game.sim.state.players[1]
	player.pos = Vector2(1800,1079)
	player.aim = Vector2(1,-0.14).normalized()
	player.invuln = 0.0
	player.coins = 12735
	for id: String in ["overclock","lens","feather","battery"]: game.sim._grant_item(player,id)
	game.sim._spawn_pickup(player.pos+Vector2(35,0),"item","glass",1)
	game.sim.state.time = 82.0
	var spitter: Dictionary = game.sim._spawn_enemy("spitter",player.pos+Vector2(330,0))
	game.sim._begin_enemy_attack(spitter,player)
	game.sim._release_enemy_attack(spitter,player)
	game.sim._step_projectiles(0.24)
	game.sim._fire_weapon(player)
	game.sim._step_projectiles(0.08)
	game.world.shake_enabled = false
	_refresh_field()
	await _save("en-game")
	game.call("_show_inventory")
	await _save("en-inventory")
	for category: String in ["passive","weapon","equipment"]:
		game.call("_populate_inventory",category)
		await _save("en-catalogue-"+category)
	game.call("_resume")
	game.call("_show_map")
	await _save("en-map")
	game.call("_resume")
	game.call("_show_pause")
	await _save("en-pause")
	game.call("_show_settings",true)
	await _save("en-settings-in-run")
	game.call("_set_language","zh")
	game.call("_resume")
	_refresh_field()
	await _save("zh-game")
	player.coins = 9876543210
	game.call("_update_hud")
	await _save("zh-coins-large")
	game.call("_show_settings",true)
	await _save("zh-settings")
	var current_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var current: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if current_exists else PackedByteArray()
	assert(current_exists==existed and current==saved,"Real UI captures must not alter user profile")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("CAPTURE_V08_RESULT native_opengl=true viewport=1280x720 profile_unchanged=true")
	quit(0)

func _refresh_field() -> void:
	game._notice_time = 0.0
	game._notice.hide()
	game._hud_clock = 1.0
	game.call("_process",0.0)
	game.world.set_frame(game.sim.get_snapshot(),1,1)
	game.world.camera_position = Vector2(1960,982)
	game.world._clock = 2.7
	game.world.queue_redraw()
	game.call("_update_hud")

func _save(label: String) -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://tools/results/v08-"+label+".png")
	assert(capture_view.get_texture().get_image().save_png(path)==OK,"Native OpenGL screenshot must save")
	print("CAPTURE_V08 ",path)
