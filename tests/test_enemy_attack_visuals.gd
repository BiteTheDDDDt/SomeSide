extends SceneTree

const Art = preload("res://scripts/enemy_attack_visual.gd")
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
	var pending: Dictionary = {"id":11,"pos":Vector2(100,250),"dir":Vector2(1,-.4).normalized(),"length":720.0,"radius":12.0,"delay":.36,"telegraph_max":.9,"active":false,"ttl":.22}
	var normal: Dictionary = Art.beam_sample(pending)
	_check(normal.sprite_family=="charge" and is_equal_approx(float(normal.sprite_phase),.6),"The replicated windup timer selects the authored charge sequence")
	for settings: Array in [[0.0,false],[.5,false],[1.0,true],[2.0,false]]:
		var sample: Dictionary = Art.beam_sample(pending,settings[0],settings[1])
		_check(sample.origin==normal.origin and sample.end==normal.end and sample.radius==normal.radius and sample.edge_alpha==normal.edge_alpha,"FX settings preserve the entire authoritative warning capsule and its contrast")
		_check(int(sample.filaments)<=Art.MAX_FILAMENTS and (int(sample.filaments)==0 if float(settings[0])<.6 or bool(settings[1]) else true),"Optional charge filaments stay bounded and respect low/reduced-motion settings")
	var saved_pending: PackedByteArray = var_to_bytes(pending)
	_check(Art.beam_sample(pending)==Art.beam_sample(pending) and var_to_bytes(pending)==saved_pending,"Identical remote or paused snapshots produce identical charge samples without history")
	pending.active=true
	var first: Dictionary = Art.beam_sample(pending)
	pending.ttl=.001
	var last: Dictionary = Art.beam_sample(pending)
	_check(first.sprite_family=="beam" and first.sprite_phase<last.sprite_phase,"Active beam lifetime advances the actual textured release frames")
	_check(float(first.core_width)>float(last.core_width),"The fired beam core decays across its real active lifetime")
	_check(first.edge_alpha==last.edge_alpha and first.fill_alpha==last.fill_alpha and first.radius==last.radius,"Fading the core never hides still-active damage or shrinks its boundary")
	await _real_locked_attack()
	print("ENEMY_ATTACK_VISUALS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

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
	for tick: int in range(78):
		sim.step(1.0/60.0,{})
		for live: Dictionary in sim.state.hazards:
			if int(live.id)!=int(hazard.id): continue
			var sample: Dictionary=Art.beam_sample(live,0.0,true)
			geometry_locked=geometry_locked and sample.origin==locked.origin and sample.end==locked.end and sample.radius==locked.radius and sample.direction==locked.direction
			active_seen=active_seen or bool(sample.active)
			samples+=1
		var frame: Dictionary=sim.get_snapshot()
		var before: PackedByteArray=var_to_bytes(frame)
		world.set_frame(frame,1,1.0/60.0)
		world.camera_position=Vector2(2160,550)
		world.queue_redraw()
		if tick%8==0: await process_frame
		readonly=readonly and var_to_bytes(frame)==before
	_check(samples>50 and active_seen,"A real sentinel progresses from warning into an active release")
	_check(geometry_locked,"Dodging across a real sentinel cannot retarget either charge or fired-beam geometry")
	_check(readonly,"The real WorldView preparation and release path leaves snapshots immutable")
	_check(sim.state.hazards.is_empty(),"The beam visual disappears when the authority expires its hazard")
	world.queue_free()
	await process_frame
