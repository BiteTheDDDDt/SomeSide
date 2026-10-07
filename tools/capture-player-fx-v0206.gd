extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
const Content=preload("res://scripts/content.gd")
const START:=Vector2(1650,1079)
const DT: float=1.0/60.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/results/player-fx-v0206")
	var reports: Array=[]
	for definition: Dictionary in Content.weapons()+Content.equipment():
		var sim=Sim.new(); sim.start_run([{"id":1,"name":"","character":"vanguard" if definition.id=="arc_blade" else "ranger"}],206)
		sim.state.chests.clear(); sim.state.enemies.clear(); sim._spawn_clock=9999
		var player: Dictionary=sim.state.players[1]
		player.pos=START; player.vel=Vector2.ZERO; player.grounded=true; player.invuln=0
		if definition.category=="weapon": player.weapon=definition.id
		else: player.equipment=definition.id; player.hp=50
		var target: Dictionary=sim._spawn_enemy("crawler",START+Vector2(65 if definition.id=="arc_blade" else (125 if definition.id=="flamethrower" else 265),2))
		target.hp=10000; target.max_hp=10000; target.move_speed=0; target.attack_cd=9999; target.grounded=true
		var view:=SubViewport.new(); view.size=Vector2i(960,540); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
		var world=World.new(); world.screen_size=Vector2(960,540); world.shake_enabled=false; world.scenery_cache_enabled=false; view.add_child(world); world.set_process(false)
		var samples: Array[Image]=[]
		var events: Dictionary={}
		for tick: int in range(116):
			sim.step(DT,{1:{"aim":Vector2.RIGHT,"fire":tick==20 and definition.category=="weapon","skill":tick==20 and definition.category=="equipment","jump":false,"move":0}})
			world._process(DT)
			var snapshot: Dictionary=sim.get_snapshot(); var before: PackedByteArray=var_to_bytes(snapshot)
			world.set_frame(snapshot,1,DT); world.camera_position=START+Vector2(90,-78); world.push_events(sim.events)
			for event: Dictionary in sim.events: events[str(event.type)]=int(events.get(str(event.type),0))+1
			world.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			assert(var_to_bytes(snapshot)==before)
			if tick in [22,32,58,108]: samples.append(view.get_texture().get_image())
		var output:=Image.create(1920,1080,false,Image.FORMAT_RGBA8)
		for i: int in range(4): output.blit_rect(samples[i],Rect2i(0,0,960,540),Vector2i(i%2*960,i/2*540))
		assert(output.save_png("res://tools/results/player-fx-v0206/"+str(definition.id)+".png")==OK)
		reports.append({"id":definition.id,"events":events,"target_damage":10000-float(target.hp)})
		view.queue_free(); await process_frame
	FileAccess.open("res://tools/results/player-fx-v0206/report.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"\t"))
	print("PLAYER_FX_CAPTURE_RESULT real_simulation=true cases=",reports.size()," readonly=true")
	quit()
