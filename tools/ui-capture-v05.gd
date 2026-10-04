extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	for index in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/results/v05-" + label + ".png"
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
	game._show_guide()
	await _capture("guide")
	game._start_solo()
	game.set_physics_process(false)
	game._notice_time = 0
	game._notice.text = ""
	game.sim.state.enemies.clear()
	game.sim.state.chests.clear()
	game.sim.state.pickups.clear()
	var player: Dictionary = game.sim.state.players[1]
	player.items = {"overclock": 3, "glass": 1, "feather": 1, "plating": 2, "frost": 2}
	root.warp_mouse(Vector2(950, 300))
	game._update_hud()
	await _capture("compact-owned")
	for item in game.sim.item_catalog():
		player.items[item.id] = 2
	game._update_hud()
	await _capture("full-owned")
	root.warp_mouse(game._relic_tiles[0].control.get_global_rect().get_center())
	await _capture("hover")
	root.warp_mouse(Vector2(950, 300))
	for item_id in ["plating", "flamethrower", "boomerang", "meteor"]:
		game.sim.state.pickups.clear()
		game.sim._spawn_pickup(player.pos + Vector2(32, -18), "item", item_id, 1)
		await _capture("loot-" + item_id)
	game.sim.state.pickups.clear()
	game._show_inventory()
	await _capture("inventory-owned")
	for filter_key in ["passive", "weapon", "equipment"]:
		game._populate_inventory(filter_key)
		await _capture("inventory-" + filter_key)
		game._inventory_grid.get_parent().scroll_vertical = 100000
		await _capture("inventory-" + filter_key + "-end")
	game.sound.shutdown()
	await create_timer(0.15).timeout
	quit()
