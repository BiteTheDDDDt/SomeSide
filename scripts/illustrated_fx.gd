class_name SideIllustratedFX
extends RefCounted

## Hard-edged energy and material fragments. All inputs are presentation samples;
## no timers, hit tests, targets, RNG or canvas transforms are changed here.
const Clips=preload("res://scripts/motion_clips_24.gd")
const CORE:=Color("eee7c7")
const JADE:=Color("94cabb")
const ICE:=Color("a9c9d7")
const GOLD:=Color("d9b785")
const SHADOW:=Color("49595d")

static func motion(family: String,p: float,loop: bool=false) -> Dictionary:
	return Clips.sample("effect/"+family,p,func(t: float):
		var push: float=Clips.curve([[0,.84],[.10,1.08],[.28,1.0],[.62,.94],[1,.72]],t)
		var drift: float=Clips.curve([[0,0],[.18,.16],[.55,.62],[1,1]],t)
		return {"progress":t,"push":push,"drift":drift,"pulse":sin(TAU*t)},loop)

static func polygon(c: CanvasItem,origin: Vector2,angle: float,points: Array,color: Color) -> void:
	var shape:=PackedVector2Array()
	for point: Vector2 in points: shape.append(origin+point.rotated(angle))
	if shape.size()>3 and shape[0].is_equal_approx(shape[-1]): shape.remove_at(shape.size()-1)
	c.draw_colored_polygon(shape,color)

static func ribbon(c: CanvasItem,origin: Vector2,radius: float,start: float,finish: float,width: float,color: Color) -> void:
	if radius<.1 or width<.03 or color.a<=.001 or absf(finish-start)<.001: return
	var points:=PackedVector2Array()
	for i: int in range(25):
		var t: float=i/24.0
		var taper: float=pow(maxf(0,sin(PI*t)),.7)
		points.append(origin+Vector2.from_angle(lerpf(start,finish,t))*(radius+width*taper*.5))
	for i: int in range(23,0,-1):
		var t: float=i/24.0
		var taper: float=pow(maxf(0,sin(PI*t)),.7)
		points.append(origin+Vector2.from_angle(lerpf(start,finish,t))*(radius-width*taper*.5))
	c.draw_colored_polygon(points,color)

static func shard(c: CanvasItem,p: Vector2,angle: float,length: float,width: float,color: Color) -> void:
	# Subpixel chips have already visually vanished. Drop them before the
	# renderer's world-coordinate triangulation loses their area to rounding.
	if length<.6 or width<.2 or color.a<.015: return
	polygon(c,p,angle,[Vector2(-length,0),Vector2(-length*.2,-width),Vector2(length*.45,0),Vector2(-length*.1,width*.55)],color)

static func muzzle_shape(length: float) -> Array:
	# All longitudinal points contract together. Fixed 5/7px shoulders
	# crossed a short, weak muzzle tip near expiry, creating a bow-tie.
	return [Vector2.ZERO,Vector2(length*.25,-2.5),Vector2(length*.5,-1.5),Vector2(length,0),Vector2(length*.35,2),Vector2(length*.15,3)]

static func muzzle(c: CanvasItem,p: Vector2,angle: float,weapon: String,t: float,strength: float) -> void:
	if t>=1: return
	var alpha: float=1.0-smoothstep(.12,1,t)
	var frame: Dictionary=motion("muzzle/"+weapon,t)
	var length: float=float(frame.push)*(13+clampf(strength,0.5,3.3)*6)*(1-.55*t)
	var tint: Color=Color(JADE,alpha)
	match weapon:
		"arc_needle":
			shard(c,p+Vector2(length*.15,0).rotated(angle),angle,length*.27,.8,Color(JADE,alpha))
		"star_seeker":
			for side: int in [-1,1]: shard(c,p+Vector2(length*.2,side*2).rotated(angle),angle,length*.34,1.3,Color(ICE,alpha))
		"scattergun":
			for side: int in [-1,0,1]:
				shard(c,p+Vector2(length*.38,0).rotated(angle+side*.36),angle+side*.36,length*(.62 if side==0 else .4),2.8,Color(GOLD,alpha))
		"railgun", "rail":
			polygon(c,p,angle,[Vector2.ZERO,Vector2(length*1.55,-1),Vector2(length*.45,2),Vector2.ZERO],Color(ICE,alpha))
			ribbon(c,p,7,angle-1.1,angle+1.1,2,Color(ICE,alpha*.75))
		"storm_staff", "storm":
			polygon(c,p,angle,[Vector2.ZERO,Vector2(length*.3,-3),Vector2(length*.6,-1),Vector2(length,-3),Vector2(length*.66,3),Vector2(length*.3,1)],Color(ICE,alpha))
		"sun_lance", "lance":
			shard(c,p+Vector2(length*.4,0).rotated(angle),angle,length,2.3,Color(GOLD,alpha))
		"boomerang":
			ribbon(c,p,11,angle-1.1+t,angle+1.1+t,3,Color(JADE,alpha))
		_:
			polygon(c,p,angle,muzzle_shape(length),tint)
	shard(c,p+Vector2(length*.24,0).rotated(angle),angle,length*.28,.9,Color(CORE,alpha))

static func impact(c: CanvasItem,p: Vector2,angle: float,t: float,strength: float,crit: bool=false) -> void:
	if t>=1: return
	var frame: Dictionary=motion("impact",t)
	var spread: float=(5+strength*3)*(1+float(frame.drift)*1.3)
	var color:=Color(GOLD if crit else JADE,1-t)
	shard(c,p+Vector2(spread*.2,0).rotated(angle),angle,8*(1-t)+1,3*(1-t)+.3,color)
	for i: int in range(3 if crit else 2):
		var a: float=angle+[-.85,.55,1.55][i]
		shard(c,p+Vector2.from_angle(a)*spread,a,4*(1-t)+.3,1.3*(1-t)+.15,color)
	if t<.28: shard(c,p,angle,3,1.7,Color(CORE,1-t))

static func blast(c: CanvasItem,p: Vector2,radius: float,t: float,color: Color,strength: float=1.0) -> void:
	if t>=1: return
	var frame: Dictionary=motion("blast",t)
	var r: float=maxf(.2,radius*(.15+.75*(1-pow(1-t,3))))*float(frame.push)
	var alpha: float=1-smoothstep(.12,1,t)
	for i: int in range(3):
		var a: float=i*2.1+.25
		ribbon(c,p,r*(1-i*.13),a,a+1.15-i*.12,(5+strength*2)*(1-t),Color(color,alpha*.8))
		shard(c,p+Vector2.from_angle(a+.7)*r*.75,a+.7,7*(1-t),3*(1-t),Color(CORE,alpha*.65))
	if t<.22: shard(c,p,-.6,13*(1-t/.22)+.1,6*(1-t/.22)+.1,Color(CORE,.8*(1-t/.22)))

static func flame(c: CanvasItem,p: Vector2,angle: float,reach: float,t: float,strength: float) -> void:
	if t>=1: return
	var frame: Dictionary=motion("flame",t)
	reach*=float(frame.push)
	for i: int in range(3):
		var side: float=i-1
		var tip: float=reach*(.78+(.2 if i==1 else .06))* (1-.12*t)
		var y: float=side*reach*.17
		polygon(c,p,angle,[Vector2(0,side),Vector2(tip*.32,y*.25-3),Vector2(tip*.68,y*.65-4),Vector2(tip,y),Vector2(tip*.59,y*.72+3),Vector2(tip*.24,y*.18+2)],Color(GOLD if i!=1 else CORE,(.85-t*.65)))

static func shield(c: CanvasItem,p: Vector2,radius: float,phase: float,color: Color,alpha: float) -> void:
	var frame: Dictionary=motion("shield",phase/TAU,true)
	radius+=float(frame.pulse)*.25
	for i: int in range(3):
		var a: float=i*TAU/3+phase
		ribbon(c,p,radius,a,a+1.55,4.0,Color(color,alpha))
		ribbon(c,p,radius+1,a+.12,a+.75,1.1,Color(CORE,alpha*.8))

static func proc(c: CanvasItem,family: String,p: Vector2,size: Vector2,angle: float,phase: float,alpha: float) -> bool:
	if size.x<=0 or size.y<=0 or alpha<=0: return false
	var frame: Dictionary=motion("proc/"+family,phase)
	phase=float(frame.progress)
	match family:
		"missile":
			# A physical olive-grey casing remains readable through the exhaust.
			var s: float=size.x/52.0
			polygon(c,p,angle,[Vector2(-11,-4)*s,Vector2(7,-4)*s,Vector2(15,0)*s,Vector2(7,4)*s,Vector2(-11,4)*s,Vector2(-7,0)*s],Color(SHADOW,alpha))
			polygon(c,p,angle,[Vector2(-7,-3)*s,Vector2(7,-3)*s,Vector2(15,0)*s,Vector2(-8,0)*s],Color(ICE,alpha))
			shard(c,p+Vector2(-13,0).rotated(angle)*s,angle+PI,(8+phase*5)*s,2*s,Color(GOLD,alpha))
		"wave":
			var r: float=size.y*.43*float(frame.push)
			ribbon(c,p,r,angle-1.2,angle+1.2,7,Color(ICE,alpha))
			ribbon(c,p,r+2,angle-.9,angle+.75,1.5,Color(CORE,alpha))
		"aura":
			var r: float=size.x*.5
			for i: int in range(3):
				var a: float=i*TAU/3+phase*.22
				ribbon(c,p,r-2,a,a+1.45,4,Color(ICE,alpha))
				shard(c,p+Vector2.from_angle(a+.9)*(r-7),a+.9,5,2,Color(CORE,alpha))
		"charge":
			for i: int in range(3):
				var a: float=i*2.1-.4
				var r: float=size.x*.35*(1-phase)
				shard(c,p+Vector2.from_angle(a)*r,a+PI,4*(1-phase)+.2,1.8,Color(JADE,alpha))
		_: return false
	return true

static func effect(c: CanvasItem,data: Dictionary,p: Vector2,angle: float,t: float,strength: float,color: Color,from: Vector2) -> bool:
	var kind: String=str(data.get("kind",""))
	var frame: Dictionary=motion(kind,t)
	t=float(frame.progress)
	var radius: float=float(data.get("radius",90))
	match kind:
		"muzzle": muzzle(c,p,angle,str(data.get("style",data.get("weapon","pulse_rifle"))),t,strength)
		"impact": impact(c,p,angle,t,strength,bool(data.get("crit",false)))
		"blast", "guard_release": blast(c,p,radius,t,GOLD if kind=="guard_release" else color,strength)
		"flame": flame(c,p,angle,maxf(20,radius-46),t,strength)
		"gravity":
			for i: int in range(3):
				var a: float=i*2.1+float(frame.drift)*1.7
				ribbon(c,p,radius*(.8-t*.6),a,a+1.2,4*(1-t)+.1,Color(ICE,.8*(1-t)))
			shard(c,p,t,6*(1-t),3*(1-t),Color(CORE,1-t))
		"meteor":
			var a: float=Vector2(90,220).angle()
			shard(c,p,a,90*(1-t)*float(frame.push)+1,5*(1-t)+.2,Color(GOLD,1-t))
			shard(c,p,a,24*(1-t)+1,3*(1-t)+.1,Color(CORE,1-t))
		"shatter":
			for i: int in range(4):
				var a: float=i*2.4+.2
				shard(c,p+Vector2.from_angle(a)*radius*(.25+float(frame.drift)*.6),a,5*(1-t)+.1,2*(1-t)+.1,Color(color,1-t))
		"dash":
			for i: int in range(2):
				var offset:=Vector2(-15,(-1 if i==0 else 1)*8).rotated(angle)
				shard(c,p+offset,angle,30*(1-t)*float(frame.push)+1,2.2*(1-t)+.1,Color(JADE,.75*(1-t)))
		"rush", "rush_hit":
			ribbon(c,p,12+float(frame.drift)*25,angle-1.1,angle+1.1,5*(1-t)+.1,Color(GOLD,1-t))
		"heal":
			for i: int in range(5):
				var a: float=i*2.4
				var at: Vector2=p+Vector2.from_angle(a)*radius*.55+Vector2(0,-float(frame.drift)*20)
				shard(c,at,-PI*.5,5,2.5,Color(JADE,1-t))
		"arc":
			var delta: Vector2=p-from
			var side:=Vector2(-delta.y,delta.x).normalized()
			var points:=PackedVector2Array([from,from+delta*.28+side*(6+float(frame.pulse)*2),from+delta*.48-side*(4+float(frame.pulse)),from+delta*.7+side*3,p])
			c.draw_polyline(points,Color(ICE,.85*(1-t)),2.8,true)
			c.draw_polyline(points,Color(CORE,.9*(1-t)),.8,true)
		"ring":
			for i: int in range(3): ribbon(c,p,maxf(.2,radius*(.2+.8*float(frame.drift))),i*2.1,i*2.1+1.1,3*(1-t)+.1,Color(color,1-t))
		_: return false
	return true
