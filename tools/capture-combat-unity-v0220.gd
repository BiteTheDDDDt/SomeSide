extends SceneTree

## Three authority-selected phases, at actual logical pixel size. Transient
## feedback is replayed from the real event history, never fabricated artwork.
const Base = preload("res://tools/capture-natural-warnings-v0201.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const World = preload("res://scripts/world_view.gd")
const CASES = Base.CASES
const DT: float = 1.0 / 60.0
const DIRECTORY: String = "res://tools/results/combat-unity-v0220/"
const PANEL: Vector2i = Vector2i(960, 540)

class BodiesOnly extends World:
	func _draw_threat_overlays() -> void: pass
	func _draw_projectiles() -> void: pass
	func _draw_effects() -> void: pass

static func fixture(attack: String, invulnerable: bool = true) -> Dictionary:
	var underlying: String = attack.trim_prefix("airborne_")
	var setup: Dictionary = Base.fixture("beam" if underlying=="crowd" else underlying, invulnerable and not ("--hit-demo" in OS.get_cmdline_user_args()))
	if underlying=="crowd":
		var sim = setup.sim
		var floor_y: float = sim.state.floor_y
		for data: Array in [["sentinel",1160.0,floor_y-165.0],["sentinel",1570.0,floor_y-17.0],["spitter",1080.0,floor_y-17.0],["spitter",1630.0,floor_y-17.0],["crawler",1210.0,floor_y-17.0],["crawler",1500.0,floor_y-17.0]]:
			var y: float = sim._surface_below(float(data[1]),float(data[2])-1.0)-17.0
			var added: Dictionary = sim._spawn_enemy(str(data[0]),Vector2(float(data[1]),y))
			added.grounded=true
			added.attack_cd=.25 if str(added.kind)=="sentinel" else .9
		setup.enemy.move_speed=55.0
		setup.camera=Vector2(1350.0,floor_y-170.0)
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
	var window: float = float(enemy.telegraph_max)
	for hazard: Dictionary in sim.state.hazards: window = maxf(window, float(hazard.delay))
	for tick: int in range(int(ceil(window / DT)) + 230):
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
		if not active and selected[0] < 0 and progress >= 0.6: selected[0] = tick
		if active and released_at >= 0 and tick - released_at >= (3 if has_hazard else 5) and selected[1] < 0: selected[1] = tick
		# Sample a true damaging frame at ~60ms into the .22s active window,
		# rather than inferring danger from a rounded display timer.
		if released_at >= 0 and tick - released_at >= 40 and (not has_hazard or ttl < 0.0) and (underlying != "spit" or sim.state.projectiles.is_empty()):
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
	var world = BodiesOnly.new() if "--bodies-only" in OS.get_cmdline_user_args() else World.new()
	world.screen_size = Vector2(PANEL)
	world.scenery_cache_enabled = false
	world.shake_enabled = false
	world.fx_scale = 0.0 if low else 1.0
	world.reduced_motion = low
	pane.add_child(world)
	if "--grayscale" in OS.get_cmdline_user_args():
		var shader := Shader.new()
		shader.code="shader_type canvas_item; void fragment(){ float y=dot(COLOR.rgb,vec3(0.2126,0.7152,0.0722)); COLOR=vec4(vec3(y),COLOR.a); }"
		var material_value := ShaderMaterial.new()
		material_value.shader=shader
		world.material=material_value
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
	var phase: String = ["WINDUP", "DAMAGE / RELEASE", "RECOVERED"][phase_index]
	var entry: Dictionary = sample.history[tick]
	label.text = "%s / %s / %s / 1x\nTick %d | delay %.3fs | active %s | ttl %.3fs" % [str(sample.attack).to_upper(), phase, "LOW FX" if low else "NORMAL", tick, entry.remaining, str(entry.active), entry.ttl]
	pane.add_child(label)

func _run() -> void:
	var verify: bool = "--verify-only" in OS.get_cmdline_user_args()
	var video: bool = "--video" in OS.get_cmdline_user_args() or "--video-only" in OS.get_cmdline_user_args()
	var video_only: bool = "--video-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify:
		push_error("Native capture required; use -- --verify-only to audit the real AI phases.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var attacks: Array = Array(CASES)
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
		if not verify and not video_only:
			var board := SubViewport.new()
			board.size = Vector2i(PANEL.x * 3, PANEL.y * 2)
			board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(board)
			for row: int in range(2):
				for column: int in range(3): _panel(board, sample, row == 1, column, Vector2(column * PANEL.x, row * PANEL.y))
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var suffix: String = "-gray" if "--grayscale" in OS.get_cmdline_user_args() else ("-bodies" if "--bodies-only" in OS.get_cmdline_user_args() else ("-hit" if "--hit-demo" in OS.get_cmdline_user_args() else ""))
			assert(board.get_texture().get_image().save_png(DIRECTORY + attack + suffix + ".png") == OK)
			board.queue_free()
			await process_frame
		FileAccess.open(DIRECTORY + attack + "-phases.json", FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
		report.append({"attack": attack, "ticks": sample.selected, "first_active_tick": sample.first_active_tick, "hazard": sample.has_hazard})
	if video and not verify:
		var film_attacks: Array = attacks
		for attack: String in film_attacks: await _film(attack)
	var result: Dictionary = {"passed": accepted, "native": not verify, "scale": 1.0, "panel_size": [960, 540],
		"attacks": report, "film_fps": 30, "film_size": [1280, 720], "simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
	var report_name: String = "verify.json" if verify else ("report.json" if selection.is_empty() else "selected-report.json")
	FileAccess.open(DIRECTORY + report_name, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("ATTACK_PHASES_CAPTURE_RESULT ", JSON.stringify(result))
	quit(0 if accepted else 1)

static func dodge_command(attack: String, tick: int, windup: float) -> Dictionary:
	var kind: String = attack.trim_prefix("airborne_")
	var elapsed: float = tick * DT
	var reacting: bool = elapsed >= 0.30
	var beam: bool = kind in ["beam", "prism_beam", "prism_cross"]
	var leap_tick: int = int(floor(maxf(0.35, windup - 0.10) / DT))
	# Use ordinary running and one jump; no item, dash, teleport or invulnerability.
	return {"move": 1.0 if reacting else 0.0,
		"jump": beam and tick == leap_tick, "jump_held": beam and tick >= leap_tick and tick < leap_tick + 32,
		"aim": Vector2.LEFT}

func _film(attack: String) -> void:
	var setup: Dictionary = fixture(attack, false)
	var sim = setup.sim
	var enemy: Dictionary = setup.enemy
	var definition: Dictionary = Enemies.definition(str(enemy.kind))
	enemy.move_speed = float(definition.get("speed", 78.0))
	# Keep generated platforms, vegetation, landmarks, atmosphere, live camera,
	# and all genuine enemy locomotion. This is normal gameplay scale in motion.
	var low: bool = "--low-fx-video" in OS.get_cmdline_user_args()
	var directory: String = DIRECTORY + "film-" + attack + ("-low" if low else "") + "/"
	DirAccess.make_dir_recursive_absolute(directory)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world = World.new()
	world.screen_size = Vector2(1280, 720)
	world.scenery_cache_enabled = false
	world.shake_enabled = false
	world.fx_scale = 0.0 if low else 1.0
	world.reduced_motion = low
	view.add_child(world)
	world.set_process(false)
	var strip := ColorRect.new()
	strip.size = Vector2(1280, 50)
	strip.color = Color("08141def")
	view.add_child(strip)
	var label := Label.new()
	label.position = Vector2(18, 6)
	label.add_theme_font_size_override("font_size", 17)
	view.add_child(label)
	var windup: float = float(enemy.telegraph_max)
	var ticks: int = int(ceil((windup + 2.0) / DT))
	var trace: Array = []
	for tick: int in range(ticks):
		var snapshot: Dictionary = sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		world._process(DT)
		world.set_frame(snapshot, 1, DT)
		world.push_events(sim.events)
		var active: bool = Array(snapshot.hazards).any(func(h: Dictionary) -> bool: return bool(h.active))
		var command: Dictionary = dodge_command(attack, tick, windup)
		label.text = "%s / real movement + generated scenery / 1x / %s\n%.2fs | remaining %.2fs | damage active %s | HP %.0f | move %.0f" % [attack.to_upper(), "LOW FX" if low else "NORMAL", tick * DT, maxf(0, windup - tick * DT), str(active), snapshot.players[1].hp, command.move]
		world.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(var_to_bytes(snapshot) == before)
		if tick % 2 == 0: assert(view.get_texture().get_image().save_png(directory + "frame-%03d.png" % (tick / 2)) == OK)
		trace.append({"tick":tick,"active":active,"hp":snapshot.players[1].hp,"position":snapshot.players[1].pos,"command":command,"hazards":snapshot.hazards,"events":sim.events.duplicate(true)})
		sim.step(DT, {1:command})
	FileAccess.open(directory + "trace.json", FileAccess.WRITE).store_string(JSON.stringify({"attack":attack,"windup":windup,"low_fx":low,"enemy_speed":enemy.move_speed,"generated_platform_count":sim.state.platforms.size(),"trace":trace}, "\t"))
	view.queue_free()
	await process_frame
