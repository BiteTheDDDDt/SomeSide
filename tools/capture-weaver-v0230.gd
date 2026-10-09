extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
const DIRECTORY="res://tools/results/tracking-v0230/weaver-motion/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var sim=Sim.new(); sim.start_run([{"id":1,"name":"Weaver","character":"weaver"}],23023)
	sim._spawn_clock=99999; sim.state.chests.clear(); sim.state.pickups.clear(); sim.state.enemies.clear()
	var floor_y: float=sim.state.floor_y
	sim.state.platforms=[Rect2(0,floor_y,sim.state.world_size.x,200)]
	var p: Dictionary=sim.state.players[1]; p.pos=Vector2(1200,floor_y-240); p.grounded=false; p.invuln=100
	var target: Dictionary=sim._spawn_enemy("charger",Vector2(1570,floor_y-24))
	target.hp=10000; target.max_hp=10000; target.attack_cd=9999; target.move_speed=0
	var world=World.new(); world.screen_size=Vector2(1280,720); world.shake_enabled=false
	root.add_child(world); world.set_process(false)
	var trace: Array=[]
	for tick: int in range(360):
		p.weapon="arc_needle" if tick<180 else "star_seeker"
		var move: float=1.0 if tick>=65 and tick<120 else (-1.0 if tick>=155 and tick<205 else 0.0)
		var aim: Vector2=(Vector2(target.pos)-(Vector2(p.pos)+Vector2(0,-14))).normalized()
		sim.step(1.0/60,{1:{"move":move,"aim":aim,"jump":tick in [90,220],"jump_held":(tick>=90 and tick<115) or (tick>=220 and tick<235),"fire":tick>=100,"dash":tick==130,"skill":tick==150}})
		world._process(1.0/60); world.set_frame(sim.get_snapshot(),1,1.0/60); world.push_events(sim.events)
		world.camera_position=Vector2(1350,floor_y-210)
		var pose: Dictionary=world.weapon_draw_pose(p)
		trace.append({"tick":tick,"phase":pose.body.phase,"position":p.pos,"shoulder":pose.shoulder,"landing":pose.body.landing,"weapon":p.weapon,"marks":p.get("trace_mark",{}),"projectiles":sim.state.projectiles.size()})
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIRECTORY+"frame-%03d.png"%tick)
	FileAccess.open(DIRECTORY+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
	world.queue_free(); await process_frame
	print("WEAVER_MOTION_CAPTURE frames=360 size=1280x720 actual_simulation=true actual_world=true")
	quit(0)
