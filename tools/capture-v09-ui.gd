extends SceneTree

var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var profile: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	game = load("res://main.tscn").instantiate()
	game._smoke = "ui-capture-v09"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	for language in ["en", "zh"]:
		game._set_language(language)
		game._show_guide()
		await _capture(language + "-guide")
	game._begin_local([{"id": 1, "name": "Pilot", "character": "ranger"}], 909)
	game._notify("", 0.0)
	var player: Dictionary = game.sim.state.players[1]
	player.coins = 12735
	game.sim._grant_item(player, "glass")
	game.sim._spawn_pickup(player.pos + Vector2(30, 0), "item", "feather", 1)
	await _capture("zh-game")
	assert(FileAccess.file_exists("user://profile.cfg") == existed)
	assert((FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()) == profile)
	game.queue_free()
	await process_frame
	print("UI_CAPTURE_V09_COMPLETE")
	quit()

func _capture(label: String) -> void:
	for frame in range(12):
		game._process(1.0 / 120.0)
		await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://tools/results/v09-" + label + ".png")
	assert(error == OK)
