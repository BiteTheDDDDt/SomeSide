extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Icons = preload("res://scripts/item_icons.gd")
var passed: int = 0
var failed: int = 0

class ShopView extends "res://scripts/world_view.gd":
	func _ready() -> void: set_process(false)
	func _draw() -> void: pass

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS: ",message)
	else: failed+=1; push_error("FAIL: "+message)

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	await process_frame
	var simulation=Simulation.new()
	simulation.start_run([{"id":1,"name":"Shop stability","character":"ranger"}],20261005)
	var shops: Array=[]
	var group: int=-1
	for chest: Dictionary in simulation.state.chests:
		if chest.type=="choice" and (group==-1 or group==int(chest.group)):
			group=int(chest.group)
			shops.append(chest)
	_check(shops.size()==3,"The real generated shop retains exactly three identified offers")
	var original: PackedByteArray=var_to_bytes(simulation.state)
	var rng_before: int=simulation._rng.state
	var view:=ShopView.new()
	view.scenery_cache_enabled=false
	root.add_child(view)
	var divergent_phases: Dictionary={}
	for rate: int in [30,45,60,75,120,144,165,240]:
		var independent: bool=true
		var bounded: bool=true
		var smooth: bool=true
		var active: bool=true
		for chest: Dictionary in shops:
			var last: float=0.0
			var last_direction: int=0
			var reversals: int=0
			var smallest: float=INF
			var largest: float=-INF
			for tick: int in range(rate*4):
				view._clock=float(tick)/rate
				var stationary: Rect2=view.facility_icon_rect(Vector2(640,417),chest,"choice")
				# 460 px/s camera travel and oscillating shake must not become
				# an animation clock; only the world-to-screen anchor translates.
				var shift: float=float(tick)*460.0/rate+sin(float(tick)*.81)*5.0
				var moving: Rect2=view.facility_icon_rect(Vector2(640+shift,417),chest,"choice")
				independent=independent and stationary.position.y==moving.position.y
				var hover: float=stationary.position.y-417.0
				bounded=bounded and absf(hover+41.0)<=2.0 and stationary.size==Vector2(24,24)
				smallest=minf(smallest,hover); largest=maxf(largest,hover)
				if tick>0:
					var change: float=hover-last
					smooth=smooth and absf(change)<=1.0
					var direction: int=int(signf(change))
					if direction!=0:
						if last_direction!=0 and direction!=last_direction: reversals+=1
						last_direction=direction
				last=hover
			active=active and largest-smallest>=2.0 and reversals<=3
		_check(independent,"%d Hz: moving cameras and horizontal shake cannot alter any offer's hover phase"%rate)
		_check(bounded,"%d Hz: all three icons retain a fixed 24 px size and bounded gentle hover"%rate)
		_check(smooth and active,"%d Hz: retained hover has no rapid reversals or multi-pixel vertical jumps"%rate)
	view._clock=0.73
	for chest: Dictionary in shops:
		var expected: Rect2=view.facility_icon_rect(Vector2(640,417),chest,"choice")
		divergent_phases[expected.position.y]=true
		var valid: bool=true
		for index: int in range(400):
			var origin: Vector2=Vector2(300+index*.125,200+index*.046875)
			var rect: Rect2=view.facility_icon_rect(origin,chest,"choice")
			valid=valid and rect.position==rect.position.round() and rect.size==Vector2(24,24)
		_check(valid,"Offer %s stays aligned under subpixel camera travel"%chest.id)
	shops.reverse()
	var stable: bool=true
	for chest: Dictionary in shops:
		var rect: Rect2=view.facility_icon_rect(Vector2(640,417),chest,"choice")
		var copied: Dictionary=chest.duplicate(true)
		copied.item="sun_lance"
		copied.opened=true
		stable=stable and rect==view.facility_icon_rect(Vector2(640,417),copied,"choice")
	_check(stable,"Array ordering, reward identity and purchase flags cannot reseed visual phase")
	_check(divergent_phases.size()>1,"Separate offers retain offset hover phases rather than a synchronized static display")
	var bay: Dictionary={"id":9001,"item":"grenade","type":"equipment"}
	var bay_rect: Rect2=view.facility_icon_rect(Vector2(600,417),bay,"equipment")
	view._clock=9000.0
	_check(bay_rect==view.facility_icon_rect(Vector2(600,417),bay,"equipment"),"Equipment bay previews remain stationary inside their sockets")
	for size: int in [24,28]:
		var texture: Texture2D=Icons.texture("feather",size)
		_check(texture.get_size()==Vector2(size,size) and texture==Icons.texture("feather",size),"Ground icon size %d uses one cached native raster instead of rescaling a 32 px texture"%size)
	_check(original==var_to_bytes(simulation.state) and rng_before==simulation._rng.state,"All display probes preserve authoritative shop state and random sequence")
	var selected: Dictionary=shops[1]
	var player: Dictionary=simulation.state.players[1]
	player.pos=selected.pos
	player.coins=10000
	var balance: int=player.coins
	simulation._interact(player,{"kind":"chest","id":selected.id})
	var locked: int=0
	for chest: Dictionary in shops:
		if bool(chest.locked): locked+=1
	_check(bool(selected.opened) and locked==2 and player.coins==balance-int(selected.cost),"Buying the displayed offer still charges exactly once and locks both alternatives")
	view.queue_free()
	await process_frame
	print("SHOP_MOTION_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
