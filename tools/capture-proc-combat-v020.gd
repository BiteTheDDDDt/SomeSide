extends SceneTree

## Five separate 1:1 views of real authority triggers. No proc entities, damage,
## or feedback events are fabricated. --verify-only runs the same fixtures;
## --video also saves 90 frames per three-second scene for 30 FPS encoding.
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
const Rules = preload("res://scripts/proc_rules.gd")
const Locale = preload("res://scripts/localization.gd")
const DT: float = 1.0 / 60.0
const FRAMES: int = 180
const SIZE: Vector2i = Vector2i(960, 540)
const START: Vector2 = Vector2(1650, 1079)
const DIRECTORY: String = "res://tools/results/proc-combat-v020/"
const CASES: Array[String] = ["missile_pod", "landing_coil", "frost_halo", "pursuit_protocol", "reactive_plating"]
const TITLES: Dictionary = {
	"missile_pod": "SWARM POD  /  direct critical hit -> seeking missile",
	"landing_coil": "LANDING COIL  /  full base jump -> two ground waves",
	"frost_halo": "FROST HALO  /  direct kill -> three timed aura pulses",
	"pursuit_protocol": "RANGER  /  six main-weapon hits -> pursuit missile",
	"reactive_plating": "VANGUARD  /  30 HP lost -> 10 temporary shield"
}

func _initialize() -> void: _run.call_deferred()

func _target(sim, offset: Vector2, health: float) -> Dictionary:
	var enemy: Dictionary = sim._spawn_enemy("crawler", START + offset)
	enemy.hp = health
	enemy.max_hp = health
	enemy.move_speed = 0.0
	enemy.attack_cd = 9999.0
	enemy.grounded = true
	return enemy

func _fixture(kind: String):
	var sim = Simulation.new()
	var character: String = "vanguard" if kind == "reactive_plating" else "ranger"
	sim.start_run([{"id": 1, "name": "", "character": character}], 200021)
	# Keep the authored rainforest shelf and all collision geometry. Only
	# photography fixtures (stationary targets and a legal build) are directed.
	sim.state.chests.clear()
	sim._spawn_clock = 9999.0
	var player: Dictionary = sim.state.players[1]
	player.pos = START
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 0.0
	player.explore_anchor = START
	player.explore_sites = [START]
	Rules.reset(player)
	match kind:
		"missile_pod":
			sim._grant_item(player, "missile_pod")
			for stack: int in range(10): sim._grant_item(player, "lens")
			_target(sim, Vector2(240, 2), 500.0)
		"landing_coil":
			sim._grant_item(player, "landing_coil")
			_target(sim, Vector2(-115, 2), 100.0)
			_target(sim, Vector2(115, 2), 100.0)
		"frost_halo":
			sim._grant_item(player, "frost_halo")
			_target(sim, Vector2(-70, 2), 8.0)
			_target(sim, Vector2(82, 2), 100.0)
		"pursuit_protocol": _target(sim, Vector2(240, 2), 500.0)
		"reactive_plating": _target(sim, Vector2(240, 2), 100.0)
	sim.events.clear()
	return sim

func _command(kind: String, player: Dictionary, tick: int, activations: int) -> Dictionary:
	var command: Dictionary = {"aim": Vector2.RIGHT, "move": 0.0, "jump": false, "jump_held": true, "fire": false}
	match kind:
		"missile_pod": command.fire = tick >= 20 and activations == 0
		"landing_coil": command.jump = tick == 25
		"frost_halo":
			command.aim = Vector2.LEFT
			command.fire = tick == 20
		"pursuit_protocol": command.fire = tick >= 15 and int(player.attack_count) < 6
	return command

func _run() -> void:
	var verify_only: bool = "--verify-only" in OS.get_cmdline_user_args()
	var save_video: bool = "--video" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not verify_only:
		push_error("Use native rendering, or pass -- --verify-only for the authority fixture audit.")
		quit(2)
		return
	Locale.set_language("en")
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var reports: Array = []
	var all_ok: bool = true
	for kind: String in CASES:
		var sim = _fixture(kind)
		var player: Dictionary = sim.state.players[1]
		var initial: Dictionary = {}
		for enemy: Dictionary in sim.state.enemies: initial[int(enemy.id)] = float(enemy.hp)
		var view: SubViewport
		var world
		var status: Label
		if not verify_only:
			view = SubViewport.new()
			view.size = SIZE
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			world = World.new()
			world.screen_size = Vector2(SIZE)
			world.shake_enabled = false
			world.scenery_cache_enabled = false
			view.add_child(world)
			world.set_process(false)
			var backdrop := ColorRect.new()
			backdrop.size = Vector2(SIZE.x, 76)
			backdrop.color = Color(0.025, 0.04, 0.06, 0.94)
			view.add_child(backdrop)
			var title := Label.new()
			title.position = Vector2(22, 12)
			title.add_theme_font_size_override("font_size", 20)
			title.text = TITLES[kind]
			view.add_child(title)
			status = Label.new()
			status.position = Vector2(22, 43)
			status.add_theme_font_size_override("font_size", 15)
			view.add_child(status)
			if save_video: DirAccess.make_dir_recursive_absolute(DIRECTORY + kind)
		var activation_tick: int = -1
		var activations: int = 0
		var key_saved: bool = false
		var trace: Array = []
		for tick: int in range(FRAMES):
			sim.step(DT, {1: _command(kind, player, tick, activations)})
			if kind == "reactive_plating" and tick in [15, 55, 95, 135]:
				# Real hostile shot and continuous collision, with genuine HP
				# loss/knockback; the final shot consumes eight shield points.
				var shooter: Dictionary = sim.state.enemies[0]
				sim._enemy_shoot(shooter, (Vector2(player.pos) - Vector2(shooter.pos)).normalized(), 600.0, 8.0 if tick == 135 else 10.0, "spit")
			for event: Dictionary in sim.events:
				if event.type == "proc" and event.kind == kind:
					activations += 1
					if activation_tick < 0: activation_tick = tick
			var targets: Array = []
			for enemy: Dictionary in sim.state.enemies:
				targets.append({"id": enemy.id, "hp": enemy.hp, "slow": enemy.get("slow_factor", 1.0)})
			trace.append({"tick": tick, "hp": player.hp, "shield": player.reactive_shield,
				"height": START.y - float(player.pos.y), "primary_actions": player.attack_count,
				"events": sim.events.duplicate(true), "targets": targets,
				"shots": sim.state.projectiles.map(func(p: Dictionary): return {"id": p.id, "kind": p.kind, "pos": p.pos, "proc": p.get("proc", false)}),
				"auras": sim.state.proc_effects.size()})
			if verify_only: continue
			world._process(DT)
			var snapshot: Dictionary = sim.get_snapshot()
			var before: PackedByteArray = var_to_bytes(snapshot)
			world.set_frame(snapshot, 1, DT)
			world.camera_position = START + Vector2(95, -78)
			world.push_events(sim.events)
			status.text = "1:1 game scale  |  %.2fs  |  HP %d  |  shield %d  |  procs %d" % [tick * DT, player.hp, player.reactive_shield, activations]
			world.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(var_to_bytes(snapshot) == before, "Presentation changed the authority snapshot")
			var key_offset: int = 34 if kind == "frost_halo" else 8
			var save_key: bool = activation_tick >= 0 and tick == activation_tick + key_offset
			if save_key or (save_video and tick % 2 == 0):
				var picture: Image = view.get_texture().get_image()
				if save_key:
					assert(picture.save_png(DIRECTORY + kind + ".png") == OK)
					key_saved = true
				if save_video and tick % 2 == 0:
					assert(picture.save_png(DIRECTORY + kind + "/frame-%03d.png" % (tick / 2)) == OK)
		var damage: Dictionary = {}
		for enemy: Dictionary in sim.state.enemies: damage[str(enemy.id)] = float(initial[int(enemy.id)]) - float(enemy.hp)
		var accepted: bool = activations == 1 and (verify_only or key_saved)
		match kind:
			"landing_coil": accepted = accepted and damage.values() == [12.0, 12.0]
			"frost_halo": accepted = accepted and sim.state.kills == 1 and damage.values() == [24.0]
			"pursuit_protocol": accepted = accepted and int(player.attack_count) == 6 and float(damage.values()[0]) >= 56.0
			"reactive_plating": accepted = accepted and player.hp == 115.0 and player.reactive_shield == 2.0
			"missile_pod": accepted = accepted and float(damage.values()[0]) >= 34.0
		all_ok = all_ok and accepted
		reports.append({"kind": kind, "passed": accepted, "activation_tick": activation_tick, "activations": activations,
			"final_hp": player.hp, "final_shield": player.reactive_shield, "target_damage": damage, "primary_actions": player.attack_count})
		FileAccess.open(DIRECTORY + kind + "-trace.json", FileAccess.WRITE).store_string(JSON.stringify(trace))
		if view != null:
			view.queue_free()
			await process_frame
	var report: Dictionary = {"passed": all_ok, "native": not verify_only, "video_frames": 90 if save_video else 0,
		"fps": 30, "size": [SIZE.x, SIZE.y], "scale": 1.0, "frames_simulated": FRAMES, "scenes": reports,
		"simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
	FileAccess.open(DIRECTORY + ("verify.json" if verify_only else "report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PROC_COMBAT_CAPTURE_RESULT ", JSON.stringify(report))
	quit(0 if all_ok else 1)
