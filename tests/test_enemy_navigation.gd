extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const DT: float=1.0/60.0
var passed: int=0
var failed: int=0

func _initialize() -> void:
	_short_hops()
	_high_platform()
	_stairs_and_gap()
	_guards_and_determinism()
	print("ENEMY_NAVIGATION_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error("FAIL: "+label)

func _fresh(seed_value: int=1707):
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Navigation","character":"ranger"}],seed_value)
	sim.state.world_size=Vector2(2400,1100)
	sim.state.floor_y=1000.0
	sim.state.platforms=[Rect2(0,1000,2400,100)]
	sim.state.enemies=[]
	sim.state.chests=[]
	sim._spawn_clock=9999.0
	var p: Dictionary=sim.state.players[1]
	p.pos=Vector2(1000,979)
	p.vel=Vector2.ZERO
	p.grounded=true
	p.invuln=9999.0
	sim.events.clear()
	return sim

func _enemy(sim, position: Vector2, kind: String="crawler") -> Dictionary:
	var e: Dictionary=sim._spawn_enemy(kind,position)
	e.grounded=true
	e.attack_cd=9999.0
	e.jump_cd=0.0
	return e

func _tick_enemies(sim) -> void:
	sim.state.time+=DT
	sim._step_enemies(DT)

func _short_hops() -> void:
	var sim=_fresh()
	for index: int in range(12): _enemy(sim,Vector2(760+index*20,983))
	for tick: int in range(240):
		var command: Dictionary={"jump":tick in [30,120],"jump_held":tick%90<35}
		sim.step(DT,{1:command})
	_check(sim.state.enemies.all(func(e:Dictionary):return int(e.nav_jumps)==0),"A crowd does not echo two real player jumps from the same floor")
	_check(sim.state.enemies.all(func(e:Dictionary):return is_equal_approx(e.pos.y,983.0)),"Player airborne height never becomes the crowd's next landing platform")
	var initial_air=_fresh()
	var p: Dictionary=initial_air.state.players[1]
	p.pos.y=750
	p.grounded=false
	var enemy: Dictionary=_enemy(initial_air,Vector2(800,983))
	for tick: int in range(45): _tick_enemies(initial_air)
	_check(enemy.nav_jumps==0 and Rect2(enemy.nav_support).size==Vector2.ZERO,"A newly observed airborne player supplies no invented upper floor")

func _high_platform() -> void:
	var sim=_fresh()
	sim.state.platforms.append(Rect2(700,910,650,28))
	sim.state.players[1].pos=Vector2(1050,889)
	var starts: Dictionary={}
	var heights: Dictionary={}
	for index: int in range(12): _enemy(sim,Vector2(790+index*9,983))
	var rng_before: int=sim._rng.state
	for tick: int in range(240):
		_tick_enemies(sim)
		for e: Dictionary in sim.state.enemies:
			if e.nav_jumps>0 and not starts.has(e.id):
				starts[e.id]=tick
				heights[snappedf(-float(e.vel.y),.01)]=true
	_check(starts.size()==12,"Every grounded pursuer can recognize and reach a stable 90 px upper platform")
	var times: Array=starts.values()
	times.sort()
	_check(times.size()==12 and int(times.back())-int(times.front())>=10,"Even an already-ready crowd spreads decisions over at least ten physics ticks")
	_check(heights.size()>=6,"Same-kind pursuers retain individual jump-height variations")
	_check(sim.state.enemies.all(func(e:Dictionary):return is_equal_approx(e.pos.y,893.0) and e.grounded),"All twelve land on the real platform rather than merely jumping toward the player's centre")
	_check(sim._rng.state==rng_before,"Navigation never consumes shared combat or drop random numbers each tick")
	var landed_jumps: Array=sim.state.enemies.map(func(e:Dictionary):return e.nav_jumps)
	for tick: int in range(240): _tick_enemies(sim)
	_check(landed_jumps==sim.state.enemies.map(func(e:Dictionary):return e.nav_jumps),"Enemies stop navigation jumping once they share the target's floor")

func _stairs_and_gap() -> void:
	var sim=_fresh()
	sim.state.platforms.append_array([Rect2(700,910,320,28),Rect2(920,820,340,28),Rect2(1140,730,420,28)])
	sim.state.players[1].pos=Vector2(1350,709)
	var e: Dictionary=_enemy(sim,Vector2(750,983))
	for tick: int in range(1200): _tick_enemies(sim)
	_check(e.pos.y<=713.1 and e.grounded and e.nav_jumps>=3,"A melee enemy follows intermediate overlapping steps to a target three floors above")
	for kind: String in ["crawler","charger"]:
		var fighting=_fresh()
		fighting.state.platforms.append_array([Rect2(700,910,320,28),Rect2(920,820,340,28),Rect2(1140,730,420,28)])
		fighting.state.players[1].pos=Vector2(1350,709)
		var pursuer: Dictionary=_enemy(fighting,Vector2(750,983),kind)
		pursuer.attack_cd=0.8
		var reached: bool=false
		for tick: int in range(1800):
			_tick_enemies(fighting)
			if pursuer.pos.y<=713.1 and pursuer.grounded: reached=true; break
		_check(reached,kind+" still reaches the upper floor with its real attack AI enabled")
	for stage: int in [1,2,3]:
		var authored=_fresh()
		authored._build_stage(stage)
		var upper: Rect2=authored.state.platforms[3]
		var first: Rect2=authored.state.platforms[1]
		authored.state.players[1].pos=Vector2(upper.get_center().x,upper.position.y-21)
		authored.state.players[1].grounded=true
		var pursuer: Dictionary=_enemy(authored,Vector2(first.get_center().x,float(authored.state.floor_y)-17))
		var reached: bool=false
		for tick: int in range(1800):
			_tick_enemies(authored)
			if pursuer.pos.y<=upper.position.y-16.9 and pursuer.grounded: reached=true; break
		_check(reached,"The real stage %d opening platforms remain navigable by a melee pursuer"%stage)
	var gap=_fresh()
	gap.state.platforms.append_array([Rect2(500,820,200,28),Rect2(725,820,260,28)])
	gap.state.players[1].pos=Vector2(920,799)
	e=_enemy(gap,Vector2(640,803))
	for tick: int in range(300): _tick_enemies(gap)
	_check(e.pos.x>740 and is_equal_approx(e.pos.y,803.0) and e.nav_jumps>=1,"A nearby real platform gap triggers a useful crossing rather than a fall")
	var bridge=_fresh()
	bridge.state.platforms.append_array([Rect2(500,820,240,28),Rect2(725,820,300,28)])
	bridge.state.players[1].pos=Vector2(950,799)
	e=_enemy(bridge,Vector2(600,803))
	for tick: int in range(300): _tick_enemies(bridge)
	_check(e.pos.x>850 and e.nav_jumps==0,"Overlapping platform rectangles form a walkable bridge without unnecessary seam jumps")
	var unreachable=_fresh()
	unreachable.state.platforms.append(Rect2(700,650,600,28))
	unreachable.state.players[1].pos=Vector2(1000,629)
	e=_enemy(unreachable,Vector2(850,983))
	for tick: int in range(240): _tick_enemies(unreachable)
	_check(e.nav_jumps==0,"A balcony with no reachable intermediate surface does not cause endless futile hopping")

func _guards_and_determinism() -> void:
	for guard: String in ["airborne","windup","charge","stun"]:
		var sim=_fresh()
		sim.state.platforms.append(Rect2(700,910,600,28))
		sim.state.players[1].pos=Vector2(1000,889)
		var e: Dictionary=_enemy(sim,Vector2(850,983))
		for tick: int in range(30):
			match guard:
				"airborne": e.grounded=false; e.pos.y=850.0; e.vel.y=-50.0
				"windup": e.telegraph=1.0
				"charge": e.charge_timer=1.0; e.charge_speed=100.0
				"stun": e.stun_timer=1.0
			_tick_enemies(sim)
		_check(e.nav_jumps==0,guard+" cannot repeatedly trigger a navigation jump")
	var a=_fresh()
	var b=_fresh()
	for sim in [a,b]:
		sim.state.platforms.append(Rect2(700,910,650,28))
		sim.state.players[1].pos=Vector2(1100,889)
		for index: int in range(10): _enemy(sim,Vector2(800+index*8,983))
	for tick: int in range(360):
		_tick_enemies(a)
		_tick_enemies(b)
	_check(a.get_snapshot()==b.get_snapshot(),"Identical seeds and inputs reproduce all decisions, cooldowns and movement exactly")
	var clone=Simulation.new()
	clone.apply_snapshot(a.get_snapshot())
	for tick: int in range(120):
		_tick_enemies(a)
		_tick_enemies(clone)
	_check(a.state.enemies==clone.state.enemies,"Serialized navigation memory continues consistently after a cooperative snapshot")
	clone.state.enemies[0].nav_support=Rect2()
	_check(clone.state.enemies[0].nav_support!=a.state.enemies[0].nav_support,"Snapshot navigation memory cannot mutate its source")
	var attack=_fresh()
	var crawler: Dictionary=_enemy(attack,Vector2(900,983))
	attack._begin_enemy_attack(crawler,attack.state.players[1])
	for tick: int in range(42): _tick_enemies(attack)
	_check(crawler.charge_timer>0.0 and crawler.nav_jumps==0,"The crawler's authored windup and offensive pounce remain active and independent")
