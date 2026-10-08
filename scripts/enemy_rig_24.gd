class_name SideEnemyRig24
extends RefCounted

const Clips=preload("res://scripts/motion_clips_24.gd")
# Neck, shoulder, hip and tail have separate pivots. Values are rotations,
# not whole-picture stretch factors; the muzzle is pinned by the renderer.
const PROFILES: Dictionary={
	"crawler":{"head":.08,"front":.24,"rear":-.28,"tail":.18,"lift":1.6},
	"spitter":{"head":-.10,"front":.07,"rear":.11,"tail":.07,"lift":.5},
	"spore_moth":{"head":-.06,"front":.15,"rear":-.08,"tail":.18,"lift":.9},
	"drone":{"head":.02,"front":-.11,"rear":.12,"tail":-.14,"lift":.4},
	"charger":{"head":.16,"front":-.16,"rear":.23,"tail":.12,"lift":1.3},
	"burrower":{"head":.10,"front":-.29,"rear":.13,"tail":.08,"lift":.9},
	"sentinel":{"head":-.025,"front":-.14,"rear":.11,"tail":.025,"lift":.65},
	"skirmisher":{"head":.14,"front":.27,"rear":-.19,"tail":-.15,"lift":1.3},
	"conductor":{"head":-.05,"front":-.22,"rear":.13,"tail":.18,"lift":.8},
	"boss_stone":{"head":.095,"front":-.22,"rear":.14,"tail":.045,"lift":2.0},
	"boss_spore":{"head":-.08,"front":.06,"rear":-.09,"tail":.12,"lift":1.2},
	"boss_prism":{"head":.02,"front":-.12,"rear":.14,"tail":-.18,"lift":.8}}

static func sample(id: String,action: String,stage: String,progress: float,interpolate: bool=true) -> Dictionary:
	var first: int=0
	var last: int=23
	var loop: bool=stage in ["move","idle"]
	var clip: Dictionary
	if stage in ["coil","release","recover"]:
		# A COMPLETE attack has 24 poses: 10 anticipation, 5 release, 9
		# recovery. Authority independently maps its real stage time into
		# that section; interpolation never crosses a damage transition.
		clip=Clips.bake("enemy/"+id+"/"+action,func(t: float):
			var frame: int=roundi(t*23)
			if frame<10: return _pose(id,"coil",frame/9.0)
			if frame<15: return _pose(id,"release",(frame-10)/4.0)
			return _pose(id,"recover",(frame-15)/8.0))
		if stage=="coil": first=0; last=9
		elif stage=="release": first=10; last=14
		else: first=15; last=23
		var position: float=lerpf(first,last,clampf(progress,0,1))
		return Clips.play(clip,(position if interpolate else floorf(position+.00001))/23.0)
	clip=Clips.bake("enemy/"+id+"/"+stage,func(t: float): return _pose(id,stage,t),loop)
	return Clips.play(clip,progress if interpolate else floorf(fposmod(progress,1.0)*24)/24.0)

static func _pose(id: String,stage: String,t: float) -> Dictionary:
	var profile: Dictionary=PROFILES[id]
	var drive: float=0.0
	var lag: float=0.0
	match stage:
		"coil":
			drive=Clips.curve([[0,0],[.24,.18],[.72,.83],[1,1]],t)
			lag=Clips.curve([[0,0],[.45,.14],[1,.8]],t)
		"release":
			drive=Clips.curve([[0,1],[.16,-.65],[.48,-.85],[1,-.25]],t)
			lag=Clips.curve([[0,.8],[.24,.15],[.68,-.5],[1,-.2]],t)
		"recover":
			drive=Clips.curve([[0,-.25],[.36,.12],[.72,-.035],[1,0]],t)
			lag=Clips.curve([[0,-.2],[.5,.07],[1,0]],t)
		"move": drive=sin(TAU*t)*.22; lag=sin(TAU*t-.6)*.2
		"idle": drive=sin(TAU*t)*.045; lag=sin(TAU*t-.8)*.04
		"death": drive=sin(PI*t*.5)*.55; lag=sin(PI*t)*.3
	return {"head":float(profile.head)*drive,"front":float(profile.front)*drive,"rear":float(profile.rear)*drive,"tail":float(profile.tail)*lag,"lift":float(profile.lift)*drive}

static func bend(point: Vector2,uv: Vector2,target: Rect2,pose: Dictionary) -> Vector2:
	# Non-overlapping limb zones keep the torso solid and leave the sole row
	# fixed. Adjacent neck/shoulder vertices taper into the articulated patch.
	var head: float=smoothstep(.53,.82,uv.x)*(1.0-smoothstep(.38,.62,uv.y))
	var front: float=smoothstep(.46,.72,uv.x)*smoothstep(.52,.80,uv.y)
	var rear: float=(1.0-smoothstep(.26,.51,uv.x))*smoothstep(.52,.80,uv.y)
	var tail: float=(1.0-smoothstep(.12,.34,uv.x))*(1.0-smoothstep(.45,.7,uv.y))
	var result: Vector2=point
	# No temporary joint arrays per vertex; this path runs on cache misses.
	if head>.001: result+=_turn(point,target.position+Vector2(.67,.38)*target.size,float(pose.head))*head
	if front>.001: result+=_turn(point,target.position+Vector2(.67,.56)*target.size,float(pose.front))*front
	if rear>.001: result+=_turn(point,target.position+Vector2(.33,.56)*target.size,float(pose.rear))*rear
	if tail>.001: result+=_turn(point,target.position+Vector2(.31,.4)*target.size,float(pose.tail))*tail
	result.y+=float(pose.lift)*(1.0-smoothstep(.60,1,uv.y))
	return point.lerp(result,1.0-smoothstep(.94,1,uv.y))

static func _turn(point: Vector2,pivot: Vector2,angle: float) -> Vector2:
	var relative: Vector2=point-pivot
	return relative.rotated(angle)-relative
