extends SceneTree
const Gait = preload("res://scripts/player_gait.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Sim = preload("res://scripts/simulation.gd")

class BodyProbe extends Node2D:
	var state: Dictionary = {}
	var clock: float = 0.0
	func _draw() -> void:
		draw_set_transform(Vector2(60,40))
		Pixels.draw_player(self,state,clock)

var passed: int = 0
var failed: int = 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	if value: passed += 1; print("PASS: ",label)
	else: failed += 1; push_error("FAIL: "+label)
func player() -> Dictionary:
	return {"id":1,"character":"ranger","pos":Vector2(200,300),"vel":Vector2(245,0),"aim":Vector2.RIGHT,"grounded":true}
func _run() -> void:
	var canvas := Node2D.new()
	var state: Dictionary = player()
	var forward: Dictionary = Gait.profile(245,false)
	var backwards: Dictionary = Gait.profile(245,true)
	check(is_equal_approx(forward.stride,120) and 245.0/float(forward.stride)<2.1,"Forward gait has a 120px stride and only 2.04 complete cycles/s at base speed")
	check(is_equal_approx(backwards.stride,108) and backwards.lift < forward.lift,"Retreat uses a lower 108px step arc instead of reversing the forward animation")
	check(1000.0/float(Gait.profile(1000,false).stride)<=2.61,"High movement stacks lengthen flight without exceeding 2.6 cycles/s")
	for direction: float in [-1.0,1.0]:
		for facing: float in [-1.0,1.0]:
			Gait.reset(canvas)
			state = player(); state.vel.x*=direction; state.aim.x=facing
			var last: Dictionary = {}
			var pinned: bool = true
			var anatomy: bool = true
			var alternating: Dictionary = {}
			var contacts: int = 0
			for tick: int in range(181):
				state.pos.x = 200+direction*245*tick/60.0
				var before: PackedByteArray = var_to_bytes(state)
				var pose: Dictionary = Gait.sample(canvas,state,tick/60.0,"backpedal" if direction*facing<0 else "run")
				anatomy = anatomy and pose.legs.size()==2 and before==var_to_bytes(state)
				for index: int in range(2):
					var leg: Dictionary = pose.legs[index]
					anatomy = anatomy and absf(Vector2(leg.hip).distance_to(leg.knee)-Gait.THIGH)<.02 and absf(Vector2(leg.knee).distance_to(leg.ankle)-Gait.SHIN)<.02
					if leg.planted:
						contacts+=1; alternating[index]=true
						pinned=pinned and is_equal_approx(float(leg.ankle.y)+3,Gait.SOLE_Y)
						if not last.is_empty() and last.legs[index].planted: pinned=pinned and absf(float(leg.world.x)-float(last.legs[index].world.x))<.001
				last=pose
			check(pinned and contacts>50,"Contact feet stay at one world x and collider floor y while moving %s facing %s"%[direction,facing])
			check(anatomy and alternating.size()==2,"Exactly two unchanging-length joint chains alternate supports for travel %s facing %s"%[direction,facing])
	Gait.reset(canvas); state=player()
	var initial: Dictionary = Gait.sample(canvas,state,0.0,"run")
	var repeat: Dictionary = Gait.sample(canvas,state,0.0,"run")
	check(initial==repeat,"Repeated body/weapon sampling at one time is idempotent")
	state.aim=Vector2.LEFT
	var turned: Dictionary = Gait.sample(canvas,state,0.0,"backpedal")
	check(Vector2(turned.legs[0].world)==Vector2(initial.legs[0].world) and float(turned.legs[0].ankle.x)==-float(initial.legs[0].ankle.x),"A mouse-facing change mirrors local coordinates without teleporting planted feet")
	state.aim=Vector2.RIGHT
	var frozen: Dictionary = Gait.sample(canvas,state,.1,"run")
	check(frozen.phase==initial.phase,"A frozen position never pumps the legs just because velocity or the render clock is nonzero")
	state.vel=Vector2.ZERO
	var settling: Dictionary = Gait.sample(canvas,state,.12,"idle")
	check(settling.active and settling.legs.size()==2,"Stopping settles the existing two feet without overlaying an idle pair")
	Gait.sample(canvas,state,.24,"idle")
	check(not Gait.sample(canvas,state,.25,"idle").active,"After 120ms settling the original idle sprite takes over")
	state=player(); Gait.sample(canvas,state,.3,"run"); state.grounded=false
	check(not Gait.sample(canvas,state,.32,"rise").active,"Jumping removes all ground legs before the authored airborne pose draws")
	state.grounded=true;state.dash_timer=.1
	check(not Gait.sample(canvas,state,.34,"dash").active,"Dash poses cannot double-draw the grounded limb rig")
	state.dash_timer=0;Gait.sample(canvas,state,1.0,"run");state.pos.x+=500
	check(is_zero_approx(float(Gait.sample(canvas,state,1.01,"run").phase)),"Teleports discard stale world foot anchors")
	var phases: Array[float]=[]
	for hz: int in [30,60,120,165]:
		Gait.reset(canvas);state=player()
		for tick: int in range(hz+1):
			state.pos.x=200+245.0*tick/hz
			initial=Gait.sample(canvas,state,float(tick)/hz,"run")
		phases.append(initial.phase)
	check(phases.all(func(p:float)->bool:return absf(p-fposmod(245.0/120.0,1.0))<.0001),"Actual travel produces the same phase at 30,60,120 and 165 FPS")
	var turning_safe: bool = true
	for speed: float in [52.0,245.0,900.0]:
		Gait.reset(canvas);state=player();state.vel.x=speed
		for tick: int in range(180):
			state.vel.x = speed if tick < 60 else -speed
			state.pos.x += state.vel.x/60.0
			var pose: Dictionary = Gait.sample(canvas,state,tick/60.0,"run" if tick < 60 else "backpedal")
			for leg: Dictionary in pose.legs:
				turning_safe=turning_safe and Vector2(leg.hip).distance_to(leg.ankle)<Gait.THIGH+Gait.SHIN+.1
	check(turning_safe,"Guard-speed, base-speed and high-haste reversals never overextend either leg")
	_check_braking(canvas)
	await _native_crop_check()
	canvas.free()
	print("PLAYER_GAIT_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _check_braking(canvas: Node2D) -> void:
	# Exercise real acceleration, guard slowdown/recovery and release-key friction
	# at every entry phase, rather than replacing the velocity with a test constant.
	for mode: String in ["guard", "release"]:
		var anatomy: bool = true
		var pinned: bool = true
		var changed_speed: bool = false
		var max_reach: float = 0.0
		for change_tick: int in range(12,73):
			Gait.reset(canvas)
			var sim = Sim.new()
			sim.start_run([{"id":1,"name":"Gait","character":"vanguard"}],17)
			sim.state.platforms=[Rect2(0,1000,2400,100)]
			sim.state.floor_y=1000.0
			sim.state.world_size=Vector2(2400,1100)
			sim._spawn_clock=9999.0
			var state: Dictionary=sim.state.players[1]
			state.pos=Vector2(600,979); state.vel=Vector2.ZERO; state.grounded=true
			var previous: Dictionary={}
			for tick: int in range(120):
				sim.step(1.0/60,{1:{"move":0.0 if mode=="release" and tick>=change_tick else 1.0,"dash":mode=="guard" and tick==change_tick}})
				changed_speed=changed_speed or (tick>change_tick and float(state.vel.x)<100.0)
				var pose: Dictionary=Gait.sample(canvas,state,tick/60.0,"run" if absf(state.vel.x)>15 else "idle")
				if not pose.active:
					previous={}
					continue
				for index: int in range(2):
					var leg: Dictionary=pose.legs[index]
					max_reach=maxf(max_reach,Vector2(leg.hip).distance_to(leg.ankle))
					anatomy=anatomy and absf(Vector2(leg.hip).distance_to(leg.knee)-Gait.THIGH)<.02 and absf(Vector2(leg.knee).distance_to(leg.ankle)-Gait.SHIN)<.02
					if leg.planted and not previous.is_empty() and previous.legs[index].planted and is_zero_approx(float(pose.settle)):
						pinned=pinned and absf(float(leg.world.x)-float(previous.legs[index].world.x))<.001
				previous=pose
		check(anatomy and changed_speed and max_reach<Gait.THIGH+Gait.SHIN,"Real %s slowdown across 61 gait entry phases preserves both bone lengths (max reach %.3f)"%[mode,max_reach])
		check(pinned,"Real %s slowdown preserves each continuing support foot's world anchor"%mode)

func _native_crop_check() -> void:
	if DisplayServer.get_name()=="headless": return
	var source := Image.create(32,64,false,Image.FORMAT_RGBA8)
	source.fill(Color.CYAN)
	for y: int in range(32,64):
		for x: int in range(32): source.set_pixel(x,y,Color.MAGENTA)
	var record: Dictionary = {"texture":"leg_fixture","frames":[{"rect":[0,0,32,64],"anchor":[16,32],"duration":.1}],"animations":{"idle":[0],"run":[0],"backpedal":[0],"rise":[0]}}
	Pixels.install_manifest({"version":1,"actors":{"ranger":record}},{"leg_fixture":ImageTexture.create_from_image(source)})
	var view := SubViewport.new()
	view.size=Vector2i(120,100)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var probe := BodyProbe.new()
	view.add_child(probe)
	var clean: bool = true
	for mode: String in ["run","backpedal"]:
		for angle: float in [0.0,.16,-.12]:
			Pixels.reset_tracks(probe)
			probe.state=player()
			probe.state.vel.x=245 if mode=="run" else -245
			probe.state._melee_pose={"active":true,"draw_origin":Vector2(60,40),"facing":1.0,"body_angle":angle}
			for tick: int in range(3):
				probe.state.pos.x+=probe.state.vel.x/60.0
				probe.clock=tick/60.0
				probe.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var output: Image=view.get_texture().get_image()
				for y: int in range(47,100):
					for x: int in range(120):
						var color: Color=output.get_pixel(x,y)
						if color.r>.8 and color.b>.8 and color.g<.2: clean=false
	check(clean,"Native running/retreat/attack renders never include the source sprite's magenta lower-body pixels")
	probe.state.grounded=false
	probe.state.vel.y=-100
	probe.state.erase("_melee_pose")
	probe.clock+=.1
	probe.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var airborne: Image=view.get_texture().get_image()
	check(airborne.get_pixel(60,60).r>.8 and airborne.get_pixel(60,60).b>.8,"Native airborne rendering restores the authored lower body after removing the ground rig")
	view.queue_free()
	await process_frame
	Pixels.reload_manifest()
