class_name SideEnemyAttackVisual
extends RefCounted

## Stateless presentation sampled from replicated attack timers. No global-clock
## wobble, simulation writes, runtime textures, or unbounded particle queues.
const Pose = preload("res://scripts/weapon_pose.gd")
const Sprites = preload("res://scripts/attack_fx_sprites.gd")
const Geometry = preload("res://scripts/combat_geometry.gd")
const ACTIVE_LIFETIME: float = 0.22
const BEAM_LIFETIME: float = 0.55

static func attack_sample(enemy: Dictionary) -> Dictionary:
	var kind: String = str(enemy.get("attack_kind", ""))
	var remaining: float = maxf(0.0,float(enemy.get("telegraph",0.0)))
	var progress: float = clampf(1.0-remaining/maxf(.01,float(enemy.get("telegraph_max",.8))),0,1)
	var elapsed: float = maxf(0.0,float(enemy.get("attack_cooldown",3.0))-float(enemy.get("attack_cd",0.0)))
	var duration: float = BEAM_LIFETIME if kind in ["beam","prism_beam","prism_cross"] else ACTIVE_LIFETIME
	var active: bool = not kind.is_empty() and float(enemy.get("hp",1.0))>0 and (remaining>0 or elapsed<duration)
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
	var release: float = clampf(1.0-float(hazard.get("ttl",BEAM_LIFETIME))/BEAM_LIFETIME,0,1) if active else 0.0
	# Warning geometry is visible from the first replicated windup frame.
	# Its hollow red dashed footprint is distinct from filled geometric bands
	# that exist only while authority marks damage active.
	return {"origin":position,"end":position+direction*length,"direction":direction,"radius":radius,"active":active,"progress":progress,"release":release,
		"warning_visible":not active,"warning_origin":position,"warning_end":position+direction*length,"warning_radius":radius,
		"warning_alpha":0.0 if active else Geometry.warning_alpha(progress*float(hazard.get("telegraph_max",1.5))),
		"warning_fill_alpha":0.0,
		"geometry":Geometry.capsule(position,position+direction*length,radius),
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
	var phase: float = clampf(progress,0,1)
	var color: Color = Geometry.palette("crystal").attack
	Geometry.diamond(canvas,origin,direction,6.0 if active else 2.0+phase*3.0,4.5 if active else 1.5+phase*2.0,Geometry.CORE if active else color,1.2)
	if not active and _detail:
		# Paired facets converge into the aperture, never paint a second path.
		for side: float in [-1.0,1.0]:
			var from: Vector2 = origin-direction*(10.0-phase*4.0)+direction.orthogonal()*side*(7.0-phase*3.0)
			canvas.draw_line(from,from+direction*3.0-direction.orthogonal()*side*2.0,color,Geometry.DETAIL,true)

static func preparation_sample(enemy: Dictionary, center: Vector2, direction: Vector2, progress: float, foot: float) -> Dictionary:
	var kind: String = str(enemy.get("attack_kind",""))
	var phase: float = clampf(progress,0,1)
	if kind == "pounce": return {}
	if kind in ["charge","stone_charge"]:
		var width: float = 52.0 if kind=="stone_charge" else 30.0
		# Clods collect directly under braced feet. They do not paint a runway
		# across safe ground or pretend the charge has already happened.
		return {"family":"earth_ready","origin":center+Vector2(0,foot-3.0),
			"size":Vector2(width,10.0 if kind=="stone_charge" else 7.0),
			"angle":0.0,"phase":phase,"tint":Color(.78,.78,.78,.48+.2*phase)}
	if kind in ["spit","mend"]:
		var extent: float = 7.0+6.0*phase
		var origin: Vector2 = center+Geometry.source_offset(enemy,direction)
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
	if str(enemy.get("attack_kind","")) in ["spit","mend"]:
		Geometry.draw_ammunition(canvas,sample.origin,direction,Vector2(sample.size).y*.35,str(enemy.get("attack_kind",""))=="spit",true,progress)
		return
	Geometry.draw_ground_charge(canvas,sample.origin,float(sample.size.x),progress)

static func warning_capsule(start: Vector2, finish: Vector2, radius: float) -> PackedVector2Array:
	return Geometry.capsule(start,finish,radius)

static func draw_beam_warning(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	if not bool(sample.warning_visible): return
	var outline: PackedVector2Array = warning_capsule(start,finish,float(sample.radius))
	Geometry.draw_warning(canvas,outline,float(sample.warning_alpha))
	if bool(sample.detail):
		# Two small inward-facing crystal facets are subordinate to the intact
		# boundary. Nothing extends beyond the announced danger silhouette.
		var direction: Vector2 = sample.direction
		for side: float in [-1.0,1.0]:
			var point: Vector2 = start.lerp(finish,.18)+direction.orthogonal()*side*(float(sample.radius)-3.0)
			Geometry.diamond(canvas,point,direction,4.0,1.4,Geometry.WARNING)

static func draw_beam(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	var direction: Vector2 = sample.direction
	draw_beam_warning(canvas,start,finish,sample)
	if bool(sample.material_visible):
		# Both phases consume exactly the same capsule, including both end caps.
		# Damage fills it with hard bands fading along distance; no texture/bloom/taper can
		# imply a different width or an early fade during the authority window.
		Geometry.draw_beam_band(canvas,warning_capsule(start,finish,float(sample.radius)),start,finish,Color("d99089"),.06)
		Geometry.draw_beam_band(canvas,warning_capsule(start,finish,float(sample.radius)*.55),start,finish,Color("edd2bb"),.12)
		Geometry.draw_beam_band(canvas,warning_capsule(start,finish,maxf(1.5,float(sample.radius)*.15)),start,finish,Geometry.CORE,.22)

		# Short energy packets travel inside the filled core; these do not
		# redraw the removed warning perimeter or extend the hit silhouette.
		var across: Vector2=direction.orthogonal()
		var length: float=start.distance_to(finish)
		for index: int in range(3):
			var along: float=fposmod(float(sample.release)*1.4+index/3.0,1.0)
			if length*along<1.0: continue
			var head: Vector2=start.lerp(finish,along)
			var tail: Vector2=head-direction*minf(34.0,length*along)
			var width: float=maxf(.8,float(sample.radius)*.09)
			var tint:=Color(Geometry.CORE,lerpf(.72,.16,along))
			canvas.draw_colored_polygon(PackedVector2Array([head,tail-across*width,tail+across*width]),tint)

	draw_source(canvas,start,direction,1.0 if bool(sample.active) else float(sample.progress),bool(sample.detail),bool(sample.active),float(sample.release))
