class_name SideTrackingRules
extends RefCounted

## Opt-in new content only. No Nodes, owner-global marks or flight-time searches.
const Guidance = preload("res://scripts/projectile_guidance.gd")
const KINDS: Array[String] = ["arc_needle", "star_seeker", "engraved_blade", "beacon_dart", "hunting_crystal"]
const MAX_BEACONS: int = 4
const BEACON_TIMES: Array[float] = [.4, 1.4, 2.4]

static func hand_offset(aim: Vector2,elapsed: float) -> Vector2:
	var raise: float=sin(PI*clampf(elapsed/.34,0,1))
	return Vector2((-1.0 if aim.x<0 else 1.0)*(4+raise*6),-8-raise*14)

static func profile(kind: String) -> Dictionary:
	match kind:
		"arc_needle": return Guidance.NEEDLE
		"star_seeker": return Guidance.SEEKER
		"engraved_blade": return Guidance.BLADE
		"beacon_dart": return Guidance.BEACON
		"hunting_crystal": return Guidance.MOTH
	return {}

static func segment_box(a: Vector2, b: Vector2, rect: Rect2, radius: float=0.0) -> float:
	var box: Rect2 = rect.grow(radius)
	var near: float = 0.0
	var far: float = 1.0
	var v: Vector2 = b-a
	for axis: int in range(2):
		if absf(v[axis])<.000001:
			if a[axis]<box.position[axis] or a[axis]>box.end[axis]: return -1.0
		else:
			var x: float = (box.position[axis]-a[axis])/v[axis]
			var y: float = (box.end[axis]-a[axis])/v[axis]
			near=maxf(near,minf(x,y)); far=minf(far,maxf(x,y))
			if near>far: return -1.0
	return near

static func cover_time(a: Vector2, b: Vector2, solids: Array, radius: float=0.0) -> float:
	var first: float = 2.0
	for solid: Rect2 in solids:
		var t: float=segment_box(a,b,solid,radius)
		if t>=0.0: first=minf(first,t)
	return first

static func legal_target(origin: Vector2, aim: Vector2, target: Dictionary, preset: Dictionary, solids: Array) -> bool:
	if not Guidance._living(target) or not bool(target.get("hittable",true)): return false
	var offset: Vector2=Vector2(target.pos)-origin
	if offset.length_squared()<.0001 or offset.length_squared()>pow(float(preset.range),2): return false
	if offset.normalized().dot(aim.normalized())<cos(deg_to_rad(float(preset.cone)))-.000001: return false
	return cover_time(origin,target.pos,solids)>1.0

static func acquire(origin: Vector2, aim: Vector2, candidates: Array, preset: Dictionary, solids: Array, preferred: int=-1) -> Dictionary:
	var legal: Array=[]
	for target: Dictionary in candidates:
		if not legal_target(origin,aim,target,preset,solids): continue
		if int(target.id)==preferred: return Guidance.lock(origin,aim,[target],preset)
		legal.append(target)
	return Guidance.lock(origin,aim,legal,preset)

static func owner_mark(player: Dictionary) -> int:
	if str(player.get("character",""))!="weaver" or bool(player.get("dead",false)): return -1
	var mark: Dictionary=player.get("trace_mark",{})
	return int(mark.get("target_id",-1)) if float(mark.get("remaining",0))>0 else -1

static func visible(player: Dictionary, point: Vector2, margin: float=32.0) -> bool:
	# Reported local viewport only RESTRICTS this conservative player-centred
	# interior. Missing/stale reports use this smaller safe area, never full map.
	var safe:=Rect2(Vector2(player.pos)-Vector2(330,210),Vector2(660,420))
	if not safe.grow(-margin).has_point(point): return false
	var view: Variant=player.get("tracking_view",null)
	return view==null or (view is Rect2 and Rect2(view).grow(-margin).has_point(point))

static func set_view(player: Dictionary, command: Dictionary) -> void:
	var view: Variant=command.get("view_rect",null)
	if not view is Rect2: return
	var rect: Rect2=view
	if not rect.position.is_finite() or not rect.size.is_finite(): return
	if rect.size.x<320 or rect.size.y<180 or rect.size.x>2560 or rect.size.y>1440: return
	if not rect.has_point(player.pos): return
	player["tracking_view"]=rect
