class_name SideIllustratedPlayers
extends RefCounted

const Pixels=preload("res://scripts/pixel_actor_renderer.gd")
const Gait=preload("res://scripts/player_gait.gd")
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

static func draw(c: Node2D,player: Dictionary,clock: float) -> bool:
	var character: String=str(player.get("character","ranger"))
	if not REGIONS.has(character): return false
	var tracked: Dictionary=Pixels.tracked_frame_for(c,character,player,clock,true)
	var animation: String=str(tracked.get("animation","idle"))
	var index: int=1 if animation in ["jump","rise"] else (2 if animation=="fall" else (3 if animation=="dash" else 0))
	var f: Dictionary=frame(character,index)
	var tint: Color=tracked.get("tint",Color.WHITE)
	var gait: Dictionary=Gait.sample(c,player,clock,animation)
	var motion: Dictionary=player.get("_melee_pose",{})
	var split: bool=bool(gait.active) or bool(motion.get("active",false))
	if not split:
		c.draw_texture_rect(f.texture,f.target,false,tint)
		return true
	var target: Rect2=f.target
	var source: Rect2=Rect2(Vector2.ZERO,Rect2(f.region).size)
	var cut: float=1.0
	var fraction: float=clampf((cut-target.position.y)/target.size.y,0,1)
	var upper_source:=Rect2(Vector2.ZERO,Vector2(source.size.x,source.size.y*fraction))
	var upper_target:=Rect2(target.position,Vector2(target.size.x,cut-target.position.y))
	if bool(gait.active): Gait.draw(c,gait,character,tint)
	else:
		c.draw_texture_rect_region(f.texture,Rect2(Vector2(target.position.x,cut),Vector2(target.size.x,target.end.y-cut)),Rect2(Vector2(0,upper_source.size.y),Vector2(source.size.x,source.size.y-upper_source.size.y)),tint)
	if bool(motion.get("active",false)) and motion.has("draw_origin"):
		var facing: float=float(motion.facing)
		c.draw_set_transform(Vector2(motion.draw_origin)+Vector2(0,5),float(motion.body_angle)*facing,Vector2(facing,1))
		upper_target.position-=Vector2(0,5)
		c.draw_texture_rect_region(f.texture,upper_target,upper_source,tint)
		c.draw_set_transform(motion.draw_origin,0,Vector2(facing,1))
	else: c.draw_texture_rect_region(f.texture,upper_target,upper_source,tint)
	return true
