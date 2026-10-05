extends SceneTree

const Locale = preload("res://scripts/localization.gd")
var capture_view: SubViewport
var game: Node
var captures: int = 0
var button_bounds: Dictionary = {}
var output_prefix: String = "res://tools/results/ui-style-"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): output_prefix = argument.trim_prefix("--prefix=")
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	capture_view = SubViewport.new()
	capture_view.size = Vector2i(1280, 720)
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke", "ui-release-capture")
	capture_view.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	game.profile.name = "Pilot"
	game.profile.runs = 0
	for language: String in ["zh", "en"]:
		Locale.set_language(language)
		game.profile.language = language
		game.profile.character = "ranger"
		game.profile.runs = 0
		game.profile.wins = 0
		game.profile.best_stage = 0
		for method: String in ["menu", "characters", "join", "guide", "settings"]:
			game.call("_show_" + method)
			game.world.set_frame(game.sim.get_snapshot(), 1, 1)
			game.world.queue_redraw()
			await _save(language + "-" + method)
		game.profile.character = "vanguard"
		game._show_characters()
		await _save(language + "-characters-vanguard")
		game.profile.character = "ranger"
		game._show_menu()
		_focus_first(game.ui)
		await _save(language + "-menu-focus")
		game.roster = []
		for id: int in range(1, 5):
			game.roster.append({"id": id, "name": ["Pilot", "Moss", "Nova", "Atlas"][id - 1], "character": "ranger" if id % 2 == 1 else "vanguard", "ready": id != 4})
		game.hosting = true
		game.call("_show_lobby")
		await _save(language + "-lobby")
		if language == "en":
			for member: Dictionary in game.roster: member.name = "WWWWWWWWWWWWWWWWWW"
			game.call("_show_lobby")
			await _save(language + "-lobby-long")
		game.hosting = false
		game.online = false
		game.call("_begin_local", [{"id": 1, "name": "Pilot", "character": "ranger"}], 808)
		var player: Dictionary = game.sim.state.players[1]
		player.pos = Vector2(1800, 1079)
		player.aim = Vector2(1, -0.14).normalized()
		player.invuln = 0.0
		player.coins = 12735
		for id: String in ["overclock", "glass", "feather", "battery"]: game.sim._grant_item(player, id)
		game.sim.state.time = 143.0
		game.world.shake_enabled = false
		game.call("_update_hud")
		game.world.set_frame(game.sim.get_snapshot(), 1, 1)
		game.world.camera_position = Vector2(1960, 982)
		game.world._clock = 2.7
		game.world.queue_redraw()
		for method: String in ["inventory", "map", "pause"]:
			game.call("_show_" + method)
			await _save(language + "-" + method)
			if language == "en" and method == "inventory":
				for category: String in ["passive", "weapon", "equipment"]:
					game.call("_populate_inventory", category)
					await _save(language + "-catalogue-" + category)
			game.call("_resume")
		game.call("_show_pause")
		game.call("_show_settings", true)
		await _save(language + "-settings-in-run")
		game.call("_resume")
		for phase: String in ["won", "lost"]:
			game.sim.state.stage = 3 if phase == "won" else 2
			game.sim.state.phase = phase
			game.call("_show_results")
			await _save(language + "-results-" + phase)
		if language == "en":
			for id: int in range(2, 5):
				game.sim.state.players[id] = player.duplicate(true)
			for actor: Dictionary in game.sim.state.players.values(): actor.name = "WWWWWWWWWWWWWWWWWW"
			game.call("_show_results")
			await _save(language + "-results-long")
		game.call("_begin_local", [{"id":1,"name":"Pilot","character":"vanguard"}], 1717)
		game.sim.state.players[1].invuln = 0.0
		game.sim.state.players[1].guard_timer = 0.5
		game.sim.state.players[1].guard_absorbed = 24.0
		game.call("_update_hud")
		game.world.set_frame(game.sim.get_snapshot(), 1, 1)
		game.world.queue_redraw()
		await _save(language + "-vanguard-hud")
		game.call("_show_inventory")
		await _save(language + "-vanguard-inventory")
	game._web_runtime = true
	for language: String in ["zh", "en"]:
		Locale.set_language(language)
		game.profile.language = language
		game.profile.runs = 0
		game.profile.wins = 0
		game._show_menu()
		await _save(language + "-web-menu")
		game._show_settings()
		await _save(language + "-web-settings")
	var bounds_file := FileAccess.open(output_prefix + "buttons.json", FileAccess.WRITE)
	bounds_file.store_string(JSON.stringify(button_bounds, "\t"))
	var current_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var current: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if current_exists else PackedByteArray()
	assert(current_exists == existed and current == saved, "Release captures must not alter the user's profile")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("CAPTURE_UI_STYLE_RESULT images=", captures, " native_opengl=true viewport=1280x720 profile_unchanged=true")
	quit(0)

func _save(label: String) -> void:
	captures += 1
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	button_bounds[label] = _button_rects(game.ui)
	var path: String = ProjectSettings.globalize_path(output_prefix + label + ".png")
	assert(capture_view.get_texture().get_image().save_png(path) == OK)
	print("CAPTURE_UI_STYLE ", path)

func _button_rects(parent: Node) -> Array:
	var result: Array = []
	for child: Node in parent.get_children():
		if child is Button and child.is_visible_in_tree():
			var rect: Rect2 = child.get_global_rect()
			result.append({"text": child.text, "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y, "cx": rect.get_center().x, "cy": rect.get_center().y})
		result.append_array(_button_rects(child))
	return result

func _focus_first(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is Button and child.text == Locale.text("单人游戏"):
			child.grab_focus()
			return true
		if _focus_first(child): return true
	return false
