class_name SideEntityRenderer
extends RefCounted

## Silhouettes and material panels, in the actor's local facing transform.
## All animation is presentation-only and never changes the supplied snapshot.
const Atlas = preload("res://scripts/sprite_atlas.gd")
const IllustratedPlayers = preload("res://scripts/illustrated_player_renderer.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Geometric = preload("res://scripts/geometric_enemies.gd")
const CACHE_META: StringName = &"someside_enemy_atlas"
const CACHE_MAX_BYTES: int = 28 * 1024 * 1024
const ANIMATION_FRAMES: int = 16
const FREQUENCIES: Dictionary = {"crawler": 1.4, "spitter": 0.45, "spore_moth": 1.25, "drone": 1.0, "charger": 1.0, "burrower": 0.4, "sentinel": 0.0, "skirmisher": 1.0, "conductor": 0.4}

const INK: Color = Color("081920")
const BONE: Color = Color("e0dcc1")
const HOT: Color = Color("ffaf78")
const WHITE: Color = Color("edf4e4")
const KINDS: Array[String] = ["crawler","spitter","spore_moth","drone","charger","burrower","sentinel","skirmisher","conductor"]

static func prepare(canvas: Node2D) -> void:
	if DisplayServer.get_name() == "headless" or canvas.has_meta(CACHE_META):
		return
	var fallback_entries: Array = []
	for entry: Dictionary in atlas_entries():
		if not Pixels.available(str(entry.data.state.kind)):
			fallback_entries.append(entry)
	if not fallback_entries.is_empty():
		Atlas.prepare(canvas, CACHE_META, fallback_entries, _paint_atlas_entry, CACHE_MAX_BYTES)

static func cache_info(canvas: Node2D) -> Dictionary:
	return Atlas.stats(canvas, CACHE_META)

static func atlas_entries() -> Array:
	var entries: Array = []
	for kind: String in KINDS:
		var frequency: float = float(FREQUENCIES[kind])
		var frames: int = ANIMATION_FRAMES if frequency > 0.0 else 1
		for variant: int in range(8 if kind == "charger" else 4):
			var state: Dictionary = {"kind": kind, "id": 0, "elite": (variant & 1) != 0, "flash": 0.1 if (variant & 2) != 0 else 0.0, "telegraph": 0.5 if (variant & 4) != 0 else 0.0}
			var bounds: Rect2 = _vector_enemy_bounds(state)
			# The elite crown extends seven pixels above the base art bounds.
			bounds = Rect2(bounds.position - Vector2(4, 10), bounds.size + Vector2(8, 14))
			for frame: int in range(frames):
				var phase: float = float(frame) / float(frames) * TAU / frequency if frequency > 0.0 else 0.0
				entries.append({"key": "%s/%d/%d" % [kind, variant, frame], "bounds": bounds, "data": {"state": state, "clock": phase / 9.0}})
	return entries

static func _paint_atlas_entry(canvas: Node2D, data: Dictionary) -> void:
	_enemy_vector(canvas, data.state, float(data.clock))

static func enemy_kinds() -> Array[String]:
	return KINDS.duplicate()

static func enemy_bounds(enemy: Dictionary) -> Rect2:
	if Geometric.supports(str(enemy.get("kind", ""))): return Geometric.bounds(enemy)
	var pixel_bounds: Rect2 = Pixels.bounds(Pixels.enemy_id(enemy))
	if pixel_bounds.size != Vector2.ZERO:
		return pixel_bounds
	return _vector_enemy_bounds(enemy)

static func _vector_enemy_bounds(enemy: Dictionary) -> Rect2:
	match str(enemy.get("kind","crawler")):
		"boss": return Rect2(-68,-78,136,128)
		"spore_moth": return Rect2(-37,-32,74,59)
		"drone": return Rect2(-34,-28,68,48)
		"charger": return Rect2(-30,-26,65,46)
		"burrower": return Rect2(-26,-32,54,53)
		"sentinel": return Rect2(-22,-34,46,54)
		"skirmisher": return Rect2(-27,-30,57,53)
		"conductor": return Rect2(-31,-33,62,66)
		_: return Rect2(-28,-27,61,48)

static func _poly(c: Node2D, points: Array, color: Color, edge: bool = true) -> void:
	var shape: PackedVector2Array = PackedVector2Array(points)
	c.draw_colored_polygon(shape,color)
	if edge:
		shape.append(shape[0])
		c.draw_polyline(shape,INK,1.5,true)

static func _plate(c: Node2D, points: Array, color: Color, highlight: Array = []) -> void:
	_poly(c,points,color)
	if not highlight.is_empty(): c.draw_polyline(PackedVector2Array(highlight),color.lightened(0.35),1.0,true)

static func _joint(c: Node2D, center: Vector2, radius: float, metal: Color) -> void:
	c.draw_circle(center,radius+1,INK,true,-1,true)
	c.draw_circle(center,radius,metal,true,-1,true)
	c.draw_arc(center,radius-0.7,PI,PI*1.85,10,metal.lightened(0.35),0.8,true)
	c.draw_circle(center,maxf(0.7,radius*0.23),INK,true,-1,true)

static func _limb(c: Node2D, points: Array, color: Color, width: float) -> void:
	var path: PackedVector2Array = PackedVector2Array(points)
	c.draw_polyline(path,INK,width+2.0,true)
	c.draw_polyline(path,color,width,true)
	c.draw_polyline(path,color.lightened(0.25),maxf(0.7,width*0.22),true)

static func _eye(c: Node2D, center: Vector2, radius: float, tint: Color = HOT) -> void:
	c.draw_circle(center,radius+1.5,INK,true,-1,true)
	c.draw_circle(center,radius,tint.darkened(0.15),true,-1,true)
	c.draw_circle(center+Vector2(-0.3,-0.6),radius*0.54,tint.lightened(0.28),true,-1,true)
	c.draw_circle(center+Vector2(-0.6,-0.9),maxf(0.5,radius*0.22),WHITE,true,-1,true)

static func player_body(c: Node2D, player: Dictionary, clock: float) -> void:
	if IllustratedPlayers.draw(c,player,clock): return
	if Pixels.draw_player(c, player, clock):
		return
	_player_vector(c, player, clock)

static func _player_vector(c: Node2D, player: Dictionary, clock: float) -> void:
	var heavy: bool = str(player.get("character","ranger")) == "vanguard"
	var metal: Color = Color("c8d2bf") if not heavy else Color("d6bb8d")
	var shadow: Color = Color("3f5b62") if not heavy else Color("725d4b")
	var cloth: Color = Color("233c46") if not heavy else Color("414149")
	var signal_color: Color = Color("86edd8") if not heavy else Color("ffd38a")
	var vel: Vector2 = player.get("vel",Vector2.ZERO)
	var grounded: bool = bool(player.get("grounded",false))
	var speed: float = clampf(absf(vel.x)/180.0,0.0,1.0)
	var cycle: float = clock*16.0
	var scarf: float = sin(clock*7.0)*1.5+speed*4.0
	_poly(c,[Vector2(-5,-10),Vector2(-16-speed*5,-9+scarf),Vector2(-22-speed*3,-3+scarf),Vector2(-13,0+scarf),Vector2(-4,-5)],Color("ce895f") if not heavy else Color("638e94"))
	c.draw_polyline(PackedVector2Array([Vector2(-7,-8),Vector2(-14,-6+scarf),Vector2(-20-speed*3,-4+scarf)]),Color("f0b888") if not heavy else Color("a7c8c4"),0.8,true)
	_plate(c,[Vector2(-13,-8),Vector2(-7,-11),Vector2(-5,6),Vector2(-12,9),Vector2(-15,4)],shadow,[Vector2(-13,-7),Vector2(-11,-8),Vector2(-10,5)])
	c.draw_rect(Rect2(-14,-3,3,5),INK)
	c.draw_line(Vector2(-13,-2),Vector2(-13,1),signal_color,1.0,true)
	# Separate hip, knee, ankle and toe profiles make run and jump readable.
	for side: int in [-1,1]:
		var stride: float = sin(cycle+ (PI if side<0 else 0.0))*speed
		var hip: Vector2 = Vector2(side*3,6)
		var knee: Vector2 = Vector2(side*3+stride*5,12.5)
		var ankle: Vector2 = Vector2(side*4+stride*8,18-maxf(0.0,stride)*4)
		if not grounded:
			knee = Vector2(7 if side>0 else -6,10 if side>0 else 13)
			ankle = Vector2(4 if side>0 else -9,15 if vel.y<0 else 19)
		var tint: Color = shadow if side<0 else metal.darkened(0.2)
		_limb(c,[hip,knee,ankle],cloth,5.0)
		_joint(c,knee,2.3,tint)
		_plate(c,[knee+Vector2(-2,2),knee+Vector2(2,2),ankle+Vector2(2,0),ankle+Vector2(-2,1)],tint,[knee+Vector2(1,3),ankle+Vector2(1,-1)])
		_poly(c,[ankle+Vector2(-3,-1),ankle+Vector2(2,-1),ankle+Vector2(5,1),ankle+Vector2(5,3),ankle+Vector2(-3,3)],shadow)
		c.draw_line(ankle+Vector2(-2,2),ankle+Vector2(4,2),metal,1.0,true)
	# A dark pressure suit stays visible between independent torso plates.
	_poly(c,[Vector2(-8,-9),Vector2(6,-10),Vector2(9,4),Vector2(4,10),Vector2(-7,8)],cloth)
	_plate(c,[Vector2(-7,-7),Vector2(-1,-9),Vector2(5,-8),Vector2(7,-1),Vector2(0,2),Vector2(-6,0)],metal,[Vector2(-6,-6),Vector2(-1,-8),Vector2(4,-7)])
	_poly(c,[Vector2(-6,1),Vector2(0,3),Vector2(6,1),Vector2(5,6),Vector2(0,8),Vector2(-5,6)],shadow)
	c.draw_line(Vector2(-3,3),Vector2(3,3),metal,0.8,true)
	c.draw_line(Vector2(-2,5),Vector2(2,5),metal.darkened(0.1),0.8,true)
	c.draw_rect(Rect2(-7,6,13,2),INK)
	c.draw_rect(Rect2(-1,6,3,2),metal.lightened(0.15))
	_poly(c,[Vector2(-9,3),Vector2(-5,4),Vector2(-6,9),Vector2(-10,8)],shadow)
	c.draw_line(Vector2(-8,4),Vector2(-7,4),signal_color,1.2,true)
	_joint(c,Vector2(-5,-4),3.5,shadow)
	# Paired collar and asymmetric shoulder cap distinguish the two classes.
	_plate(c,[Vector2(-9,-10),Vector2(-5,-12),Vector2(0,-9),Vector2(-1,-5),Vector2(-8,-6)],metal.darkened(0.12),[Vector2(-8,-10),Vector2(-5,-11),Vector2(-1,-9)])
	c.draw_line(Vector2(-7,-7),Vector2(-4,-7),signal_color,1.0,true)
	if heavy:
		_plate(c,[Vector2(-12,-10),Vector2(-7,-14),Vector2(-1,-11),Vector2(-3,-5),Vector2(-11,-5)],metal,[Vector2(-10,-10),Vector2(-7,-12),Vector2(-2,-10)])
		c.draw_line(Vector2(-10,-7),Vector2(-5,-7),Color("ecd09c"),1.0,true)
	# Helmet shell, face glass, brow, respirator and rear comms are separate.
	_poly(c,[Vector2(-8,-20),Vector2(-3,-24),Vector2(4,-23),Vector2(10,-18),Vector2(11,-12),Vector2(7,-8),Vector2(-6,-8),Vector2(-10,-13)],shadow)
	_plate(c,[Vector2(-8,-18),Vector2(-4,-22),Vector2(3,-22),Vector2(8,-18),Vector2(7,-15),Vector2(-3,-15),Vector2(-5,-11),Vector2(-8,-13)],metal,[Vector2(-6,-19),Vector2(-3,-21),Vector2(2,-21),Vector2(6,-18)])
	_poly(c,[Vector2(-1,-18),Vector2(7,-18),Vector2(10,-15),Vector2(9,-12),Vector2(0,-12),Vector2(-2,-14)],Color("102b37"))
	_poly(c,[Vector2(0,-17),Vector2(6,-17),Vector2(8,-15),Vector2(1,-14)],signal_color.darkened(0.18),false)
	c.draw_line(Vector2(1,-17),Vector2(6,-16),signal_color.lightened(0.45),1.0,true)
	_plate(c,[Vector2(-2,-11),Vector2(7,-11),Vector2(6,-8),Vector2(1,-7),Vector2(-3,-9)],metal.darkened(0.14),[Vector2(0,-10),Vector2(5,-10)])
	for x: int in [1,3,5]: c.draw_line(Vector2(x,-10),Vector2(x,-8.5),INK,0.7,true)
	_joint(c,Vector2(-7,-14),2.4,shadow)
	c.draw_line(Vector2(-7,-15),Vector2(-7,-13),signal_color,0.8,true)
	if heavy:
		_plate(c,[Vector2(-5,-24),Vector2(-1,-26),Vector2(3,-24),Vector2(3,-21),Vector2(-3,-22)],metal.lightened(0.15))
	else:
		c.draw_line(Vector2(-8,-20),Vector2(-10,-28),shadow,1.5,true)
		c.draw_circle(Vector2(-10,-28),1.1,signal_color,true,-1,true)

static func enemy(c: Node2D, state: Dictionary, clock: float) -> void:
	if Geometric.draw(c,state,clock):
		if bool(state.get("elite", false)):
			var top: float = enemy_bounds(state).position.y - 3.0
			_poly(c,[Vector2(-5,top),Vector2(0,top-4),Vector2(5,top)],Color("ffc77c"),false)
		return
	if Pixels.draw_enemy(c, state, clock):
		if bool(state.get("elite", false)) and str(state.get("kind", "")) != "boss":
			var top: float = enemy_bounds(state).position.y - 3.0
			_poly(c, [Vector2(-5, top), Vector2(-3, top-4), Vector2(0, top-1), Vector2(3, top-4), Vector2(5, top)], Color("ffc77c"), false)
		return
	var kind: String = str(state.get("kind", "crawler"))
	# Large bosses retain the full vector animation. Ordinary silhouettes are
	# sampled at subpixel resolution; position, facing and warning stay live.
	if FREQUENCIES.has(kind):
		var cached: Dictionary = Atlas.cache(c, CACHE_META)
		if not cached.is_empty():
			var frequency: float = float(FREQUENCIES[kind])
			var phase: float = (clock * 9.0 + float(state.get("id", 0)) * 1.7) * frequency
			var frame: int = int(floor(fposmod(phase, TAU) / TAU * ANIMATION_FRAMES)) if frequency > 0.0 else 0
			var variant: int = (1 if state.get("elite", false) else 0) | (2 if float(state.get("flash", 0.0)) > 0.0 else 0)
			if kind == "charger" and float(state.get("telegraph", 0.0)) > 0.0:
				variant |= 4
			if Atlas.draw_region(c, cached, "%s/%d/%d" % [kind, variant, frame]):
				return
	_enemy_vector(c, state, clock)

static func _enemy_vector(c: Node2D, state: Dictionary, clock: float) -> void:
	var kind: String = str(state.get("kind","crawler"))
	var phase: float = clock*9.0+float(state.get("id",0))*1.7
	var flash: float = 0.5 if float(state.get("flash",0.0))>0 else 0.0
	var elite: bool = bool(state.get("elite",false))
	var signal_color: Color = Color("ffd08b") if elite else HOT
	match kind:
		"crawler": _crawler(c,phase,flash,signal_color)
		"spitter": _spitter(c,phase,flash,signal_color)
		"spore_moth": _moth(c,phase,flash,signal_color)
		"drone": _drone(c,phase,flash,signal_color)
		"charger": _charger(c,phase,flash,signal_color,float(state.get("telegraph",0.0))>0)
		"burrower": _burrower(c,phase,flash,signal_color)
		"sentinel": _sentinel(c,phase,flash,signal_color)
		"skirmisher": _skirmisher(c,phase,flash,signal_color)
		"conductor": _conductor(c,phase,flash,signal_color)
		"boss": _boss(c,state,phase,flash,signal_color)
		_: _crawler(c,phase,flash,signal_color)
	if elite and kind!="boss":
		var top: float = _vector_enemy_bounds(state).position.y-3.0
		_poly(c,[Vector2(-5,top),Vector2(-3,top-4),Vector2(0,top-1),Vector2(3,top-4),Vector2(5,top)],Color("ffc77c"),false)

static func _crawler(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	var shell: Color = Color("788477").lerp(WHITE,flash)
	for leg: int in range(3):
		var x: float = -13+leg*11
		var gait: float = sin(phase*1.4+leg*2.0)*3.5
		_limb(c,[Vector2(x,4),Vector2(x-7+gait,11),Vector2(x-4+gait,17)],Color("718c82"),2.6)
		c.draw_line(Vector2(x-4+gait,17),Vector2(x+gait,16),BONE,1.3,true)
	_poly(c,[Vector2(-22,0),Vector2(-18,-10),Vector2(-8,-16),Vector2(9,-13),Vector2(18,-5),Vector2(19,5),Vector2(-6,9)],Color("344d4d"))
	for i: int in range(3):
		var x: float = -17+i*9
		_plate(c,[Vector2(x,0),Vector2(x-1,-10+i),Vector2(x+5,-14+i),Vector2(x+10,-7+i),Vector2(x+8,4),Vector2(x+2,6)],shell,[Vector2(x+1,-9+i),Vector2(x+5,-12+i),Vector2(x+8,-7+i)])
		_poly(c,[Vector2(x,-10+i),Vector2(x-5,-20+i*2),Vector2(x+6,-13+i)],Color("a4aa81"))
	_plate(c,[Vector2(9,-7),Vector2(19,-9),Vector2(25,-3),Vector2(23,5),Vector2(15,8),Vector2(9,2)],Color("9da389").lerp(WHITE,flash))
	_eye(c,Vector2(19,-3),2.5,signal_color)
	_limb(c,[Vector2(20,5),Vector2(29,4),Vector2(26,11)],BONE,2.0)
	_limb(c,[Vector2(14,7),Vector2(23,10),Vector2(26,7)],Color("a8b6a1"),1.5)

static func _spitter(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	var swell: float = sin(phase*0.45)*0.7
	for side: int in [-1,1]:
		_limb(c,[Vector2(side*7,5),Vector2(side*18,11),Vector2(side*21,18)],Color("72977e"),3.0)
		_limb(c,[Vector2(side*20,17),Vector2(side*25,18)],BONE,1.7)
	c.draw_circle(Vector2(-5,0),15+swell,INK,true,-1,true)
	c.draw_circle(Vector2(-6,-1),12+swell,Color("586f53").lerp(WHITE,flash),true,-1,true)
	_poly(c,[Vector2(-17,-4),Vector2(-14,-12),Vector2(-6,-17),Vector2(3,-12),Vector2(6,2),Vector2(-3,-1)],Color("96ac75").lerp(WHITE,flash))
	c.draw_arc(Vector2(-6,-1),10,PI*0.9,PI*1.7,18,Color("d2d1a0"),1.0,true)
	for i: int in range(3):
		var p: Vector2 = Vector2(-12+i*6,2+(i%2)*4)
		c.draw_circle(p,3.3,Color("243f38"),true,-1,true)
		c.draw_circle(p+Vector2(-0.3,-0.4),2.4,Color("bdc489"),true,-1,true)
	_plate(c,[Vector2(-1,-10),Vector2(10,-18),Vector2(20,-16),Vector2(26,-9),Vector2(24,-4),Vector2(12,-2),Vector2(4,5)],Color("849984").lerp(WHITE,flash),[Vector2(2,-10),Vector2(11,-16),Vector2(18,-14)])
	_poly(c,[Vector2(18,-13),Vector2(29,-11),Vector2(30,-6),Vector2(21,-3)],Color("47534b"))
	c.draw_line(Vector2(28,-9),Vector2(28,-6),signal_color,2.2,true)
	_eye(c,Vector2(13,-13),2.2,signal_color)
	for x: int in [-11,-5,1]: _poly(c,[Vector2(x,-13),Vector2(x-3,-21),Vector2(x+3,-17)],Color("bdc99b"))

static func _moth(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	var flap: float = sin(phase*1.25)*5.0
	for side: int in [-1,1]:
		var tip: Vector2 = Vector2(side*34,-18+flap)
		_plate(c,[Vector2(side*4,-5),Vector2(side*13,-18),tip,Vector2(side*30,0+flap*0.4),Vector2(side*17,8),Vector2(side*6,4)],Color("947e69").lerp(WHITE,flash),[Vector2(side*9,-7),Vector2(side*17,-15),tip-Vector2(side*4,-1)])
		_poly(c,[Vector2(side*9,-5),Vector2(side*28,-14+flap),Vector2(side*24,-1),Vector2(side*15,4)],Color("d0be8e"),false)
		_plate(c,[Vector2(side*6,1),Vector2(side*24,7-flap*0.3),Vector2(side*25,20-flap*0.4),Vector2(side*11,14),Vector2(side*3,8)],Color("5f807b"),[Vector2(side*9,5),Vector2(side*20,9)])
		c.draw_line(Vector2(side*7,-1),tip-Vector2(side*4,1),Color("6b554d"),1.0,true)
		_eye(c,Vector2(side*22,-4+flap*0.3),3.1,Color("efb578"))
		_limb(c,[Vector2(side*3,-10),Vector2(side*9,-22),Vector2(side*16,-24)],Color("c6c9a2"),1.0)
	_poly(c,[Vector2(-5,-8),Vector2(0,-13),Vector2(6,-7),Vector2(5,14),Vector2(0,23),Vector2(-5,14)],Color("425b51"))
	for i: int in range(4): c.draw_line(Vector2(-4,1+i*4),Vector2(4,1+i*4),Color("aec189"),2.0,true)
	_eye(c,Vector2(0,-7),3,signal_color)
	c.draw_circle(Vector2(0,18),3.5,Color("c9bb82"),true,-1,true)

static func _drone(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	for side: int in [-1,1]:
		var y: float = sin(phase)*2
		_limb(c,[Vector2(side*6,-1),Vector2(side*17,-5),Vector2(side*23,-9+y)],Color("6c8791"),2.0)
		_plate(c,[Vector2(side*12,-4),Vector2(side*27,-23+y),Vector2(side*33,-13+y),Vector2(side*25,3+y),Vector2(side*16,7)],Color("7398a8").lerp(WHITE,flash),[Vector2(side*17,-6),Vector2(side*27,-19+y),Vector2(side*30,-13+y)])
		_poly(c,[Vector2(side*18,-3),Vector2(side*27,-17+y),Vector2(side*25,1+y)],Color("b6d4d4"),false)
		_plate(c,[Vector2(side*12,2),Vector2(side*27,7),Vector2(side*22,16),Vector2(side*10,10)],Color("5c708d"),[Vector2(side*15,5),Vector2(side*23,8)])
		c.draw_line(Vector2(side*20,11),Vector2(side*17,16),signal_color,1.5,true)
	_plate(c,[Vector2(0,-16),Vector2(10,-7),Vector2(9,8),Vector2(0,17),Vector2(-9,8),Vector2(-10,-7)],Color("6d8490").lerp(WHITE,flash),[Vector2(-7,-6),Vector2(0,-13),Vector2(7,-6)])
	_poly(c,[Vector2(0,-10),Vector2(5,-3),Vector2(0,6),Vector2(-5,-3)],Color("cedcdb"))
	_eye(c,Vector2(0,1),4.0,signal_color)
	c.draw_line(Vector2(-3,10),Vector2(3,10),Color("384d62"),2.0,true)

static func _charger(c: Node2D, phase: float, flash: float, signal_color: Color, charging: bool) -> void:
	var crouch: float = 3.0 if charging else 0.0
	for i: int in range(3):
		var x: float = -15+i*13
		var gait: float = sin(phase+i*2.5)*2
		_limb(c,[Vector2(x,3),Vector2(x-3+gait,12),Vector2(x+2+gait,18)],Color("897563"),4.0)
		_joint(c,Vector2(x-3+gait,12),2.2,Color("b9aa83"))
	_poly(c,[Vector2(-26,3),Vector2(-23,-12+crouch),Vector2(-11,-19+crouch),Vector2(13,-15+crouch),Vector2(24,-3),Vector2(23,10),Vector2(-12,11)],Color("544b43"))
	_plate(c,[Vector2(-24,-2),Vector2(-20,-13+crouch),Vector2(-7,-18+crouch),Vector2(4,-10+crouch),Vector2(0,4),Vector2(-13,7)],Color("ac8566").lerp(WHITE,flash),[Vector2(-20,-9+crouch),Vector2(-8,-15+crouch),Vector2(0,-9+crouch)])
	_plate(c,[Vector2(0,-12+crouch),Vector2(15,-18+crouch),Vector2(28,-7+crouch),Vector2(24,8),Vector2(8,10),Vector2(0,3)],Color("c1a780").lerp(WHITE,flash),[Vector2(4,-10+crouch),Vector2(15,-15+crouch),Vector2(25,-6+crouch)])
	_poly(c,[Vector2(19,-9+crouch),Vector2(34,-16+crouch),Vector2(29,-2+crouch),Vector2(22,2)],Color("d9d8bb"))
	c.draw_line(Vector2(27,-8+crouch),Vector2(32,-13+crouch),WHITE,1.0,true)
	_eye(c,Vector2(18,-3+crouch),2.3,signal_color)
	for x: int in [-17,-12,-7]: c.draw_line(Vector2(x,-6),Vector2(x-2,2),Color("504d47"),1.7,true)

static func _burrower(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	for i: int in range(4):
		var p: Vector2 = Vector2(-9+sin(i*0.7+phase*0.4)*3,14-i*6)
		_plate(c,[p+Vector2(-12,-3),p+Vector2(7,-5),p+Vector2(12,0),p+Vector2(9,5),p+Vector2(-10,5)],Color("8b7767").lerp(WHITE,flash),[p+Vector2(-9,-2),p+Vector2(6,-4)])
		c.draw_line(p+Vector2(-6,2),p+Vector2(6,2),Color("c9ae81"),1.0,true)
	_plate(c,[Vector2(-13,-8),Vector2(-8,-18),Vector2(7,-20),Vector2(18,-11),Vector2(16,0),Vector2(3,7),Vector2(-9,2)],Color("c9a779").lerp(WHITE,flash),[Vector2(-10,-9),Vector2(-6,-16),Vector2(6,-17),Vector2(14,-10)])
	_poly(c,[Vector2(6,-18),Vector2(16,-30),Vector2(22,-7),Vector2(14,-3)],Color("b6c4c1"))
	for i: int in range(3): c.draw_line(Vector2(10+i*3,-17+i*2),Vector2(18+i,-14+i*3),Color("526878"),1.8,true)
	_eye(c,Vector2(8,-5),3,signal_color)
	for side: int in [-1,1]: _limb(c,[Vector2(side*11,5),Vector2(side*23,10),Vector2(side*24,17)],Color("c7bba0"),2.0)

static func _sentinel(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	for side: int in [-1,1]:
		_limb(c,[Vector2(side*6,4),Vector2(side*9,12),Vector2(side*12,18)],Color("66637f"),4.0)
		_plate(c,[Vector2(side*5,7),Vector2(side*11,7),Vector2(side*14,18),Vector2(side*6,18)],Color("b0a5a0"),[Vector2(side*8,9),Vector2(side*10,15)])
	_plate(c,[Vector2(-13,-18),Vector2(0,-25),Vector2(13,-18),Vector2(12,6),Vector2(0,13),Vector2(-12,6)],Color("8f8992").lerp(WHITE,flash),[Vector2(-10,-15),Vector2(0,-22),Vector2(10,-15)])
	_poly(c,[Vector2(-9,-9),Vector2(9,-9),Vector2(8,4),Vector2(0,8),Vector2(-8,4)],Color("494758"))
	_plate(c,[Vector2(-12,-17),Vector2(-15,-29),Vector2(-6,-25),Vector2(-4,-14)],Color("c4b8a5"))
	_plate(c,[Vector2(5,-17),Vector2(10,-31),Vector2(18,-20),Vector2(13,-10)],Color("c4b8a5"))
	_eye(c,Vector2(0,-13),4.2,signal_color)
	_joint(c,Vector2(13,-4),4.0,Color("777287"))
	_plate(c,[Vector2(12,-8),Vector2(22,-9),Vector2(25,-4),Vector2(23,2),Vector2(12,1)],Color("bfb4a1"),[Vector2(15,-6),Vector2(22,-6)])
	c.draw_line(Vector2(24,-6),Vector2(24,0),signal_color,1.7,true)
	c.draw_line(Vector2(-4,2),Vector2(4,2),Color("ac91c0"),1.2,true)

static func _skirmisher(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	var step: float = sin(phase)*3
	_poly(c,[Vector2(-9,-13),Vector2(-19,-8),Vector2(-25,12+step),Vector2(-11,8),Vector2(-4,14),Vector2(0,-1)],Color("4c4b6b"))
	c.draw_polyline(PackedVector2Array([Vector2(-13,-7),Vector2(-19,8),Vector2(-11,5)]),Color("9c8fa8"),1.0,true)
	for side: int in [-1,1]:
		_limb(c,[Vector2(side*4,4),Vector2(side*5+step*side,11),Vector2(side*8-step*side,19)],Color("8c8494"),3.5)
		c.draw_line(Vector2(side*8-step*side-2,19),Vector2(side*8-step*side+4,19),BONE,2.0,true)
	_plate(c,[Vector2(-9,-12),Vector2(5,-13),Vector2(10,-2),Vector2(5,9),Vector2(-5,7)],Color("9991a4").lerp(WHITE,flash),[Vector2(-6,-10),Vector2(3,-11),Vector2(7,-3)])
	_poly(c,[Vector2(-7,-20),Vector2(2,-28),Vector2(12,-21),Vector2(10,-10),Vector2(0,-8),Vector2(-9,-13)],Color("655d79").lerp(WHITE,flash))
	_poly(c,[Vector2(-2,-21),Vector2(7,-23),Vector2(11,-17),Vector2(4,-13),Vector2(-2,-15)],Color("c3bab0"))
	c.draw_line(Vector2(3,-18),Vector2(10,-18),signal_color,1.8,true)
	for side: int in [-1,1]:
		_limb(c,[Vector2(side*7,-8),Vector2(side*13,-1),Vector2(side*20,-3)],Color("a19b9f"),3.0)
		_plate(c,[Vector2(side*17,-6),Vector2(side*26,-7),Vector2(side*28,-2),Vector2(side*20,2)],Color("7b7794"))
		c.draw_line(Vector2(side*26,-5),Vector2(side*27,-2),signal_color,1.8,true)

static func _conductor(c: Node2D, phase: float, flash: float, signal_color: Color) -> void:
	var bob: float = sin(phase*0.4)*2
	for side: int in [-1,1]:
		_limb(c,[Vector2(side*8,-6),Vector2(side*21,-12+bob),Vector2(side*26,-4+bob)],Color("8b87a7"),2.0)
		_plate(c,[Vector2(side*18,-17+bob),Vector2(side*28,-16+bob),Vector2(side*29,-1+bob),Vector2(side*23,4+bob),Vector2(side*18,-4+bob)],Color("aca2ad").lerp(WHITE,flash),[Vector2(side*21,-14+bob),Vector2(side*26,-14+bob)])
		_eye(c,Vector2(side*24,-7+bob),2.0,Color("ffc07e"))
		_poly(c,[Vector2(side*6,8),Vector2(side*13,17+bob),Vector2(side*9,29+bob),Vector2(side*3,17)],Color("645d7e"))
	_plate(c,[Vector2(0,-21),Vector2(12,-10),Vector2(10,9),Vector2(0,22),Vector2(-10,9),Vector2(-12,-10)],Color("9b96aa").lerp(WHITE,flash),[Vector2(-8,-8),Vector2(0,-17),Vector2(8,-8)])
	_poly(c,[Vector2(0,-9),Vector2(6,0),Vector2(0,12),Vector2(-6,0)],Color("544861"))
	_eye(c,Vector2(0,-2),4.0,signal_color)
	c.draw_arc(Vector2(0,-16),15,PI*0.85,PI*2.15,26,INK,4.0,true)
	c.draw_arc(Vector2(0,-16),15,PI*0.85,PI*2.15,26,Color("c8b9a8"),1.8,true)
	for angle: float in [PI*1.1,PI*1.5,PI*1.9]:
		var node: Vector2 = Vector2(0,-16)+Vector2.from_angle(angle)*15
		c.draw_circle(node,2.0,signal_color,true,-1,true)

static func _boss(c: Node2D, state: Dictionary, phase: float, flash: float, signal_color: Color) -> void:
	var style: String = str(state.get("boss_style","spore"))
	var armor: Color = Color("879782") if style=="spore" else (Color("ae9274") if style=="stone" else Color("aaa0b1"))
	armor=armor.lerp(WHITE,flash)
	var shadow: Color = Color("405b50") if style=="spore" else (Color("635b56") if style=="stone" else Color("56506e"))
	for side: int in [-1,1]:
		var gait: float = sin(phase*0.55+side)*3
		_limb(c,[Vector2(side*16,11),Vector2(side*29,28),Vector2(side*36+gait,43)],shadow,12)
		_joint(c,Vector2(side*29,28),7,armor.darkened(0.15))
		_plate(c,[Vector2(side*24,30),Vector2(side*34,30),Vector2(side*44+gait,44),Vector2(side*28+gait,46)],armor,[Vector2(side*29,33),Vector2(side*37+gait,42)])
		_plate(c,[Vector2(side*17,-28),Vector2(side*41,-38),Vector2(side*56,-19),Vector2(side*53,11),Vector2(side*42,24),Vector2(side*28,9)],armor,[Vector2(side*24,-27),Vector2(side*40,-34),Vector2(side*50,-18)])
		_poly(c,[Vector2(side*35,-17),Vector2(side*49,-17),Vector2(side*47,8),Vector2(side*40,16)],shadow)
		for i: int in range(3): c.draw_line(Vector2(side*38,-11+i*7),Vector2(side*46,-11+i*7),armor.lightened(0.17),1.4,true)
		_joint(c,Vector2(side*35,-8),6,shadow)
	_plate(c,[Vector2(-26,-28),Vector2(-11,-44),Vector2(12,-44),Vector2(28,-25),Vector2(23,21),Vector2(0,32),Vector2(-23,20)],armor,[Vector2(-20,-26),Vector2(-8,-39),Vector2(9,-39),Vector2(21,-24)])
	_poly(c,[Vector2(-20,-15),Vector2(-8,-25),Vector2(8,-25),Vector2(20,-15),Vector2(15,16),Vector2(0,25),Vector2(-15,16)],shadow)
	for y: int in [8,15]: c.draw_line(Vector2(-11,y),Vector2(11,y),armor,2.0,true)
	_plate(c,[Vector2(-16,-34),Vector2(-9,-48),Vector2(9,-48),Vector2(17,-34),Vector2(10,-22),Vector2(-10,-22)],armor.lightened(0.1),[Vector2(-11,-33),Vector2(-6,-43),Vector2(6,-43),Vector2(12,-33)])
	c.draw_line(Vector2(-10,-33),Vector2(10,-33),INK,7.0,true)
	c.draw_line(Vector2(-9,-33),Vector2(9,-33),signal_color,2.7,true)
	_eye(c,Vector2(0,-4),7.5,signal_color)
	if style=="spore":
		for side: int in [-1,1]:
			_limb(c,[Vector2(side*14,-39),Vector2(side*27,-55),Vector2(side*24,-73)],Color("afb49a"),5.0)
			_limb(c,[Vector2(side*25,-53),Vector2(side*40,-63),Vector2(side*43,-69)],Color("9daa8c"),3.0)
			for i: int in range(3):
				var p: Vector2 = Vector2(side*(30+i*9),-33+i*8)
				c.draw_line(p+Vector2(0,8),p,Color("768e64"),3,true)
				_poly(c,[p+Vector2(-8,2),p+Vector2(-6,-5),p+Vector2(0,-8),p+Vector2(6,-4),p+Vector2(9,2)],Color("c4b687"))
				c.draw_circle(p+Vector2(-2,-3),1.5,Color("f2d2a2"),true,-1,true)
			c.draw_polyline(PackedVector2Array([Vector2(side*20,-8),Vector2(side*25,3),Vector2(side*17,15)]),Color("a4b978"),2.0,true)
	elif style=="stone":
		for side: int in [-1,1]:
			_plate(c,[Vector2(side*22,-31),Vector2(side*32,-68),Vector2(side*46,-49),Vector2(side*42,-21)],Color("b3c6c7"),[Vector2(side*27,-35),Vector2(side*32,-62),Vector2(side*40,-47)])
			_poly(c,[Vector2(side*32,-59),Vector2(side*40,-46),Vector2(side*37,-27)],Color("7097ae"),false)
			_plate(c,[Vector2(side*44,-6),Vector2(side*61,-10),Vector2(side*66,15),Vector2(side*48,26)],Color("bdac8c"),[Vector2(side*49,-2),Vector2(side*58,-5),Vector2(side*62,12)])
			for i: int in range(3): c.draw_line(Vector2(side*(51+i*4),4),Vector2(side*(53+i*4),18),Color("79674f"),1.8,true)
	else:
		c.draw_arc(Vector2(0,-26),45,PI*0.88,PI*2.12,60,INK,6,true)
		c.draw_arc(Vector2(0,-26),45,PI*0.88,PI*2.12,60,Color("ceb99f"),2.5,true)
		for i: int in range(5):
			var point: Vector2 = Vector2(0,-26)+Vector2.from_angle(PI*(0.92+i*0.29))*45
			_plate(c,[point+Vector2(-5,0),point+Vector2(0,-7),point+Vector2(5,0),point+Vector2(0,7)],Color("ded1b8"))
			c.draw_circle(point,1.8,signal_color,true,-1,true)
		for side: int in [-1,1]:
			_poly(c,[Vector2(side*20,-5),Vector2(side*31,10),Vector2(side*22,40),Vector2(side*9,23)],Color("746586"))
			c.draw_line(Vector2(side*23,10),Vector2(side*19,29),Color("c0a8c8"),1.2,true)
