extends SceneTree

const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, title: String) -> void:
	if ok:
		passed+=1
		print("PASS: ",title)
	else:
		failed+=1
		push_error("FAIL: "+title)

func _run() -> void:
	var sim: Variant=Simulation.new()
	sim.start_run([{"id":1,"name":"FX","character":"ranger"}],2610)
	var world: Node2D=World.new()
	root.add_child(world)
	world.set_process(false)
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(640,650)
	player.aim=Vector2.RIGHT
	var styles: Dictionary={}
	for weapon: Dictionary in Content.weapons():
		player.weapon=weapon.id
		player.fire_cd=0.0
		sim.events.clear()
		sim._fire_weapon(player)
		world.set_frame(sim.get_snapshot(),1,0.0)
		world._effects.clear()
		var before: PackedByteArray=var_to_bytes(sim.events)
		world.push_events(sim.events)
		var primary: Dictionary={}
		for effect: Dictionary in world._effects:
			if effect.kind in ["muzzle","slash","flame"]: primary=effect
		_check(not primary.is_empty() and primary.get("weapon","")==weapon.id and before==var_to_bytes(sim.events),"Real "+str(weapon.id)+" feedback keeps the weapon identity, muzzle and immutable authority event")
		styles[primary.get("style",primary.get("kind",""))]=true
	_check(styles.size()==8,"All eight real weapon attacks have distinct feedback styles")
	world._effects.clear()
	world.push_events([{"type":"hit","pos":player.pos+Vector2(80,0),"owner":1,"amount":8}])
	var forward: int=0
	var sparks: int=0
	var fragments: int=0
	for effect: Dictionary in world._effects:
		if effect.kind=="spark":
			sparks+=1
			if Vector2(effect.vel).x>0: forward+=1
		if effect.kind=="fragment": fragments+=1
	_check(sparks>=4 and forward==sparks and fragments>0,"A real-owner hit ejects bright motes along the incoming shot with separate solid fragments")
	var materials: Dictionary={}
	for kind: String in ["crawler","charger","sentinel"]:
		sim.events.clear()
		var enemy: Dictionary=sim._spawn_enemy(kind,player.pos+Vector2(120,0))
		sim._damage_enemy(enemy,99999.0,1,false,0)
		world._effects.clear()
		world.push_events(sim.events)
		var shatter: Dictionary={}
		for effect: Dictionary in world._effects:
			if effect.kind=="shatter": shatter=effect
		_check(not shatter.is_empty(),"Actual "+kind+" death produces a short material breakup")
		if not shatter.is_empty(): materials[str(shatter.color)]=true
	_check(materials.size()==3,"Organic, stone and mechanical deaths have distinct material palettes")
	world._effects.clear()
	world.push_events([{"type":"pickup","kind":"coin","automatic":true,"amount":4,"pos":player.pos}])
	_check(world._effects.size()<=12 and world._effects.all(func(effect: Dictionary) -> bool: return effect.color==World.GOLD) and world._effects.any(func(effect: Dictionary) -> bool: return effect.kind=="coin_collect") and world._effects.any(func(effect: Dictionary) -> bool: return effect.kind=="ring" and float(effect.radius)<=28.0),"Gold arrival has a distinct flash and compact gold ring within its local effect budget")
	world._effects.clear()
	world.push_events([{"type":"pickup","kind":"item","pos":player.pos}])
	_check(world._effects.size()==12 and world._effects.all(func(effect: Dictionary) -> bool: return effect.color==World.TEAL) and world._effects.back().radius==32.0,"Relic pickup retains its larger teal feedback")
	var state_bytes: PackedByteArray=var_to_bytes(sim.state)
	world.set_frame(sim.get_snapshot(),1,0.0)
	world.fx_scale=1.5
	for index: int in range(500):
		world.push_events([
			{"type":"hit","pos":player.pos+Vector2(index%20,0),"owner":1,"amount":8,"crit":true,"visual_stacks":9999},
			{"type":"explosion","pos":player.pos,"radius":10000.0,"visual_stacks":9999},
			{"type":"death","pos":player.pos,"kind":"charger","elite":true}])
	var stats: Dictionary=world.visual_budget_stats()
	_check(stats.effects<=384 and stats.damage_numbers<=32 and stats.shake<=5.0,"Sustained four-player-scale proc bursts retain the 384/32/five-pixel budgets")
	world._effects.clear()
	world.push_events([{"type":"explosion","pos":player.pos,"radius":100.0},{"type":"death","pos":player.pos,"kind":"charger"}])
	world._process(0.08)
	world._build_particle_batches()
	stats=world.visual_budget_stats()
	var valid: bool=true
	for bucket: int in range(4):
		valid=valid and world._particle_points[bucket].size()==world._particle_colors[bucket].size()*2
	_check(stats.particle_batches>0 and stats.particle_batches<=4 and stats.particle_segments<=768 and valid,"Every debris, spark, ember and smoke segment shares at most four valid native draw batches")
	world.camera_position+=Vector2(10000,10000)
	world._build_particle_batches()
	_check(world.visual_budget_stats().particle_segments==0,"Fully off-screen cosmetic particles generate no draw segments")
	_check(var_to_bytes(sim.state)==state_bytes,"Event enrichment and particle batching never modify gameplay state")
	world._process(2.0)
	world._build_particle_batches()
	_check(world._effects.is_empty() and world._numbers.is_empty() and world.visual_budget_stats().particle_batches==0,"All enhanced effects expire and release their draw batches")
	world.queue_free()
	await process_frame
	print("COMBAT_FX_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
