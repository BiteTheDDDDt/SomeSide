class_name SideCombatGeometry
extends RefCounted

## Shared visual vocabulary. World units are logical display pixels; this module
## never chooses a target, advances a timer, or changes a collision shape.
const INK := Color("091e26")
const WARNING := Color("fb716d")
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

static func dashed_boundary(points: PackedVector2Array) -> PackedVector2Array:
	var segments := PackedVector2Array()
	var traveled: float = 0.0
	for i: int in range(points.size()):
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

static func draw_warning(c: CanvasItem, points: PackedVector2Array, alpha: float) -> void:
	var border: PackedVector2Array=points.duplicate()
	border.append(points[0])
	c.draw_polyline(border,INK,BACK,true)
	# The restrained dark-red under-line persists between bright dashes and
	# pulses. Timing never creates an invisible warning frame.
	c.draw_polyline(border,Color("8d484c"),1.0,true)
	c.draw_multiline(dashed_boundary(points),Color(WARNING,alpha),EDGE,true)

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
	var colors: Dictionary = palette("spore" if organic else "crystal")
	var across: Vector2 = direction.orthogonal()
	if organic:
		var points := PackedVector2Array()
		for index: int in range(12):
			var angle: float = TAU*index/12.0
			points.append(origin+direction*cos(angle)*radius+across*sin(angle)*radius*.85)
		polygon(c,points,colors.base,BODY)
		c.draw_arc(origin,radius*.6,direction.angle()-2.5,direction.angle()-.7,8,colors.light,1.5,true)
		if not preparing:
			c.draw_line(origin-direction*(radius+2),origin-direction*(radius+5),colors.attack,1.5,true)
	else:
		diamond(c,origin,direction,radius*1.3,radius*.85,colors.attack,BODY)
		diamond(c,origin-direction*radius*.12-across*radius*.12,direction,radius*.55,radius*.25,CORE)
	if preparing:
		# Inward gathering only beside the organ; no hypothetical trajectory.
		for side: float in [-1.0,1.0]:
			var near: Vector2 = origin-direction*3+across*side*(radius+2.0)
			var far: Vector2 = near-direction*(3.0-progress*2.0)+across*side*2.0
			c.draw_line(far,near,colors.attack,DETAIL,true)

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
			c.draw_arc(center,5.0+phase*5.0,direction.angle()-.65,direction.angle()+.35,8,tint,1.8*(1.0-phase),true)

static func draw_ground_charge(c: CanvasItem, center: Vector2, width: float, progress: float) -> void:
	var colors: Dictionary=palette("stone")
	for i: int in range(3):
		var point:=center+Vector2((i-1)*width*.24,-1-progress*2)
		polygon(c,PackedVector2Array([point+Vector2(-4,2),point+Vector2(-2,-3-progress*2),point+Vector2(3,-2),point+Vector2(5,2)]),colors.base,1)

static func draw_rift(c: CanvasItem, center: Vector2, height: float, progress: float, ending: bool = false) -> void:
	var colors: Dictionary=palette("crystal")
	var alpha: float=1.0-progress if ending else .7
	for side: float in [-1.0,1.0]:
		var x: float=side*(3+progress*4)
		var points:=PackedVector2Array([center+Vector2(x, -height*.45),center+Vector2(x+side*4,-height*.1),center+Vector2(x, height*.15)])
		c.draw_polyline(points,Color(colors.attack,alpha),2,true)
		if not ending: diamond(c,center+Vector2(x,height*.34),Vector2.UP,4,2,colors.light)

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
			# A closed capsule and small seam, never a filled danger region.
			c.draw_line(center-Vector2(0,seed*.6),center+Vector2(0,seed*.6),INK,1.5,true)
		else: draw_ground_charge(c,center+Vector2(0,13),minf(radius,48),phase)
		return
	# Only active authority owns the complete filled footprint. No textured
	# cloud and no warning/dashed perimeter is rendered during damage.
	var disk:=PackedVector2Array()
	for i: int in range(48): disk.append(center+Vector2.from_angle(i*TAU/48.0)*radius)
	c.draw_colored_polygon(disk,Color(colors.attack,.22))
	if organic:
		# Split seed walls open into broad curved ribbons, with a few expelled
		# beads. Unequal arcs avoid a radial emblem / concentric target look.
		for i: int in range(3):
			var angle: float=-2.4+i*2.1
			var extent: float=radius*(.45+i*.14+.08*phase)
			var arc:=PackedVector2Array()
			for j: int in range(9): arc.append(center+Vector2.from_angle(angle+j*.95/8)*extent)
			for j: int in range(8,-1,-1): arc.append(center+Vector2.from_angle(angle+j*.95/8)*(extent-radius*.15))
			polygon(c,arc,colors.base,1)
			c.draw_arc(center,extent-radius*.035,angle+.1,angle+.68,9,colors.light,1.8,true)
			var ray:=Vector2.from_angle(angle+.4)
			draw_ammunition(c,center+ray*radius*(.45+.12*phase),ray,maxf(3,radius*.095),true)
		for side: float in [-1.0,1.0]:
			var shell:=PackedVector2Array()
			var offset:=center+Vector2(side*radius*(.10+.08*phase),-radius*.06)
			for j: int in range(8): shell.append(offset+Vector2.from_angle(-PI*.5+side*j*PI/7)*radius*.26)
			polygon(c,shell,colors.light,1)
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
			polygon(c,PackedVector2Array([left,tip,right,center+Vector2(x,minf(safe_y,base+radius*.2))]),colors.base,1)
			polygon(c,PackedVector2Array([center+Vector2(x,base),tip,right]),colors.light,0)

			var ridge: Vector2=tip.lerp(center+Vector2(x,base),.5)
			c.draw_line(ridge,center+Vector2(x+half_width*.4,base-2),colors.shade,1.0,true)
		for i: int in range(3):
			var rock:=center+Vector2((i-1)*radius*.35,minf(12,radius*.25))
			var width: float=radius*.10
			polygon(c,PackedVector2Array([rock+Vector2(-width,3),rock+Vector2(-width*.5,-4),rock+Vector2(width*.6,-2),rock+Vector2(width,4)]),colors.base,1)
