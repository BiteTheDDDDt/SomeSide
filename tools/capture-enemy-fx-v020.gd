extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DIRECTORY: String = "res://tools/results/enemy-attacks-v020/"
const TIMES: Array[float] = [.20,.60,.92,1.03,1.19]
const LABELS: Array[String] = ["Gather / 20%","Focus / 60%","Ready / 92%","Release","Decay"]


class AtlasBoard extends Node2D:
	const Fx = preload("res://scripts/attack_fx_sprites.gd")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,840),Color("111c26"))
		var font: Font=ThemeDB.fallback_font
		var families: Array[String]=["charge","beam","burst","missile","wave","aura"]
		for row: int in range(6):
			draw_string(font,Vector2(8,row*140+20),families[row],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
			for column: int in range(8):
				var p:=Vector2(105+column*176,row*140+80)
				var size_value:=Vector2(98,98)
				if families[row]=="beam": size_value=Vector2(150,52)
				elif families[row]=="missile": size_value=Vector2(90,44)
				Fx.draw_oriented(self,families[row],p,size_value,0,float(column)/8+.001)
				draw_string(font,Vector2(100+column*176,row*140+132),str(column+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c1d1db"))

class Lane extends "res://scripts/world_view.gd":
	var title: String=""
	func _ready() -> void:
		super._ready()
		set_process(false)
	func _draw() -> void:
		# The gameplay background assumes a full-height viewport; tiny contact
		# cells use a neutral backdrop, while the 1x captures retain real scenery.
		if screen_size.y<300:
			draw_rect(Rect2(Vector2.ZERO,screen_size),Color("141c2a"))
		else:
			Biomes.background(self,"ruins",camera_position,screen_size,Vector2(5000,1900),_clock)
		_draw_terrain()
		_draw_players()
		_draw_enemies()
		_draw_projectiles()
		_build_particle_batches()
		_draw_effects()
		_draw_threat_overlays()
		draw_rect(Rect2(0,0,screen_size.x,17),Color("08151c"))
		draw_string(_font,Vector2(5,12),title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("dfe8d7"))

func _initialize() -> void: _run.call_deferred()

func _simulation(kind: String):
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],19001)
	sim.state.enemies.clear(); sim.state.chests.clear();sim.state.hazards.clear()
	sim.state.platforms=[Rect2(0,600,5000,90)]
	sim.state.floor_y=600.0;sim.state.biome="ruins"
	sim._spawn_clock=9999.0
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(2370,579);player.vel=Vector2.ZERO;player.invuln=1000.0
	var enemy: Dictionary=sim._spawn_enemy(kind,Vector2(2000,583))
	enemy.grounded=true
	if kind=="boss": enemy.boss_style="prism";enemy.attack_count=1;enemy.pos.y=550
	sim._begin_enemy_attack(enemy,player)
	return sim

func _view(size: Vector2i) -> SubViewport:
	var view:=SubViewport.new()
	view.size=size
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func _lane(view: SubViewport, frame: Dictionary, position: Vector2, dimensions: Vector2, zoom: float, low: bool, label: String) -> Lane:
	var clip:=Control.new()
	clip.position=position;clip.size=dimensions;clip.clip_contents=true
	view.add_child(clip)
	var lane:=Lane.new()
	lane.screen_size=dimensions/zoom;lane.scale=Vector2.ONE*zoom
	lane.fx_scale=0.0 if low else 1.0;lane.reduced_motion=low
	lane.scenery_cache_enabled=false;lane.shake_enabled=false
	lane.title=label
	clip.add_child(lane)
	lane.set_frame(frame,1,1.0/60.0)
	lane._clock=float(frame.time)
	lane.camera_position=Vector2(2000+lane.screen_size.x*.5-48,600-lane.screen_size.y*.5+18)
	if str(frame.enemies[0].get("kind",""))=="charger":
		lane.camera_position.x=float(Vector2(frame.enemies[0].pos).x)+lane.screen_size.x*.5-48
	return lane

func _save(view: SubViewport, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(DIRECTORY+filename)==OK)

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var atlas_view:=_view(Vector2i(1440,840))
	atlas_view.add_child(AtlasBoard.new())
	await _save(atlas_view,"atlas-eight-frames.png")
	atlas_view.queue_free();await process_frame
	var samples: Dictionary={}
	var snapshots: Array=[]
	for kind: String in ["sentinel","spitter","charger","boss"]:
		var sim=_simulation(kind)
		var enemy: Dictionary=sim.state.enemies[0]
		var windup: float=float(enemy.telegraph_max)
		var selected: Array=[]
		for tick: int in range(90):
			sim.step(1.0/60.0,{})
			var age: float=float(tick+1)/60.0
			if kind=="sentinel": snapshots.append(sim.get_snapshot())
			if selected.size()<TIMES.size():
				var wanted: float=TIMES[selected.size()]*windup if selected.size()<3 else windup+(0.03 if selected.size()==3 else .19)
				if age>=wanted: selected.append(sim.get_snapshot())
		samples[kind]=selected
	var phases:=_view(Vector2i(1600,520))
	for row: int in range(2):
		for column: int in range(5):
			_lane(phases,samples.sentinel[column],Vector2(column*320,row*260),Vector2(320,260),2.0,row==1,("Low FX / " if row==1 else "Sentinel / ")+LABELS[column]+" / 2x")
	await _save(phases,"laser-phases.png")
	phases.queue_free();await process_frame
	var bodies:=_view(Vector2i(1600,520))
	for row: int in range(2):
		var kind: String="spitter" if row==0 else "charger"
		for column: int in range(5):
			_lane(bodies,samples[kind][column],Vector2(column*320,row*260),Vector2(320,260),2.0,false,kind+" / "+LABELS[column]+" / 2x")
	await _save(bodies,"body-preparation-phases.png")
	bodies.queue_free();await process_frame
	var normal:=_view(Vector2i(1280,720))
	var world: Lane=_lane(normal,samples.sentinel[2],Vector2.ZERO,Vector2(1280,720),1.0,false,"Normal game scale / locked beam charge / 1x")
	world.camera_position=Vector2(2270,420)
	world.queue_redraw()
	await _save(normal,"normal-scale-charge.png")
	world.set_frame(samples.sentinel[3],1,1.0/60.0);world._clock=float(samples.sentinel[3].time);world.camera_position=Vector2(2270,420)
	world.title="Normal game scale / locked beam release / 1x";world.queue_redraw()
	await _save(normal,"normal-scale-release.png")
	world.set_frame(samples.boss[3],1,1.0/60.0);world._clock=float(samples.boss[3].time);world.camera_position=Vector2(2230,420)
	world.title="Prism boss / three independently locked beams / 1x";world.queue_redraw()
	await _save(normal,"prism-cross.png")
	normal.queue_free();await process_frame
	# Native 60 Hz footage retains original image pixels; JPEG is only an
	# encoder input for the locally available minimal FFmpeg, PNGs stay intact.
	DirAccess.make_dir_recursive_absolute(DIRECTORY+"frames/")
	var film:=_view(Vector2i(1280,720))
	var film_lane: Lane=_lane(film,snapshots[0],Vector2.ZERO,Vector2(1280,720),1.0,false,"Sentinel preparation and release / normal 1x / 60 fps")
	for tick: int in range(snapshots.size()):
		film_lane.set_frame(snapshots[tick],1,1.0/60.0)
		film_lane._clock=float(snapshots[tick].time)
		film_lane.camera_position=Vector2(2270,420)
		film_lane.queue_redraw()
		await _save(film,"frames/frame-%03d.png"%tick)
	FileAccess.open(DIRECTORY+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"native":true,"real_simulation":true,"frames":snapshots.size(),"hz":60,"normal_scale":1,"detail_scale":2,"source":"enemy_attack_visual.gd","phase_images":5,"atlas_images":1,"film_scale":1,"film_size":[1280,720]},"\t"))
	print("ENEMY_ATTACK_CAPTURE_RESULT snapshots=90 stills=6 native=true real_simulation=true")
	quit(0)
