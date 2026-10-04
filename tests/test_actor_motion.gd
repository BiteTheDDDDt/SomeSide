extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
var passed: int = 0
var failed: int = 0

class Probe extends Node2D:
	var offset: Vector2 = Vector2.ZERO
	var actors: Array = []
	func center(index: int) -> Vector2:
		return Vector2(100+(index%7)*170,150+(index/7)*280)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("10202c"))
		for index: int in range(actors.size()):
			var id: String = actors[index]
			draw_set_transform(Pixels.snap_position(self,center(index)+offset))
			if id in ["ranger","vanguard"]:
				Entities.player_body(self,{"character":id,"grounded":true,"vel":Vector2.ZERO},0.0)
			else:
				Entities.enemy(self,{"kind":"boss" if id.begins_with("boss_") else id,"boss_style":id.trim_prefix("boss_"),"id":0,"vel":Vector2.ZERO},0.0)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		passed+=1
		print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)

func _world() -> Node2D:
	var world := World.new()
	world.scenery_cache_enabled=false
	return world

func _run() -> void:
	Pixels.reload_manifest()
	_check(Pixels.stats().actors==14 and Pixels.stats().errors.is_empty(),"All production pixel actors load without fallback")
	_check(Pixels.stats().baked_bytes>0 and Pixels.stats().baked_bytes<=Pixels.MAX_BAKED_BYTES,"Runtime logical-pixel frames have an explicit bounded memory budget")
	for id: String in Pixels.actor_ids():
		var common: Rect2=Rect2()
		var valid: bool=true
		for entry: Dictionary in Pixels._actors[id].frames:
			var target: Rect2=entry.draw_target
			if common.size==Vector2.ZERO: common=target
			valid=valid and target==common and target.position==target.position.round() and target.size==entry.texture.get_size()
		_check(valid,"Every %s pose shares one native-pixel size and integer anchor"%id)
	for rate: int in [30,45,60,75,120,144,165,240]:
		var sim=Simulation.new()
		sim.start_run([{"id":1,"name":"Motion","character":"ranger"}],1101)
		var player: Dictionary=sim.state.players[1]
		player.pos=Vector2(1500,float(sim.state.floor_y)-21.0)
		player.invuln=9999.0
		sim._spawn_clock=9999.0
		var world: Node2D=_world()
		var accumulated: float=0.0
		var previous: Vector2=Vector2.ZERO
		var worst_backward: float=0.0
		var largest: float=0.0
		var immutable: bool=true
		for frame: int in range(rate*4):
			accumulated+=1.0/rate
			while accumulated+0.0000001>=1.0/60.0:
				sim.step(1.0/60.0,{1:{"move":1.0,"aim":Vector2.RIGHT}})
				accumulated-=1.0/60.0
			var before: Vector2=player.pos
			world.set_frame(sim.state,1,1.0/rate)
			var position_value: Vector2=world.world_to_screen(world.weapon_draw_pose(player).position)
			if frame>rate*2:
				worst_backward=minf(worst_backward,position_value.x-previous.x)
				largest=maxf(largest,absf(position_value.x-previous.x))
			immutable=immutable and before==player.pos
			previous=position_value
		_check(worst_backward>-.02 and largest<.04,"Actual 60 Hz simulation with %d Hz rendering has no backwards camera/body sawtooth"%rate)
		_check(immutable,"%d Hz presentation keeps the authoritative position unchanged"%rate)
		world.free()
	var world: Node2D=_world()
	var entity: Dictionary={"pos":Vector2(10,90),"dead":false}
	world._cache_fixed_position("p1",entity,0.0,0.0)
	entity.pos=Vector2(20,100)
	world._cache_fixed_position("p1",entity,1.0/60.0,1.0/60.0)
	world._cache_fixed_position("p1",entity,1.0/60.0,1.0/120.0)
	_check(world._render_positions.p1.is_equal_approx(Vector2(15,95)),"Half-frame landing interpolation stays between known collision-safe positions")
	world._cache_fixed_position("p1",entity,1.0/60.0,0.0)
	_check(world._render_positions.p1.is_equal_approx(Vector2(15,95)),"A zero-delta pause cannot advance the visual position")
	world._cache_fixed_position("p1",entity,1.0/60.0,1.0)
	_check(world._render_positions.p1==entity.pos,"A stopped player settles at the latest collision point without velocity extrapolation")
	entity.pos=Vector2(900,100)
	world._cache_fixed_position("p1",entity,2.0/60.0,1.0/60.0)
	_check(world._render_positions.p1==entity.pos,"Large teleports snap instead of sweeping across the map")
	entity.pos=Vector2(910,100)
	entity.dead=true
	world._cache_fixed_position("p1",entity,3.0/60.0,1.0/60.0)
	_check(world._render_positions.p1==entity.pos,"Death clears an old movement segment immediately")
	entity.pos=Vector2(920,100)
	entity.dead=false
	world._cache_fixed_position("p1",entity,4.0/60.0,1.0/60.0)
	_check(world._render_positions.p1==entity.pos,"Revival cannot reuse the corpse movement history")
	entity.pos=Vector2(950,100)
	world._cache_fixed_position("p1",entity,8.0/60.0,4.0/60.0)
	_check(world._render_positions.p1.is_equal_approx(Vector2(942.5,100)),"Skipped physics updates retain a consistent one-tick lag instead of alternating interpolation and snapping")
	entity.pos=Vector2(970,100)
	world._cache_fixed_position("p1",entity,30.0/60.0,22.0/60.0)
	_check(world._render_positions.p1==entity.pos,"An extreme render hitch discards old movement history")
	entity.pos=Vector2(30,100)
	world._cache_fixed_position("p1",entity,0.0,1.0/60.0)
	_check(world._render_positions.p1==entity.pos,"Time rollback discards an old run's interpolation")
	world._frame={"time":0.0,"stage":2,"players":{1:{"id":1,"pos":Vector2(32,101)}},"enemies":[],"projectiles":[]}
	world._update_render_positions(0.0)
	_check(world._render_positions.p1==Vector2(32,101),"Changing stage resets even a short-distance transition")
	world._frame.players.clear()
	world._update_render_positions(1.0/60.0)
	_check(world._fixed_samples.is_empty() and world._render_positions.is_empty(),"Departed actors leave no unbounded render history")
	world.free()
	# Real engine physics ticks, independent of unchanged network snapshot time.
	world=_world()
	world.interpolate_remote_entities=true
	world.set_frame({"time":10.0,"stage":1,"players":{1:{"id":1,"pos":Vector2.ZERO}},"enemies":[],"projectiles":[]},1,0.0)
	await physics_frame
	await process_frame
	world._frame.players[1].pos=Vector2(10,0)
	world.set_frame(world._frame,1,1.0/60.0)
	_check(int(world._fixed_samples.p1.tick)==Engine.get_physics_frames() and world._fixed_samples.p1.current==Vector2(10,0),"Client local movement follows prediction ticks even when no new server snapshot arrives")
	world.free()
	# Use the actual step/firing order: movement, weapon fire, then projectile
	# travel occur before a render ever sees a newly spawned bullet.
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Running shots","character":"ranger"}],1102)
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(1500,float(sim.state.floor_y)-21.0)
	player.invuln=9999.0
	sim._spawn_clock=9999.0
	world=_world()
	var aligned: bool=true
	var clean_tail: bool=true
	var unchanged: bool=true
	for weapon: String in ["pulse_rifle","scattergun","railgun","boomerang","storm_staff","sun_lance"]:
		for direction: int in range(8):
			player.weapon=weapon
			player.fire_cd=0.0
			sim.state.projectiles.clear()
			var command: Dictionary={"move":1.0,"aim":Vector2.from_angle(direction*TAU/8.0)}
			sim.step(1.0/60.0, {1:command})
			world.set_frame(sim.state,1,1.0/60.0)
			command.fire=true
			sim.step(1.0/60.0, {1:command})
			var before: PackedByteArray=var_to_bytes(sim.state)
			world.set_frame(sim.state,1,1.0/60.0)
			for bullet: Dictionary in sim.state.projectiles:
				var rendered: Vector2=world._entity_draw_position("b"+str(bullet.id),bullet.pos)
				aligned=aligned and rendered.is_equal_approx(world.weapon_draw_pose(player).muzzle)
				clean_tail=clean_tail and is_zero_approx(world.rendered_projectile_trail_length(bullet,rendered,100.0))
			unchanged=unchanged and before==var_to_bytes(sim.state)
	_check(aligned,"Actual running shots from six projectile weapons in eight directions begin at the displayed gun muzzle")
	_check(clean_tail,"New moving shots have zero rear trail even when firing against the movement direction")
	_check(unchanged,"First-shot visual alignment never changes authority origins, travel, collision or player state")
	world.free()
	for rate: int in [60,120]:
		world=_world()
		world.interpolate_remote_entities=true
		var snapshot: Dictionary={"time":0.0,"stage":1,"players":{1:{"id":1,"pos":Vector2(1500,1000),"vel":Vector2.ZERO,"aim":Vector2.RIGHT},2:{"id":2,"pos":Vector2(1660,1000),"vel":Vector2(245,0),"aim":Vector2.RIGHT}},"enemies":[],"projectiles":[]}
		var previous_remote: Vector2=Vector2(1660,1000)
		var monotonic: bool=true
		var coherent: bool=true
		var readonly: bool=true
		for frame: int in range(rate*2):
			if frame%(rate/20)==0:
				snapshot.time=float(frame)/rate
				snapshot.players[2].pos=Vector2(1660+245.0*float(frame)/rate,1000)
			var before: PackedByteArray=var_to_bytes(snapshot)
			world.set_frame(snapshot,1,1.0/rate)
			var pose: Dictionary=world.weapon_draw_pose(snapshot.players[2])
			monotonic=monotonic and Vector2(pose.position).x>=previous_remote.x-.001
			coherent=coherent and Vector2(pose.shoulder).is_equal_approx(Vector2(pose.position)+Vector2(0,-5)) and Vector2(pose.muzzle).is_equal_approx(Vector2(pose.shoulder)+Vector2(36,0))
			readonly=readonly and before==var_to_bytes(snapshot)
			previous_remote=pose.position
		_check(monotonic and not world._fixed_samples.has("p2"),"20 Hz remote snapshots at %d Hz draw smoothly without adding local interpolation twice"%rate)
		_check(coherent and readonly,"Remote body, shoulder and muzzle share one immutable render position at %d Hz"%rate)
		world.free()
	if DisplayServer.get_name()!="headless":
		await _native()
	print("ACTOR_MOTION_CACHE ",JSON.stringify(Pixels.stats()))
	print("ACTOR_MOTION_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _native() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var canvas:=Probe.new()
	canvas.actors=Pixels.actor_ids()
	root.add_child(canvas)
	for factor: float in [1.0,1.5,2.0]:
		root.size=Vector2i(Vector2(1280,720)*factor)
		await process_frame
		var hashes: Array=[]
		for id: String in canvas.actors: hashes.append({})
		for frame: int in range(16):
			canvas.offset=Vector2(frame*.125,frame*.046875)
			canvas.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image=root.get_texture().get_image()
			for index: int in range(canvas.actors.size()):
				var origin: Vector2i=Vector2i(((canvas.center(index)+canvas.offset)*factor).round())
				var size_value: Vector2i=Vector2i(Vector2(150,200)*factor)
				var crop: Image=shot.get_region(Rect2i(origin-size_value/2,size_value))
				hashes[index][hash(crop.get_data())]=true
		for index: int in range(canvas.actors.size()):
			_check(hashes[index].size()==1,"Native %sx %s has identical pixels over sixteen subpixel camera/movement phases"%[factor,canvas.actors[index]])
	canvas.queue_free()
	await process_frame
