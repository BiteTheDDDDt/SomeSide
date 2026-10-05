extends SceneTree

## Native, deterministic 180-frame comparison. Both panels use the same real
## input direction and enemy; only the selected character changes the ability.
const Simulation = preload("res://scripts/simulation.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const DT: float = 1.0 / 60.0
const FRAMES: int = 180
const AIM: Vector2 = Vector2(0.8944272, -0.4472136)
const START: Vector2 = Vector2(800, 579)
const DIRECTORY: String = "res://tools/results/abilities-v017/"

class Lane extends "res://scripts/world_view.gd":
	var caption: String = ""
	var ability_title: String = ""
	var impacts: int = 0
	var peak_charge: float = 0.0
	var tick: int = 0
	var target_id: int = -1
	var start_position: Vector2 = Vector2.ZERO
	var aim_marker: Vector2 = Vector2.ZERO
	func _ready() -> void:
		set_process(false)
		_font = ThemeDB.fallback_font
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, screen_size), Color("0b1c24"))
		var tint: Color = TEAL if caption == "RANGER" else GOLD
		draw_line(Vector2(0, 0), Vector2(0, screen_size.y), Color("34515c"), 1.0)
		var floor_y: float = world_to_screen(Vector2(0, 600)).y
		draw_rect(Rect2(0, floor_y, screen_size.x, screen_size.y - floor_y), Color("263c45"))
		for world_x: int in range(650, 1300, 20):
			var x: float = world_to_screen(Vector2(world_x, 600)).x
			draw_line(Vector2(x, floor_y), Vector2(x, floor_y + 7), Color("52716c"), 1.0)
		var reference: Vector2 = world_to_screen(start_position)
		draw_line(Vector2(reference.x, floor_y - 3), Vector2(reference.x, floor_y + 16), Color(tint, 0.6), 1.0)
		var player: Dictionary = _frame.players[1]
		var shoulder: Vector2 = world_to_screen(weapon_draw_pose(player).shoulder)
		var marker: Vector2 = world_to_screen(aim_marker)
		draw_dashed_line(world_to_screen(start_position + Vector2(0, -5)), marker, Color(tint, 0.28), 1.0, 5.0)
		draw_circle(marker, 4, Color(tint, 0.65), false, 1.0)
		draw_line(marker - Vector2(7, 0), marker + Vector2(7, 0), Color(tint, 0.65), 1.0)
		draw_line(marker - Vector2(0, 7), marker + Vector2(0, 7), Color(tint, 0.65), 1.0)
		_draw_enemies()
		_draw_players()
		_draw_projectiles()
		_build_particle_batches()
		_draw_effects()
		var enemy: Dictionary = {}
		for candidate: Dictionary in _frame.enemies:
			if int(candidate.id) == target_id: enemy = candidate
		draw_string(_font, Vector2(15, 25), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, tint)
		draw_string(_font, Vector2(15, 45), ability_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)
		draw_string(_font, Vector2(15, 65), "Same input: still + aim up-right + SHIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("acc1b9"))
		var status: String = "READY" if tick < 45 else ("ACTIVE" if maxf(float(player.dash_timer), float(player.get("guard_timer", 0.0))) > 0.0 else "RECOVERY")
		draw_string(_font, Vector2(15, 86), "%s  |  cooldown %.1fs" % [status, float(player.dash_cd)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
		if not enemy.is_empty():
			draw_string(_font, Vector2(15, 106), "TARGET HP: %d / %d    counters: %d" % [int(enemy.hp), int(enemy.max_hp), impacts], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffcc8e") if impacts > 0 else CREAM)
			draw_string(_font, Vector2(15, 125), "HERO HP: %d    stored damage: %.0f" % [int(player.hp), peak_charge], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
			var target: Vector2 = world_to_screen(enemy.pos)
			_world_label(target + Vector2(0, -43), "%d HP" % int(enemy.hp), CREAM, 10)
			draw_rect(Rect2(target + Vector2(-23, -35), Vector2(46, 3)), Color("102029"))
			draw_rect(Rect2(target + Vector2(-23, -35), Vector2(46.0 * float(enemy.hp) / float(enemy.max_hp), 3)), tint)
		draw_string(_font, Vector2(15, 302), "Evade the incoming shot with movement" if caption == "RANGER" else "Brace in place / absorb shot / counter", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CREAM)
		draw_string(_font, Vector2(15, 320), "Travel %.0f px    actual simulation + renderer" % Vector2(player.pos).distance_to(start_position), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("acc1b9"))
		draw_rect(Rect2(15, 340, 290, 2), Color("34515c"))
		draw_rect(Rect2(15, 340, 290.0 * float(tick + 1) / 180.0, 2), tint)

func _initialize() -> void:
	_run.call_deferred()

func _simulation(character: String):
	var sim = Simulation.new()
	sim.start_run([{"id": 1, "name": "", "character": character}], 1616)
	sim.state.floor_y = 600.0
	sim.state.world_size = Vector2(2200, 720)
	sim.state.platforms = [Rect2(0, 600, 2200, 60)]
	sim.state.chests = []
	sim.state.enemies = []
	sim._spawn_clock = 9999.0
	var player: Dictionary = sim.state.players[1]
	player.pos = START
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 0.0
	player.aim = AIM
	player.explore_anchor = START
	player.explore_sites = [START]
	var enemy: Dictionary = sim._spawn_enemy("crawler", START + Vector2(70, 2))
	enemy.hp = 80.0
	enemy.max_hp = 80.0
	# A stationary target isolates the counter. A real enemy-team projectile
	# supplies the incoming attack; HP and charge are never injected afterward.
	enemy.move_speed = 0.0
	enemy.attack_cd = 9999.0
	enemy.elite = false
	return sim

func _run() -> void:
	var verify_only: bool = "--verify-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify_only:
		push_error("Native rendering is required. Use -- --verify-only for the physics fixture audit.")
		quit(2)
		return
	Pixels.reload_manifest()
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var views: Array = []
	var lanes: Array = []
	var sims: Array = []
	var counts: Array[int] = [0, 0]
	var starts: Array[int] = [0, 0]
	var blocks: Array[int] = [0, 0]
	for index: int in range(2):
		var character: String = "ranger" if index == 0 else "vanguard"
		var sim = _simulation(character)
		sims.append(sim)
		if verify_only: continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var lane := Lane.new()
		lane.screen_size = Vector2(320, 360)
		lane.scale = Vector2(2, 2)
		lane.scenery_cache_enabled = false
		lane.shake_enabled = false
		lane.caption = character.to_upper()
		lane.ability_title = "PHASE DASH" if index == 0 else "BULWARK COUNTER"
		lane.start_position = START
		lane.aim_marker = START + Vector2(0, -5) + AIM * 105
		lane.target_id = int(sim.state.enemies[0].id)
		viewport.add_child(lane)
		views.append(viewport)
		lanes.append(lane)
	var trace: Array = []
	for tick: int in range(FRAMES):
		var frame: Array = []
		for index: int in range(2):
			var sim = sims[index]
			if tick == 45:
				sim._spawn_projectile(START + Vector2(120, 0), Vector2(-600, 0), "enemy", "spit", 50.0, -1, 1.0, 6.0)
			sim.step(DT, {1: {"dash": tick == 45, "aim": AIM, "move": 0.0, "fire": false}})
			for event: Dictionary in sim.events:
				if event.type == "ability" and event.get("phase") == "release": counts[index] += 1
				elif event.type == "ability" and event.get("phase") == "block": blocks[index] += 1
				elif event.type == "ability" and event.get("phase") == "start": starts[index] += 1
				elif event.type == "dash" and event.has("ability"): starts[index] += 1
			var player: Dictionary = sim.state.players[1]
			var enemy: Dictionary = sim.state.enemies[0]
			frame.append({"character": player.character, "position": [player.pos.x, player.pos.y],
				"ability": player.dash_kind, "timer": player.dash_timer, "cooldown": player.dash_cd,
				"target_hp": enemy.hp, "target_stun": enemy.get("stun_timer", 0.0), "impacts": counts[index],
				"hero_hp": player.hp, "guard_timer": player.guard_timer, "guard_absorbed": player.guard_absorbed,
				"events": sim.events.map(func(event: Dictionary): return str(event.type))})
			if verify_only: continue
			var lane: Lane = lanes[index]
			lane.tick = tick
			lane.impacts = counts[index]
			lane.peak_charge = maxf(lane.peak_charge, float(player.guard_absorbed))
			lane._process(DT)
			lane._frame = sim.get_snapshot()
			lane._update_render_positions(DT)
			lane.camera_position = Vector2(895, 510)
			lane.push_events(sim.events)
			lane.queue_redraw()
		trace.append(frame)
		if verify_only: continue
		await process_frame
		await RenderingServer.frame_post_draw
		var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		for index: int in range(2):
			image.blit_rect(views[index].get_texture().get_image(), Rect2i(0, 0, 640, 720), Vector2i(index * 640, 0))
		image.save_png(DIRECTORY + "frame-%03d.png" % tick)
	var accepted: bool = starts == [1, 1] and counts == [0, 1] and blocks == [0, 1] and sims[0].state.enemies[0].hp == 80.0 and sims[1].state.enemies[0].hp == 38.0
	accepted = accepted and sims[0].state.players[1].hp == 100.0 and sims[1].state.players[1].hp == 135.0 and sims[1].state.players[1].pos == START
	var report: Dictionary = {"passed": accepted, "frames": FRAMES, "fps": 60, "native": not verify_only,
		"starts": starts, "impacts": counts, "blocks": blocks, "ranger_target_hp": sims[0].state.enemies[0].hp, "vanguard_target_hp": sims[1].state.enemies[0].hp,
		"hero_hp": [sims[0].state.players[1].hp, sims[1].state.players[1].hp], "vanguard_displacement": Vector2(sims[1].state.players[1].pos).distance_to(START),
		"simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd"), "actors_sha256": FileAccess.get_sha256("res://assets/sprites/actors.json")}
	FileAccess.open(DIRECTORY + ("verify.json" if verify_only else "report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	FileAccess.open(DIRECTORY + "trace.json", FileAccess.WRITE).store_string(JSON.stringify(trace))
	for viewport: SubViewport in views: viewport.queue_free()
	if not verify_only: await process_frame
	print("ABILITIES_CAPTURE_RESULT ", JSON.stringify(report))
	quit(0 if accepted else 1)
