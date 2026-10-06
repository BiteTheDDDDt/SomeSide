class_name SideEnemyAttackVisual
extends RefCounted

## Stateless presentation sampled from replicated attack timers. No global-clock
## wobble, simulation writes, runtime textures, or unbounded particle queues.
const Pose = preload("res://scripts/weapon_pose.gd")
const ACTIVE_LIFETIME: float = 0.22
const MAX_FILAMENTS: int = 6
const HOT := Color("ffac7b")
const CORE := Color("fff0c7")

static func attack_sample(enemy: Dictionary) -> Dictionary:
	var kind: String = str(enemy.get("attack_kind", ""))
	var remaining: float = maxf(0.0,float(enemy.get("telegraph",0.0)))
	var progress: float = clampf(1.0-remaining/maxf(.01,float(enemy.get("telegraph_max",.8))),0,1)
	var elapsed: float = maxf(0.0,float(enemy.get("attack_cooldown",3.0))-float(enemy.get("attack_cd",0.0)))
	var active: bool = not kind.is_empty() and float(enemy.get("hp",1.0))>0 and (remaining>0 or elapsed<ACTIVE_LIFETIME)
	var amount: float = smoothstep(0.0,1.0,progress) if remaining>0 else (lerpf(1,-.35,smoothstep(0.0,.055,elapsed)) if elapsed<.055 else lerpf(-.35,0,smoothstep(.055,ACTIVE_LIFETIME,elapsed)))
	return {"active":active,"winding":remaining>0,"progress":progress,"elapsed":elapsed,"amount":amount if active else 0.0,"kind":kind}

static func body_rect(original: Rect2, enemy: Dictionary) -> Rect2:
	var action: Dictionary = attack_sample(enemy)
	if not bool(action.active): return original
	var amount: float = float(action.amount)
	var kind: String = action.kind
	var scale_value: Vector2 = Vector2(1-.035*amount,1-.055*amount)
	var retreat: float = -1.5*amount
	if kind in ["charge","stone_charge","pounce"]:
		scale_value = Vector2(1+.045*amount,1-.12*amount)
		retreat = -3.0*amount
	elif kind in ["spit","triple","salvo","spore_volley","mortar","mend"]:
		scale_value = Vector2(1+.055*amount,1+.035*amount)
		retreat = -1.8*amount
	# Grounded feet retain their original baseline; flyers breathe around their
	# center. The caller's existing facing transform also mirrors the retreat.
	var anchor: Vector2 = Vector2(0,0 if bool(enemy.get("flying",false)) else original.end.y)
	return Rect2(anchor+(original.position-anchor)*scale_value+Vector2(retreat,0),original.size*scale_value)

static func beam_sample(hazard: Dictionary, fx_scale: float = 1.0, reduced_motion: bool = false) -> Dictionary:
	var direction: Vector2 = Pose.normalized_aim(hazard.get("dir",Vector2.RIGHT))
	var position: Vector2 = hazard.get("pos",Vector2.ZERO)
	var length: float = clampf(float(hazard.get("length",0.0)),0.0,1200.0)
	var radius: float = clampf(float(hazard.get("radius",30.0)),1.0,400.0)
	var active: bool = bool(hazard.get("active",false))
	var progress: float = clampf(1.0-float(hazard.get("delay",0.0))/maxf(.01,float(hazard.get("telegraph_max",.8))),0,1)
	var release: float = clampf(1.0-float(hazard.get("ttl",ACTIVE_LIFETIME))/ACTIVE_LIFETIME,0,1) if active else 0.0
	return {"origin":position,"end":position+direction*length,"direction":direction,"radius":radius,"active":active,"progress":progress,"release":release,
		"edge_alpha":.92 if active else .36+.4*progress,"fill_alpha":.115 if active else .025+.035*progress,
		"core_width":maxf(2.0,radius*(.58-.36*smoothstep(.0,1.0,release))) if active else 1.0,
		"filaments":0 if reduced_motion or fx_scale<.6 else MAX_FILAMENTS}

static func draw_source(canvas: CanvasItem, origin: Vector2, direction: Vector2, progress: float, filaments: int, active: bool = false, release: float = 0.0) -> void:
	var charge: float = smoothstep(0,1,clampf(progress,0,1))
	var energy: float = (1.0-.55*release) if active else (.25+.75*charge)
	var core_radius: float = (7.0-3.0*release) if active else (2.0+4.0*charge)
	for layer: int in range(2,0,-1):
		canvas.draw_circle(origin,core_radius+layer*(4.0+charge*3.0),Color(HOT,.065*energy),true,-1,true)
	var side: Vector2 = direction.orthogonal()
	# Energy travels into the emitter along curved filaments, never along a new
	# aiming direction. Reduced FX removes only these decorative paths.
	if not active:
		for index: int in range(clampi(filaments,0,MAX_FILAMENTS)):
			var offset: float = float(index)/float(MAX_FILAMENTS)
			var t: float = fposmod(progress*1.65+offset,1.0)
			var handed: float = -1.0 if index%2==0 else 1.0
			var distance: float = (1.0-t)*(23.0+9.0*offset)
			var start: Vector2 = origin-direction*distance*.65+side*distance*handed
			var middle: Vector2 = origin-direction*distance*.32+side*distance*handed*.36
			var finish: Vector2 = origin-direction*core_radius*.2
			canvas.draw_polyline(PackedVector2Array([start,middle,finish]),Color(HOT,(.16+.32*charge)*sin(t*PI)),1.0,true)
			canvas.draw_circle(start,1.0+charge*.5,Color(CORE,.5*sin(t*PI)),true,-1,true)
	# A narrow lens compresses around a solid emitter instead of a full-body ring.
	var aperture: float = (8.0-3.0*release) if active else (17.0-10.0*charge)
	var lens := PackedVector2Array()
	for index: int in range(13):
		var angle: float = -PI*.5+PI*float(index)/12.0
		lens.append(origin+direction*(cos(angle)*3.0)+side*(sin(angle)*aperture))
	canvas.draw_polyline(lens,Color(HOT,.45+.45*energy),1.3,true)
	canvas.draw_circle(origin,core_radius,Color(HOT,.82),true,-1,true)
	canvas.draw_circle(origin+direction*.8,maxf(1.2,core_radius*.44),Color(CORE,.8+.2*energy),true,-1,true)

static func draw_preparation(canvas: CanvasItem, enemy: Dictionary, center: Vector2, direction: Vector2, progress: float, foot: float, detail: bool) -> void:
	var kind: String = str(enemy.get("attack_kind",""))
	var charge: float = smoothstep(0,1,progress)
	if kind in ["charge","stone_charge","pounce"]:
		var floor_point: Vector2 = center+Vector2(0,foot)
		var width: float = 28.0 if kind=="stone_charge" else 15.0
		for side: float in [-1.0,1.0]:
			var toe: Vector2 = floor_point+Vector2(side*width,0)
			canvas.draw_line(toe-Vector2(4,0),toe+Vector2(4,0),Color(HOT,.3+.4*charge),1.4,true)
			if detail:
				canvas.draw_circle(toe+Vector2(side*(4+charge*7),-charge*3),3+charge*3,Color("bc9b7b",.06+.1*charge),true,-1,true)
				for index: int in range(2):
					var grit: Vector2 = toe+Vector2(side*(6+index*5+charge*7),-1-charge*(3+index*3))
					canvas.draw_line(grit,grit+Vector2(side*2,-1),Color("bda48b",.22+.3*charge),1.2,true)
		return
	var origin: Vector2 = center+direction*float(enemy.get("radius",23.0))*.65
	if kind in ["spit","mortar","spore_volley","spore_bloom"]:
		var radius: float = 2.0+charge*4.0
		canvas.draw_circle(origin,radius+1,Color("213734",.85),true,-1,true)
		canvas.draw_circle(origin,radius,Color("becc7e",.65+.25*charge),true,-1,true)
		canvas.draw_circle(origin+Vector2(-radius*.25,-radius*.28),maxf(1,radius*.25),Color("eef0b2",.8),true,-1,true)
		if detail:
			for index: int in range(2):
				var distance: float = (1.0-progress)*(9+index*5)
				var drop: Vector2 = origin-direction*distance+Vector2(0,-distance*.65)
				canvas.draw_circle(drop,1.0+charge,Color("b7c36b",.4*sin(progress*PI)),true,-1,true)
		return
	draw_source(canvas,origin,direction,progress,4 if detail else 0)

static func draw_beam(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	var direction: Vector2 = sample.direction
	var radius: float = sample.radius
	var side: Vector2 = direction.orthogonal()*radius
	var active: bool = sample.active
	var progress: float = sample.progress
	var release: float = sample.release
	# The permanent envelope is precisely the authoritative capsule, including
	# rounded endpoint caps. Core fading never makes active damage look safe.
	canvas.draw_colored_polygon(PackedVector2Array([start-side,finish-side,finish+side,start+side]),Color(HOT,sample.fill_alpha))
	for cap: Array in [[start,direction.angle()+PI*.5],[finish,direction.angle()-PI*.5]]:
		var center: Vector2 = cap[0]
		var begin: float = cap[1]
		var points := PackedVector2Array([center])
		for index: int in range(19): points.append(center+Vector2.from_angle(begin+PI*index/18.0)*radius)
		canvas.draw_colored_polygon(points,Color(HOT,sample.fill_alpha))
		canvas.draw_arc(center,radius,begin,begin+PI,18,Color(HOT,sample.edge_alpha),1.3 if active else 1.0,true)
	for sign_value: float in [-1.0,1.0]:
		canvas.draw_line(start+side*sign_value,finish+side*sign_value,Color(HOT,sample.edge_alpha),1.3 if active else 1.0,true)
	if active:
		canvas.draw_line(start,finish,Color("ed755d",.44-.14*release),radius*1.25,true)
		canvas.draw_line(start,finish,Color("ffc793",.95-.22*release),float(sample.core_width)+2.0,true)
		canvas.draw_line(start,finish,Color(CORE,.95-.28*release),sample.core_width,true)
	else:
		# A slim continuous guide shows the locked axis. The actual charge lives
		# on the monster; the lane no longer contains marching arrow glyphs.
		canvas.draw_line(start,finish,Color(HOT,.16+.30*progress),1.0,true)
		if int(sample.filaments)>0:
			for index: int in range(2):
				var offset: float = (-1.0 if index==0 else 1.0)*radius*(.78-.62*progress)
				var mid: Vector2 = start.lerp(finish,.28)+direction.orthogonal()*offset
				canvas.draw_polyline(PackedVector2Array([start,mid,finish]),Color(HOT,.08+.14*progress),1.0,true)
	draw_source(canvas,start,direction,1.0 if active else progress,int(sample.filaments),active,release)

static func draw_lane(canvas: CanvasItem, start: Vector2, finish: Vector2, radius: float, progress: float, detail: bool) -> void:
	var direction: Vector2 = (finish-start).normalized()
	var side: Vector2 = direction.orthogonal()*radius
	canvas.draw_colored_polygon(PackedVector2Array([start-side,finish-side,finish+side,start+side]),Color(HOT,.025+.035*progress))
	for sign_value: float in [-1.0,1.0]: canvas.draw_line(start+side*sign_value,finish+side*sign_value,Color(HOT,.38+.36*progress),1.0,true)
	if detail:
		for index: int in range(3):
			var center: Vector2 = start.lerp(finish,(float(index)+progress)/3.0)
			var cross: Vector2 = side*(.65-.2*progress)
			canvas.draw_polyline(PackedVector2Array([center-cross-direction*5,center-direction*8,center+cross-direction*5]),Color(HOT,.08+.1*progress),1.0,true)
