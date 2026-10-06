extends SceneTree

const Art = preload("res://scripts/enemy_attack_visual.gd")
const Projectiles = preload("res://scripts/projectile_renderer.gd")
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void: _run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: passed+=1; print("PASS: ",message)
	else: failed+=1; push_error("FAIL: "+message)

func _run() -> void:
	var original := Rect2(-24,-31,48,48)
	for attack: String in ["beam","prism_cross","charge","stone_charge","pounce","spit","mortar","triple","mend"]:
		var enemy: Dictionary = {"hp":60,"attack_kind":attack,"telegraph":.01,"telegraph_max":.8,"attack_cd":0,"attack_cooldown":3.0,"flying":false}
		var saved: PackedByteArray = var_to_bytes(enemy)
		var full: Rect2 = Art.body_rect(original,enemy)
		_check(is_equal_approx(full.end.y,original.end.y),attack+": grounded anticipation keeps the original foot baseline")
		_check(full!=original and var_to_bytes(enemy)==saved,attack+": the visible body prepares without writing gameplay state")
		enemy.telegraph=0.0; enemy.attack_cd=3.0
		var release: Rect2 = Art.body_rect(original,enemy)
		_check(full.position.distance_to(release.position)<.02 and full.size.distance_to(release.size)<.02,attack+": release begins at the prepared body pose without popping")
		enemy.attack_cd=2.70
		_check(Art.body_rect(original,enemy)==original,attack+": recovery returns exactly to the original sprite rectangle")
	_test_beam_phases()
	_test_beam_capsule()
	_test_source_materials()
	await _real_locked_attack()
	print("ENEMY_ATTACK_VISUALS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _test_beam_phases() -> void:
	var pending: Dictionary = {"id":11,"pos":Vector2(100,250),"dir":Vector2(1,-.4).normalized(),"length":720.0,"radius":12.0,"delay":1.5,"telegraph_max":1.5,"active":false,"ttl":.22}
	var normal: Dictionary = Art.beam_sample(pending)
	_check(normal.warning_visible and normal.warning_alpha>=.85 and normal.warning_fill_alpha>=.1,"The first warning frame already shows a high-contrast axis and danger width")
	_check(normal.warning_origin==normal.origin and normal.warning_end==normal.end and normal.warning_radius==normal.radius,"Warning length and width exactly match the authority-locked beam geometry")
	_check(not normal.material_visible and normal.material_alpha==0.0 and normal.source_family=="emitter","Preparation uses a readable amber marker and emitter, without showing the damaging purple beam")
	for progress: float in [0.0,.1,.35,.6,.9,.999]:
		pending.delay=(1.0-progress)*1.5
		var phase: Dictionary=Art.beam_sample(pending,0.0,true)
		_check(phase.warning_visible and phase.warning_alpha>=.85 and phase.warning_fill_alpha>=.1 and not phase.material_visible,"No part of a low-FX windup can hide its warning before the beam fires")
		_check(phase.warning_origin==normal.origin and phase.warning_end==normal.end and phase.warning_radius==normal.radius,"Early and late preparation preserve the entire locked footprint")
	pending.delay=.09
	var late: Dictionary = Art.beam_sample(pending)
	for settings: Array in [[0.0,false],[.5,false],[1.0,true],[2.0,false]]:
		var sample: Dictionary = Art.beam_sample(pending,settings[0],settings[1])
		_check(sample.warning_origin==late.warning_origin and sample.warning_end==late.warning_end and sample.warning_radius==late.warning_radius and sample.warning_alpha==late.warning_alpha and sample.warning_fill_alpha==late.warning_fill_alpha,"FX settings cannot dim, shorten or narrow the essential warning")
		_check(not Art.Sprites.frame_data(sample.source_family,sample.source_phase).is_empty(),"The optional compact emitter has a loaded authored frame")
	var saved_pending: PackedByteArray = var_to_bytes(pending)
	_check(Art.beam_sample(pending)==Art.beam_sample(pending) and var_to_bytes(pending)==saved_pending,"Identical remote or paused snapshots produce identical samples without history")
	pending.active=true
	pending.delay=0.0
	var first: Dictionary = Art.beam_sample(pending)
	pending.ttl=.001
	var last: Dictionary = Art.beam_sample(pending)
	_check(first.material_visible and last.material_visible and first.material_alpha==1.0 and last.material_alpha==1.0,"Actual damage keeps an opaque laser from the first to the final active instant")
	_check(not first.warning_visible and not last.warning_visible and first.warning_alpha==0.0 and last.warning_fill_alpha==0.0,"The amber warning disappears exactly when the opaque damaging beam becomes active")
	_check(first.material_size==Vector2(720,24) and first.material_size==last.material_size,"Live damage never shrinks or fades its visible footprint before authority expiry")
	_check(first.origin==normal.warning_origin and first.end==normal.warning_end and first.radius==normal.warning_radius,"The actual laser occupies the same full footprint promised by its warning")
	_check(Art.Sprites.frame_index(first.material_family,first.material_phase)<Art.Sprites.frame_index(last.material_family,last.material_phase),"The fired laser advances through authored sustaining frames")
	for ttl: float in [.22,.17,.11,.05,.001]:
		pending.ttl=ttl
		var active: Dictionary=Art.beam_sample(pending,0.0,true)
		_check(active.material_alpha==1.0 and active.material_size==first.material_size and active.source_alpha==1.0 and not active.warning_visible,"Every live phase shows only the complete damaging beam even at the lowest FX setting")

func _test_beam_capsule() -> void:
	var sim=Simulation.new()
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2(1,-.4).normalized(),Vector2.UP]:
		var start:=Vector2(100,250)
		var finish: Vector2=start+direction*720.0
		var radius: float=12.0
		var capsule: PackedVector2Array=Art.warning_capsule(start,finish,radius)
		var perpendicular: Vector2=direction.orthogonal()
		_check(Geometry2D.is_point_in_polygon(start-direction*11.8,capsule) and Geometry2D.is_point_in_polygon(finish+direction*11.8,capsule),"Both endpoint caps visibly fill the true beam radius in every direction")
		_check(not Geometry2D.is_point_in_polygon(start-direction*12.2,capsule) and not Geometry2D.is_point_in_polygon(finish+direction*12.2,capsule),"Caps do not advertise a radius larger than the actual segment-circle hazard")
		_check(Geometry2D.is_point_in_polygon(start.lerp(finish,.5)+perpendicular*11.8,capsule) and not Geometry2D.is_point_in_polygon(start.lerp(finish,.5)+perpendicular*12.2,capsule),"Adding end caps preserves the exact straight-side width")
		var player_center: Vector2=finish+direction*25.0
		var player_near_edge: Vector2=player_center-direction*15.0
		_check(sim._segment_circle(start,finish,player_center,radius+15.0)>=0.0 and Geometry2D.is_point_in_polygon(player_near_edge,capsule),"A player hit 25px beyond the endpoint visibly overlaps the filled cap with their 15px body")
		_check(sim._segment_circle(start,finish,finish+direction*28.0,radius+15.0)<0.0 and not Geometry2D.is_point_in_polygon(finish+direction*13.0,capsule),"A player fully beyond the capsule neither overlaps its fill nor takes endpoint damage")

func _test_source_materials() -> void:
	for kind: String in ["charge","stone_charge","pounce"]:
		var actor: Dictionary={"attack_kind":kind,"radius":23.0}
		var before: PackedByteArray=var_to_bytes(actor)
		var right: Dictionary=Art.preparation_sample(actor,Vector2(100,200),Vector2.RIGHT,.8,17)
		var left: Dictionary=Art.preparation_sample(actor,Vector2(100,200),Vector2.LEFT,.8,17)
		_check(right.origin==left.origin and right.origin.distance_to(Vector2(100,217))<=4 and right.size.x<=52,"A "+kind+" only disturbs the ground directly beneath its braced feet")
		_check(right==Art.preparation_sample(actor,Vector2(100,200),Vector2.RIGHT,.8,17) and var_to_bytes(actor)==before,kind+" preparation is stable while paused and cannot change the attack")
	for kind: String in ["mortar","burrow","stone_spikes","spore_bloom","blink"]:
		_check(Art.preparation_sample({"attack_kind":kind},Vector2.ZERO,Vector2.RIGHT,.9,17).is_empty(),kind+" does not display an unrelated muzzle flash alongside its own destination material")
	for pair: Array in [["spit","spit"],["mend","energy"]]:
		var bud: Dictionary=Art.preparation_sample({"attack_kind":pair[0],"radius":23.0},Vector2.ZERO,Vector2.RIGHT,.95,17)
		var bullet: Dictionary=Projectiles.enemy_sample(pair[1],6.0,.1)
		_check(bud.family==bullet.family and bud.tint.a<bullet.tint.a and bud.size.x<bullet.size.x and bud.origin==Vector2(26,0),"The "+pair[0]+" source forms a smaller, dimmer copy of the actual harmful ammunition")
	_check(Projectiles.enemy_sample("spit",6,.2).family=="spore_shot" and Projectiles.enemy_sample("crystal",6,.2).family=="crystal_shot","Organic and crystal enemies shoot distinct authored materials")
	_check(Projectiles.enemy_sample("energy",6,.2).family=="crystal_shot","A conductor's harmful guided projectile is coral ammunition, distinct from mint healing")
	for kind: String in ["spit","crystal","pulse","energy","boss_spore_orb"]:
		for age: float in [0.0,.1,.3,1.25]:
			var sample: Dictionary=Projectiles.enemy_sample(kind,6,age)
			_check(sample.tint.a==1.0 and sample.size.y>=12.0 and not Art.Sprites.frame_data(sample.family,sample.phase).is_empty(),kind+" retains its opaque body throughout travel")

func _real_locked_attack() -> void:
	var sim = Simulation.new()
	sim.start_run([{"id":1,"name":"Visual audit","character":"ranger"}],19019)
	sim.state.enemies.clear(); sim.state.hazards.clear(); sim.state.chests.clear()
	sim.state.platforms=[Rect2(0,600,5000,80)]
	sim.state.floor_y=600.0
	sim._spawn_clock=9999.0
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(2450,579); player.vel=Vector2.ZERO; player.invuln=1000.0
	var enemy: Dictionary=sim._spawn_enemy("sentinel",Vector2(2000,583))
	enemy.grounded=true
	sim._begin_enemy_attack(enemy,player)
	var hazard: Dictionary=sim.state.hazards[0]
	var locked: Dictionary=Art.beam_sample(hazard)
	player.pos=Vector2(1740,480)
	var world=World.new()
	root.add_child(world)
	world.set_process(false)
	world.fx_scale=0.0; world.reduced_motion=true
	world.scenery_cache_enabled=false
	var geometry_locked: bool=true
	var readonly: bool=true
	var active_seen: bool=false
	var samples: int=0
	var warning_frames: int=0
	var warning_continuous: bool=true
	var ticks: int=ceili((float(hazard.telegraph_max)+Art.ACTIVE_LIFETIME+.35)*60.0)
	for tick: int in range(ticks):
		sim.step(1.0/60.0,{})
		for live: Dictionary in sim.state.hazards:
			if int(live.id)!=int(hazard.id): continue
			var sample: Dictionary=Art.beam_sample(live,0.0,true)
			geometry_locked=geometry_locked and sample.origin==locked.origin and sample.end==locked.end and sample.radius==locked.radius and sample.direction==locked.direction
			active_seen=active_seen or bool(sample.active)
			if not bool(sample.active):
				warning_frames+=1
				warning_continuous=warning_continuous and sample.warning_visible and sample.warning_alpha>=.85 and sample.warning_end==locked.end
			else:
				warning_continuous=warning_continuous and not sample.warning_visible and sample.material_visible
			samples+=1
		var frame: Dictionary=sim.get_snapshot()
		var before: PackedByteArray=var_to_bytes(frame)
		world.set_frame(frame,1,1.0/60.0)
		world.camera_position=Vector2(2160,550)
		world.queue_redraw()
		if tick%8==0: await process_frame
		readonly=readonly and var_to_bytes(frame)==before
	_check(samples>50 and active_seen,"A real sentinel progresses through its full windup into an active release")
	_check(warning_continuous and warning_frames>=int(float(hazard.telegraph_max)*60.0)-2,"Every real windup frame shows the full warning, then only the damaging laser")
	_check(geometry_locked,"Dodging across a real sentinel cannot retarget either charge or fired-beam geometry")
	_check(readonly,"The real WorldView preparation and release path leaves snapshots immutable")
	_check(sim.state.hazards.is_empty(),"The beam visual disappears when the authority expires its hazard")
	world.queue_free()
	await process_frame
