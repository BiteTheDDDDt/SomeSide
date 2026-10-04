extends SceneTree

const Simulation=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
const Pixels=preload("res://scripts/pixel_actor_renderer.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--rates" in OS.get_cmdline_user_args():
		await _rate_review()
		quit(0)
		return
	var sim: Variant=Simulation.new()
	sim.start_run([{"id":1,"name":"Motion review","character":"ranger"}],2611)
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(1500,float(sim.state.floor_y)-21.0)
	player.invuln=9999.0
	var world: Node2D=World.new()
	root.add_child(world)
	world.set_process(false)
	world.scenery_cache_enabled=false
	var samples: Array=[]
	var previous: Vector2=Vector2.ZERO
	var grounded_changes: int=0
	var previous_grounded: bool=true
	for render_frame: int in range(360):
		if render_frame%2==0:
			sim.step(1.0/60.0,{1:{"move":1.0,"aim":Vector2.RIGHT}})
		world.set_frame(sim.get_snapshot(),1,1.0/120.0)
		world._process(1.0/120.0)
		var p: Vector2=world.world_to_screen(world.weapon_draw_pose(player).position)
		var grounded: bool=bool(player.grounded)
		if render_frame>=120:
			var frame: Dictionary=Pixels.frame_for("ranger",player,world._clock,true)
			samples.append({"frame":render_frame,"screen_x":p.x,"screen_dx":p.x-previous.x,"world_x":player.pos.x,"world_y":player.pos.y,"velocity":[player.vel.x,player.vel.y],"camera":[world.camera_position.x,world.camera_position.y],"camera_x":world.camera_position.x,"simulation_time":sim.state.time,"grounded":grounded,"animation":frame.get("animation",""),"sprite_frame":frame.get("index",-1)})
			if grounded!=previous_grounded: grounded_changes+=1
		previous_grounded=grounded
		previous=p
	var minimum: float=INF
	var maximum: float=-INF
	var backwards: int=0
	for sample: Dictionary in samples:
		minimum=minf(minimum,float(sample.screen_dx))
		maximum=maxf(maximum,float(sample.screen_dx))
		if float(sample.screen_dx)<-0.5: backwards+=1
	var report: Dictionary={"source":"Actual host/solo presentation path: simulation at 60 Hz, world.set_frame at 120 Hz; horizontal movement, no network and no image sampling.","samples":samples,"min_screen_dx":minimum,"max_screen_dx":maximum,"backward_frames":backwards,"grounded_changes":grounded_changes}
	FileAccess.open("res://tools/results/v011-motion-review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MOTION_REVIEW min_dx=",minimum," max_dx=",maximum," backward_frames=",backwards," grounded_changes=",grounded_changes)
	world.queue_free()
	await process_frame
	quit(0)

func _rate_review() -> void:
	var rows: Array=[]
	for hz: int in [30,45,60,75,120,144,165]:
		var sim: Variant=Simulation.new()
		sim.start_run([{"id":1,"name":"Rate review","character":"ranger"}],2611)
		var player: Dictionary=sim.state.players[1]
		player.pos=Vector2(1500,float(sim.state.floor_y)-21.0)
		player.invuln=9999.0
		var world: Node2D=World.new()
		root.add_child(world)
		world.set_process(false)
		world.scenery_cache_enabled=false
		var accumulator: float=0.0
		var previous: float=0.0
		var minimum: float=INF
		var maximum: float=-INF
		var backwards: int=0
		for render_frame: int in range(hz*3):
			accumulator+=1.0/float(hz)
			while accumulator>=1.0/60.0-0.00000001:
				sim.step(1.0/60.0,{1:{"move":1.0,"aim":Vector2.RIGHT}})
				accumulator-=1.0/60.0
			world.set_frame(sim.get_snapshot(),1,1.0/float(hz))
			var current: float=world.world_to_screen(world.weapon_draw_pose(player).position).x
			if render_frame>=hz:
				minimum=minf(minimum,current-previous)
				maximum=maxf(maximum,current-previous)
				if current-previous < -0.5: backwards+=1
			previous=current
		rows.append({"render_hz":hz,"min_screen_dx":minimum,"max_screen_dx":maximum,"backward_frames":backwards})
		world.queue_free()
		await process_frame
	FileAccess.open("res://tools/results/v011-motion-rates-review.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("MOTION_RATE_REVIEW ",JSON.stringify(rows))
