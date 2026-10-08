extends SceneTree
const Clips=preload("res://scripts/motion_clips_24.gd")
const Rig=preload("res://scripts/enemy_rig_24.gd")
const Render=preload("res://scripts/illustrated_enemy_renderer.gd")
const EnemyMotion=preload("res://scripts/enemy_body_motion.gd")
const Catalog=preload("res://scripts/enemy_catalog.gd")
const Ranged=preload("res://scripts/weapon_action_motion.gd")
const Melee=preload("res://scripts/melee_motion.gd")
const Projectiles=preload("res://scripts/projectile_renderer.gd")
const FX=preload("res://scripts/illustrated_fx.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for action: String in ["idle","run","backpedal","stop","takeoff","rise","apex","fall","land","dash","death"]:
		for i: int in range(24):
			var frame: Dictionary=Clips.player(action,i/23.0)
			check(frame.frame_count==24 and Vector2(frame.shift).is_finite(),"Player "+action+" has finite 24-pose playback")
	for weapon: String in Ranged.WEAPONS:
		Ranged.sample(weapon,.02,.4)
		check(Clips._clips["weapon/"+weapon].frames.size()==24,"Complete ranged action contains 24 poses: "+weapon)
	Melee.sample(.1,.36,Vector2.RIGHT)
	var blade: Dictionary=Clips._clips["weapon/melee"]
	check(blade.frames.size()==24 and blade.times.has(Melee.WINDUP_END) and blade.times.has(Melee.IMPACT) and blade.times.has(Melee.SWING_END),"24 melee poses retain windup extremum, exact damage direction and recovery extremum")
	for id: String in Rig.PROFILES:
		var definition: Dictionary=Catalog.definition(id)
		var attacks: Array=[str(definition.get("attack_kind",""))]
		if id=="boss_stone": attacks=["stone_charge","stone_spikes"]
		elif id=="boss_spore": attacks=["spore_volley","spore_bloom"]
		elif id=="boss_prism": attacks=["prism_beam","prism_cross","salvo"]
		for action: String in attacks:
			for stage: String in ["coil","release","recover","move","idle"]:
				var shapes: Dictionary={}
				for i: int in range(24):
					var pose: Dictionary=Rig.sample(id,action,stage,i/23.0)
					var shape: Dictionary=Render.vertices({"id":id,"phase":0.0,"moving":0.0,"amount":0.0,"charged":false,"aim":Vector2.RIGHT,"organ":Vector2.ZERO,"rig":pose})
					shapes[var_to_bytes(shape.positions).hex_encode()]=true
					var finite: bool=true
					for point: Vector2 in shape.positions: finite=finite and point.is_finite()
					check(finite and pose.frame_count==24,id+" "+action+" "+stage+" frame "+str(i)+" is finite")
				check(shapes.size()>=18,id+" "+stage+" changes actual mesh joints, not only a frame counter")
			check(Clips._clips["enemy/"+id+"/"+action].frames.size()==24,id+" "+action+" has 24 poses across the COMPLETE attack, not 24 per stage")
		# Organs stay on the authoritative socket in every rig phase/aim.
		if not Render.DEFINITIONS[id].has("organ"): continue
		for aim: Vector2 in [Vector2.RIGHT,Vector2(.6,.8),Vector2(.6,-.8)]:
			for i: int in range(24):
				var target: Vector2=Vector2(19,-7)
				var shape: Dictionary=Render.vertices({"id":id,"phase":0.0,"moving":0.0,"amount":0.0,"charged":false,"aim":aim,"organ":target,"rig":Rig.sample(id,attacks[0],"coil",i/23.0)})
				var def: Dictionary=Render.DEFINITIONS[id]
				var uv: Vector2=(Rect2(def.region).position+Vector2(def.organ)*Rect2(def.region).size)/Vector2(1448,1086)
				var nearest: float=10000
				for n: int in range(shape.uv.size()):
					if Vector2(shape.uv[n]).distance_to(uv)<.00001: nearest=Vector2(shape.positions[n]).distance_to(target)
				check(nearest<.001,id+" rig keeps its real organ pinned")
	var claw_pinned: bool=true
	for i: int in range(24):
		var e: Dictionary={"kind":"crawler","attack_kind":"pounce","attack_cooldown":2.8,"attack_cd":2.8,"charge_timer":.35*(1-i/24.0),"attack_dir":Vector2.RIGHT,"radius":19}
		var data: Dictionary=Render.sample(e,0.0)
		var actual:=Vector2.ZERO
		for key: int in data.rhythm.weights:
			var shape: Dictionary=Render.key_vertices(data,key)
			var f: Dictionary=Render.Keys.frame("crawler",key)
			var pixel: Array=Render.Keys._data.actors.crawler.frames[key].claw
			var uv: Vector2=(Rect2(f.region).position+Vector2(pixel[0],pixel[1]))/Vector2(1448,1086)
			for n: int in range(shape.uv.size()):
				if Vector2(shape.uv[n]).distance_to(uv)<.00001: actual+=Vector2(shape.positions[n])*float(data.rhythm.weights[key]); break
		claw_pinned=claw_pinned and actual.distance_to(EnemyMotion.claw_origin(e))<.001
	check(claw_pinned,"Every pounce pose emits its claw effect at the actual articulated claw vertex")
	for family: String in ["spore","stone"]:
		for stage: String in ["ready","active","ending"]:
			Clips.fx(family,stage,.5)
			var frames: Array=Clips._clips["fx/"+family].frames
			var offset: int={"ready":0,"active":8,"ending":16}[stage]
			var geometry: Dictionary={}
			for frame: Dictionary in frames.slice(offset,offset+8): geometry[str([frame.scale_y,frame.spread,frame.bend])]=true
			check(frames.size()==24 and geometry.size()>=6,family+" "+stage+" owns its section of the complete 24-pose effect")
			var isolated: bool=true
			for i: int in range(101):
				var frame: Dictionary=Clips.fx(family,stage,i/100.0)
				isolated=isolated and int(frame.frame)>=offset and int(frame.frame)<=offset+7
			check(isolated,family+" "+stage+" never samples another damage stage")
	for stage: String in ["ready","depart","arrive"]: Clips.fx("blink",stage,.5)
	for kind: String in ["bullet","pellet","rail","lance","storm","boomerang","grenade","spit","crystal","energy","boss_spore_orb"]:
		check(Projectiles.flight_pose(kind,.3).frame_count==24,"24-pose flight cycle: "+kind)
	check(absf(angle_difference(float(Projectiles.flight_pose("boomerang",.9999).spin),float(Projectiles.flight_pose("boomerang",.0001).spin)))<.01,"Looping projectile rotation crosses the 24th pose without spinning backward")
	check(Clips._clips["player/jump"].frames.size()==24,"Takeoff, rise, apex and fall share one complete 24-pose jump")
	for kind: String in ["muzzle","impact","blast","guard_release","flame","gravity","meteor","shatter","dash","rush","rush_hit","heal","arc","ring","slash","mending","ground_charge","laser_source","lunge/pounce","lunge/charge","lunge/stone_charge","proc/missile","proc/wave","proc/aura","proc/charge"]:
		check(FX.motion(kind,.3).frame_count==24,"24-pose effect: "+kind)
	var muzzle_valid: bool=true
	for strength: float in [.5,1.0,3.3]:
		for i: int in range(101):
			var p: float=i/100.0
			var length: float=(13+strength*6)*(1-.55*p)*float(FX.motion("muzzle/pulse_rifle",p).push)
			var points:=PackedVector2Array()
			for point: Vector2 in FX.muzzle_shape(length): points.append(Vector2(1000,500)+point.rotated(.78))
			muzzle_valid=muzzle_valid and not Geometry2D.triangulate_polygon(points).is_empty()
	check(muzzle_valid,"Weak and strong muzzle flashes remain simple polygons through every contraction pose")
	var identity: Dictionary=Clips._clips["weapon/melee"]
	for i: int in range(1000): Melee.sample(.1,.36,Vector2.RIGHT)
	check(is_same(identity,Clips._clips["weapon/melee"]),"Playback reuses pose data instead of allocating new texture frames")
	var needle: Callable=func(t: float): return {"value":sin(t*PI)}
	var clip: Dictionary=Clips.bake("test/timing",needle)
	check(Clips.play(clip,.35)==Clips.play(clip,21.0/60.0) and Clips.play(clip,.35)==Clips.play(clip,50.4/144.0),"24 authored poses interpolate to the same state at 30/60/144 Hz")
	check(Clips.stats().clips<=Clips.MAX_CLIPS,"Finite registry is bounded")
	print("MOTION_CLIPS_24_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
