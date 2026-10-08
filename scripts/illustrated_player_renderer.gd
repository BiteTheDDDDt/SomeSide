class_name SideIllustratedPlayers
extends RefCounted

const Pixels=preload("res://scripts/pixel_actor_renderer.gd")
const Gait=preload("res://scripts/player_gait.gd")
const Keys=preload("res://scripts/actor_key_poses.gd")
const Body=preload("res://scripts/player_body_motion.gd")
const PATH="res://assets/art/unified-v0206/players.png"
const REGIONS: Dictionary={
	"ranger":[Rect2(77,53,298,371),Rect2(481,20,309,408),Rect2(895,59,290,374),Rect2(1371,120,326,303)],
	"vanguard":[Rect2(52,475,349,387),Rect2(447,451,367,416),Rect2(882,486,335,358),Rect2(1332,527,407,335)]}
static var _sheet: CanvasTexture
static var _frames: Dictionary={}

static func frame(character: String,index: int=0) -> Dictionary:
	if not REGIONS.has(character): return {}
	if _sheet==null:
		_sheet=CanvasTexture.new(); _sheet.diffuse_texture=load(PATH)
		_sheet.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var key: String=character+str(index)
	if _frames.has(key): return _frames[key]
	var region: Rect2=REGIONS[character][index]
	var atlas:=AtlasTexture.new(); atlas.atlas=_sheet; atlas.region=region; atlas.filter_clip=true
	var factor: float=.113 if character=="ranger" else .11
	var anchors: Array=[188.0,205.0,197.0,230.0] if character=="ranger" else [203.0,241.0,224.0,295.0]
	var target:=Rect2(Vector2(-float(anchors[index])*factor,21.0-region.size.y*factor),region.size*factor)
	if index>0: target.position.y=-20.0 if index!=3 else -15.0
	_frames[key]={"texture":atlas,"target":target,"region":region}
	return _frames[key]

static func portrait(c: CanvasItem,character: String) -> void:
	var f: Dictionary=frame(character)
	if not f.is_empty(): c.draw_texture_rect(f.texture,f.target,false)

static func pose_frame(character: String, index: int) -> Dictionary:
	return frame(character,index) if index<4 else Keys.frame(character,index-4)

static func sample_pose(c: CanvasItem, player: Dictionary, clock: float, action: Dictionary={}) -> Dictionary:
	var animation: String=Pixels.animation_for(player,true)
	var gait: Dictionary=Gait.sample(c,player,clock,animation)
	var pose: Dictionary=Body.sample(c,player,clock,gait,action)
	var shoulder := Vector2.ZERO
	for index: int in pose.weights:
		var f: Dictionary=pose_frame(str(player.get("character","ranger")),index)
		shoulder+=Vector2(f.get("shoulder",Vector2(0,-5)))*float(pose.weights[index])
	pose["socket"]=shoulder
	pose["shoulder"]=Body.transform_point(shoulder,pose)
	if float(pose.landing)>.005 and not bool(gait.get("active",false)):
		pose.gait=Gait.landing_pose(float(pose.landing))
	return pose

static func _draw_plate(c: CanvasItem, f: Dictionary, pose: Dictionary, tint: Color, upper_only: bool) -> void:
	var target: Rect2=f.target
	var socket_shift: Vector2=Vector2(pose.socket)-Vector2(f.get("shoulder",Vector2(0,-5)))
	if not upper_only and socket_shift.is_zero_approx() and Vector2(pose.offset).is_zero_approx() and is_zero_approx(float(pose.angle)):
		c.draw_texture_rect(f.texture,target,false,tint)
		return
	var fraction: float=clampf((1.0+float(pose.landing)*3.0-target.position.y)/target.size.y,0,1) if upper_only else 1.0
	# A short strip mesh moves shoulders and hips, while ground soles remain
	# exactly on their authored baseline. No whole-image squash/stretch.
	var strips: int=1 if upper_only and socket_shift.is_zero_approx() else 6
	for row: int in range(strips):
		var points:=PackedVector2Array()
		var uv:=PackedVector2Array()
		for corner: Vector2 in [Vector2(0,row/float(strips)),Vector2(1,row/float(strips)),Vector2(1,(row+1)/float(strips)),Vector2(0,(row+1)/float(strips))]:
			var v: float=corner.y*fraction
			var point: Vector2=target.position+Vector2(corner.x,v)*target.size
			point+=socket_shift*(1.0-smoothstep(0.0,5.0,point.y))
			var influence: float=1.0 if upper_only else 1.0-smoothstep(3.0,21.0,point.y)
			points.append(point.lerp(Body.transform_point(point,pose),influence))
			uv.append(Vector2(corner.x,v))
		c.draw_polygon(points,PackedColorArray([tint]),uv,f.texture)

static func draw(c: Node2D,player: Dictionary,clock: float) -> bool:
	var character: String=str(player.get("character","ranger"))
	if not REGIONS.has(character): return false
	var tracked: Dictionary=Pixels.tracked_frame_for(c,character,player,clock,true)
	var tint: Color=tracked.get("tint",Color.WHITE)
	var action: Dictionary=player.get("_melee_pose",{})
	var pose: Dictionary=player.get("_body_pose",{})
	if pose.is_empty(): pose=sample_pose(c,player,clock,action)
	var gait: Dictionary=pose.gait
	if bool(gait.get("active",false)):
		var legs: Dictionary=gait.duplicate(true)
		var shifted: Vector2=Body.transform_point(Vector2(0,2)+(Vector2(legs.hip_shift) if bool(legs.get("landing",false)) else Vector2.ZERO),pose)-Vector2(0,2)
		legs.hip_shift=shifted
		for index: int in range(2):
			legs.legs[index].hip=Vector2(-1.5 if index==0 else 1.5,2)+shifted
			legs.legs[index].knee=Gait.knee(legs.legs[index].hip,legs.legs[index].ankle)
		Gait.draw(c,legs,character,tint)
	for index: int in pose.weights:
		var weight: float=pose.weights[index]
		if weight<.005: continue
		_draw_plate(c,pose_frame(character,index),pose,Color(tint,tint.a*weight),bool(gait.get("active",false)))
	return true
