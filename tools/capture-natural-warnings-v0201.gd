extends SceneTree

## Real AI -> immutable snapshots -> unmodified WorldView rendering. Every
## contact-sheet panel is 960x540 at 1:1 scale, never an enlarged preview.
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
const DT: float = 1.0 / 60.0
const DIRECTORY: String = "res://tools/results/natural-warnings-v0201/"
const PANEL_SIZE: Vector2i = Vector2i(960, 540)
const CASES: Array[String] = ["beam", "prism_beam", "prism_cross", "charge", "stone_charge", "pounce", "mortar", "burrow", "stone_spikes", "spore_bloom", "blink", "mend", "spit", "triple", "spore_volley"]

static func fixture(attack: String, invulnerable: bool = true) -> Dictionary:
	var stage: int = 1
	var kind: String = "crawler"
	var cycle: int = 0
	match attack:
		"beam": stage = 3; kind = "sentinel"
		"prism_beam", "prism_cross": stage = 3; kind = "boss"; cycle = 1 if attack == "prism_cross" else 0
		"charge": stage = 2; kind = "charger"
		"stone_charge", "stone_spikes": stage = 2; kind = "boss"; cycle = 1 if attack == "stone_charge" else 0
		"mortar": kind = "spore_moth"
		"burrow": stage = 2; kind = "burrower"
		"spore_bloom", "spore_volley": kind = "boss"; cycle = 1 if attack == "spore_bloom" else 0
		"blink": stage = 3; kind = "skirmisher"
		"mend": stage = 3; kind = "conductor"
		"spit": kind = "spitter"
		"triple": stage = 2; kind = "drone"
	var sim = Simulation.new()
	sim.start_run([{"id": 1, "name": "", "character": "ranger"}], 201007)
	if stage != 1: sim._build_stage(stage)
	sim.state.enemies.clear()
	sim.state.hazards.clear()
	sim.state.chests.clear()
	var floor_y: float = sim.state.floor_y
	var separation: float = 110.0 if attack == "pounce" else (175.0 if attack in ["charge", "stone_charge"] else 350.0)
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(1000.0 + separation, floor_y - 21.0)
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 1000.0 if invulnerable else 0.0
	sim._reset_exploration(player, false)
	var enemy: Dictionary = sim._spawn_enemy(kind, Vector2(1000.0, floor_y - (44.0 if kind == "boss" else 17.0)))
	if bool(enemy.flying): enemy.pos.y = floor_y - 115.0
	enemy.vel = Vector2.ZERO
	enemy.grounded = not bool(enemy.flying)
	enemy.attack_count = cycle
	enemy.attack_cd = 0.0
	# Freezing ordinary locomotion keeps the display isolated. Charge/pounce,
	# blink, projectiles, hazards and all attack timers retain authority rules.
	enemy.move_speed = 0.0
	if attack == "mend":
		for offset: float in [75.0, 130.0, -85.0, -135.0]:
			var ally: Dictionary = sim._spawn_enemy("sentinel", Vector2(1000.0 + offset, floor_y - 17.0))
			ally.hp = float(ally.max_hp) - 15.0
			ally.attack_cd = 9999.0
			ally.move_speed = 0.0
			ally.grounded = true
	sim.events.clear()
	# Trigger through the same AI decision branch used in a real encounter.
	sim.step(DT, {})
	return {"sim": sim, "enemy": enemy, "camera": Vector2(1000.0 + separation * 0.5 + 80.0, floor_y - 150.0)}

static func samples(attack: String) -> Dictionary:
	var setup: Dictionary = fixture(attack)
	var sim = setup.sim
	var enemy: Dictionary = setup.enemy
	var warning: Dictionary = {}
	var release: Dictionary = {}
	var warning_events: Array = []
	var release_events: Array = []
	var release_tick: int = -1
	var trace: Array = []
	for tick: int in range(150):
		var winding: bool = str(enemy.attack_kind) == attack and float(enemy.telegraph) > 0.0
		var progress: float = 1.0 - float(enemy.telegraph) / maxf(0.01, float(enemy.telegraph_max))
		if warning.is_empty() and winding and progress >= 0.76:
			warning = sim.get_snapshot()
			warning_events = sim.events.duplicate(true)
		if release.is_empty() and not winding and tick > 1:
			release = sim.get_snapshot()
			release_events = sim.events.duplicate(true)
			release_tick = tick
		trace.append({"tick": tick, "time": sim.state.time, "attack": enemy.attack_kind,
			"telegraph": enemy.telegraph, "charge": enemy.charge_timer,
			"hazards": sim.state.hazards.duplicate(true), "events": sim.events.duplicate(true), "player_hp": sim.state.players[1].hp})
		if not warning.is_empty() and not release.is_empty(): break
		sim.step(DT, {})
	return {"attack": attack, "warning": warning, "release": release,
		"warning_events": warning_events, "release_events": release_events,
		"release_tick": release_tick, "camera": setup.camera, "trace": trace}

func _initialize() -> void: _run.call_deferred()

func _panel(board: SubViewport, sample: Dictionary, low: bool, release: bool, position: Vector2) -> Dictionary:
	var container := SubViewportContainer.new()
	container.position = position
	container.size = Vector2(PANEL_SIZE)
	board.add_child(container)
	var pane := SubViewport.new()
	pane.size = PANEL_SIZE
	pane.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(pane)
	var world = World.new()
	world.screen_size = Vector2(PANEL_SIZE)
	world.shake_enabled = false
	world.scenery_cache_enabled = false
	world.fx_scale = 0.0 if low else 1.0
	world.reduced_motion = low
	pane.add_child(world)
	world.set_process(false)
	var snapshot: Dictionary = sample.release if release else sample.warning
	var before: PackedByteArray = var_to_bytes(snapshot)
	world.set_frame(snapshot, 1, 0.0)
	world._clock = float(snapshot.time)
	world.camera_position = sample.camera
	world.push_events(sample.release_events if release else sample.warning_events)
	world.queue_redraw()
	var strip := ColorRect.new()
	strip.size = Vector2(PANEL_SIZE.x, 36)
	strip.color = Color("0a151ce8")
	pane.add_child(strip)
	var caption := Label.new()
	caption.position = Vector2(15, 6)
	caption.add_theme_font_size_override("font_size", 18)
	caption.text = "%s / %s / %s / 1x" % [str(sample.attack).to_upper(), "RELEASE" if release else "PREPARATION", "LOW FX + REDUCED MOTION" if low else "NORMAL FX"]
	pane.add_child(caption)
	return {"state": snapshot, "before": before}

func _run() -> void:
	var verify: bool = "--verify-only" in OS.get_cmdline_user_args()
	var video: bool = "--video" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify:
		push_error("Native capture required; use -- --verify-only for AI sampling.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var report: Array = []
	var accepted: bool = true
	for attack: String in CASES:
		var sample: Dictionary = samples(attack)
		var complete: bool = not sample.warning.is_empty() and not sample.release.is_empty()
		accepted = accepted and complete
		if not complete: push_error("Missing real AI sample: " + attack); continue
		if not verify:
			var board := SubViewport.new()
			board.size = PANEL_SIZE * 2
			board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(board)
			var checks: Array = []
			for row: int in range(2):
				for column: int in range(2):
					checks.append(_panel(board, sample, row == 1, column == 1, Vector2(column * PANEL_SIZE.x, row * PANEL_SIZE.y)))
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			for check: Dictionary in checks: assert(var_to_bytes(check.state) == check.before, "World changed a shared network snapshot")
			assert(board.get_texture().get_image().save_png(DIRECTORY + attack + ".png") == OK)
			board.queue_free()
			await process_frame
		FileAccess.open(DIRECTORY + attack + "-trace.json", FileAccess.WRITE).store_string(JSON.stringify(sample.trace))
		report.append({"attack": attack, "release_tick": sample.release_tick, "windup": sample.warning.enemies[0].telegraph_max,
			"hazards": sample.warning.hazards.size(), "released_hazards": sample.release.hazards.size(), "shots": sample.release.projectiles.size()})
	if video and not verify:
		for attack: String in ["beam", "stone_spikes", "blink", "mend"]: await _film(attack)
	var result: Dictionary = {"passed": accepted, "native": not verify, "scale": 1.0, "panel_size": [960, 540],
		"attacks": report, "films": ["beam", "stone_spikes", "blink", "mend"] if video else [], "film_size": [1280, 720], "film_fps": 30,
		"simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
	FileAccess.open(DIRECTORY + ("verify.json" if verify else "report.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("NATURAL_WARNINGS_CAPTURE_RESULT ", JSON.stringify(result))
	quit(0 if accepted else 1)

func _film(attack: String) -> void:
	var setup: Dictionary = fixture(attack)
	var sim = setup.sim
	var directory: String = DIRECTORY + "film-" + attack + "/"
	DirAccess.make_dir_recursive_absolute(directory)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world = World.new()
	world.screen_size = Vector2(1280, 720)
	world.scenery_cache_enabled = false
	world.shake_enabled = false
	view.add_child(world)
	world.set_process(false)
	var strip := ColorRect.new()
	strip.size = Vector2(1280, 44)
	strip.color = Color("0a151ce8")
	view.add_child(strip)
	var caption := Label.new()
	caption.position = Vector2(22, 10)
	caption.add_theme_font_size_override("font_size", 20)
	view.add_child(caption)
	for tick: int in range(180):
		var snapshot: Dictionary = sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		world._process(DT)
		world.set_frame(snapshot, 1, DT)
		world.camera_position = setup.camera
		world.push_events(sim.events)
		caption.text = "%s / real AI preparation and release / normal 1x / %.2fs" % [attack.to_upper(), tick * DT]
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(var_to_bytes(snapshot) == before, "Film rendering modified authority state")
		if tick % 2 == 0:
			assert(view.get_texture().get_image().save_png(directory + "frame-%03d.png" % (tick / 2)) == OK)
		sim.step(DT, {})
	view.queue_free()
	await process_frame
