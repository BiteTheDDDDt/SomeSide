extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Gait = preload("res://scripts/player_gait.gd")
const CASES: Array[String] = ["FORWARD", "BACKPEDAL", "RUN + JUMP", "BACKPEDAL + FIRE"]

class Lane extends "res://scripts/world_view.gd":
	var caption: String = ""
	var sample_label: String = ""
	func _ready() -> void:
		set_process(false)
		_font = ThemeDB.fallback_font
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,screen_size),Color("0b1c24"))
		var floor_y: float = world_to_screen(Vector2(0,600)).y
		if floor_y < screen_size.y:
			draw_rect(Rect2(0,floor_y,screen_size.x,maxf(0,screen_size.y-floor_y)),Color("263c45"))
			for x: int in range(0,5000,20):
				var sx: float = world_to_screen(Vector2(x,600)).x
				if sx >= 0 and sx < screen_size.x: draw_line(Vector2(sx,floor_y),Vector2(sx,floor_y+7),Color("44615d"))
		_draw_players()
		_draw_projectiles()
		_build_particle_batches()
		_draw_effects()
		draw_string(_font,Vector2(5,12),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("dce4d3"))
		draw_string(_font,Vector2(5,24),sample_label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("acc1b9"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	Pixels.reload_manifest()
	var page: String = "articulated"
	var mirrored: bool = "mirrored" in OS.get_cmdline_user_args()
	if mirrored: page += "-left"
	var directory: String = "res://tools/results/gait-v017/" + page + "/"
	DirAccess.make_dir_recursive_absolute(directory)
	var views: Array = []
	var lanes: Array = []
	var sims: Array = []
	for index: int in range(8):
		var sim = Simulation.new()
		var character: String = "ranger" if index < 4 else "vanguard"
		sim.start_run([{"id":1,"name":"","character":character}],1501)
		sim.state.floor_y = 600.0
		sim.state.world_size = Vector2(5000,720)
		sim.state.platforms = [Rect2(0,600,5000,60)]
		sim.state.enemies.clear()
		sim.state.chests.clear()
		var player: Dictionary = sim.state.players[1]
		player.pos = Vector2(2200,579)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 0.0
		player.weapon = "pulse_rifle" if character == "ranger" else "arc_blade"
		player.aim = Vector2.LEFT if mirrored else Vector2.RIGHT
		var view := SubViewport.new()
		view.size = Vector2i(400,450)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var lane := Lane.new()
		lane.screen_size = Vector2(160,180)
		lane.scale = Vector2(2.5,2.5)
		lane.scenery_cache_enabled = false
		lane.caption = character + " / " + CASES[index % 4]
		view.add_child(lane)
		views.append(view)
		lanes.append(lane)
		sims.append(sim)
	var trace: Array = []
	for tick: int in range(180):
		var frame_trace: Array = []
		for index: int in range(8):
			var sim = sims[index]
			var player: Dictionary = sim.state.players[1]
			sim.events.clear()
			sim.state.time = float(tick)/60.0
			var travel: float = -1.0 if index % 4 in [1,3] else 1.0
			if index % 4 in [0,1] and tick >= 90 and tick < 120: travel = 0.0
			var command: Dictionary = {"fire":index % 4 == 3 and tick >= 12, "aim":player.aim,
				"move":travel * (-1.0 if mirrored else 1.0),
				"dash":player.character=="vanguard" and index%4==3 and tick==45,
				"jump":tick in [30,120] and index % 4 == 2, "jump_held":tick % 90 < 48}
			sim._step_player(player,command,1.0/60.0)
			sim._step_projectiles(1.0/60.0)
			var lane: Lane = lanes[index]
			lane._process(1.0/60.0)
			lane._frame = sim.get_snapshot()
			lane._update_render_positions(1.0/60.0)
			lane.camera_position = lane._entity_draw_position("p1",player.pos) - Vector2(0,12)
			lane.push_events(sim.events)
			var pose: Dictionary = lane.weapon_draw_pose(player)
			var action: Dictionary = pose.melee if bool(pose.melee.active) else pose.ranged
			var anim: Dictionary = Pixels.tracked_frame_for(lane, player.character, player, lane._clock, true)
			lane.sample_label = (str(action.get("phase","ready")) + "  " + ("air" if not player.grounded else ("run" if absf(player.vel.x)>15 else "ground")))
			if float(player.get("guard_timer",0))>0: lane.sample_label += " / guard"
			var displayed: Dictionary = player.duplicate(false)
			displayed.pos = pose.position
			displayed.aim = pose.aim
			var gait: Dictionary = Gait.sample(lane, displayed, lane._clock, str(anim.animation))
			if bool(gait.active): lane.sample_label += " / stance " + str(int(gait.legs[0].planted)) + str(int(gait.legs[1].planted))
			frame_trace.append({"weapon":player.weapon,"phase":action.get("phase","ready"),"active":action.active,
				"angle":pose.get("weapon_angle",Vector2(pose.aim).angle()),"origin":str(pose.get("weapon_origin",pose.shoulder)),
				"muzzle":str(pose.muzzle),"grounded":player.grounded,"fire_cd":player.fire_cd,"animation":anim.animation,"gait":str(gait)})
			lane.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var output := Image.create(1600,900,false,Image.FORMAT_RGBA8)
		for index: int in range(8):
			output.blit_rect(views[index].get_texture().get_image(),Rect2i(0,0,400,450),Vector2i((index%4)*400,(index/4)*450))
		output.save_png(directory+"frame-%03d.png"%tick)
		trace.append(frame_trace)
	FileAccess.open(directory+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
	for view: SubViewport in views: view.queue_free()
	await process_frame
	print("GAIT_CAPTURE_RESULT page=",page," frames=180 actual_authority_step=true actual_world_draw=true")
	quit(0)
