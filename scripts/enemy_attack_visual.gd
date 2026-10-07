class_name SideEnemyAttackVisual
extends RefCounted

## Stateless presentation sampled from replicated attack timers. No global-clock
## wobble, simulation writes, runtime textures, or unbounded particle queues.
const Envelope = preload("res://scripts/beam_envelope.gd")
const FX = preload("res://scripts/illustrated_fx.gd")
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
		"envelope":Envelope.sample(float(hazard.get("ttl",BEAM_LIFETIME))),
		"warning_reach":smoothstep(0.0,.65,progress),
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

static func draw_source(canvas: CanvasItem, origin: Vector2, direction: Vector2, progress: float, detail: bool, active: bool = false, release: float = 0.0) -> void:
	var phase: float = clampf(progress,0,1)
	var scale_value: float = Envelope.sample((1.0-release)*BEAM_LIFETIME).y if active else .3+.7*phase
	if scale_value<.015: return
	var across: Vector2 = direction.orthogonal()
	# Nested solid facets sit inside the actual eye. Separate curved jaws
	# close into its aperture, instead of a floating star or target reticle.
	Geometry.diamond(canvas,origin,direction,5.5*scale_value,4.0*scale_value,Color("b1c6cd"),.8)
	Geometry.diamond(canvas,origin-direction, direction,3.2*scale_value,2.0*scale_value,Geometry.CORE)
	if not active and detail:
		for side: float in [-1.0,1.0]:
			var point: Vector2=origin-direction*(9.0-phase*5.0)+across*side*(7.0-phase*4.0)
			FX.shard(canvas,point,direction.angle()+side*.3,3.5,1.6,Color("b1c6cd"))

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

static func draw_lunge(canvas: CanvasItem, enemy: Dictionary, center: Vector2) -> void:
	var remaining: float=float(enemy.get("charge_timer",0.0))
	if remaining<=0.0: return
	var kind: String=str(enemy.get("attack_kind",""))
	var duration: float=.35 if kind=="pounce" else (.72 if kind=="stone_charge" else .58)
	var phase: float=clampf(1.0-remaining/duration,0,1)
	var direction: Vector2=Pose.normalized_aim(enemy.get("attack_dir",Vector2.RIGHT))
	var radius: float=float(enemy.get("radius",19.0))
	if kind=="pounce":
		# Two short claw sweeps travel with the forelimbs, never a detached
		# complete circle or a warning corridor in front of the creature.
		for i: int in range(2):
			var origin: Vector2=center+direction*radius*.36+Vector2(0,4+i*4)
			FX.ribbon(canvas,origin,radius*.65,direction.angle()-1.1+phase*.6,direction.angle()+.5+phase*.6,2.8*(1-phase),Color("c5c797",1-phase*.5))
	elif kind in ["charge","stone_charge"]:
		# Broad kicked-up chips follow the feet; avoid speed-line runways.
		for i: int in range(3):
			var t: float=fposmod(phase*2.0+i/3.0,1.0)
			var point: Vector2=center-direction*radius*(.4+t*.9)+Vector2(0,radius*.6-t*8)
			FX.shard(canvas,point,direction.angle()+.3,4*(1-t)+1,2*(1-t)+.3,Color("a99583",1-t))

static func draw_beam_warning(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	if not bool(sample.warning_visible): return
	var direction: Vector2=sample.direction
	var end: Vector2=start.lerp(finish,float(sample.warning_reach))
	# One extending red dashed aim line. No capsule, parallel borders,
	# secondary progress arc or differently colored trajectory.
	Geometry.draw_warning(canvas,PackedVector2Array([start,end]),float(sample.warning_alpha),false)
	if end.distance_to(start)>12.0:
		var across: Vector2=direction.orthogonal()
		var arrow:=PackedVector2Array([end-direction*7.0+across*4.0,end,end-direction*7.0-across*4.0])
		canvas.draw_polyline(arrow,Color("26383c"),Geometry.BACK,true)
		canvas.draw_polyline(arrow,Color(Geometry.WARNING,float(sample.warning_alpha)),Geometry.EDGE,true)

static func draw_beam(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	var direction: Vector2=sample.direction
	draw_beam_warning(canvas,start,finish,sample)
	var envelope: Vector2=sample.envelope
	if bool(sample.material_visible) and envelope.y>.005 and envelope.x>.001:
		var end: Vector2=start.lerp(finish,envelope.x)
		var width: float=float(sample.radius)*envelope.y
		# The same temporal envelope controls the actual collider. The beam
		# shoots out, holds, then contracts to a hairline before disappearing.
		Geometry.draw_beam_band(canvas,warning_capsule(start,end,width),start,end,Color("ce8987"),.08)
		Geometry.draw_beam_band(canvas,warning_capsule(start,end,width*.57),start,end,Color("e9bfaf"),.15)
		Geometry.draw_beam_band(canvas,warning_capsule(start,end,width*.16),start,end,Geometry.CORE,.27)
	draw_source(canvas,start,direction,1.0 if bool(sample.active) else float(sample.progress),bool(sample.detail),bool(sample.active),float(sample.release))
