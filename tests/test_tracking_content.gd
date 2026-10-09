extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const G=preload("res://scripts/projectile_guidance.gd")
const T=preload("res://scripts/tracking_rules.gd")
const Art=preload("res://scripts/tracking_art.gd")
const Content=preload("res://scripts/content.gd")
const Catalog=preload("res://scripts/enemy_catalog.gd")
const Locale=preload("res://scripts/localization.gd")
const Sound=preload("res://scripts/soundscape.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	_guidance()
	_weapons()
	_beacon()
	_weaver()
	_moth()
	_collision()
	_lifecycle()
	_integration()
	_stress_and_marks()
	_mixed_devices_and_authority()
	print("TRACKING_CONTENT_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func check(ok: bool,message: String) -> void:
	if ok: passed+=1; print("PASS: ",message)
	else: failed+=1; push_error("FAIL: "+message)

func fresh(roles: Array=["weaver"]):
	var sim=Sim.new()
	var roster: Array=[]
	for i: int in range(roles.size()): roster.append({"id":i+1,"name":"Trace","character":roles[i]})
	sim.start_run(roster,823023)
	sim.state.platforms=[Rect2(0,800,6000,200)]
	sim.state.solid_cover=[Rect2(0,800,6000,200)]
	sim.state.floor_y=800.0
	sim.state.chests.clear(); sim._spawn_clock=99999
	for p: Dictionary in sim.state.players.values():
		p.pos=Vector2(1000,779); p.grounded=true; p.vel=Vector2.ZERO; p.invuln=0.0
	return sim

func dummy(sim,pos: Vector2=Vector2(1200,770),kind: String="crawler") -> Dictionary:
	var e: Dictionary=sim._spawn_enemy(kind,pos)
	e.hp=10000.0; e.max_hp=10000.0; e.attack_cd=9999.0; e.move_speed=0.0
	return e

func fly(sim,seconds: float,dt: float=1.0/60.0) -> void:
	for i: int in range(int(round(seconds/dt))): sim._step_projectiles(dt)

func _guidance() -> void:
	var near: Dictionary={"id":2,"pos":Vector2(80,10),"hp":1.0}
	var aligned: Dictionary={"id":4,"pos":Vector2(300,0),"hp":1.0}
	check(G.lock(Vector2.ZERO,Vector2.RIGHT,[near,aligned],G.NEEDLE).target_id==4,"New ordinary acquisition orders angle before distance")
	check(G.lock(Vector2.ZERO,Vector2.RIGHT,[aligned,near],G.STORM).target_id==2,"Legacy acquisition still orders nearest distance")
	var tie: Dictionary=aligned.duplicate(); tie.id=3
	check(G.lock(Vector2.ZERO,Vector2.RIGHT,[aligned,tie],G.SEEKER).target_id==3,"Stable ID breaks equal angle/distance ties")
	for preset: Dictionary in [G.NEEDLE,G.BLADE,G.SEEKER]:
		var target: Dictionary={"id":1,"hp":1.0,"pos":Vector2(200,20)}
		var shot: Dictionary={"pos":Vector2.ZERO,"vel":Vector2(360,0),"ttl":3.0,"guidance":G.lock(Vector2.ZERO,Vector2.RIGHT,[target],preset)}
		var total: float=0
		var bounded: bool=true
		for i: int in range(180):
			target.pos=Vector2(1000 if i>60 else 200,100 if i%20<10 else -100)
			var before: Vector2=shot.vel
			shot.vel=G.steer(shot,target,1.0/60.0)
			var angle: float=absf(before.angle_to(shot.vel))
			total+=angle
			bounded=bounded and angle<=deg_to_rad(float(preset.rate))/60+.00001 and is_equal_approx(Vector2(shot.vel).length(),360.0)
		check(bounded,"%s angular cap and speed are invariant"%preset.mode)
		check(bool(shot.guidance.active) if str(preset.mode)=="persistent" else (not bool(shot.guidance.active) and total<=deg_to_rad(float(preset.turn))+.00001),"%s uses its own flight-validity and turn budget"%preset.mode)
		var previous: Vector2=shot.vel
		target.hp=0
		shot.vel=G.steer(shot,target,.05)
		check(shot.vel==previous and not shot.guidance.active,"%s invalidation is terminal and never retargets"%preset.mode)
	var target: Dictionary={"id":7,"hp":1,"pos":Vector2(200,0)}
	var shot: Dictionary={"pos":Vector2.ZERO,"vel":Vector2(360,0),"ttl":2.8,"guidance":G.lock(Vector2.ZERO,Vector2.RIGHT,[target],G.SEEKER)}
	target.pos=Vector2(-100,100)
	for i: int in range(90): shot.vel=G.steer(shot,target,1.0/60.0)
	check(shot.guidance.active and Vector2(shot.vel).x<0,"Persistent seeker turns behind without finite pass-stop or total-angle exhaustion")
	shot.ttl=0
	G.steer(shot,target,.02)
	check(not shot.guidance.active,"Persistent guidance respects absolute projectile expiry")

func _weapons() -> void:
	for weapon: String in ["arc_needle","star_seeker"]:
		var sim=fresh(["ranger"])
		var p: Dictionary=sim.state.players[1]; p.weapon=weapon; p.items.piercer=20
		var e: Dictionary=dummy(sim)
		sim._fire_weapon(p)
		var shot: Dictionary=sim.state.projectiles[0]
		check(shot.kind==weapon and shot.pierce==1 and shot.max_pierce==1,"%s is a real single-hit primary weapon even with piercer"%weapon)
		check(shot.guidance.target_id==e.id and shot.pos==Sim.WeaponPose.muzzle_position(p),"%s launches and locks at its actual muzzle"%weapon)
		fly(sim,1)
		check(e.hp<10000 and sim.state.projectiles.is_empty(),"%s resolves real direct damage and disappears"%weapon)
		sim.state.enemies.clear(); sim._fire_weapon(p)
		check(sim.state.projectiles.size()==1 and sim.state.projectiles[0].guidance.is_empty(),"%s fires straight with no target"%weapon)
	var sim=fresh(); var p: Dictionary=sim.state.players[1]; p.weapon="star_seeker"
	for i: int in range(5): sim._fire_weapon(p)
	check(sim.state.projectiles.size()==3 and p.attack_count==3,"Seeker cap suppresses fire without deleting any old projectile or adding an attack")
	check(sim.events.any(func(e: Dictionary)->bool:return e.type=="tracking" and e.kind=="limit"),"Seeker saturation provides visible and audible feedback")
	fly(sim,2.8)
	check(sim.state.projectiles.is_empty(),"Seeker absolute lifetime includes straight lead-in")
	sim._fire_weapon(p)
	check(sim.state.projectiles.size()==1,"Source quota becomes available after expiry")

func _beacon() -> void:
	var sim=fresh(); var p: Dictionary=sim.state.players[1]
	var e: Dictionary=dummy(sim)
	sim._use_skill(p)
	check(sim.state.deployables.size()==1 and p.skill_cd==12,"Beacon deploys on reachable support and spends one equipment cooldown")
	sim._use_skill(p)
	check(sim.state.deployables.size()==1,"Direct redeployment cannot bypass cooldown")
	var device: Dictionary=sim.state.deployables[0]
	for i: int in range(216): sim._step_deployables(1.0/60)
	check(sim.state.projectiles.size()==3 and int(device.next)==3,"Beacon performs exactly the three timed launch attempts")
	check(sim.state.deployables.is_empty(),"Beacon expires at 3.6s without extending to its last shot")
	check(sim.state.projectiles.all(func(s: Dictionary)->bool:return s.proc and s.proc_source=="beacon_dart" and s.source_id==device.id and s.pierce==1),"Beacon source IDs and nonrecursive single-hit classification serialize")
	fly(sim,1.25)
	check(is_equal_approx(10000-float(e.hp),54.0),"All three beacon hits share a total 54-damage budget")
	sim=fresh(); p=sim.state.players[1]; sim._use_skill(p)
	for i: int in range(40): sim._step_deployables(.05)
	dummy(sim)
	for i: int in range(32): sim._step_deployables(.05)
	check(sim.state.projectiles.size()==1,"Empty early nodes skip instead of accumulating shots")
	sim=fresh(); p=sim.state.players[1]; dummy(sim); sim._use_skill(p)
	sim._step_deployables(2.6)
	check(sim.state.projectiles.is_empty(),"A stalled beacon never catches up a burst of missed nodes")
	sim=fresh(); p=sim.state.players[1]; p.grounded=false; sim._use_skill(p)
	check(p.skill_cd==0 and sim.state.deployables.is_empty(),"Air placement fails without cooldown or orphan device")
	p.grounded=true; sim.state.solid_cover.append(Rect2(1008,720,35,80)); sim._use_skill(p)
	check(p.skill_cd==0 and sim.state.deployables.is_empty(),"Beacon cannot embed or deploy through solid cover")

func _weaver() -> void:
	var sim=fresh(["weaver","weaver"])
	var a: Dictionary=sim.state.players[1]; var b: Dictionary=sim.state.players[2]
	sim._step_player(a,{"dash":true,"aim":Vector2.RIGHT},1.0/60)
	check(a.dash_cd==0 and not a.has("trace_mark"),"Empty Engrave fails without consuming cooldown")
	var x: Dictionary=dummy(sim,Vector2(1220,770)); var y: Dictionary=dummy(sim,Vector2(1200,735))
	sim._engrave(a); b.aim=Vector2(y.pos)-(Vector2(b.pos)+Vector2(0,-14)); sim._engrave(b)
	check(a.trace_mark.target_id==x.id and b.trace_mark.target_id==y.id,"Two Weavers keep independent personal marks")
	a.aim=Vector2(200,20).normalized(); sim._fire_weapon(a)
	var first: Dictionary=sim.state.projectiles.back()
	check(first.guidance.target_id==x.id,"Follow the Trace prefers the owner's legal mark")
	a.trace_mark.target_id=y.id
	check(first.guidance.target_id==x.id,"Changing a mark cannot change a projectile already in flight")
	a.trace_mark.target_id=x.id; a.trace_mark.remaining=0.0
	check(T.owner_mark(a)==-1,"Expired marks are unavailable for launch-time priority")
	for i: int in range(22): sim._step_trace(a,1.0/60)
	var blades: Array=sim.state.projectiles.filter(func(s: Dictionary)->bool:return s.kind=="engraved_blade")
	check(blades.size()==3 and blades.all(func(s: Dictionary)->bool:return s.guidance.target_id==x.id and s.proc and s.damage==12),"Engrave emits three blades at the original selected target, each one third of the skill")
	check(not a.has("trace_burst") and a.dash_timer==0 and a.guard_timer==0,"Weaver has no hidden dash/guard and its queue completes")
	sim=fresh(); a=sim.state.players[1]; x=dummy(sim); sim._engrave(a)
	for i: int in range(8): sim._step_trace(a,1.0/60)
	x.hp=0; dummy(sim,Vector2(1300,770)); sim._step_trace(a,.05)
	check(sim.state.projectiles.size()==1 and not a.has("trace_burst") and a.dash_cd==8,"Target death cancels remaining blades without refund or retarget")
	sim=fresh(); a=sim.state.players[1]; x=dummy(sim); var snapshot: Dictionary=sim.get_snapshot()
	sim.predict_player(a,{"dash":true,"skill":true},.02)
	check(sim.state.projectiles.is_empty() and not a.has("trace_burst") and sim.state.deployables.is_empty(),"Client movement prediction cannot create marks, skill blades or equipment")
	sim.apply_snapshot(snapshot); a=sim.state.players[1]; a.items={"lens":100,"missile_pod":10,"arc":10,"toxin":10,"ember":10,"nova":10}; sim._engrave(a)
	for i: int in range(22): sim._step_trace(a,1.0/60)
	fly(sim,1.1)
	check(is_equal_approx(10000-float(sim.state.enemies[0].hp),36) and sim.state.projectiles.is_empty() and not sim.state.enemies[0].has("poison_timer"),"Skill damage cannot crit or recursively generate relic chains")

func _moth() -> void:
	var sim=fresh(["ranger","ranger"]); var p: Dictionary=sim.state.players[1]
	var moth: Dictionary=dummy(sim,Vector2(1240,660),"crystal_moth"); moth.attack_cd=0
	sim._begin_enemy_attack(moth,p)
	check(moth.telegraph>=.55 and moth.hunt_target_id==p.id and sim.state.projectiles.is_empty(),"Moth begins with a full harmless windup at its own locked player")
	var other: Dictionary=dummy(sim,Vector2(1200,650),"crystal_moth"); other.attack_cd=0
	sim._begin_enemy_attack(other,p)
	var third: Dictionary=dummy(sim,Vector2(1230,640),"crystal_moth"); third.attack_cd=0
	sim._begin_enemy_attack(third,p)
	check(third.telegraph==0 and sim._hunt_quota(1)==2,"Host reserves at most two windups/live crystals per target player")
	p.dead=true
	sim._step_enemies(.05)
	check(moth.telegraph==0 and other.telegraph==0 and sim.state.projectiles.is_empty(),"Target death cancels windup without switching to a teammate")
	sim=fresh(["ranger"]); p=sim.state.players[1]; moth=dummy(sim,Vector2(1220,670),"crystal_moth"); moth.attack_cd=0
	sim._begin_enemy_attack(moth,p); moth.telegraph=0; sim._release_enemy_attack(moth,p)
	check(sim.state.projectiles.size()==1 and sim.state.projectiles[0].ttl==3.0 and sim.state.projectiles[0].vel.length()==250 and sim.state.projectiles[0].damage==8,"Moth releases one slow persistent crystal with absolute TTL and modest damage")
	sim._release_enemy_attack(moth,p)
	check(sim.state.projectiles.size()==1,"Moth source quota forbids a second live projectile")
	var s: Dictionary=sim.state.projectiles[0]; var before: Vector2=s.vel
	sim._step_projectiles(.20)
	check(s.vel.is_equal_approx(before),"Hostile crystal retains its 0.22s straight dodge grace")
	s.pos=Vector2(2000,400); sim._step_projectiles(.05)
	check(sim.state.projectiles.is_empty() and sim.events.any(func(e: Dictionary)->bool:return e.type=="tracking" and e.kind=="disperse"),"Offscreen hostile tracking dissolves into harmless fragments")
	sim=fresh(); p=sim.state.players[1]; moth=dummy(sim,Vector2(1250,670),"crystal_moth")
	sim.state.solid_cover.append(Rect2(1100,620,35,180)); sim._begin_enemy_attack(moth,p)
	check(moth.telegraph==0,"Moth cannot lock through actual solid cover")
	sim.state.solid_cover.clear(); p.tracking_view=Rect2(650,400,500,400); sim._begin_enemy_attack(moth,p)
	check(moth.telegraph==0,"An enemy outside the intended player's local viewport cannot lock")
	p.erase("tracking_view"); moth.pos=Vector2(1500,670); sim._begin_enemy_attack(moth,p)
	check(moth.telegraph==0,"Offscreen acquisition remains blocked even without viewport metadata")

func _collision() -> void:
	check(T.cover_time(Vector2(0,50),Vector2(1000,50),[Rect2(100,0,1,100)],4)<.1,"Swept solid collision cannot tunnel through a one-pixel wall")
	for dt: float in [1.0/120,1.0/60,.05]:
		var sim=fresh(); var p: Dictionary=sim.state.players[1]; p.weapon="arc_needle"
		var blocker: Dictionary=dummy(sim,Vector2(1100,774)); var locked: Dictionary=dummy(sim,Vector2(1250,770))
		p.trace_mark={"target_id":locked.id,"remaining":4.0}; sim._fire_weapon(p); fly(sim,.3,dt)
		check(blocker.hp<10000 and locked.hp==10000,"%.4f step: intervening body blocks a shot aimed at another target"%dt)
		sim=fresh(); p=sim.state.players[1]; p.weapon="star_seeker"; var behind: Dictionary=dummy(sim,Vector2(1300,774))
		sim.state.solid_cover.append(Rect2(1100,650,1,150)); sim._fire_weapon(p); fly(sim,.5,dt)
		check(behind.hp==10000 and sim.state.projectiles.is_empty(),"%.4f step: cover kills the projectile before a body behind it"%dt)
		sim=fresh(); p=sim.state.players[1]; p.weapon="arc_needle"; var above: Dictionary=dummy(sim,Vector2(1250,774)); sim.state.platforms.append(Rect2(1100,730,100,28)); sim._fire_weapon(p); fly(sim,.4,dt)
		check(above.hp<10000,"%.4f step: a one-way platform underside is not an opaque wall"%dt)
	var positions: Array=[]
	for dt: float in [1.0/120,1.0/60,.05]:
		var sim=fresh(); var p: Dictionary=sim.state.players[1]; p.weapon="star_seeker"; dummy(sim,Vector2(1600,600)); sim._fire_weapon(p); fly(sim,.4,dt); positions.append(sim.state.projectiles[0].pos)
	check(Vector2(positions[0]).distance_to(positions[1])<.01 and Vector2(positions[0]).distance_to(positions[2])<.01,"Curved sweep substeps reproduce the same flight at 120, 60 and 20Hz")

func _lifecycle() -> void:
	for reason: String in ["death","disconnect","stage","restart"]:
		var sim=fresh(); var p: Dictionary=sim.state.players[1]; dummy(sim); sim._engrave(p); sim._use_skill(p); sim._fire_weapon(p)
		match reason:
			"death": p.dead=true; sim._step_player(p,{},.02); sim._step_projectiles(.02)
			"disconnect": sim.remove_player(1)
			"stage": sim._build_stage(2)
			"restart": sim.start_run([{ "id":1,"name":"Trace","character":"weaver"}],12); p=sim.state.players[1]
		check(sim.state.projectiles.is_empty() and sim.state.deployables.is_empty() and not p.has("trace_burst") and not p.has("trace_mark"),reason+" clears all new queues, marks, devices and owned projectiles")
	var sim=fresh(["weaver","weaver"]); dummy(sim); sim._engrave(sim.state.players[1]); sim._engrave(sim.state.players[2]); sim._fire_weapon(sim.state.players[1]); var snapshot: Dictionary=sim.get_snapshot()
	var replica=Sim.new(); replica.apply_snapshot(bytes_to_var(var_to_bytes(snapshot)))
	for i: int in range(18): sim._step_trace(sim.state.players[1],1.0/60); replica._step_trace(replica.state.players[1],1.0/60); sim._step_projectiles(1.0/60); replica._step_projectiles(1.0/60)
	check(sim.get_snapshot()==replica.get_snapshot(),"Serialized IDs, mark times, queues and curved projectile state resume deterministically")
	check(snapshot.players[1].trace_mark.remaining==4.0,"Prediction/replica cannot mutate retained authority snapshots")

func _integration() -> void:
	check(Sim.character_catalog().size()==3 and Sim.valid_character("weaver") and not Sim.valid_character("bad"),"Third class has its own stable roster and profile ID")
	var sim=fresh(); var p: Dictionary=sim.state.players[1]
	check(p.character=="weaver" and p.weapon=="arc_needle" and p.equipment=="hunting_beacon" and p.hp==100,"Weaver has its real independent initial loadout")
	for id: String in ["arc_needle","star_seeker","hunting_beacon"]:
		var d: Dictionary=Content.definition(id)
		check(not d.is_empty() and Locale.has_translation(d.name) and Locale.has_translation(d.description),id+" is catalogued with complete bilingual copy")
		var drop: Dictionary=sim._spawn_pickup(p.pos,"item",id,1); sim._take_loot(p,drop)
		check(str(p.weapon if d.category=="weapon" else p.equipment)==id,id+" can really be picked up and equipped")
	for id: String in ["engrave","follow_trace"]:
		var ability: Dictionary=Content.movement_ability("weaver") if id=="engrave" else Content.character_passive("weaver")
		check(Locale.has_translation(ability.name) and Locale.has_translation(ability.description),id+" has bilingual ability copy")
	check(Sound.event_sound({"type":"shoot","weapon":"arc_needle"})!=Sound.event_sound({"type":"shoot","weapon":"star_seeker"}),"New weapons have distinct sound voices")
	var texture: Texture2D=Art.weaver_frame(0).texture
	check(texture!=null and Art.weaver_frame(0).texture==texture and is_equal_approx(float(Art.weaver_frame(6).target.end.y),21.0),"New class art is bounded, cached and aligned to the old sole baseline")
	check(Catalog.definition("crystal_moth").windup>=.55 and Catalog.definition("crystal_moth").cooldown>=4,"New moth retains readable warning and recovery timing")
	var legacy_intervals: Array=[.19,.52,.60,1.05,.12,.65,.48,.85]
	var legacy_cooldowns: Array=[8,9,14,12,13,18,22,24]
	for i: int in range(8):
		check(is_equal_approx(float(Content.weapons()[i].fire_interval),float(legacy_intervals[i])) and float(Content.equipment()[i].cooldown)==float(legacy_cooldowns[i]),"Legacy weapon/equipment stats unchanged at slot %d"%i)
	var found: Dictionary={}
	sim.state.chests.clear(); sim.state.pickups.clear(); p.weapon="pulse_rifle"; p.equipment="grenade"
	for i: int in range(600):
		for category: String in ["weapon","equipment"]:
			var pool: Array=sim._gear_candidates(category,false)
			found[sim._weighted_loot(pool,"boss")]=true
	check(found.has("arc_needle") and found.has("star_seeker") and found.has("hunting_beacon"),"All three new gear IDs are selected by real weighted reward rolls")
	check("crystal_moth" in Catalog.pool("canyon") and Catalog.pool("rainforest")==["crawler","spitter","spore_moth"] and Catalog.pool("ruins")==["sentinel","skirmisher","conductor"],"Only the tested canyon encounter pool admits the new moth")

func _stress_and_marks() -> void:
	var sim=fresh(["weaver","weaver","ranger","vanguard"])
	for i: int in range(44): dummy(sim,Vector2(1200+(i%8)*40,650+(i/8)*18))
	var p: Dictionary=sim.state.players[1]
	p.trace_mark={"target_id":int(sim.state.enemies[0].id),"remaining":4.0}
	var original: int=int(p.trace_mark.target_id)
	var enemy: Dictionary=sim.state.enemies[0]
	enemy.pos=Vector2(1250,650)
	sim._fire_weapon(p)
	check(int(sim.state.projectiles[0].guidance.get("target_id",-1))!=original,"A personal mark outside the weapon's cone falls back to legal ordinary acquisition")
	p.weapon="pulse_rifle"; sim._fire_weapon(p)
	check(not sim.state.projectiles.back().has("guidance"),"Weaver passive never attaches to old guns")
	sim.state.projectiles.clear(); p.weapon="arc_needle"
	for i: int in range(Sim.MAX_PROJECTILES+20): sim._fire_weapon(p)
	check(sim.state.projectiles.size()==Sim.MAX_PROJECTILES,"New weapons respect the global 280-projectile budget")
	for i: int in range(5): sim._step_projectiles(.05)
	check(sim.state.projectiles.all(func(s: Dictionary)->bool:return Vector2(s.pos).is_finite() and Array(s.get("trail",[])).size()<=10),"Maximum projectile population has finite trajectories and bounded reusable trail history")

func _mixed_devices_and_authority() -> void:
	var sim=fresh(["weaver","ranger"])
	var a: Dictionary=sim.state.players[1]; var b: Dictionary=sim.state.players[2]
	sim._deploy_beacon(a); var beacon_id: int=int(sim.state.deployables.front().id)
	b.equipment="turret"
	for i: int in range(7): sim._use_skill(b)
	check(sim.state.deployables.size()==5 and sim.state.deployables.any(func(d: Dictionary)->bool:return d.id==beacon_id),"Four old turrets coexist with a beacon and turret replacement cannot evict it")
	var enemy: Dictionary=dummy(sim,Vector2(1230,770))
	a.trace_mark={"target_id":int(enemy.id),"remaining":4.0}
	var near: Dictionary=dummy(sim,Vector2(1120,770))
	b.equipment="hunting_beacon"; b.skill_cd=0; sim._deploy_beacon(b)
	var device: Dictionary=sim.state.deployables.back()
	sim._step_beacon(device,.4)
	check(sim.state.projectiles.back().guidance.target_id==near.id,"A teammate's beacon does not use another Weaver's personal mark")
	sim=fresh(["ranger"]); a=sim.state.players[1]
	var moth: Dictionary=dummy(sim,Vector2(1220,670),"crystal_moth")
	sim._begin_enemy_attack(moth,a); sim._release_enemy_attack(moth,a)
	var hp: float=float(a.hp)
	sim.state.solid_cover.append(Rect2(1090,600,2,190))
	fly(sim,1.0)
	check(a.hp==hp and sim.state.projectiles.is_empty(),"Actual hostile crystal is stopped by solid cover before hurting its locked player")
	sim=fresh(); a=sim.state.players[1]; a.weapon="star_seeker"; enemy=dummy(sim)
	sim._fire_weapon(a); sim._step_projectiles(.05); var shot: Dictionary=sim.state.projectiles[0]
	var deadline: float=float(shot.ttl)
	enemy.hp=0; sim._step_projectiles(.05); dummy(sim,Vector2(1250,760))
	check(not bool(shot.guidance.active) and shot.ttl<deadline,"Target loss cannot refresh lifetime or retarget an existing seeker")
	sim=fresh(); a=sim.state.players[1]; dummy(sim)
	a.items={"phoenix":1}; sim._engrave(a); sim._deploy_beacon(a); sim._fire_weapon(a)
	sim._damage_player(a,1000,Vector2(950,779))
	check(not a.dead and a.hp==35 and not a.has("trace_mark") and not a.has("trace_burst") and sim.state.projectiles.is_empty() and sim.state.deployables.is_empty(),"Phoenix recovery clears old marks, queues, beacon and tracking output before restoring life")
	sim=fresh(); a=sim.state.players[1]; dummy(sim); a.items={"thruster":3,"coolant":2}
	sim._engrave(a); sim._deploy_beacon(a)
	check(is_equal_approx(float(a.dash_cd),8.0/1.3) and is_equal_approx(float(a.skill_cd),12.0/1.32),"New skill and equipment independently respect existing cooldown relics")
	var legacy=fresh(["ranger"]); var old_snapshot: Dictionary=legacy.get_snapshot()
	old_snapshot.erase("spawn_cursor"); old_snapshot.erase("solid_cover")
	var restored=Sim.new(); restored.apply_snapshot(old_snapshot); restored.step(1.0/60,{1:{"fire":true,"aim":Vector2.RIGHT}})
	check(restored.state.players[1].character=="ranger" and restored.state.projectiles.size()==1 and not restored.state.projectiles[0].has("guidance"),"Old value snapshots without new optional fields still run the original straight rifle")
