extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/enemy_catalog.gd")
var game: Node
var tag: String = "final"
var output: Dictionary = {}
var moving: bool = false
var verify: bool = false

class MeasuredWorld:
	extends "res://scripts/world_view.gd"
	var draw_cost: float = 0.0
	var terrain_cost: float = 0.0
	var capture_camera: Vector2
	func set_frame(snapshot: Dictionary, id: int, _delta: float) -> void:
		camera_position=capture_camera
		super.set_frame(snapshot,id,0.0)
		camera_position=capture_camera
	func _draw() -> void:
		var begin: int = Time.get_ticks_usec()
		super._draw()
		draw_cost = float(Time.get_ticks_usec()-begin)/1000.0
	func _draw_terrain() -> void:
		var begin: int = Time.get_ticks_usec()
		super._draw_terrain()
		terrain_cost = float(Time.get_ticks_usec()-begin)/1000.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="): tag=argument.trim_prefix("--tag=")
		if argument=="--moving": moving=true
		if argument=="--verify": verify=true
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://main.tscn").instantiate()
	# main creates its default renderer during construction. Release that
	# unattached node before replacing it with the instrumented subclass.
	game.world.free()
	game.world=MeasuredWorld.new()
	game._smoke="render-performance"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	output={"tag":tag,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"Fixed simulation snapshots; actual main presentation + native OpenGL world. Physics disabled, no networking/audio. Frame wall times include driver/presentation; draw/main CPU measured independently.","viewport":[1280,720],"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"warmup":120,"samples":360,"source_hashes":{},"scenarios":[]}
	output["moving_camera"]=moving
	for path: String in ["scripts/world_view.gd","scripts/biome_renderer.gd","scripts/main.gd","scripts/content.gd","scripts/entity_renderer.gd","scripts/projectile_renderer.gd","scripts/sprite_atlas.gd","scripts/pixel_actor_renderer.gd","assets/sprites/actors.json"]:
		output.source_hashes[path]=FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else "absent"
	for scenario: Array in [[1,false],[1,true],[2,true],[3,true]]:
		await _scenario(int(scenario[0]),bool(scenario[1]))
	if verify: await _floor_captures()
	var file: FileAccess=FileAccess.open("res://tools/results/perf-v11-"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	print("PERF_V11_RESULT ",JSON.stringify(output))
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	quit(0)

func _scenario(stage: int,dense: bool) -> void:
	game._begin_local([{"id":1,"name":"Perf","character":"ranger"}],909)
	game.sim._build_stage(stage)
	game.sim.state.enemies=[]
	game.sim.state.projectiles=[]
	game.sim.state.pickups=[]
	var centers: Array[Vector2]=[Vector2(1960,982),Vector2(2150,2130),Vector2(4350,1544)]
	var camera: Vector2=centers[stage-1]
	var p: Dictionary=game.sim.state.players[1]
	p.pos=camera+Vector2(-92,58)
	p.aim=Vector2.RIGHT
	p.invuln=0.0
	p.coins=1234
	if dense:
		for id: int in range(2,5):
			game.sim.add_player(id,"Peer"+str(id),"ranger")
			game.sim.state.players[id].pos=p.pos+Vector2((id-2)*80,-40)
		for player: Dictionary in game.sim.state.players.values():
			player.items={"overclock":4,"feather":4,"lens":4,"battery":4,"arc":4,"glass":4}
		var kinds: Array=Catalog.pool(game.sim.state.biome)
		for i: int in range(60):
			var at: Vector2=camera+Vector2(-560+(i%15)*78,-210+(i/15)*120)
			var enemy: Dictionary=game.sim._spawn_enemy(kinds[i%3],at)
			enemy.vel=Vector2.LEFT*80
		for i: int in range(160):
			var at: Vector2=camera+Vector2(-580+(i%32)*37,-250+(i/32)*110)
			game.sim._spawn_projectile(at,Vector2.RIGHT*700,"player" if i%2==0 else "enemy","bullet" if i%2==0 else "spit",10,1,3,4)
		for i: int in range(24): game.sim._spawn_pickup(p.pos+Vector2(-200+i*18,10),"item",["glass","overclock","feather"][i%3],1)
		for i: int in range(6):
			var enemy: Dictionary=game.sim.state.enemies[i]
			game.sim._spawn_hazard(enemy,"beam" if i%2==0 else "spore_mortar",enemy.pos,"line" if i%2==0 else "circle",Vector2.RIGHT,440,14 if i%2==0 else 48,0.9,12)
	game._notice_time=0
	game._notice.text=""
	game.world.shake_enabled=false
	game._update_hud()
	var immutable: PackedByteArray=var_to_bytes(game.sim.state)
	if verify:
		for enabled: bool in [false,true]:
			game.world.scenery_cache_enabled=enabled
			for frame_index: int in range(40):
				await process_frame
				game.world._clock=2.7
				game.world.capture_camera=camera
				game._process(0.0)
				await RenderingServer.frame_post_draw
			var mode: String="cached" if enabled else "vector"
			root.get_texture().get_image().save_png("res://tools/results/perf-v11-verify-%d-%s-%s.png"%[stage,"dense" if dense else "quiet",mode])
		assert(var_to_bytes(game.sim.state)==immutable,"Fidelity captures preserve simulation state")
		print("PERF_V11_VERIFIED stage=",stage," dense=",dense)
		return
	var samples: Dictionary={"frame_ms":[],"main_process_ms":[],"world_draw_ms":[],"terrain_ms":[],"render_cpu_ms":[],"render_gpu_ms":[],"draw_calls":[],"physics_ms":[]}
	var peak_cache_entries: int=0
	var peak_cache_bytes: int=0
	for index: int in range(480):
		await process_frame
		var frame_start: int=Time.get_ticks_usec()
		game.world.capture_camera=camera+(Vector2(float(index-120)*1.4,sin(float(index)*0.025)*90.0) if moving else Vector2.ZERO)
		var cpu_start: int=frame_start
		game._process(1.0/120.0)
		var main_cost: float=float(Time.get_ticks_usec()-cpu_start)/1000.0
		game.world._clock=float(index)/120.0
		game.world.queue_redraw()
		await RenderingServer.frame_post_draw
		if game.world.has_method("scenery_cache_stats"):
			var cache_stats: Dictionary=game.world.scenery_cache_stats()
			peak_cache_entries=maxi(peak_cache_entries,int(cache_stats.entries))
			peak_cache_bytes=maxi(peak_cache_bytes,int(cache_stats.bytes))
		if index>=120:
			samples.frame_ms.append(float(Time.get_ticks_usec()-frame_start)/1000.0)
			samples.main_process_ms.append(main_cost)
			samples.world_draw_ms.append(game.world.draw_cost)
			samples.terrain_ms.append(game.world.terrain_cost)
			samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			samples.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	assert(var_to_bytes(game.sim.state)==immutable,"Presentation benchmark must not mutate simulation state")
	var summary: Dictionary={"stage":stage,"dense":dense,"enemies":game.sim.state.enemies.size(),"projectiles":game.sim.state.projectiles.size(),"metrics":{}}
	if game.world.has_method("scenery_cache_stats"): summary["cache"]=game.world.scenery_cache_stats()
	summary["pixel_actors"]=load("res://scripts/pixel_actor_renderer.gd").stats()
	summary["peak_cache_entries"]=peak_cache_entries
	summary["peak_cache_bytes"]=peak_cache_bytes
	for metadata: StringName in [&"someside_enemy_atlas",&"someside_projectile_atlas"]:
		if game.world.has_meta(metadata):
			var atlas: Dictionary=game.world.get_meta(metadata)
			summary[str(metadata)]={"bytes":atlas.get("bytes",0),"entries":atlas.get("entries",0),"builds":atlas.get("builds",0)}
	for key: String in samples: summary.metrics[key]=_percentiles(samples[key])
	output.scenarios.append(summary)
	root.get_texture().get_image().save_png("res://tools/results/perf-v11-"+tag+"-"+str(stage)+("-dense" if dense else "-quiet")+".png")
	print("PERF_V11_SCENARIO ",JSON.stringify(summary))

func _percentiles(values: Array) -> Dictionary:
	var ordered: Array=values.duplicate()
	ordered.sort()
	return {"p50":ordered[int(ordered.size()*0.5)],"p95":ordered[int(ordered.size()*0.95)]}

func _floor_captures() -> void:
	game._begin_local([{"id":1,"name":"Perf","character":"ranger"}],909)
	for stage: int in range(1,4):
		game.sim._build_stage(stage)
		var camera: Vector2=Vector2(640,game.sim.state.world_size.y-330)
		for enabled: bool in [false,true]:
			game.world.scenery_cache_enabled=enabled
			for index: int in range(32):
				await process_frame
				game.world._clock=2.7
				game.world.capture_camera=camera
				game._process(0.0)
				await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tools/results/perf-v11-floor-%d-%s.png"%[stage,"cached" if enabled else "vector"])
	print("PERF_V11_FLOOR_VISUALS stages=3 cache_comparison=true")
