extends SceneTree

const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sim: Variant=Simulation.new()
	sim.start_run([{"id":1,"name":"Cache","character":"ranger"}],909)
	var world: Node2D=World.new()
	root.add_child(world)
	world.set_process(false)
	world.interpolate_remote_entities=true
	for stage: int in range(1,4):
		sim._build_stage(stage)
		var snapshot: Dictionary=sim.get_snapshot()
		var original: PackedByteArray=var_to_bytes(snapshot)
		for pass_index: int in range(4):
			world.set_frame(snapshot,1,0.0)
			await process_frame
		var stats: Dictionary=world.scenery_cache_stats()
		_check(int(stats.entries)>0 and int(stats.entries)<=int(stats.max_entries) and int(stats.bytes)<=int(stats.max_bytes),"Stage %d creates scenery within entry and memory limits"%stage)
		_check(var_to_bytes(snapshot)==original,"Stage %d cached rendering leaves the client snapshot unchanged"%stage)
		_check(world._terrain_tiles(snapshot.platforms[0])==Vector2i(-1,-1),"Stage %d ground retains screen-dependent depth instead of being cropped to a texture"%stage)
		var before: Vector2=world.camera_position
		world._camera_ready=true
		world.camera_position+=Vector2(40,-10)
		world.set_frame(snapshot,1,0.0)
		_check(world._background_live and world.camera_position!=before,"Stage %d moving camera preserves continuously updated parallax"%stage)
		var point: Vector2=Vector2(snapshot.spawn)
		_check(world.screen_to_world(world.world_to_screen(point)).is_equal_approx(point),"Stage %d caching preserves aim/world coordinate conversion"%stage)
		# Simulate long traversal without growing an unbounded off-screen cache.
		for step: int in range(48):
			world.camera_position=Vector2(640+step*103,700+(step%9)*90)
			world._prepare_scenery_cache()
			await process_frame
		stats=world.scenery_cache_stats()
		_check(stats.entries<=stats.max_entries and stats.bytes<=stats.max_bytes,"Stage %d long traversal remains bounded"%stage)
		# Geometry may be replaced without changing the stage number.
		var old_viewport: WeakRef
		if not world._scenery_cache.is_empty(): old_viewport=weakref(world._scenery_cache.values()[0].viewport)
		var changed: Dictionary=snapshot.duplicate(true)
		changed.platforms.append(Rect2(190,840,350,28))
		world.set_frame(changed,1,0.0)
		await process_frame
		await process_frame
		_check(old_viewport==null or old_viewport.get_ref()==null,"Stage %d same-stage layout changes invalidate and release old cache resources"%stage)
		_check(var_to_bytes(snapshot)==original,"Stage %d invalidation never edits the old source layout"%stage)
	world.queue_free()
	await process_frame
	print("RENDER_CACHE_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _check(condition: bool,message: String) -> void:
	if condition:
		passed+=1
		print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)
