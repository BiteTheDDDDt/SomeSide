extends SceneTree

## Three authority-selected phases, at actual logical pixel size. Transient
## feedback is replayed from the real event history, never fabricated artwork.
const Base = preload("res://tools/capture-natural-warnings-v0201.gd")
const World = preload("res://scripts/world_view.gd")
const CASES = Base.CASES
const DT: float = 1.0 / 60.0
const DIRECTORY: String = "res://tools/results/attack-phases-v0202/"
const PANEL: Vector2i = Vector2i(960, 540)

static func fixture(attack: String, invulnerable: bool = true) -> Dictionary:
	var underlying: String = attack.trim_prefix("airborne_")
	var setup: Dictionary = Base.fixture(underlying, invulnerable)
	if attack.begins_with("airborne_"):
		var sim = setup.sim
		var enemy: Dictionary = setup.enemy
		# Re-arm the actual AI with its target already in the air. The attack
		# locks the real center; no hazard position or damage state is edited.
		sim._cancel_enemy_attack(enemy)
		if str(enemy.kind) == "boss": enemy.attack_count = maxi(0, int(enemy.attack_count) - 1)
		enemy.attack_cd = 0.0
		var player: Dictionary = sim.state.players[1]
		player.pos.y -= 120.0
		player.grounded = false
		player.vel = Vector2.ZERO
		sim.step(DT, {})
	return setup

static func phase_samples(attack: String) -> Dictionary:
	var underlying: String = attack.trim_prefix("airborne_")
	var setup: Dictionary = fixture(attack)
	var sim = setup.sim
	var enemy: Dictionary = setup.enemy
	var selected: Array[int] = [-1, -1, -1]
	var history: Array = []
	var released_at: int = -1
	var has_hazard: bool = not sim.state.hazards.is_empty()
	for tick: int in range(150):
		var active: bool = false
		var progress: float = 1.0 - float(enemy.telegraph) / maxf(0.01, float(enemy.telegraph_max))
		var remaining: float = float(enemy.telegraph)
		var ttl: float = -1.0
		if has_hazard:
			for hazard: Dictionary in sim.state.hazards:
				if int(hazard.owner) != int(enemy.id): continue
				active = bool(hazard.active)
				progress = 1.0 - float(hazard.delay) / maxf(0.01, float(hazard.telegraph_max))
				remaining = float(hazard.delay)
				ttl = float(hazard.ttl)
				break
		else:
			active = str(enemy.attack_kind) != underlying or float(enemy.telegraph) <= 0.0
		if active and released_at < 0: released_at = tick
		history.append({"tick": tick, "state": sim.get_snapshot(), "events": sim.events.duplicate(true),
			"active": active, "progress": progress, "remaining": remaining, "ttl": ttl})
		if not active and selected[0] < 0 and progress >= 0.18: selected[0] = tick
		if not active and selected[1] < 0 and progress >= 0.82: selected[1] = tick
		# Sample a true damaging frame at ~60ms into the .22s active window,
		# rather than inferring danger from the attacker's one-tick-later timer.
		if active and released_at >= 0 and tick - released_at >= 3:
			selected[2] = tick
			break
		sim.step(DT, {})
	return {"attack": attack, "selected": selected, "history": history, "has_hazard": has_hazard,
		"camera": setup.camera, "first_active_tick": released_at}

func _initialize() -> void: _run.call_deferred()

func _panel(board: SubViewport, sample: Dictionary, low: bool, phase_index: int, offset: Vector2) -> void:
	var container := SubViewportContainer.new()
	container.position = offset
	container.size = Vector2(PANEL)
	board.add_child(container)
	var pane := SubViewport.new()
	pane.size = PANEL
	pane.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(pane)
	var world = World.new()
	world.screen_size = Vector2(PANEL)
	world.scenery_cache_enabled = false
	world.shake_enabled = false
	world.fx_scale = 0.0 if low else 1.0
	world.reduced_motion = low
	pane.add_child(world)
	world.set_process(false)
	var tick: int = int(sample.selected[phase_index])
	for index: int in range(tick + 1):
		var entry: Dictionary = sample.history[index]
		var before: PackedByteArray = var_to_bytes(entry.state)
		world._process(DT)
		world.set_frame(entry.state, 1, DT)
		world.push_events(entry.events)
		assert(var_to_bytes(entry.state) == before, "Preview changed an authority snapshot")
	world.camera_position = sample.camera
	world.queue_redraw()
	var strip := ColorRect.new()
	strip.size = Vector2(PANEL.x, 50)
	strip.color = Color("08141def")
	pane.add_child(strip)
	var label := Label.new()
	label.position = Vector2(14, 5)
	label.add_theme_font_size_override("font_size", 16)
	var phase: String = ["EARLY READY", "LATE READY", "DAMAGE ACTIVE" if sample.has_hazard else "RELEASE"][phase_index]
	var entry: Dictionary = sample.history[tick]
	label.text = "%s / %s / %s / 1x\nTick %d | delay %.3fs | active %s | ttl %.3fs" % [str(sample.attack).to_upper(), phase, "LOW FX" if low else "NORMAL", tick, entry.remaining, str(entry.active), entry.ttl]
	pane.add_child(label)

func _run() -> void:
	var verify: bool = "--verify-only" in OS.get_cmdline_user_args()
	var video: bool = "--video" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify:
		push_error("Native capture required; use -- --verify-only to audit the real AI phases.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var attacks: Array = CASES.duplicate()
	attacks.append("airborne_mortar")
	var selection: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--cases="): selection = argument.trim_prefix("--cases=")
	if not selection.is_empty():
		attacks = Array(selection.split(",", false))
	var report: Array = []
	var accepted: bool = true
	for attack: String in attacks:
		var sample: Dictionary = phase_samples(attack)
		var complete: bool = not (-1 in sample.selected)
		accepted = accepted and complete
		if not complete: push_error("Missing attack phase: " + attack); continue
		var records: Array = []
		for index: int in range(3):
			var entry: Dictionary = sample.history[int(sample.selected[index])]
			records.append({"tick": entry.tick, "active": entry.active, "progress": entry.progress, "delay": entry.remaining, "ttl": entry.ttl,
				"hazards": entry.state.hazards.duplicate(true), "events": entry.events})
		if not verify:
			var board := SubViewport.new()
			board.size = Vector2i(PANEL.x * 3, PANEL.y * 2)
			board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(board)
			for row: int in range(2):
				for column: int in range(3): _panel(board, sample, row == 1, column, Vector2(column * PANEL.x, row * PANEL.y))
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			assert(board.get_texture().get_image().save_png(DIRECTORY + attack + ".png") == OK)
			board.queue_free()
			await process_frame
		FileAccess.open(DIRECTORY + attack + "-phases.json", FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
		report.append({"attack": attack, "ticks": sample.selected, "first_active_tick": sample.first_active_tick, "hazard": sample.has_hazard})
	if video and not verify:
		for attack: String in ["beam", "stone_spikes", "mortar", "burrow"]: await _film(attack)
	var result: Dictionary = {"passed": accepted, "native": not verify, "scale": 1.0, "panel_size": [960, 540],
		"attacks": report, "film_fps": 30, "film_size": [1280, 720], "simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
	var report_name: String = "verify.json" if verify else ("report.json" if selection.is_empty() else "selected-report.json")
	FileAccess.open(DIRECTORY + report_name, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("ATTACK_PHASES_CAPTURE_RESULT ", JSON.stringify(result))
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
	strip.color = Color("08141def")
	view.add_child(strip)
	var label := Label.new()
	label.position = Vector2(18, 10)
	label.add_theme_font_size_override("font_size", 19)
	view.add_child(label)
	for tick: int in range(180):
		var snapshot: Dictionary = sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		world._process(DT)
		world.set_frame(snapshot, 1, DT)
		world.camera_position = setup.camera
		world.push_events(sim.events)
		var active: bool = Array(snapshot.hazards).any(func(h: Dictionary) -> bool: return bool(h.active))
		label.text = "%s / genuine AI / 1x / %.2fs / hazard active: %s" % [attack.to_upper(), tick * DT, str(active)]
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(var_to_bytes(snapshot) == before)
		if tick % 2 == 0: assert(view.get_texture().get_image().save_png(directory + "frame-%03d.png" % (tick / 2)) == OK)
		sim.step(DT, {})
	view.queue_free()
	await process_frame
