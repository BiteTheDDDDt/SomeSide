extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _capture(name_text: String) -> void:
	for index in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/results/v04-" + name_text + ".png"
	root.get_texture().get_image().save_png(path)
	print("UI_CAPTURE ", path)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke", "ui")
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await _capture("menu")
	game._show_settings()
	await _capture("settings")
	game._show_guide()
	await _capture("guide")
	game._start_solo()
	game.set_physics_process(false)
	game._notice_time = 0
	game._notice.text = ""
	for stage in range(1, 4):
		game.sim._build_stage(stage)
		game.sim.state.time = (stage - 1) * 240.0
		game.sim._update_difficulty()
		game._update_hud()
		game._show_map()
		await _capture("map-" + str(stage))
		game._resume()
		var player: Dictionary = game.sim.state.players[1]
		game.world.camera_position = player.pos
		await _capture("field-" + str(stage))
	game.sound.shutdown()
	await create_timer(0.15).timeout
	quit()
