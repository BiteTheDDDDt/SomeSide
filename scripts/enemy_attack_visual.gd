class_name SideEnemyAttackVisual
extends RefCounted

## Stateless presentation sampled from replicated attack timers. No global-clock
## wobble, simulation writes, runtime textures, or unbounded particle queues.
const Pose = preload("res://scripts/weapon_pose.gd")
const Sprites = preload("res://scripts/attack_fx_sprites.gd")
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
		"edge_alpha":.48 if active else .24+.26*progress,"fill_alpha":.075 if active else .025+.025*progress,
		"sprite_family":"beam" if active else "charge","sprite_phase":release if active else progress,
		"core_width":maxf(2.0,radius*(.58-.36*smoothstep(.0,1.0,release))) if active else 1.0,
		"filaments":0 if reduced_motion or fx_scale<.6 else MAX_FILAMENTS}

static func draw_source(canvas: CanvasItem, origin: Vector2, direction: Vector2, progress: float, filaments: int, active: bool = false, release: float = 0.0) -> void:
	# The visible action is an authored eight-frame painted sequence. Even the
	# low-FX path keeps the emitter sprite; optional wisps are in the same atlas.
	var family: String = "burst" if active else "charge"
	var phase: float = clampf(release,0,1) if active else clampf(progress,0,1)
	var extent: float = 48.0 if active else 37.0 + 11.0 * progress
	if filaments == 0: extent *= .9
	Sprites.draw_oriented(canvas,family,origin,Vector2.ONE*extent,direction.angle(),phase,Color(1,1,1,.92 if active else .68+.32*progress))

static func draw_preparation(canvas: CanvasItem, enemy: Dictionary, center: Vector2, direction: Vector2, progress: float, foot: float, detail: bool) -> void:
	var kind: String = str(enemy.get("attack_kind",""))
	if kind in ["charge","stone_charge","pounce"]:
		var extent: float = 63.0 if kind=="stone_charge" else 40.0
		# A low, dusty burst compresses under the feet, with the sprite's own
		# billowing texture replacing the old stroked grit and circles.
		Sprites.draw_family(canvas,"burst",Rect2(center+Vector2(-extent*.5,foot-extent*.34),Vector2(extent,extent*.45)),.5+progress*.38,Color(.75,.70,.61,.35+.4*progress))
		return
	var origin: Vector2 = center+direction*float(enemy.get("radius",23.0))*.65
	if kind in ["spit","mortar","spore_volley","spore_bloom"]:
		var extent: float = 24.0+14.0*progress
		Sprites.draw_oriented(canvas,"burst",origin,Vector2.ONE*extent,direction.angle(),progress*.4,Color(.82,1.0,.68,.75+progress*.25))
		return
	draw_source(canvas,origin,direction,progress,4 if detail else 0)

static func draw_beam(canvas: CanvasItem, start: Vector2, finish: Vector2, sample: Dictionary) -> void:
	var direction: Vector2 = sample.direction
	var radius: float = sample.radius
	var side: Vector2 = direction.orthogonal()*radius
	var active: bool = sample.active
	var progress: float = sample.progress
	var release: float = sample.release
	# The thin capsule is only an auxiliary boundary. Its exact authoritative
	# radius/endpoints survive low FX; the actual release is a textured sprite.
	canvas.draw_colored_polygon(PackedVector2Array([start-side,finish-side,finish+side,start+side]),Color(HOT,sample.fill_alpha))
	for cap: Array in [[start,direction.angle()+PI*.5],[finish,direction.angle()-PI*.5]]:
		var center: Vector2 = cap[0]
		var begin: float = cap[1]
		canvas.draw_arc(center,radius,begin,begin+PI,18,Color(HOT,sample.edge_alpha),.8,true)
	for sign_value: float in [-1.0,1.0]:
		canvas.draw_line(start+side*sign_value,finish+side*sign_value,Color(HOT,sample.edge_alpha),.8,true)
	if active:
		Sprites.draw_oriented(canvas,"beam",start.lerp(finish,.5),Vector2(start.distance_to(finish),radius*2.15),direction.angle(),release,Color.WHITE)
	else:
		canvas.draw_line(start,finish,Color(HOT,.10+.12*progress),.8,true)
	draw_source(canvas,start,direction,1.0 if active else progress,int(sample.filaments),active,release)

static func draw_lane(canvas: CanvasItem, start: Vector2, finish: Vector2, radius: float, progress: float, _detail: bool) -> void:
	var direction: Vector2 = (finish-start).normalized()
	var side: Vector2 = direction.orthogonal()*radius
	canvas.draw_colored_polygon(PackedVector2Array([start-side,finish-side,finish+side,start+side]),Color(HOT,.025+.025*progress))
	for sign_value: float in [-1.0,1.0]: canvas.draw_line(start+side*sign_value,finish+side*sign_value,Color(HOT,.25+.25*progress),.8,true)
