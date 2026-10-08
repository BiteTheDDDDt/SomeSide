extends SceneTree
const Body=preload("res://scripts/player_body_motion.gd")
const Players=preload("res://scripts/illustrated_player_renderer.gd")
const Keys=preload("res://scripts/actor_key_poses.gd")
const Enemy=preload("res://scripts/enemy_body_motion.gd")
const Render=preload("res://scripts/illustrated_enemy_renderer.gd")
const FX=preload("res://scripts/selected_enemy_fx.gd")
const Ranged=preload("res://scripts/weapon_action_motion.gd")
const Melee=preload("res://scripts/melee_motion.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func state() -> Dictionary:
	return {"id":1,"character":"ranger","pos":Vector2(400,200),"vel":Vector2.ZERO,"aim":Vector2.RIGHT,"grounded":true,"dash_timer":0.0}
func landing(speed: float, interrupt: String="") -> Dictionary:
	var canvas:=Node2D.new(); root.add_child(canvas)
	var p: Dictionary=state(); p.grounded=false; p.vel.y=speed
	Body.sample(canvas,p,0.0,{}, {})
	p.grounded=true; p.vel.y=0
	Body.sample(canvas,p,.02,{}, {})
	var action: Dictionary={}
	match interrupt:
		"move": p.vel.x=100
		"jump": p.grounded=false; p.vel.y=-400
		"dash": p.dash_timer=.1
		"fire": action={"active":true}
	var result: Dictionary=Body.sample(canvas,p,.06,{},action)
	canvas.free()
	return result
func run() -> void:
	var soft: Dictionary=landing(260)
	var hard: Dictionary=landing(900)
	check(hard.landing>soft.landing and hard.landing<=1,"High falls compress more, with a bounded impact")
	for action: String in ["move","jump","dash","fire"]:
		check(float(landing(900,action).landing)==0,"Landing immediately yields to "+action)
	var canvas:=Node2D.new(); root.add_child(canvas)
	var p: Dictionary=state()
	Body.sample(canvas,p,0,{}, {})
	p.grounded=false; p.vel.y=-420
	var launch: Dictionary=Body.sample(canvas,p,.01,{}, {})
	check(launch.phase=="takeoff" and launch.weights.get(4,0)>0,"Immediate physics jump selects a genuine extension pose")
	p.vel.y=0
	var apex: Dictionary=Body.sample(canvas,p,.21,{}, {})
	check(apex.phase=="apex" and apex.weights.get(5,0)>.99,"Apex uses a new gathered pose instead of rise/fall snapping")
	check(Body.sample(canvas,p,.21,{}, {})==apex,"Multiple muzzle/body samples in one clock are idempotent")
	var before: PackedByteArray=var_to_bytes(p)
	for i: int in range(40): Players.sample_pose(canvas,p,.22+i/144.0,Ranged.sample("railgun",.01,.6))
	check(before==var_to_bytes(p),"Pose sampling never writes player snapshots")
	Body.reset(canvas)
	check(not canvas.has_meta(Body.META),"Scene reset clears visual landing history")
	canvas.free()
	var clocks: Array=[]
	for hz: int in [30,60,144]:
		var c:=Node2D.new(); root.add_child(c)
		var player: Dictionary=state(); player.grounded=false; player.vel.y=550
		for i: int in range(hz/2+1): Body.sample(c,player,float(i)/hz,{}, {})
		player.grounded=true; player.vel.y=0
		Body.sample(c,player,.51,{}, {})
		clocks.append(Body.sample(c,player,.60,{}, {}).landing)
		c.free()
	check(is_equal_approx(clocks[0],clocks[1]) and is_equal_approx(clocks[1],clocks[2]),"30/60/144 render sampling retains the same time-based landing envelope")
	var budget: Dictionary=Keys.stats()
	check(budget.textures==2 and budget.bytes<=budget.max_bytes,"New actor poses reuse two bounded imported atlases")
	for actor: String in ["ranger","vanguard","crawler","spitter","boss_stone"]:
		for index: int in range(3 if actor in ["ranger","vanguard"] else 4):
			var f: Dictionary=Keys.frame(actor,index)
			check(f.target.has_area() and is_equal_approx(Vector2(f.sole).y,21 if actor in ["ranger","vanguard"] else (44 if actor=="boss_stone" else 17)),actor+" keeps authored sole baseline")
			check(Keys.frame(actor,index).texture==f.texture,actor+" reuses pose views")
	for id: String in Enemy.PROFILES:
		var e: Dictionary={"kind":"boss" if id=="boss_stone" else id,"boss_style":"stone","attack_kind":"stone_spikes" if id=="boss_stone" else ("pounce" if id=="crawler" else "spit"),"telegraph":.2,"telegraph_max":1.0,"attack_cd":2.0,"attack_cooldown":2.0,"radius":19}
		check(Enemy.sample(e,id).phase=="coil","Distinct anticipation selected for "+id)
		e.telegraph=0
		if id=="crawler": e["charge_timer"]=.35
		check(Enemy.sample(e,id).phase=="release","Authority release selects striking pose for "+id)
		e.attack_cd=1.0; e["charge_timer"]=0.0
		check(Enemy.sample(e,id).weights.is_empty(),"Recovery fully resolves without cumulative deformation for "+id)
	for aim: Vector2 in [Vector2.RIGHT,Vector2(.6,-.8),Vector2(.6,.8)]:
		for index: int in range(4):
			var e: Dictionary={"id":"spitter","aim":aim,"organ":aim*22}
			var vertices: Dictionary=Render.key_vertices(e,index)
			var f: Dictionary=Keys.frame("spitter",index)
			var wanted: Vector2=(Rect2(f.region).position+Vector2(f.socket))/Vector2(1448,1086)
			var nearest: float=10000
			for n: int in range(vertices.uv.size()):
				if Vector2(vertices.uv[n]).distance_to(wanted)<.00001: nearest=Vector2(vertices.positions[n]).distance_to(e.organ)
			check(nearest<.001,"Every articulated spit mouth follows the real launch socket at steep aim")
	for i: int in range(101):
		var progress: float=i/100.0
		var ready: Dictionary=FX.timeline(false,progress)
		var active: Dictionary=FX.timeline(true,progress)
		var ending: Dictionary=FX.timeline(false,progress,true)
		check(int(ready.index) in [0,1,2,3] and int(ready.next) in [0,1,2,3] and int(active.index) in [8,4,5,6] and int(ending.index) in [9,7],"Nonuniform FX sampling never blends across damage stages")
	check(FX.timeline(true,.04).index==8 and FX.timeline(true,.4).index==5,"Rupture is brief; full burst receives a longer readable hold")
	check(FX.blink_timeline(.55,true,true).alpha<FX.blink_timeline(.55,true,false).alpha,"Departure collapses before arrival settles")
	for weapon: String in Ranged.WEAPONS:
		var pose: Dictionary=Ranged.sample(weapon,.02,.2)
		check(Vector2(pose.body_shift).length()<3 and absf(float(pose.elbow_follow))<2,"Weapon reaction remains bounded for "+weapon)
	check(Ranged.sample("railgun",.02,.2).body_shift.length()>Ranged.sample("pulse_rifle",.02,.2).body_shift.length(),"Heavy gun transfers more motion into the torso")
	check(Melee.sample(.15,.36,Vector2.RIGHT).has("body_shift"),"Melee retains its curve while driving torso and elbow")
	print("MOTION_WEIGHT_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
