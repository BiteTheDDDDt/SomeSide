extends SceneTree

const World = preload("res://scripts/world_view.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		passed+=1
		print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)

func _run() -> void:
	var world := World.new()
	world.web_background_cache_enabled=true
	root.add_child(world)
	world.set_process(false)
	world._frame={"stage":1,"biome":"rainforest","world_size":Vector2(7200,1900),"platforms":[Rect2(600,500,500,25)],"landmarks":[]}
	world.camera_position=Vector2(900,500)
	var before: PackedByteArray=var_to_bytes(world._frame)
	world._prepare_scenery_cache()
	_check(world._background_cache.is_empty() and not world._web_background.is_empty(),"Web creates only its retained background, without the native30Hz background")
	_check(world._web_background.viewport.size==Vector2i(1792,976),"Background overscan is256×128 logical pixels around the original1280×720 composition")
	_check(world._web_background.painter.screen_size==Vector2(1280,720) and world._web_background.painter.background_margin==Vector2(256,128),"Padding keeps the original biome viewport and moon composition")
	_check(world._web_background.viewport.render_target_update_mode==SubViewport.UPDATE_ONCE,"Each web background is baked once")
	_check(world.scenery_cache_stats().background_bytes==6995968 and world.scenery_cache_stats().background_entries==1,"Initial texture accounting matches actual overscan allocation")
	var anchor: Vector2=world.camera_position
	var previous: Vector2=world._web_background_offset(world._web_background)
	var continuous: bool=true
	for index: int in range(1,241):
		world._clock=float(index)/60.0
		world.camera_position=anchor+Vector2(index*2.0,index*.2)
		world._prepare_web_background()
		var offset: Vector2=world._web_background_offset(world._web_background)
		continuous=continuous and (offset-previous).distance_to(Vector2(-.36,-.036))<0.0001
		previous=offset
	_check(continuous,"Background translation stays continuous for every camera step, independent of baking cadence")
	_check(world._web_background_builds==1 and world._web_background_pending.is_empty(),"Four seconds of smooth short movement do not rebuild the background every frame")
	_check(world._web_background.painter.clock_value==0.0,"Ambient vine time is retained with the cached image")
	_check(world._web_background_covers(world._web_background),"Ordinary movement stays within the padded image")
	var has_cached_foliage: bool=false
	for entry: Dictionary in world._scenery_cache.values():
		if entry.painter.mode=="terrain": has_cached_foliage=has_cached_foliage or entry.painter.freeze_foliage
	_check(has_cached_foliage,"Web terrain bake includes its static fern geometry")
	world.camera_position=anchor+Vector2(700,0)
	world._prepare_web_background()
	var old_viewport: SubViewport=world._web_background.viewport
	_check(world._web_background_builds==2 and not world._web_background_pending.is_empty() and world._web_background.viewport==old_viewport,"Reanchor prepares a second texture while keeping the original available")
	var stats: Dictionary=world.scenery_cache_stats()
	_check(stats.background_entries==2 and stats.background_bytes==13991936 and stats.background_bytes<=stats.background_max_bytes,"Both textures together stay below the16MiB budget")
	world._web_background_pending.ready=Engine.get_process_frames()
	world._prepare_web_background()
	_check(is_zero_approx(world._web_background_mix()) and world._web_background.viewport==old_viewport,"A ready replacement starts at zero opacity instead of popping to a new parallax anchor")
	world._clock+=.11
	world._prepare_web_background()
	_check(is_equal_approx(world._web_background_mix(),.5),"Replacement crossfade is based on elapsed time")
	world._clock+=.12
	world._prepare_web_background()
	_check(world._web_background_pending.is_empty() and world._web_background.viewport!=old_viewport and old_viewport.is_queued_for_deletion(),"Completed transition releases the old image and retains only the new one")
	world.camera_position+=Vector2(5000,0)
	_check(not world._web_background_covers(world._web_background),"Large same-stage camera jumps are detected before drawing an uncovered border")
	_check(not world._draw_web_background(),"A teleport outside retained coverage selects the complete live fallback instead of drawing empty edges")
	world._prepare_web_background()
	_check(world._web_background_covers(world._web_background_pending) and not world._draw_web_background(),"Teleport replacement uses the new camera anchor while incomplete textures keep the safe fallback")
	_check(var_to_bytes(world._frame)==before,"All background and foliage preparation leaves the simulation snapshot unchanged")
	world.screen_size=Vector2(1100,700)
	world._prepare_web_background()
	_check(world._web_background.screen_size==world.screen_size and world._web_background_pending.is_empty(),"Viewport changes reset both anchors before rebuilding")
	world.screen_size=Vector2(4096,4096)
	world._prepare_web_background()
	_check(world._web_background.is_empty() and world.scenery_cache_stats().background_bytes==0,"Oversized viewport requests fall back without exceeding the texture budget")
	world.screen_size=Vector2(1280,720)
	world._prepare_web_background()
	world._clear_scenery_cache()
	_check(world._web_background.is_empty() and world._web_background_pending.is_empty() and world._scenery_cache.is_empty(),"Stage/layout cleanup clears web backgrounds and terrain together")
	world.queue_free()
	await process_frame
	var native := World.new()
	native.web_background_cache_enabled=false
	root.add_child(native)
	native.set_process(false)
	native._frame={"stage":1,"biome":"rainforest","world_size":Vector2(7200,1900),"platforms":[Rect2(600,500,500,25)],"landmarks":[]}
	native.camera_position=Vector2(900,500)
	native._prepare_scenery_cache()
	_check(not native._background_cache.is_empty() and native._web_background.is_empty(),"Native rendering retains its existing background path")
	var native_foliage: bool=true
	for entry: Dictionary in native._scenery_cache.values():
		if entry.painter.mode=="terrain": native_foliage=native_foliage and not entry.painter.freeze_foliage
	_check(native_foliage,"Native terrain continues to leave foliage for its live animation pass")
	native.queue_free()
	await process_frame
	print("WEB_BACKGROUND_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
