class_name SideProjectileRenderer
extends RefCounted

## A white, tapered core identifies friendly fire. Hostile ammunition uses a
## closed warm shell around a dark centre, so allegiance also reads in shape.
const Atlas = preload("res://scripts/sprite_atlas.gd")
const AttackFx = preload("res://scripts/attack_fx_sprites.gd")
const CACHE_META: StringName = &"someside_projectile_atlas"
const CACHE_MAX_BYTES: int = 4 * 1024 * 1024
const ORB_FRAMES: int = 16
const INK: Color = Color("101b23")
const CORE: Color = Color("f4f7df")
const HOT: Color = Color("ffb180")

static func prepare(canvas: Node2D) -> void:
	AttackFx.prepare()
	if DisplayServer.get_name() == "headless" or canvas.has_meta(CACHE_META):
		return
	Atlas.prepare(canvas, CACHE_META, atlas_entries(), _paint_atlas_entry, CACHE_MAX_BYTES, 1024)

static func cache_info(canvas: Node2D) -> Dictionary:
	return Atlas.stats(canvas, CACHE_META)

static func atlas_entries() -> Array:
	var entries: Array = []
	for kind: String in ["spit", "crystal", "energy", "boss_spore_orb"]:
		for radius: int in range(4, 13):
			var left: float = minf(-radius * 1.8 - 4, -radius - 11)
			var bounds := Rect2(left, -radius - 7, radius + 7 - left, radius * 2 + 14)
			for frame: int in range(ORB_FRAMES if kind == "boss_spore_orb" else 1):
				entries.append({"key": "enemy/%s/%d/%d" % [kind, radius, frame], "bounds": bounds, "data": {"kind": kind, "radius": radius, "clock": float(frame) / ORB_FRAMES * TAU / 1.3}})
	return entries

static func _paint_atlas_entry(canvas: Node2D, data: Dictionary) -> void:
	_enemy_vector(canvas, str(data.kind), float(data.radius), float(data.clock))

static func draw(c: Node2D, shot: Dictionary, position: Vector2, clock: float, strength: float, tail: float) -> void:
	var velocity: Vector2 = shot.get("vel",Vector2.RIGHT)
	var angle: float = velocity.angle()
	var radius: float = maxf(2.0,float(shot.get("radius",3.0)))
	var kind: String = str(shot.get("kind","bullet"))
	c.draw_set_transform(position,angle)
	if str(shot.get("team","player")) == "player":
		_friendly(c,kind,radius,clampf(strength,0.5,3.3),maxf(0.0,tail),clock,float(shot.get("id",0)))
	else:
		_enemy(c,kind,radius,maxf(0.0,float(shot.get("age",0.0))))
	if bool(Dictionary(shot.get("guidance", {})).get("active", false)):
		# Small forward fins identify the guided ammunition without another
		# atlas, target line or bright halo obscuring its dodgeable trajectory.
		var tint: Color = Color("b8f0ff") if str(shot.get("team", "player")) == "player" else Color("ffcb8b")
		for side: int in [-1, 1]:
			c.draw_line(Vector2(-radius - 3, side * (radius + 2)), Vector2(1, side * (radius + 1)), Color(tint, 0.75), 1.0, true)
	c.draw_set_transform(Vector2.ZERO)

static func _poly(c: Node2D, points: Array, fill: Color, outline: float = 0.0, outline_color: Color = INK) -> void:
	var shape: PackedVector2Array = PackedVector2Array(points)
	c.draw_colored_polygon(shape,fill)
	if outline>0:
		shape.append(shape[0])
		c.draw_polyline(shape,outline_color,outline,true)

static func _taper(c: Node2D, tail: float, width: float, tint: Color) -> void:
	if tail <= 0.01: return
	_poly(c,[Vector2(-tail,0),Vector2(-tail*0.4,-width),Vector2(0,-width*0.6),Vector2(0,width*0.6),Vector2(-tail*0.4,width)],Color(tint,0.13))
	c.draw_line(Vector2(-tail*0.72,0),Vector2.ZERO,Color(tint,0.76),1.0,true)
	c.draw_line(Vector2(-tail*0.28,0),Vector2.ZERO,CORE,1.0,true)

static func _friendly(c: Node2D, kind: String, radius: float, strength: float, tail: float, clock: float, id: float) -> void:
	var tint: Color = Color("8ff0d8")
	if kind=="pellet": tint=Color("edcc97")
	elif kind=="rail": tint=Color("a9daff")
	elif kind=="lance": tint=Color("ffe0a0")
	elif kind=="storm": tint=Color("a1eaff")
	if kind=="grenade":
		var spin: float = clock*6.0
		var points: Array=[]
		for i: int in range(6): points.append(Vector2.from_angle(spin+i*TAU/6.0)*(radius+1))
		_poly(c,points,Color("748c7e"),1.5)
		c.draw_arc(Vector2.ZERO,radius-1.5,spin,spin+PI*1.1,14,Color("bdcdb0"),1.2,true)
		c.draw_circle(Vector2.ZERO,2.0,Color("203e42"),true,-1,true)
		c.draw_circle(Vector2(1,-1),1.0,CORE,true,-1,true)
		c.draw_line(Vector2(-2,-radius),Vector2(3,-radius-1),Color("b1c39d"),1.7,true)
		return
	if kind=="boomerang":
		_taper(c,minf(tail,32.0),2.0,tint)
		var spin: float = clock*15.0+id
		for side: int in [-1,1]:
			var a: Vector2 = Vector2(-9,side*13).rotated(spin)
			var b: Vector2 = Vector2(8,0).rotated(spin)
			var d: Vector2 = Vector2(-3,side*4).rotated(spin)
			_poly(c,[a,b,d],Color("8de2d1"),1.5)
			c.draw_line(a,b,CORE,1.0,true)
		c.draw_circle(Vector2.ZERO,2,Color("436b78"),true,-1,true)
		return
	if kind=="storm":
		_taper(c,minf(tail,38.0),3.0,tint)
		var points: Array=[]
		for i: int in range(8): points.append(Vector2.from_angle(i*PI*0.25+clock*2.0)*(radius if i%2==0 else radius*0.46))
		_poly(c,points,Color("a5dcf4"),1.0)
		_poly(c,[Vector2(-3,0),Vector2(0,-5),Vector2(5,0),Vector2(0,5)],CORE)
		for side: int in [-1,1]:
			c.draw_polyline(PackedVector2Array([Vector2(-5,side*4),Vector2(-9,side*7),Vector2(-7,side*10)]),Color(tint,0.65),0.9,true)
		return
	if kind=="lance":
		_taper(c,minf(tail,78.0),3.2,tint)
		var rear: float = minf(11.0,tail)
		_poly(c,[Vector2(12,0),Vector2(-rear,-3.5),Vector2(-rear*0.5,0),Vector2(-rear,3.5)],tint)
		c.draw_line(Vector2(-minf(tail,32.0),0),Vector2(10,0),CORE,1.4,true)
		if strength>=1.7:
			for side: int in [-1,1]: c.draw_line(Vector2(-minf(tail,28.0),side*3.5),Vector2(-minf(tail,6.0),side*2),Color(tint,0.55),0.8,true)
		return
	var maximum: float = 92.0 if kind=="rail" else (22.0 if kind=="pellet" else 35.0)
	var length: float = minf(tail,maximum)
	_taper(c,length,2.3 if kind=="rail" else 1.7,tint)
	var core_tail: float = minf(length,14.0 if kind=="rail" else 6.0)
	_poly(c,[Vector2(3,0),Vector2(0,-1.5),Vector2(-core_tail,-0.8),Vector2(-core_tail,0.8),Vector2(0,1.5)],CORE)
	if kind=="rail":
		for side: int in [-1,1]:
			c.draw_line(Vector2(-length*0.9,side*2.5),Vector2(-length*0.1,side*1.5),Color(tint,0.45),0.8,true)
	elif strength>=1.7:
		c.draw_line(Vector2(-length*0.8,-3),Vector2(-length*0.2,-2),Color(tint,0.45),0.8,true)

static func _enemy(c: Node2D, kind: String, radius: float, clock: float) -> void:
	var r: float = maxf(4.0, radius)
	var organic: bool = kind in ["spit","spore","acid","poison","boss_spore_orb","boss_orb"]
	var sprite_family: String = "burst" if organic else "charge"
	var phase: float = .25 + fposmod(clock*1.8,1.0)*.35 if organic else .5 + fposmod(clock*2.0,1.0)*.49
	var size_value: Vector2 = Vector2(r*3.2,r*3.0)
	if AttackFx.draw_oriented(c,sprite_family,Vector2.ZERO,size_value,0.0,phase,Color(1.0,.88,.74)):
		return
	var cached: Dictionary = Atlas.cache(c, CACHE_META)
	if not cached.is_empty() and is_equal_approx(r, roundf(r)) and r >= 4.0 and r <= 12.0:
		var family: String = "energy"
		if kind in ["spit", "spore", "acid", "poison"]: family = "spit"
		elif kind in ["crystal", "pulse"]: family = "crystal"
		elif kind in ["boss_spore_orb", "boss_orb"]: family = "boss_spore_orb"
		var frame: int = int(floor(fposmod(clock * 1.3, TAU) / TAU * ORB_FRAMES)) if family == "boss_spore_orb" else 0
		if Atlas.draw_region(c, cached, "enemy/%s/%d/%d" % [family, int(r), frame]):
			return
	_enemy_vector(c, kind, radius, clock)

static func _enemy_vector(c: Node2D, kind: String, radius: float, clock: float) -> void:
	var r: float = maxf(4.0,radius)
	if kind in ["spit","spore","acid","poison"]:
		_poly(c,[Vector2(r+2,0),Vector2(r*0.25,-r),Vector2(-r,-r*0.45),Vector2(-r*1.8,0),Vector2(-r,r*0.5),Vector2(r*0.2,r)],Color("ba8e61"),1.4)
		c.draw_arc(Vector2.ZERO,r*0.8,PI*1.05,PI*1.85,14,Color("ffd38d"),1.3,true)
		c.draw_circle(Vector2(0.5,0),r*0.45,Color("465a3e"),true,-1,true)
		c.draw_circle(Vector2(r*0.3,-r*0.3),1.3,Color("f4dfa3"),true,-1,true)
		c.draw_circle(Vector2(-r*1.6,r*0.4),1.1,HOT,true,-1,true)
	elif kind in ["crystal","pulse"]:
		var points: Array = [Vector2(r+4,0),Vector2(0,-r),Vector2(-r-3,0),Vector2(0,r)]
		_poly(c,points,Color("bd775e"),1.8)
		_poly(c,[Vector2(r+2,0),Vector2(0,-r+1),Vector2(0,0)],Color("ffbf88"))
		_poly(c,[Vector2(r*0.55,0),Vector2(0,-r*0.45),Vector2(-r*0.55,0),Vector2(0,r*0.45)],Color("532e37"))
		c.draw_line(Vector2(-r-5,-2),Vector2(-r-9,-2),Color("c88273"),1.2,true)
	elif kind in ["boss_spore_orb","boss_orb"]:
		for i: int in range(7):
			var arm: Vector2 = Vector2.from_angle(i*TAU/7.0+clock*1.3)
			_poly(c,[arm*r*0.75+arm.orthogonal()*2,arm*(r+4),arm*r*0.75-arm.orthogonal()*2],Color("d59264"),1.0)
		c.draw_circle(Vector2.ZERO,r,INK,true,-1,true)
		c.draw_circle(Vector2.ZERO,r-1.5,Color("e5a474"),true,-1,true)
		c.draw_circle(Vector2.ZERO,r*0.58,Color("4b3339"),true,-1,true)
		c.draw_arc(Vector2.ZERO,r-2,PI,PI*1.75,16,Color("ffe4aa"),1.0,true)
		c.draw_line(Vector2(-2,0),Vector2(2,0),Color("f79473"),1.4,true)
	else:
		var points: Array=[]
		for i: int in range(6): points.append(Vector2.from_angle(i*TAU/6.0)*(r+1))
		_poly(c,points,Color("bd715f"),1.5)
		c.draw_arc(Vector2.ZERO,r-0.5,PI*0.9,PI*1.9,16,Color("ffd4a5"),1.2,true)
		c.draw_circle(Vector2.ZERO,r*0.57,Color("512e40"),true,-1,true)
		c.draw_line(Vector2(0,-r*0.3),Vector2(0,r*0.3),Color("ff9b80"),1.2,true)
		for side: int in [-1,1]: c.draw_line(Vector2(-r-2,side*2),Vector2(-r-6,side*3),Color("bc7466"),0.9,true)
