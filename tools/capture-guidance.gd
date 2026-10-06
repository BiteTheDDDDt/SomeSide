extends SceneTree

## Native contact sheet of sampled authority trajectories, not painted paths.
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
const DT: float = 1.0 / 60.0
var samples: Array = []

func _initialize() -> void: _run.call_deferred()

func _sample(sim, title: String, camera: Vector2, tick: int) -> void:
	samples.append({"title": title, "state": sim.get_snapshot(), "events": sim.events.duplicate(true), "camera": camera, "tick": tick})

func _fresh(stage: int, position: Vector2):
	var sim = Simulation.new()
	sim.start_run([{"id": 1, "name": "Guide", "character": "ranger"}], 190019)
	if stage != 1: sim._build_stage(stage)
	var player: Dictionary = sim.state.players[1]
	player.pos = position
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 0.0
	sim._spawn_clock = 9999.0
	# This diagnostic view isolates the shot from facility hover labels.
	sim.state.chests.clear()
	sim.events.clear()
	return sim

func _run() -> void:
	var storm = _fresh(1, Vector2(1230, 1079))
	storm.state.time = 650.0
	storm._update_difficulty()
	var player: Dictionary = storm.state.players[1]
	player.weapon = "storm_staff"
	player.aim = Vector2.RIGHT
	var target: Dictionary = storm._spawn_enemy("spore_moth", Vector2(1580, 994))
	var health: float = target.hp
	storm._fire_weapon(player)
	_sample(storm, "STORM | launch: horizontal aim", Vector2(1400, 1005), 0)
	for tick: int in range(1, 80):
		storm.events.clear()
		storm.state.time += DT
		storm._step_projectiles(DT)
		if tick == 12: _sample(storm, "STORM | bounded correction", Vector2(1400, 1005), tick)
		if float(target.hp) < health:
			_sample(storm, "STORM | actual off-axis hit: %.0f damage" % (health - float(target.hp)), Vector2(1400, 1005), tick)
			break
	assert(samples.size() == 3)
	var hostile = _fresh(3, Vector2(4200, 579))
	var conductor: Dictionary = hostile._spawn_enemy("conductor", Vector2(3800, 579))
	hostile._begin_enemy_attack(conductor, hostile.state.players[1])
	for tick: int in range(52): hostile._step_enemies(DT)
	assert(hostile.state.projectiles.size() == 1)
	_sample(hostile, "CONDUCTOR | shot after 0.85s warning", Vector2(4060, 510), 0)
	for tick: int in range(1, 120):
		hostile.events.clear()
		hostile.state.time += DT
		hostile._move_player(hostile.state.players[1], {"jump": tick == 80, "jump_held": true}, DT)
		hostile._step_projectiles(DT)
		if tick == 35: _sample(hostile, "CONDUCTOR | slow, limited tracking", Vector2(4060, 510), tick)
		if tick == 110: _sample(hostile, "CONDUCTOR | base jump dodges: HP 100/100", Vector2(4060, 510), tick)
	assert(float(hostile.state.players[1].hp) == 100.0 and samples.size() == 6)
	var output := SubViewport.new()
	output.size = Vector2i(1920, 720)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var worlds: Array = []
	var audit: Array = []
	for index: int in range(samples.size()):
		var sample: Dictionary = samples[index]
		var container := SubViewportContainer.new()
		container.position = Vector2((index % 3) * 640, (index / 3) * 360)
		container.size = Vector2(640, 360)
		output.add_child(container)
		var pane := SubViewport.new()
		pane.size = Vector2i(640, 360)
		pane.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(pane)
		var world = World.new()
		world.set_process(false)
		world.screen_size = Vector2(640, 360)
		world.shake_enabled = false
		world.scenery_cache_enabled = false
		pane.add_child(world)
		world.set_process(false)
		var before: PackedByteArray = var_to_bytes(sample.state)
		world.set_frame(sample.state, 1, 0.0)
		world.camera_position = sample.camera
		world.push_events(sample.events)
		world.queue_redraw()
		worlds.append(world)
		var panel := ColorRect.new()
		panel.size = Vector2(640, 34)
		panel.color = Color(0.025, 0.04, 0.06, 0.94)
		pane.add_child(panel)
		var label := Label.new()
		label.position = Vector2(10, 7)
		label.add_theme_font_size_override("font_size", 15)
		label.text = sample.title
		pane.add_child(label)
		audit.append({"title": sample.title, "tick": sample.tick, "player_hp": sample.state.players[1].hp,
			"shots": sample.state.projectiles.map(func(p: Dictionary): return {"id": p.id, "pos": [p.pos.x, p.pos.y], "vel": [p.vel.x, p.vel.y], "guidance": p.get("guidance", {})})})
		assert(var_to_bytes(sample.state) == before)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(output.get_texture().get_image().save_png("res://tools/results/guidance-native.png") == OK)
	FileAccess.open("res://tools/results/guidance-native.json", FileAccess.WRITE).store_string(JSON.stringify(audit, "\t"))
	output.queue_free()
	await process_frame
	print("GUIDANCE_CAPTURE_RESULT samples=6 hit=true dodge=true")
	quit(0)
