class_name SideCombatGeometry
extends RefCounted

## Shared visual vocabulary. World units are logical display pixels; this module
## never chooses a target, advances a timer, or changes a collision shape.
const INK := Color("424e55")
const FX = preload("res://scripts/illustrated_fx.gd")
const SelectedFX = preload("res://scripts/selected_enemy_fx.gd")
const WARNING := Color("f16b78")
const CORE := Color("fff0cf")
const EDGE: float = 2.0
const BACK: float = 4.0
const DETAIL: float = 1.1
const BODY: float = 1.5
const PROFILES: Dictionary = {
	"sentinel": "crystal", "drone": "crystal", "skirmisher": "crystal", "conductor": "crystal",
	"crawler": "claw", "charger": "stone", "burrower": "stone",
	"spitter": "spore", "spore_moth": "spore",
	"boss_prism": "crystal", "boss_stone": "stone", "boss_spore": "spore",
}

static func family(enemy: Dictionary) -> String:
	var kind: String = str(enemy.get("kind", ""))
	if kind == "boss": kind += "_" + str(enemy.get("boss_style", "spore"))
	return str(PROFILES.get(kind, "stone"))

static func palette(family_name: String) -> Dictionary:
	match family_name:
		"spore": return {"base":Color("8e9b5f"),"light":Color("c7d38c"),"shade":Color("3c584e"),"attack":Color("dfbc75")}
		"claw": return {"base":Color("84926a"),"light":Color("c5c797"),"shade":Color("354b46"),"attack":Color("e2bd82")}
		"stone": return {"base":Color("a18c72"),"light":Color("d6be91"),"shade":Color("53544e"),"attack":Color("eab780")}
		_: return {"base":Color("748e99"),"light":Color("b6c9c9"),"shade":Color("344d60"),"attack":Color("f0bd80")}

static func polygon(c: CanvasItem, points: PackedVector2Array, color: Color, edge: float = BODY) -> void:
	if points.size()>2 and points[0].is_equal_approx(points[-1]): points = points.slice(0,points.size()-1)
	c.draw_colored_polygon(points, color)
	if edge > 0.0:
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		c.draw_polyline(outline, Color(INK, color.a), edge, true)

static func diamond(c: CanvasItem, center: Vector2, direction: Vector2, length: float, width: float, color: Color, edge: float = 0.0) -> void:
	# Late laser contraction and spent chips can fall below a world pixel.
	# Discard them before native triangulation loses their nonzero area.
	if length<.35 or width<.25 or color.a<.01: return
	var across: Vector2 = direction.orthogonal()
	polygon(c, PackedVector2Array([center+direction*length,center+across*width,center-direction*length,center-across*width]),color,edge)

static func capsule(start: Vector2, finish: Vector2, radius: float) -> PackedVector2Array:
	var angle: float = (finish-start).angle()
	var points := PackedVector2Array()
	for cap: Dictionary in [{"center":finish,"angle":angle-PI*.5},{"center":start,"angle":angle+PI*.5}]:
		for step: int in range(25):
			points.append(Vector2(cap.center)+Vector2.from_angle(float(cap.angle)+PI*float(step)/24.0)*radius)
	return points

static func warning_alpha(elapsed: float) -> float:
	return .68+.32*(.5+.5*cos(maxf(0.0,elapsed)*TAU*2.0))

static func dashed_boundary(points: PackedVector2Array, closed: bool = true) -> PackedVector2Array:
	var segments := PackedVector2Array()
	var traveled: float = 0.0
	for i: int in range(points.size() if closed else points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var length: float = a.distance_to(b)
		var along: float = 0.0
		while along<length-.0001:
			var phase: float = fposmod(traveled,15.0)
			var visible: bool = phase<9.0
			var advance: float = minf(length-along,(9.0 if visible else 15.0)-phase)
			if advance<.0001: advance=minf(.001,length-along)
			if visible:
				segments.append(a.lerp(b,along/length))
				segments.append(a.lerp(b,(along+advance)/length))
			along+=advance
			traveled+=advance
	return segments

static func draw_warning(c: CanvasItem, points: PackedVector2Array, alpha: float, closed: bool = true) -> void:
	var dashes: PackedVector2Array=dashed_boundary(points,closed)
	if dashes.is_empty(): return
	c.draw_multiline(dashes,Color("26383c"),BACK,true)
	c.draw_multiline(dashes,Color(WARNING,alpha),EDGE,true)

static func beam_fade(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var axis: Vector2=finish-start
	var fraction: float=clampf((point-start).dot(axis)/maxf(1.0,axis.length_squared()),0.0,1.0)
	return lerpf(1.0,.38,fraction)

static func draw_beam_band(c: CanvasItem, points: PackedVector2Array, start: Vector2, finish: Vector2, tint: Color, minimum_alpha: float = .38) -> void:
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var fade: float=beam_fade(point,start,finish)
		colors.append(Color(tint,lerpf(minimum_alpha,1.0,(fade-.38)/.62)))
	c.draw_polygon(points,colors)

static func local_direction(enemy: Dictionary) -> Vector2:
	var aim: Vector2 = enemy.get("attack_dir", Vector2.RIGHT)
	if aim.length_squared() < .001: return Vector2.RIGHT
	return Vector2(absf(aim.x),aim.y).normalized()

static func source_offset(enemy: Dictionary, direction: Vector2) -> Vector2:
	# The beam is locked at enemy.pos by authority. Its visible emitter is
	# authored at that origin, rather than shifting the locked attack forward.
	if str(enemy.get("kind", "")) == "sentinel" or (str(enemy.get("kind", ""))=="boss" and str(enemy.get("boss_style",""))=="prism"): return Vector2.ZERO
	return direction.normalized() * (float(enemy.get("radius", 19.0)) + 3.0)

static func impact_family(kind: String) -> String:
	if kind in ["beam","boss_beam","prism_beam","prism_cross","crystal","pulse","energy","triple","salvo","mend","blink"]: return "crystal"
	if kind in ["spit","spore","boss_spore_orb","spore_mortar","boss_spore","mortar","spore_volley","spore_bloom"]: return "spore"
	if kind == "pounce": return "claw"
	if kind in ["stone_spike","burrow","charge","stone_charge","stone_spikes"]: return "stone"
	return ""

static func draw_ammunition(c: CanvasItem, origin: Vector2, direction: Vector2, radius: float, organic: bool, preparing: bool = false, progress: float = 1.0) -> void:
	if organic:
		SelectedFX.draw_seed(c,origin,direction,radius)
		return
	var colors: Dictionary=palette("spore" if organic else "crystal")
	var across: Vector2=direction.orthogonal()
	# Unequal facets form a physical crystal dart, rather than a hollow
	# diamond glyph. The preparation grows the same object at the port.
	var points:=PackedVector2Array()
	for point: Vector2 in [Vector2(1.3,0),Vector2(.15,-.72),Vector2(-.9,-.36),Vector2(-1.15,.18),Vector2(-.18,.72)]:
		points.append(origin+(direction*point.x+across*point.y)*radius)
	polygon(c,points,Color("b87679"),.8)
	polygon(c,PackedVector2Array([points[0],points[1],origin-direction*radius*.6,origin+across*radius*.13]),Color("ead0b7"),0)
	polygon(c,PackedVector2Array([points[0],origin+across*radius*.13,points[4]]),Color("cd9391"),0)
	if not preparing:
		FX.shard(c,origin-direction*radius*1.5,direction.angle(),radius*.7,radius*.18,Color("d7b8ac",.6))
	if preparing:
		for side: float in [-1.0,1.0]:
			var point: Vector2=origin-direction*(radius*.4)+across*side*(radius+3.0-progress*2.0)
			FX.shard(c,point,direction.angle()-side*.4,2.0,1.0,colors.light)

static func draw_impact(c: CanvasItem, position: Vector2, family_name: String, direction: Vector2, phase: float) -> void:
	var tint: Color = palette(family_name).attack
	tint.a = 1.0-phase
	var side: Vector2 = direction.orthogonal()
	if family_name == "crystal":
		for index: int in range(3):
			var offset: Vector2 = direction*(2.0+phase*7.0+index*2.0)+side*(index-1)*4.0
			diamond(c,position+offset,direction,3.0*(1.0-phase),1.8*(1.0-phase),tint)
	elif family_name == "spore":
		for index: int in range(3):
			var offset: Vector2 = direction*(phase*8.0+index*1.5)+side*(index-1)*(3.0+phase*3.0)
			c.draw_circle(position+offset,2.7*(1.0-phase),tint,true,-1,true)
	elif family_name == "stone":
		for index: int in range(3):
			var center: Vector2=position+direction*(phase*9+index*2)+side*(index-1)*4
			var r: float=3*(1-phase)
			polygon(c,PackedVector2Array([center+Vector2(-r,-r*.5),center+Vector2(r*.4,-r),center+Vector2(r,r*.7),center+Vector2(-r*.6,r)]),tint,0)
	else:
		for index: int in range(2):
			var center: Vector2 = position+side*(index*4.0-2.0)
			FX.ribbon(c,center,6.0+phase*6.0,direction.angle()-1.0,direction.angle()+.45,3.0*(1.0-phase),tint)

static func draw_ground_charge(c: CanvasItem, center: Vector2, width: float, progress: float) -> void:
	var colors: Dictionary=palette("stone")
	for i: int in range(3):
		var point:=center+Vector2((i-1)*width*.24,-1-progress*2)
		polygon(c,PackedVector2Array([point+Vector2(-4,2),point+Vector2(-2,-3-progress*2),point+Vector2(3,-2),point+Vector2(5,2)]),colors.base,1)

static func draw_rift(c: CanvasItem, center: Vector2, height: float, progress: float, ending: bool = false) -> void:
	var amount: float=1.0-progress if ending else .5+.5*progress
	if amount<.025: return
	for side: float in [-1.0,1.0]:
		var ribbon:=PackedVector2Array()
		for j: int in range(17):
			var t: float=j/16.0
			ribbon.append(center+Vector2(side*sin(PI*t)*height*.17*amount,(t-.5)*height))
		for j: int in range(16,-1,-1):
			var t: float=j/16.0
			ribbon.append(center+Vector2(side*sin(PI*t)*height*.08*amount,(t-.5)*height))
		polygon(c,ribbon,Color("aabec9",amount),0)
		FX.shard(c,center+Vector2(side*height*.1,-height*.22),-PI*.5,height*.16*amount,height*.025,Color("e2d8c1",amount))

static func draw_area_material(c: CanvasItem, center: Vector2, sample: Dictionary) -> void:
	var organic: bool=str(sample.family).begins_with("spore")
	var active: bool=bool(sample.active)
	var radius: float=float(sample.radius)
	var colors: Dictionary=palette("spore" if organic else "stone")
	var phase: float=float(sample.phase)
	if not active:
		if organic:
			var seed: float=Vector2(sample.size).x*.38
			draw_ammunition(c,center,Vector2.UP,seed,true,true,phase)
		else: draw_ground_charge(c,center+Vector2(0,13),minf(radius,48),phase)
		return
	# Only active authority owns the complete filled footprint. No textured
	# cloud and no warning/dashed perimeter is rendered during damage.
	var disk:=PackedVector2Array()
	for i: int in range(48): disk.append(center+Vector2.from_angle(i*TAU/48.0)*radius)
	c.draw_colored_polygon(disk,Color(colors.base,.18) if organic else Color(colors.attack,.22))
	if organic:
		# Two split fleshy pod walls flare outward as one burst, rather than
		# four isolated circular decorations. Stretched seeds carry its motion.
		var open: float=smoothstep(0.0,.55,phase)
		for side: float in [-1.0,1.0]:
			var petal:=PackedVector2Array()
			var shift: Vector2=Vector2(side*radius*(.10+.15*open),-radius*.05)
			for j: int in range(25):
				var t: float=j/24.0
				petal.append(center+shift+Vector2(side*sin(PI*t)*radius*.48,(t-.5)*radius*1.25))
			for j: int in range(24,-1,-1):
				var t: float=j/24.0
				petal.append(center+shift+Vector2(side*sin(PI*t)*radius*.24,(t-.5)*radius*1.25))
			polygon(c,petal,colors.base,0)
			var rib:=PackedVector2Array()
			for j: int in range(15):
				var t: float=.15+j/14.0*.6
				rib.append(center+shift+Vector2(side*sin(PI*t)*radius*.41,(t-.5)*radius*1.25))
			c.draw_polyline(rib,colors.light,2.0,true)
		for i: int in range(5):
			var angle: float=-2.8+i*1.25
			var ray: Vector2=Vector2.from_angle(angle)
			var travel: float=radius*(.35+open*.3)
			draw_ammunition(c,center+ray*travel,ray,maxf(3,radius*(.075 if i%2==0 else .05)),true)

	else:
		# Ground-launched uneven shards: tall top facets and small underground
		# roots stay within the real circular footprint, without a star emblem.
		for i: int in range(4):
			var x: float=radius*(-.66+i*.43)
			var half_width: float=radius*.13
			var safe_y: float=sqrt(maxf(0,radius*radius-pow(absf(x)+half_width,2)))*.92
			var base: float=minf(17.0,safe_y)
			var tip:=center+Vector2(x+half_width*.25,-safe_y*(.7 if i%2==0 else 1.0)*lerpf(.82,1.0,smoothstep(0,.18,phase)))
			var left:=center+Vector2(x-half_width,base)
			var right:=center+Vector2(x+half_width,base)
			polygon(c,PackedVector2Array([left,tip+Vector2(-half_width*.3,half_width*.8),tip,tip+Vector2(half_width*.45,half_width*1.15),right,center+Vector2(x,minf(safe_y,base+radius*.2))]),colors.base,1)
			polygon(c,PackedVector2Array([center+Vector2(x,base),tip,right]),colors.light,0)

			var ridge: Vector2=tip.lerp(center+Vector2(x,base),.5)
			c.draw_line(ridge,center+Vector2(x+half_width*.4,base-2),colors.shade,1.0,true)
		for i: int in range(3):
			var rock:=center+Vector2((i-1)*radius*.35,minf(12,radius*.25))
			var width: float=radius*.10
			polygon(c,PackedVector2Array([rock+Vector2(-width,3),rock+Vector2(-width*.5,-4),rock+Vector2(width*.6,-2),rock+Vector2(width,4)]),colors.base,1)
