extends SceneTree

const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
var sim: Variant
var bench: bool=false
var reverse: bool=false
var plate_only: bool=false
var results: Array=[]

class FxPlate:
	extends "res://scripts/world_view.gd"
	var titles: Array[String]=[]
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,screen_size),Color("0a1720"))
		for index: int in range(8):
			var p: Vector2=Vector2(index%4*320,index/4*285+70)
			draw_rect(Rect2(p+Vector2(10,0),Vector2(300,265)),Color("122934"))
			if index<titles.size(): _world_label(p+Vector2(160,28),titles[index],CREAM,17)
			_world_label(p+Vector2(160,250),"MUZZLE  /  IMPACT  /  DEBRIS",Color("8aabb4"),11)
		_world_label(Vector2(640,34),"SOMESIDE  /  WEAPON FEEDBACK",CREAM,24)
		_draw_enemies()
		_draw_players()
		_draw_effects()
		_draw_projectiles()
		_draw_threat_overlays()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--benchmark": bench=true
		if argument=="--reverse": reverse=true
		if argument=="--plate": plate_only=true
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if bench:
		if not _ensure_baseline():
			quit(2)
			return
		for enhanced: bool in ([true,false] if reverse else [false,true]): await _benchmark(enhanced)
		var output: Dictionary={"scope":"Same process, actor modules and fixed 4-player/24-enemy/48-projectile snapshot; only v0.9 vs v0.10 world FX differs. Continuous dense event stream; no gameplay simulation/audio/network during measurement.","adapter":RenderingServer.get_video_adapter_name(),"warmup":120,"samples":360,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"scenarios":results}
		FileAccess.open("res://tools/results/v010-fx-performance"+("-reverse" if reverse else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
		print("FX_PERF_RESULT ",JSON.stringify(output))
	else:
		await _weapons()
		if not plate_only: await _battle()
	quit(0)

func _ensure_baseline() -> bool:
	var path: String="res://tools/results/fx-v010-baseline-world.gd"
	if FileAccess.file_exists(path): return true
	var output: Array=[]
	var status: int=OS.execute("git",PackedStringArray(["-C",ProjectSettings.globalize_path("res://"),"show","v0.9.0:scripts/world_view.gd"]),output,true)
	if status!=0 or output.is_empty():
		push_error("FX A/B requires the v0.9.0 Git tag or tools/results/fx-v010-baseline-world.gd")
		return false
	var source: String=str(output[0]).replace("class_name SideWorldView","## v0.9 FX baseline fixture")
	FileAccess.open(path,FileAccess.WRITE).store_string(source)
	return true

func _new_sim(count: int=4) -> void:
	sim=Simulation.new()
	var roster: Array=[]
	for index: int in range(count): roster.append({"id":index+1,"name":"FX "+str(index+1),"character":"ranger" if index%2==0 else "vanguard"})
	sim.start_run(roster,2610)
	# The game correctly caps real parties at four; the comparison plate uses
	# extra independent display actors to show all eight weapons at once.
	for index: int in range(4,count):
		var actor: Dictionary=Dictionary(sim.state.players[1]).duplicate(true)
		actor.id=index+1
		actor.name="FX "+str(index+1)
		sim.state.players[index+1]=actor
	sim.state.enemies.clear()
	sim.state.projectiles.clear()
	sim.state.pickups.clear()

func _weapons() -> void:
	_new_sim(8)
	var world: Node2D=FxPlate.new()
	root.add_child(world)
	world.set_process(false)
	world.shake_enabled=false
	world.menu_preview=true
	var events: Array=[]
	var weapons: Array=Content.weapons()
	for index: int in range(8):
		var weapon: Dictionary=weapons[index]
		var p: Dictionary=sim.state.players[index+1]
		p.weapon=weapon.id
		p.pos=Vector2(60+index%4*320,195+index/4*285)
		p.aim=Vector2.RIGHT
		p.invuln=0.0
		p.items={"capacitor":4}
		world.titles.append(str(weapon.id).replace("_"," ").to_upper())
		sim.events.clear()
		sim._fire_weapon(p)
		events.append_array(sim.events)
		var enemy: Dictionary=sim._spawn_enemy(["crawler","charger","sentinel"][index%3],p.pos+Vector2(157,0))
		enemy.hp=500.0
		enemy.max_hp=500.0
		sim.events.clear()
		sim._damage_enemy(enemy,18.0,index+1,false,0)
		events.append_array(sim.events)
	world.set_frame(sim.get_snapshot(),1,0.0)
	world.camera_position=Vector2(640,360)
	world.push_events(events)
	world._process(0.065)
	await _capture(world,"v010-fx-weapons.png")
	world.queue_free()
	await process_frame

func _fixture() -> Dictionary:
	_new_sim()
	var weapons: Array[String]=["pulse_rifle","scattergun","railgun","storm_staff"]
	for index: int in range(4):
		var p: Dictionary=sim.state.players[index+1]
		p.pos=Vector2(1580+index*190,1080-index%2*90)
		p.weapon=weapons[index]
		p.aim=Vector2.RIGHT
		p.invuln=0.0
		p.items={"capacitor":6}
	for index: int in range(24):
		var enemy: Dictionary=sim._spawn_enemy(["crawler","charger","sentinel"][index%3],Vector2(1540+index%8*100,850+index/8*90),index%7==0)
		enemy.hp=500.0
		enemy.max_hp=500.0
	for index: int in range(48):
		sim.state.projectiles.append({"id":index+1,"pos":Vector2(1500+index%12*65,830+index/12*70),"vel":Vector2(320,20),"radius":4.0,"team":"player" if index%2==0 else "enemy","kind":"bullet" if index%2==0 else "orb","owner":1})
	sim.state.hazards=[{"id":1,"kind":"beam","shape":"line","pos":Vector2(1650,1120),"dir":Vector2.RIGHT,"length":500.0,"radius":18.0,"delay":0.4,"telegraph_max":0.9,"active":false,"ttl":0.2},{"id":2,"kind":"spore_mortar","shape":"circle","pos":Vector2(2180,1080),"radius":65.0,"delay":0.4,"telegraph_max":0.9,"active":false,"ttl":0.2}]
	return sim.get_snapshot()

func _events() -> Array:
	var events: Array=[]
	for index: int in range(4):
		var p: Dictionary=sim.state.players[index+1]
		sim.events.clear()
		sim._fire_weapon(p)
		events.append_array(sim.events)
		for hit: int in range(2):
			events.append({"type":"hit","pos":p.pos+Vector2(100+hit*28,-25),"owner":index+1,"amount":18,"crit":hit==1,"visual_stacks":6})
	events.append({"type":"death","pos":Vector2(2090,975),"kind":"charger","elite":false})
	events.append({"type":"explosion","pos":Vector2(2050,930),"radius":92.0,"owner":1,"visual_stacks":6})
	return events

func _battle() -> void:
	var snapshot: Dictionary=_fixture()
	var events: Array=_events()
	var world: Node2D=World.new()
	root.add_child(world)
	world.set_process(false)
	world.shake_enabled=false
	world.set_frame(snapshot,1,0.0)
	world.camera_position=Vector2(1900,970)
	world.push_events(events)
	world._process(0.07)
	await _capture(world,"v010-fx-battle.png")
	world._effects.clear()
	for kind: String in ["crawler","charger","sentinel"]:
		world.push_events([{"type":"death","kind":kind,"pos":Vector2(1650+["crawler","charger","sentinel"].find(kind)*240,990),"elite":true}])
	world._process(0.17)
	await _capture(world,"v010-fx-materials.png")
	world.queue_free()
	await process_frame

func _capture(world: Node2D, filename: String) -> void:
	for index: int in range(50):
		await process_frame
		world._prepare_scenery_cache()
		world.queue_redraw()
		await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png("res://tools/results/"+filename)
	assert(error==OK)
	print("FX_CAPTURE ",filename," ",JSON.stringify(world.visual_budget_stats()))

func _benchmark(enhanced: bool) -> void:
	var snapshot: Dictionary=_fixture()
	var events: Array=_events()
	var immutable: PackedByteArray=var_to_bytes(snapshot)
	var measured: GDScript=GDScript.new()
	var base: String="res://scripts/world_view.gd" if enhanced else "res://tools/results/fx-v010-baseline-world.gd"
	measured.source_code="extends \"%s\"\nvar perf_fx_ms: float=0.0\nvar perf_draw_ms: float=0.0\nfunc _draw() -> void:\n\tvar began: int=Time.get_ticks_usec()\n\tsuper._draw()\n\tperf_draw_ms=float(Time.get_ticks_usec()-began)/1000.0\nfunc _draw_effects() -> void:\n\tvar began: int=Time.get_ticks_usec()\n\tsuper._draw_effects()\n\tperf_fx_ms=float(Time.get_ticks_usec()-began)/1000.0\n"%base
	assert(measured.reload()==OK)
	var world: Node2D=measured.new()
	root.add_child(world)
	world.set_process(false)
	world.shake_enabled=false
	world.set_frame(snapshot,1,0.0)
	world.camera_position=Vector2(1900,970)
	var samples: Array=[]
	var draws: Array=[]
	var cpu: Array=[]
	var fx_cpu: Array=[]
	var draw_cpu: Array=[]
	var peak: int=0
	for index: int in range(480):
		await process_frame
		var begin: int=Time.get_ticks_usec()
		world._process(1.0/120.0)
		if index%6==0: world.push_events(events)
		world._prepare_scenery_cache()
		await RenderingServer.frame_post_draw
		if index>=120:
			samples.append(float(Time.get_ticks_usec()-begin)/1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			fx_cpu.append(world.perf_fx_ms)
			draw_cpu.append(world.perf_draw_ms)
		peak=maxi(peak,int(world.visual_budget_stats().effects))
	assert(var_to_bytes(snapshot)==immutable)
	results.append({"enhanced":enhanced,"frame_ms":_percentiles(samples),"draw_calls":_percentiles(draws),"render_cpu_ms":_percentiles(cpu),"fx_draw_ms":_percentiles(fx_cpu),"world_draw_ms":_percentiles(draw_cpu),"peak_effects":peak,"final_budget":world.visual_budget_stats()})
	root.get_texture().get_image().save_png("res://tools/results/v010-fx-dense-"+("after" if enhanced else "before")+".png")
	print("FX_BENCHMARK ",JSON.stringify(results.back()))
	world.queue_free()
	await process_frame
	await process_frame

func _percentiles(samples: Array) -> Dictionary:
	samples.sort()
	return {"p50":samples[int(samples.size()*0.5)],"p95":samples[int(samples.size()*0.95)]}
