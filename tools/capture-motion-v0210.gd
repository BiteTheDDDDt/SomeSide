extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
const DT: float=1.0/60.0
const DIRECTORY: String="res://tools/results/motion-v0210/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for character: String in ["ranger","vanguard"]:
		var sim=Simulation.new()
		sim.start_run([{"id":1,"name":"","character":character}],1501)
		var floor_y: float=sim.state.floor_y
		sim.state.platforms=[Rect2(0,floor_y,5000,100)]
		sim.state.enemies.clear(); sim.state.chests.clear(); sim.state.pickups.clear()
		var player: Dictionary=sim.state.players[1]
		player.pos=Vector2(1200,floor_y-240); player.vel=Vector2.ZERO; player.grounded=false; player.invuln=0
		var viewport:=SubViewport.new(); viewport.size=Vector2i(960,540); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var world=World.new(); world.screen_size=Vector2(960,540); world.scenery_cache_enabled=false; world.shake_enabled=false
		viewport.add_child(world); world.set_process(false)
		var trace: Array=[]
		var phases: Dictionary={}
		var directory: String=DIRECTORY+character+"/"
		DirAccess.make_dir_recursive_absolute(directory)
		for tick: int in range(330):
			var time: float=tick*DT
			sim.state.time=time; sim.events.clear()
			player.weapon="pulse_rifle" if tick<170 else ("railgun" if tick<250 else "arc_blade")
			var move: float=1.0 if tick>=70 and tick<140 else (-1.0 if tick>=180 and tick<225 else 0.0)
			var aim: Vector2=Vector2(.97,-.24).normalized() if tick<200 else Vector2(-.96,-.28).normalized()
			var input: Dictionary={"move":move,"aim":aim,"jump":tick in [95,228,290],"jump_held":tick<115 or (tick>=228 and tick<245) or tick>=290,"dash":tick==150,"fire":(tick>=120 and tick<140) or (tick>=185 and tick<220) or tick>=260}
			sim._step_player(player,input,DT); sim._step_projectiles(DT)
			world._process(DT); world.set_frame(sim.get_snapshot(),1,DT); world.push_events(sim.events)
			world.camera_position=Vector2(1230,floor_y-155)
			var pose: Dictionary=world.weapon_draw_pose(player)
			var phase: String=pose.body.phase
			if not phases.has(phase): phases[phase]=tick
			trace.append({"tick":tick,"phase":phase,"grounded":player.grounded,"position":str(player.pos),"velocity":str(player.vel),"landing":pose.body.landing,"shoulder":str(pose.shoulder),"weapon":player.weapon,"input":str(input)})
			world.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(directory+"frame-%03d.png"%tick)
		FileAccess.open(directory+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
		FileAccess.open(directory+"phases.json",FileAccess.WRITE).store_string(JSON.stringify(phases))
		viewport.queue_free(); await process_frame
		print("MOTION_CAPTURE character=",character," frames=330 actual_player_step=true actual_world_draw=true phases=",phases)
	quit(0)
