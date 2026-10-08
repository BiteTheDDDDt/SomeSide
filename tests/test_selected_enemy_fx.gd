extends SceneTree
const FX=preload("res://scripts/selected_enemy_fx.gd")
const Capture=preload("res://tools/capture-combat-unity-v0209.gd")
const World=preload("res://scripts/world_view.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	FX.prepare()
	var stat: Dictionary=FX.cache_stats()
	check(stat.textures==4 and stat.bytes<=stat.max_bytes,"Selected sheets and supplements fit their 10MiB budget")
	for family: String in ["spore","stone","blink"]:
		for i: int in range(8):
			var pose: Dictionary=FX.placement(family,i,Vector2(400,200),48)
			check(Rect2(Vector2.ZERO,pose.source).encloses(pose.region) and pose.rect.has_area(),family+" frame stays within its source atlas")
			check(pose.anchor==Vector2(400,217) if family!="blink" else pose.anchor==Vector2(400,200),family+" retains its fixed base/center through animation")
	check(FX.frame_index(false,1)==3 and FX.frame_index(true,0)==4 and FX.frame_index(true,1)==6 and FX.frame_index(false,0,true)==7,"Harmless preparation cannot sample a burst; recovery cannot sample a live shape")
	var setup: Dictionary=Capture.fixture("blink")
	var sim=setup.sim
	var enemy: Dictionary=setup.enemy
	var source: Vector2=enemy.pos
	var target: Vector2=enemy.blink_target
	var captured: Dictionary={}
	for tick: int in range(60):
		sim.step(1.0/60.0,{})
		for event: Dictionary in sim.events:
			if event.type=="dash" and event.get("kind","")=="blink": captured=event.duplicate(true)
	check(not captured.is_empty() and captured.from==source and captured.pos==target,"Real teleport reports both authoritative endpoints")
	var view=World.new(); root.add_child(view); view.set_process(false)
	if not captured.is_empty(): view.push_events([captured])
	var origins: Array=[]
	for effect: Dictionary in view._effects:
		if effect.get("family","")=="rift": origins.append(effect.pos)
	check(origins.size()==2 and source in origins and target in origins,"Departure and arrival both receive the new animation")
	var area: Dictionary=Capture.fixture("mortar")
	var authority=area.sim
	var active_seen: bool=false
	var residue_seen: bool=false
	var readonly: bool=true
	for tick: int in range(150):
		var state: Dictionary=authority.get_snapshot()
		var before: PackedByteArray=var_to_bytes(state)
		view._process(1.0/60.0)
		view.set_frame(state,1,1.0/60.0)
		active_seen=active_seen or Array(state.hazards).any(func(h: Dictionary)->bool:return bool(h.active))
		for effect: Dictionary in view._effects:
			if effect.kind=="area_recovery": residue_seen=true
		readonly=readonly and before==var_to_bytes(state)
		authority.step(1.0/60.0,{})
	check(active_seen and residue_seen and readonly,"Actual expiry produces only harmless residue without mutating the snapshot")
	for tick: int in range(30): view._process(1.0/60.0)
	check(not view._effects.any(func(e: Dictionary)->bool:return str(e.kind)=="area_recovery"),"Spent husks cannot linger as a hazard-looking outline")
	view.queue_free()
	print("SELECTED_ENEMY_FX_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
