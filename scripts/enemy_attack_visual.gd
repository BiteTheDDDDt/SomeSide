class_name SideEnemyAttackVisual
extends RefCounted

## Stateless presentation sampled from replicated attack timers. No global-clock
## wobble, simulation writes, runtime textures, or unbounded particle queues.
const Pose = preload("res://scripts/weapon_pose.gd")
const Sprites = preload("res://scripts/attack_fx_sprites.gd")
const ACTIVE_LIFETIME: float = 0.22

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
	# Warning geometry is visible from the first replicated windup frame.
	# Its amber outlined footprint is intentionally distinct from the opaque
	# purple laser that exists only while the authority marks damage active.
	return {"origin":position,"end":position+direction*length,"direction":direction,"radius":radius,"active":active,"progress":progress,"release":release,
		"warning_visible":not active,"warning_origin":position,"warning_end":position+direction*length,"warning_radius":radius,
		"warning_alpha":0.0 if active else .86+.14*progress,
		"warning_fill_alpha":0.0 if active else .10+.08*progress,
		"material_family":"laser","material_phase":release if active else 0.0,
		"material_visible":active,"material_size":Vector2(length,radius*2.0),
		"material_center":position+direction*length*.5,
		"material_alpha":1.0 if active else 0.0,
		"sprite_family":"laser","sprite_phase":release if active else 0.0,
		"source_family":"emitter","source_phase":1.0 if active else progress,
		"source_size":Vector2.ONE*(26.0 if active else 12.0+12.0*progress),
		"source_alpha":1.0 if active else .6+.3*progress,
		"detail":not reduced_motion and fx_scale>=.6}

static func draw_source(canvas: CanvasItem, origin: Vector2, direction: Vector2, progress: float, _detail: bool, active: bool = false, _release: float = 0.0) -> void:
	var phase: float = 1.0 if active else clampf(progress,0,1)
	var extent: float = 26.0 if active else 12.0+12.0*phase
	Sprites.draw_oriented(canvas,"emitter",origin,Vector2.ONE*extent,direction.angle(),phase,Color(1,1,1,1.0 if active else .6+.3*phase))

static func preparation_sample(enemy: Dictionary, center: Vector2, direction: Vector2, progress: float, foot: float) -> Dictionary:
	var kind: String = str(enemy.get("attack_kind",""))
	var phase: float = clampf(progress,0,1)
	if kind in ["charge","stone_charge","pounce"]:
		var width: float = 52.0 if kind=="stone_charge" else 30.0
		# Clods collect directly under braced feet. They do not paint a runway
		# across safe ground or pretend the charge has already happened.
		return {"family":"earth_ready","origin":center+Vector2(0,foot-3.0),
			"size":Vector2(width,10.0 if kind=="stone_charge" else 7.0),
			"angle":0.0,"phase":phase,"tint":Color(.78,.78,.78,.48+.2*phase)}
	if kind in ["spit","mend"]:
		var extent: float = 7.0+6.0*phase
		var origin: Vector2 = center+direction*(float(enemy.get("radius",19.0))+3.0)
		# The seed/crystal forming at the muzzle becomes the actual ammunition.
		# A conductor's harmful crystal remains coral; its healing uses mint.
		return {"family":"spore_shot" if kind=="spit" else "crystal_shot","origin":origin,
			"size":Vector2.ONE*extent,"angle":direction.angle(),"phase":phase,
			"tint":Color(.72,.72,.72,.7+.15*phase)}
	# Terrain attacks telegraph at their destination, blink uses paired rifts,
	# and spread attacks expose individual ammunition at each firing port.
	return {}

static func draw_preparation(canvas: CanvasItem, enemy: Dictionary, center: Vector2, direction: Vector2, progress: float, foot: float, _detail: bool) -> void:
	var sample: Dictionary = preparation_sample(enemy,center,direction,progress,foot)
	if sample.is_empty(): return
	Sprites.draw_oriented(canvas,sample.family,sample.origin,sample.size,sample.angle,sample.phase,sample.tint)

static func warning_capsule(start: Vector2, finish: Vector2, radius: float) -> PackedVector2Array:
	var angle: float = Pose.normalized_aim(finish-start).angle()
	var points := PackedVector2Array()
	# Sample the same two semicircles used by the outline, including endpoints.
	# The intervening polygon edges are the straight sides of the capsule.
	for cap: Dictionary in [{"center":finish,"angle":angle-PI*.5},{"center":start,"angle":angle+PI*.5}]:
		for step: int in range(25):
			points.append(Vector2(cap.center)+Vector2.from_angle(float(cap.angle)+PI*float(step)/24.0)*radius)
	return points

static func draw_beam_warning(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	if not bool(sample.warning_visible): return
	var perpendicular: Vector2 = Vector2(sample.direction).orthogonal()*float(sample.warning_radius)
	var amber := Color("ffcb70")
	var outline := Color("071219")
	var foreground: Color = Color(amber,float(sample.warning_alpha))
	canvas.draw_colored_polygon(warning_capsule(start,finish,float(sample.warning_radius)),Color(amber,float(sample.warning_fill_alpha)))
	# The dark under-stroke separates these cues from both pale rock and dark
	# foliage. The rounded ends are part of the real segment-circle hit shape;
	# both fill and outline must include them, not just the center rectangle.
	canvas.draw_line(start,finish,outline,4.5,true)
	canvas.draw_line(start,finish,foreground,1.7,true)
	for side: float in [-1.0,1.0]:
		var offset: Vector2 = perpendicular*side
		canvas.draw_line(start+offset,finish+offset,outline,2.8,true)
		canvas.draw_line(start+offset,finish+offset,Color(amber,float(sample.warning_alpha)*.8),.9,true)
	var angle: float = Vector2(sample.direction).angle()
	for cap: Dictionary in [{"center":start,"angle":angle+PI*.5},{"center":finish,"angle":angle-PI*.5}]:
		canvas.draw_arc(cap.center,float(sample.warning_radius),float(cap.angle),float(cap.angle)+PI,25,outline,2.8,true)
		canvas.draw_arc(cap.center,float(sample.warning_radius),float(cap.angle),float(cap.angle)+PI,25,Color(amber,float(sample.warning_alpha)*.8),.9,true)

static func draw_beam(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	var direction: Vector2 = sample.direction
	draw_beam_warning(canvas,start,finish,sample)
	if bool(sample.material_visible):
		Sprites.draw_oriented(canvas,sample.material_family,start+direction*Vector2(sample.material_size).x*.5,sample.material_size,direction.angle(),sample.material_phase,Color(1,1,1,sample.material_alpha))
	draw_source(canvas,start,direction,1.0 if bool(sample.active) else float(sample.progress),bool(sample.detail),bool(sample.active),float(sample.release))
