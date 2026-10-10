extends SceneTree

## Cover-only studio: an authored diorama built from unchanged game assets.
## This is explicitly not an ordinary gameplay screenshot or a new level.
const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0/60.0
const DIRECTORY: String = "res://tools/results/cover-v2/"
const ORIGIN := Vector2(2000,900)
const LOGICAL := Vector2(504,400)

class Studio extends "res://scripts/world_view.gd":
	func _ready() -> void:
		super._ready()
		set_process(false)
	func _draw() -> void:
		Biomes.background(self,"rainforest",camera_position,screen_size,_frame.get("world_size",Vector2(5000,1900)),_clock)
		_draw_terrain()
		_draw_enemies()
		_draw_players()
		_build_particle_batches()
		_draw_effects()
		_draw_projectiles()
		_draw_atmosphere()
	func _world_label(_p: Vector2, _message: String, _color: Color, _size: int) -> void: pass
	func _draw_enemies() -> void:
		# Production bodies, with studio-only removal of health/status/target UI.
		for enemy: Dictionary in _frame.get("enemies",[]):
			if float(enemy.hp)<=0.0: continue
			var p: Vector2=Pixels.snap_position(self,world_to_screen(_entity_draw_position("e"+str(enemy.id),enemy.pos)))
			var heading: Vector2=enemy.get("vel",Vector2.LEFT)
			draw_set_transform(p,0,Vector2(-1 if heading.x<=0 else 1,1))
			Entities.enemy(self,enemy,_clock)
			draw_set_transform(Vector2.ZERO)
	func _draw_players() -> void:
		# Reuse the exact body, articulated ground gait, weapon motion and arms.
		# Accessories, names, health/shield circles and local-player arrows are
		# intentionally absent from this cover-only photographic presentation.
		for player: Dictionary in _frame.get("players",{}).values():
			var pose: Dictionary=weapon_draw_pose(player)
			var p: Vector2=Pixels.snap_position(self,world_to_screen(pose.position))
			var facing: float=1.0 if Vector2(pose.aim).x>=0 else -1.0
			var displayed: Dictionary=player.duplicate(false)
			displayed.pos=pose.position; displayed.aim=pose.aim
			if bool(pose.melee.active) or bool(pose.ranged.active):
				var motion: Dictionary=(pose.melee if bool(pose.melee.active) else pose.ranged).duplicate(false)
				motion.draw_origin=p; motion.facing=facing
				displayed._melee_pose=motion
			draw_set_transform(p,0,Vector2(facing,1))
			Entities.player_body(self,displayed,_clock)
			if bool(pose.melee.active): _draw_melee_actor(player,pose)
			elif bool(pose.ranged.active): _draw_ranged_actor(player,pose)
			else:
				draw_set_transform(world_to_screen(pose.shoulder),Vector2(pose.aim).angle(),Vector2(1,facing))
				_draw_weapon(str(player.weapon))
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"},{"id":2,"name":"","character":"vanguard"}],17202)
	sim.state.world_size=Vector2(5000,1900)
	sim.state.floor_y=1820.0
	sim.state.platforms=[Rect2(0,1820,5000,80),Rect2(ORIGIN+Vector2(18,249),Vector2(154,38)),Rect2(ORIGIN+Vector2(182,330),Vector2(154,42)),Rect2(ORIGIN+Vector2(326,306),Vector2(218,42)),Rect2(ORIGIN+Vector2(-25,361),Vector2(103,34))]
	sim.state.chests=[];sim.state.enemies=[];sim.state.landmarks=[]
	sim._spawn_clock=9999.0
	var ranger: Dictionary=sim.state.players[1]
	var vanguard: Dictionary=sim.state.players[2]
	ranger.pos=ORIGIN+Vector2(103,228); ranger.weapon="pulse_rifle"
	vanguard.pos=ORIGIN+Vector2(195,309); vanguard.weapon="arc_blade"
	for player: Dictionary in [ranger,vanguard]:
		player.vel=Vector2.ZERO;player.grounded=true;player.invuln=0.0
		player.items={};player.explore_anchor=player.pos;player.explore_sites=[player.pos]
	for setup: Array in [["crawler",345,289],["spitter",459,289],["spore_moth",407,175]]:
		var enemy: Dictionary=sim._spawn_enemy(str(setup[0]),ORIGIN+Vector2(setup[1],setup[2]))
		enemy.attack_cd=2.0
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1260,1000)
	viewport.size_2d_override=Vector2i(LOGICAL)
	viewport.size_2d_override_stretch=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view:=Studio.new()
	view.screen_size=LOGICAL
	view.scenery_cache_enabled=false
	view.shake_enabled=false
	view.fx_scale=1.0
	viewport.add_child(view)
	var report: Dictionary={"purpose":"Cover-only diorama, not a normal gameplay screenshot","native_output":[1260,1000],"logical_view":[504,400],"production_assets_unchanged":true,"custom_terrain":true,"simulation_hz":60,"hud_names_numbers_markers_accessories_hidden":true,"captures":[]}
	for tick: int in range(24):
		sim.step(DT,{1:{"move":1.0,"aim":Vector2(1,.29).normalized(),"fire":tick>=15},2:{"move":1.0,"aim":Vector2(1,-.08).normalized(),"fire":tick>=8}})
		view._process(DT)
		view.set_frame(sim.get_snapshot(),1,DT)
		view.camera_position=ORIGIN+LOGICAL*.5
		var combat: Array=sim.events.filter(func(event:Dictionary)->bool:return str(event.type) in ["shoot","slash","hit","death"])
		view.push_events(combat)
		view._numbers.clear()
		view.queue_redraw()
		await process_frame
		if tick in [16,17,18,19]:
			await RenderingServer.frame_post_draw
			var filename: String="cover-v2-%02d.png"%tick
			viewport.get_texture().get_image().save_png(DIRECTORY+filename)
			var pose: Dictionary=view.weapon_draw_pose(view._frame.players[2])
			report.captures.append({"file":filename,"tick":tick,"blade_angle_deg":rad_to_deg(float(pose.weapon_angle)),"blade_phase":pose.melee.get("phase","idle"),"ranger_position":str(ranger.pos-ORIGIN),"vanguard_position":str(vanguard.pos-ORIGIN),"events":sim.events.map(func(event:Dictionary):return event.type)})
			# Native thumbnail renders, not repainted or composited image files.
			for dimensions: Vector2i in [Vector2i(630,500),Vector2i(315,250)]:
				viewport.size=dimensions
				view.queue_redraw()
				await process_frame;await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(DIRECTORY+"cover-v2-%02d-%d.png"%[tick,dimensions.x])
			viewport.size=Vector2i(1260,1000)
			view.queue_redraw()
			await process_frame
	FileAccess.open(DIRECTORY+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	viewport.queue_free();await process_frame
	print("COVER_STUDIO_RESULT ",JSON.stringify(report))
	quit(0)
