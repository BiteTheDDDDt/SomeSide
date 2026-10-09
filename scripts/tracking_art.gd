class_name SideTrackingArt
extends RefCounted

const Geometry=preload("res://scripts/combat_geometry.gd")
const Clips=preload("res://scripts/motion_clips_24.gd")
const INK:=Color("424e55")
const LIGHT:=Color("d6dfd2")
const FRIEND:=Color("a2c7bd")
const HOSTILE:=Color("d29ca8")
static var _textures: Dictionary={}

static func texture(key: String,svg: String,size: Vector2) -> Texture2D:
	if _textures.has(key): return _textures[key]
	var image:=Image.new()
	var source: String='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'%[int(size.x),int(size.y),int(size.x),int(size.y)]+svg+'</svg>'
	if image.load_svg_from_string(source,4.0)!=OK: return null
	image.fix_alpha_edges(); image.generate_mipmaps()
	var result:=CanvasTexture.new(); result.diffuse_texture=ImageTexture.create_from_image(image)
	result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_textures[key]=result
	return result

const WEAVER_PATH="res://assets/art/tracking-v0230/weaver-poses.png"
const WEAVER_REGIONS: Array[Rect2]=[Rect2(55,74,268,410),Rect2(420,50,285,435),Rect2(795,83,285,408),Rect2(1185,158,317,333),Rect2(55,595,289,394),Rect2(476,544,309,402),Rect2(820,636,315,344)]
const WEAVER_HIPS: Array[float]=[173.0,173.0,183.0,233.0,200.0,181.0,190.0]
static var _weaver_sheet: CanvasTexture
static var _weaver_frames: Dictionary={}

static func weaver_frame(index: int) -> Dictionary:
	index=clampi(index,0,6)
	if _weaver_frames.has(index): return _weaver_frames[index]
	if _weaver_sheet==null:
		_weaver_sheet=CanvasTexture.new(); _weaver_sheet.diffuse_texture=load(WEAVER_PATH)
		_weaver_sheet.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var region: Rect2=WEAVER_REGIONS[index]
	var atlas:=AtlasTexture.new(); atlas.atlas=_weaver_sheet; atlas.region=region; atlas.filter_clip=true
	var factor: float=.102
	var target:=Rect2(Vector2(-WEAVER_HIPS[index]*factor,21-region.size.y*factor),region.size*factor)
	if index in [1,2,5]: target.position.y=-20.0
	if index==3: target.position.y=-15.0
	_weaver_frames[index]={"texture":atlas,"target":target,"region":region,"shoulder":Vector2(0,-5)}
	return _weaver_frames[index]

static func beacon_svg() -> String:
	return '<path d="M17 51L22 35H42L48 51L44 55H19Z" fill="#424e55"/><path d="M21 49L24 37H30L28 49Z" fill="#c6d0c4"/><path d="M35 37H40L44 49H36Z" fill="#81999d"/><path d="M27 35V17L32 10L37 17V35Z" fill="#424e55"/><path d="M29 18L32 14L35 18V34H29Z" fill="#a8b7c4"/><path d="M30 20H34V29H30Z" fill="#a2c7bd"/><path d="M17 19L21 14L27 18V29L21 33L17 29ZM37 18L43 14L47 19V29L43 33L37 29Z" fill="#70858f"/><path d="M18 19L21 16L25 19V23H18ZM39 19L43 16L46 20V23H39Z" fill="#cbd1bb"/><path d="M24 48H39V52H24Z" fill="#617983"/>'

static func _poly(c: CanvasItem,points: Array,fill: Color,edge: float=1.2) -> void:
	Geometry.polygon(c,PackedVector2Array(points),fill,edge)

static func moth(c: CanvasItem,enemy: Dictionary,clock: float) -> void:
	var remaining: float=float(enemy.get("telegraph",0))
	var charge: float=clampf(1.0-remaining/maxf(.01,float(enemy.get("telegraph_max",.65))),0,1) if remaining>0 else 0.0
	var recover: float=clampf((float(enemy.get("attack_cd",0))-3.85)/.45,0,1)
	var phase: float=fposmod(clock*1.7+int(enemy.id)*.13,1.0)
	var pose: Dictionary=Clips.sample("tracking/moth/"+("charge" if remaining>0 else "flight"),charge if remaining>0 else phase,func(t: float)->Dictionary: return {"fold":.18+.42*t if remaining>0 else .22+sin(t*TAU)*.13})
	var fold: float=float(pose.fold)
	var tint: Color=Color("9ba7b0").lightened(.15 if float(enemy.get("flash",0))>0 else 0)
	# Faceted fore/hind wings use curved outer silhouettes and large planes.
	for rear: bool in [true,false]:
		var side: float=-1.0 if rear else 1.0
		var angle: float=side*fold
		var points: Array=[]
		for p: Vector2 in [Vector2(-6,-4),Vector2(-20,-32),Vector2(-36,-39),Vector2(-33,-12),Vector2(-25,5),Vector2(-11,10)]: points.append(p.rotated(angle))
		_poly(c,points,Color("667c89") if rear else tint)
		points=[]
		for p: Vector2 in [Vector2(-7,-5),Vector2(-22,-30),Vector2(-32,-33),Vector2(-29,-12),Vector2(-17,2)]: points.append(p.rotated(angle))
		_poly(c,points,Color("b9c6c5") if not rear else Color("8e9eaa"),0)
		_poly(c,[Vector2(-10,4).rotated(angle),Vector2(-27,12).rotated(angle),Vector2(-34,31).rotated(angle),Vector2(-16,23).rotated(angle),Vector2(-5,12).rotated(angle)],Color("788b9b"))
		_poly(c,[Vector2(-11,7).rotated(angle),Vector2(-27,14).rotated(angle),Vector2(-29,24).rotated(angle),Vector2(-17,20).rotated(angle)],Color("aab7bc"),0)
	_poly(c,[Vector2(-16,3),Vector2(-9,-11),Vector2(3,-13),Vector2(13,-4),Vector2(8,9),Vector2(-6,15)],Color("677f8e"))
	_poly(c,[Vector2(-12,0),Vector2(-7,-9),Vector2(2,-10),Vector2(5,-4),Vector2(-3,4)],Color("cad0c4"),0)
	_poly(c,[Vector2(-9,7),Vector2(4,3),Vector2(8,8),Vector2(-3,12)],Color("8fa4ae"),0)
	var aim: Vector2=Geometry.local_direction(enemy)
	var across: Vector2=aim.orthogonal()
	var mouth: Vector2=aim*22.0
	var neck: float=charge*3.0-recover*3.0
	var head: Array=[]
	for p: Vector2 in [Vector2(-15-neck,-8),Vector2(-5,-9),Vector2(0,-4),Vector2(0,4),Vector2(-8,8),Vector2(-16-neck,3)]: head.append(mouth+aim*p.x+across*p.y)
	_poly(c,head,Color("8796a6"))
	Geometry.diamond(c,mouth-aim*8,aim,6,4,Color("cdd6cd"))
	c.draw_line(mouth-across*3,mouth+across*3,INK,3,true)
	if charge>0:
		Geometry.diamond(c,mouth-aim*2,aim,2+charge*2,1.6,HOSTILE)
		for side: int in [-1,1]:
			c.draw_line(mouth-aim*(12*(1-charge)+6)+across*side*6,mouth-aim*5+across*side*3,Color(HOSTILE,.7),1,true)

static func projectile(c: Node2D,shot: Dictionary,p: Vector2,world_offset: Vector2) -> void:
	var trail: Array=shot.get("trail",[])
	var friendly: bool=str(shot.team)=="player"
	var tint: Color=FRIEND if friendly else HOSTILE
	# History, not a predicted path. Bounded samples were produced by authority.
	for i: int in range(1,trail.size()):
		var opacity: float=.12+.38*float(i)/maxi(1,trail.size()-1)
		c.draw_line(Vector2(trail[i-1])+world_offset,Vector2(trail[i])+world_offset,Color(tint,opacity),.7+float(i)/maxi(1,trail.size()),true)
	if not trail.is_empty(): c.draw_line(Vector2(trail.back())+world_offset,p,Color(tint,.7),1.4,true)
	var aim: Vector2=Vector2(shot.vel).normalized()
	var side: Vector2=aim.orthogonal()
	var kind: String=str(shot.kind)
	if kind=="arc_needle":
		c.draw_line(p-aim*7,p+aim*3,INK,3.6,true)
		c.draw_line(p-aim*6,p+aim*3,LIGHT,1.8,true)
		return
	if kind=="engraved_blade":
		_poly(c,[p+aim*9,p+side*3,p-aim*8-side*2,p-aim*3],Color("b9d1cd"))
		c.draw_line(p-aim*3,p+aim*7,LIGHT,1,true)
		return
	if not friendly:
		Geometry.diamond(c,p,aim,8,4.5,HOSTILE,1.5)
		Geometry.diamond(c,p+aim*2,aim,4,2,LIGHT)
		_poly(c,[p-aim*3+side*3,p-aim*9+side*7,p-aim*7],Color("ac8798"))
		return
	_poly(c,[p+aim*9,p-aim*4-side*3.5,p-aim*7,p-aim*4+side*3.5],Color("8da8b3"))
	for sign_value: int in [-1,1]: _poly(c,[p-aim*2+side*sign_value*3,p-aim*7+side*sign_value*6,p-aim*8+side*sign_value*2],Color("b6c9c6"),.7)
	c.draw_line(p-aim*2,p+aim*6,LIGHT,1.7,true)

static func mark(c: CanvasItem,p: Vector2,own: bool,remaining: float) -> void:
	var tint: Color=FRIEND if own else Color("93a9ba")
	var top: Vector2=p+Vector2(0,-38)
	Geometry.diamond(c,top,Vector2.UP,5,3,tint,1)
	c.draw_line(top+Vector2(-5,8),top+Vector2(5,8),Color(tint,.6),1,true)
	c.draw_line(top+Vector2(-5,8),top+Vector2(-5+10*clampf(remaining/4,0,1),8),LIGHT,1.5,true)

static func effect(c: CanvasItem,p: Vector2,kind: String,aim: Vector2,t: float,hostile: bool=false) -> void:
	var tint: Color=HOSTILE if hostile else FRIEND
	var side: Vector2=aim.orthogonal()
	if kind=="impact":
		for i: int in range(3):
			var dir: Vector2=aim.rotated((i-1)*.7)
			Geometry.diamond(c,p+dir*(4+12*t),dir,3*(1-t),1.2*(1-t),Color(tint,1-t))
	elif kind=="disperse":
		for i: int in range(3):
			var offset: Vector2=side*(i-1)*(3+6*t)-aim*3*t
			c.draw_line(p+offset,p+offset+aim*2,Color(tint,(1-t)*.5),1,true)
	elif kind in ["limit","no_target"]:
		c.draw_line(p-side*3-aim*3,p+side*3+aim*3,Color("d7b6a5",1-t),1.4,true)
	elif kind in ["beacon_deploy","engrave"]:
		for sign_value: int in [-1,1]:
			var a: Vector2=p+side*sign_value*(12*(1-t)+4)
			c.draw_line(a,a+aim*5,Color(tint,.7*(1-t)),1.2,true)
	else:
		Geometry.diamond(c,p-aim*2,aim,5*(1-t),2*(1-t),Color(tint,1-t))
