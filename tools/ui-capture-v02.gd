extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _capture(name_text: String) -> void:
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/results/v02-" + name_text + ".png"
	root.get_texture().get_image().save_png(path)
	print("UI_CAPTURE ", path)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sound.enabled = false
	game.set_physics_process(false)
	await _capture("menu")
	game._show_guide()
	await _capture("guide")
	game._start_solo()
	game.set_physics_process(false)
	var player: Dictionary = game.sim.state.players[1]
	player.pos = Vector2(1020, 639)
	player.weapon = "railgun"
	player.equipment = "repair_field"
	player.skill_cd = 12.6
	player.coins = 82
	player.items = {"overclock": 3, "feather": 1, "lens": 2, "moss": 1, "capacitor": 2, "siphon": 1}
	game.sim.state.pickups.clear()
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "glass", 1)
	game.world.camera_position = player.pos
	game._notice_time = 0
	game._notice.text = ""
	await create_timer(0.3).timeout
	game._update_hud()
	await _capture("loot")
	game._show_inventory()
	await _capture("inventory")
	game._resume()
	game.sim.state.pickups.clear()
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "scattergun", 1)
	await _capture("weapon")
	game.sim.state.pickups.clear()
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "glass", 1)
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "feather", 1)
	game._cycle_interaction()
	await _capture("overlap")
	game._cycle_interaction()
	await _capture("overlap-first")
	game.sim.state.pickups.clear()
	for facility in ["blood", "choice", "combat"]:
		for chest in game.sim.state.chests:
			if chest.type == facility:
				player.pos = chest.pos + Vector2(-32, -4)
				game.world.camera_position = player.pos
				break
		await _capture(facility)
	game.sound.shutdown()
	await create_timer(0.15).timeout
	quit()
