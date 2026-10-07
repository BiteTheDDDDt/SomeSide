extends SceneTree

const Geometry = preload("res://scripts/combat_geometry.gd")
const Actors = preload("res://scripts/geometric_enemies.gd")
const Art = preload("res://scripts/enemy_attack_visual.gd")
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
const Illustrated = preload("res://scripts/illustrated_enemy_renderer.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error("FAIL: ",label)

func _run() -> void:
	_check(Geometry.PROFILES.size()==12,"Each existing enemy/boss has a material vocabulary; all production bodies are migrated")
	_check(Geometry.EDGE>=2.0 and Geometry.EDGE>Geometry.DETAIL and Geometry.BACK>Geometry.EDGE,"Danger edges retain a readable logical-pixel hierarchy")
	for kind: String in ["sentinel","crawler","spitter","spore_moth","drone","charger","burrower","skirmisher","conductor","boss"]:
		_check(Actors.supports(kind),kind+" uses the new opaque body path")
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(-1,-.6).normalized(),Vector2(1,.7).normalized()]:
		var sim=Simulation.new()
		sim.start_run([{"id":1,"name":"Anchor","character":"ranger"}],20004)
		var enemy: Dictionary=sim._spawn_enemy("spitter",Vector2(1000,500))
		enemy.attack_dir=direction
		var before: PackedByteArray=var_to_bytes(enemy)
		var start: Vector2=Vector2(enemy.pos)+Geometry.source_offset(enemy,direction)
		var preview: Dictionary=Art.preparation_sample(enemy.merged({"attack_kind":"spit"},true),enemy.pos,direction,.9,17)
		sim._enemy_shoot(enemy,direction,270.0,10.0,"spit")
		var projectile: Dictionary=sim.state.projectiles.back()
		_check(start.is_equal_approx(projectile.pos) and preview.origin.is_equal_approx(start),"A real projectile and its prepared bead share the mouth anchor in every aim direction")
		var facing: float=1.0 if direction.x>=0.0 else -1.0
		var local: Vector2=Geometry.source_offset(enemy,Geometry.local_direction(enemy))*Vector2(facing,1)
		_check(local.is_equal_approx(start-Vector2(enemy.pos)) and var_to_bytes(enemy)==before,"Mirrored visible mouth meets the authoritative muzzle without mutating the actor")
		var hazard: Dictionary={"pos":Vector2(1000,500),"dir":direction,"length":720.0,"radius":12.0,"delay":1.5,"telegraph_max":1.5,"active":false,"ttl":.22}
		var ready: Dictionary=Art.beam_sample(hazard,0.0,true)
		hazard.active=true
		var live: Dictionary=Art.beam_sample(hazard,0.0,true)
		_check(ready.geometry==live.geometry and ready.warning_fill_alpha==0 and not ready.material_visible and live.material_alpha==1.0,"Hollow and solid beam phases use one identical full capsule even at minimum FX")
		_check(Geometry.source_offset({"kind":"sentinel"},direction)==Vector2.ZERO,"Sentinel socket remains at the locked source through aim and recoil")
	_test_warning_style()
	_test_illustrated_faces()
	_test_laser_lifetime()
	_test_feedback()
	await _integration()
	print("COMBAT_GEOMETRY_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _test_illustrated_faces() -> void:
	# Regression: clockwise orthogonal inverted the face UV patch, removing
	# the prism's eye and folding its entire crown through the torso.
	for id: String in ["sentinel","boss_prism"]:
		var e: Dictionary={"kind":"boss" if id=="boss_prism" else id,"boss_style":"prism","attack_dir":Vector2.RIGHT,"radius":44}
		var shape: Dictionary=Illustrated.vertices(Illustrated.sample(e,0.0))
		var def: Dictionary=Illustrated.DEFINITIONS[id]
		var organ_uv: Vector2=(Rect2(def.region).position+Vector2(def.organ)*Rect2(def.region).size)/Vector2(1448,1086)
		var anchor_index: int=-1
		for i: int in range(shape.uv.size()):
			if Vector2(shape.uv[i]).is_equal_approx(organ_uv): anchor_index=i
		_check(anchor_index>=0 and Vector2(shape.positions[anchor_index]).is_equal_approx(Vector2.ZERO),id+" visible eye remains exactly at the real beam origin")
		var above: bool=false
		for i: int in range(shape.uv.size()):
			var uv: Vector2=shape.uv[i]
			if is_equal_approx(uv.x,organ_uv.x) and uv.y<organ_uv.y:
				above=true
				if Vector2(shape.positions[i]).y>=0: above=false; break
		_check(above,id+" crown stays above its eye instead of folding through it")

func _test_feedback() -> void:
	for kind: String in ["beam","spit","pounce"]:
		var control=Simulation.new()
		var sample=Simulation.new()
		var peers: Array=[{"id":1,"name":"Damage","character":"ranger"}]
		control.start_run(peers,204); sample.start_run(peers,204)
		control.state.players[1].invuln=0.0; sample.state.players[1].invuln=0.0
		control.events.clear(); sample.events.clear()
		control._damage_player(control.state.players[1],12.0,Vector2(10,20))
		sample._damage_player(sample.state.players[1],12.0,Vector2(10,20),{"attack_kind":kind,"enemy_id":17,"aim":Vector2.LEFT})
		_check(var_to_bytes(control.get_snapshot())==var_to_bytes(sample.get_snapshot()),kind+" contact metadata leaves HP, knockback, immunity, state IDs and every gameplay field unchanged")
		var hit: Dictionary=sample.events.filter(func(e: Dictionary) -> bool: return e.type=="hit")[0]
		_check(hit.attack_kind==kind and hit.enemy_id==17 and hit.aim==Vector2.LEFT,kind+" preserves actual source and impact direction in the hit event")
		var world=World.new()
		root.add_child(world); world.set_process(false)
		world.set_frame(sample.get_snapshot(),1,0)
		world.push_events(sample.events)
		_check(world._effects.size()==1 and world._effects[0].kind=="hostile_contact" and world._effects[0].family==Geometry.impact_family(kind),kind+" yields a short material-specific contact, without a ring or persistent beam")
		world._process(.2)
		_check(world._effects.is_empty(),kind+" contact fragments expire promptly after impact")
		world.free()

func _integration() -> void:
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Crossing","character":"ranger"}],204)
	sim._build_stage(3); sim.state.enemies.clear(); sim.state.chests.clear(); sim._spawn_clock=9999
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(1300,float(sim.state.floor_y)-21); player.invuln=1000.0
	for kind: String in ["sentinel","crawler","spitter","spore_moth","drone","charger","burrower","skirmisher","conductor","boss"]:
		var enemy: Dictionary=sim._spawn_enemy(kind,Vector2(1000,float(sim.state.floor_y)-17))
		enemy.grounded=true; enemy.attack_cd=0.0
	var world=World.new(); root.add_child(world); world.set_process(false)
	world.fx_scale=0.0; world.interpolate_remote_entities=true
	var readonly: bool=true
	var effects_bounded: bool=true
	for tick: int in range(240):
		sim.step(1.0/60.0,{})
		var frame: Dictionary=sim.get_snapshot()
		var saved: PackedByteArray=var_to_bytes(frame)
		world.set_frame(frame,1,1.0/60.0); world.push_events(sim.events); world._process(1.0/60.0)
		world.camera_position=Vector2(1200,float(sim.state.floor_y)-170)
		if tick%20==0: await process_frame
		readonly=readonly and var_to_bytes(frame)==saved
		effects_bounded=effects_bounded and world._effects.size()<=world.MAX_EFFECTS
	_check(readonly and effects_bounded,"Mixed real attacks with remote interpolation and low FX keep snapshots immutable and effects bounded")
	world.queue_free(); await process_frame

func _test_warning_style() -> void:
	var minimum: float = 1.0
	var maximum: float = 0.0
	for tick: int in range(120):
		var opacity: float = Geometry.warning_alpha(tick/60.0)
		minimum=minf(minimum,opacity); maximum=maxf(maximum,opacity)
	_check(minimum>=.67 and maximum-minimum>.3,"Red pulse stays visible throughout each two-Hz cycle")
	for finish: Vector2 in [Vector2(720,0),Vector2(-420,180),Vector2(0,-320)]:
		var shape: PackedVector2Array = Geometry.capsule(Vector2.ZERO,finish,12)
		var dashes: PackedVector2Array = Geometry.dashed_boundary(shape)
		var valid: bool = dashes.size()>20 and dashes.size()%2==0 and dashes.size()<1000
		for point: Vector2 in dashes:
			var distance: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2.ZERO,finish))
			valid=valid and point.is_finite() and absf(distance-12)<.1
		_check(valid,"Warning dashes stay on the actual capsule boundary, including mirrored and vertical beams")
		_check(Geometry.beam_fade(Vector2.ZERO,Vector2.ZERO,finish)>Geometry.beam_fade(finish*.5,Vector2.ZERO,finish) and Geometry.beam_fade(finish,Vector2.ZERO,finish)>.1,"Distance falloff is monotonic and never hides the far end")

func _test_laser_lifetime() -> void:
	var capture=load("res://tools/capture-natural-warnings-v0201.gd")
	for kind: String in ["beam","prism_beam","prism_cross"]:
		var setup: Dictionary=capture.fixture(kind,false)
		var sim=setup.sim
		var enemy: Dictionary=setup.enemy
		var player: Dictionary=sim.state.players[1]
		var original: Vector2=enemy.pos
		var ttl_ok: bool=true
		for hazard: Dictionary in sim.state.hazards: ttl_ok=ttl_ok and is_equal_approx(float(hazard.ttl),.55)
		_check(ttl_ok,kind+" owns a 550ms authoritative damage window")
		player.invuln=1000.0
		for tick: int in range(160):
			sim.step(1.0/60.0,{})
			if not sim.state.hazards.is_empty() and bool(sim.state.hazards[0].active): break
		var frozen: bool=true
		var active_ticks: int=0
		while not sim.state.hazards.is_empty() and active_ticks<60:
			var hazard: Dictionary=sim.state.hazards[0]
			var sample: Dictionary=Art.beam_sample(hazard,0,true)
			frozen=frozen and Vector2(enemy.pos).is_equal_approx(original) and not sample.warning_visible and float(sample.warning_alpha)==0.0 and sample.material_visible
			sim.step(1.0/60.0,{})
			active_ticks+=1
		_check(active_ticks>=32 and active_ticks<=34 and frozen,kind+" keeps its source locked and has no warning throughout the extended active interval")
		_check(sim.state.hazards.is_empty(),kind+" removes all damage geometry at the actual end")
	var setup: Dictionary=capture.fixture("beam",false)
	var sim=setup.sim
	var player: Dictionary=sim.state.players[1]
	player.invuln=1000.0
	player.pos=Vector2(setup.enemy.pos)+Vector2(-250,0)
	while not bool(sim.state.hazards[0].active): sim.step(1.0/60.0,{})
	var hazard: Dictionary=sim.state.hazards[0]
	# Enter late, after the previous 220ms duration, while damage still exists.
	for tick: int in range(17): sim.step(1.0/60.0,{})
	player.pos=Vector2(hazard.pos)+Vector2(hazard.dir)*200
	player.invuln=0.0
	var before: float=player.hp
	sim.step(1.0/60.0,{})
	var after: float=player.hp
	_check(after<before,"Late entry after 220ms is hit by the real extended beam")
	player.invuln=0.0; player.pos=Vector2(hazard.pos)+Vector2(hazard.dir)*200
	sim.step(1.0/60.0,{})
	_check(is_equal_approx(float(player.hp),after),"One beam still damages each player at most once even when immunity is cleared")
	var area: Dictionary=capture.fixture("mortar")
	_check(is_equal_approx(float(area.sim.state.hazards[0].ttl),.22),"Extending lasers leaves area attack damage durations unchanged")
