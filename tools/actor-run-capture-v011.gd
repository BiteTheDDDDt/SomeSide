extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Simulation = preload("res://scripts/simulation.gd")

class Live extends "res://scripts/world_view.gd":
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,screen_size),Color("10202c"))
		var floor_line: float=world_to_screen(Vector2(0,float(_frame.get("floor_y",1900)))).y
		draw_rect(Rect2(0,floor_line,screen_size.x,screen_size.y),Color("29404b"))
		_draw_players()
		_draw_projectiles()

class Legacy extends Live:
	var sources: Dictionary={}
	func _update_render_positions(_delta: float) -> void:
		_render_positions.clear()
	func _draw_players() -> void:
		for player: Dictionary in _frame.get("players",{}).values():
			var pose: Dictionary=weapon_draw_pose(player)
			var p: Vector2=world_to_screen(pose.position)
			var frame: Dictionary=Pixels.frame_for(player.character,player,_clock,true)
			var key: String=player.character+str(frame.index)
			if not sources.has(key):
				var sampler:=CanvasTexture.new()
				sampler.diffuse_texture=load(Pixels._actors[player.character].path)
				sampler.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				var atlas:=AtlasTexture.new()
				atlas.atlas=sampler
				atlas.region=frame.source
				atlas.filter_clip=true
				sources[key]=atlas
			if player.grounded: p.y-=absf(cos(_clock*16.0))*clampf(absf(player.vel.x)/100.0,0.0,1.0)
			var facing: float=1.0 if pose.aim.x>=0 else -1.0
			draw_set_transform(p,0,Vector2(facing,1))
			draw_texture_rect(sources[key],frame.target,false,frame.tint)
			draw_set_transform(world_to_screen(pose.shoulder),pose.aim.angle(),Vector2(1,facing))
			_draw_weapon(player.weapon)
			draw_set_transform(Vector2.ZERO)
			_world_label(p+Vector2(0,-42),str(player.name),TEAL if int(player.id)==1 else CREAM,11)
			if int(player.id)==1:
				draw_colored_polygon(PackedVector2Array([p+Vector2(-3,-37),p+Vector2(3,-37),p+Vector2(0,-33)]),Color(TEAL,.75))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Run","character":"ranger"},{"id":2,"name":"Run","character":"vanguard"}],1103)
	for id: int in [1,2]:
		sim.state.players[id].pos=Vector2(1500+(id-1)*160,float(sim.state.floor_y)-21)
		sim.state.players[id].invuln=0.0
	sim._spawn_clock=9999.0
	var views: Array=[]
	var worlds: Array=[]
	for before: bool in [true,false]:
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(640,360)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.disable_3d=true
		root.add_child(viewport)
		var world: Node2D=Legacy.new() if before else Live.new()
		world.scenery_cache_enabled=false
		viewport.add_child(world)
		world.screen_size=Vector2(640,360)
		world.set_process(false)
		views.append(viewport)
		worlds.append(world)
	var montage: Image=Image.create(12*128,4*104,false,Image.FORMAT_RGBA8)
	var frames_dir: String="res://tools/results/actor-run-v011"
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var report: Array=[]
	for frame: int in range(384):
		if frame%2==0:
			var command: Dictionary={"move":1.0,"aim":Vector2.RIGHT,"jump":frame==312,"jump_held":frame<338,"fire":frame>=290 and frame<308}
			sim.step(1.0/60.0,{1:command,2:command})
		for world: Node2D in worlds:
			world.set_frame(sim.state,1,1.0/120.0)
			world._clock+=1.0/120.0
		if frame<288: continue
		await process_frame
		await RenderingServer.frame_post_draw
		var joined: Image=Image.create(1280,360,false,Image.FORMAT_RGBA8)
		for index: int in range(2):
			var shot: Image=views[index].get_texture().get_image()
			joined.blit_rect(shot,Rect2i(0,0,640,360),Vector2i(index*640,0))
			if frame<312:
				var crop: Image=shot.get_region(Rect2i(220,196,128,104))
				montage.blit_rect(crop,Rect2i(0,0,128,104),Vector2i(((frame-288)%12)*128,(index*2+(frame-288)/12)*104))
		joined.save_png(frames_dir+"/frame-%03d.png"%(frame-288))
		report.append({"frame":frame-288,"time":sim.state.time,"grounded":sim.state.players[1].grounded,"position":str(sim.state.players[1].pos),"legacy_screen":str(worlds[0].world_to_screen(worlds[0].weapon_draw_pose(sim.state.players[1]).position)),"fixed_screen":str(worlds[1].world_to_screen(worlds[1].weapon_draw_pose(sim.state.players[1]).position))})
	montage.save_png("res://tools/results/actor-run-v011-contact.png")
	FileAccess.open("res://tools/results/actor-run-v011.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for viewport: SubViewport in views: viewport.queue_free()
	await process_frame
	print("ACTOR_RUN_CAPTURE frames=96 before=left after=right actual_simulation=60 render=120")
	quit(0)
