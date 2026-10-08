class_name SideSelectedEnemyFX
extends RefCounted

## User-selected spore A / stone C. Original PNGs remain unmodified; source
## rectangles and fixed baseline anchors are authored metadata, not new images.
const MANIFEST: String="res://assets/fx/v0209/manifest.json"
static var _data: Dictionary={}
static var _textures: Dictionary={}
static var _extra: Dictionary={}
static var _supplement: CanvasTexture
static func prepare() -> void:
	if not _data.is_empty(): return
	_data=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_extra=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/motion-v0210/fx-manifest.json"))
	_supplement=CanvasTexture.new()
	_supplement.diffuse_texture=load("res://assets/art/motion-v0210/fx-inbetweens.png")
	_supplement.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	for family: String in _data:
		var texture: Texture2D=load(str(_data[family].path))
		var sampled:=CanvasTexture.new()
		sampled.diffuse_texture=texture
		sampled.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_textures[family]=sampled

static func frame_index(active: bool, progress: float, ending: bool=false) -> int:
	if ending: return 7
	return (4 if active else 0)+clampi(int(clampf(progress,0,1)*(3 if active else 4)),0,2 if active else 3)

static func placement(family: String, index: int, origin: Vector2, radius: float, ground_offset: float=17.0) -> Dictionary:
	prepare()
	var data: Dictionary=_data[family]
	var frame: Dictionary=data.frames[clampi(index,0,7)] if index<8 else _extra[family][clampi(index-8,0,1)]
	var values: Array=frame.region
	var region:=Rect2(values[0],values[1],values[2],values[3])
	var reference:=Vector2(data.reference[0],data.reference[1])
	var scale_value: float=minf(radius*2/reference.x,(radius+ground_offset)/reference.y) if family!="blink" else radius/reference.y
	scale_value*=float(frame.get("scale",1.0))
	var anchor:=Vector2(frame.anchor[0],frame.anchor[1])
	var base: Vector2=origin+(Vector2(0,ground_offset) if family!="blink" else Vector2.ZERO)
	return {"region":region,"rect":Rect2(base-anchor*scale_value,region.size*scale_value),"source":Vector2(frame.source_size[0],frame.source_size[1]) if frame.has("source_size") else Vector2(data.source_size[0],data.source_size[1]),"texture":_supplement if index>=8 else _textures[family],"anchor":base}

static func draw_frame(canvas: CanvasItem, family: String, index: int, origin: Vector2, radius: float, alpha: float=1.0, ground_offset: float=17.0) -> void:
	if alpha<.005: return
	var pose: Dictionary=placement(family,index,origin,radius,ground_offset)
	var rect: Rect2=pose.rect
	var points:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	if family!="blink":
		# Authored pixels, including chips, remain inside the actual hazard.
		var footprint:=PackedVector2Array()
		for i: int in range(64): footprint.append(origin+Vector2.from_angle(TAU*i/64.0)*radius)
		var intersections: Array[PackedVector2Array]=Geometry2D.intersect_polygons(points,footprint)
		if intersections.is_empty(): return
		points=intersections[0]
	var uv:=PackedVector2Array()
	for point: Vector2 in points:
		uv.append((Vector2(pose.region.position)+(point-rect.position)/rect.size*Vector2(pose.region.size))/Vector2(pose.source))
	canvas.draw_polygon(points,PackedColorArray([Color(1,1,1,alpha)]),uv,pose.texture)

static func timeline(active: bool, progress: float, ending: bool=false) -> Dictionary:
	var frames: Array=[9,7] if ending else ([8,4,5,6] if active else [0,1,2,3])
	var ends: Array=[.48,1.0] if ending else ([.10,.27,.68,1.0] if active else [.15,.50,.88,1.0])
	var p: float=clampf(progress,0,1)
	var index: int=0
	while index<ends.size()-1 and p>=float(ends[index]): index+=1
	var start: float=0.0 if index==0 else float(ends[index-1])
	var local: float=(p-start)/maxf(.001,float(ends[index])-start)
	return {"index":frames[index],"next":frames[mini(index+1,frames.size()-1)],"blend":smoothstep(.80,1.0,local) if index<frames.size()-1 else 0.0}

static func _draw_timeline(canvas: CanvasItem,family: String,origin: Vector2,radius: float,sample: Dictionary,alpha: float=1.0) -> void:
	draw_frame(canvas,family,int(sample.index),origin,radius,alpha*(1.0-float(sample.blend)))
	if float(sample.blend)>.005: draw_frame(canvas,family,int(sample.next),origin,radius,alpha*float(sample.blend))

static func draw_area(canvas: CanvasItem, origin: Vector2, sample: Dictionary) -> void:
	var family: String="spore" if str(sample.family).begins_with("spore") else "stone"
	var progress: float=clampf(float(sample.phase),0,1)
	var active: bool=bool(sample.active)
	var radius: float=float(sample.radius)
	if active: canvas.draw_circle(origin,radius,Color("8e9b5f",.12) if family=="spore" else Color("a18c72",.12),true,-1,true)
	_draw_timeline(canvas,family,origin,radius,timeline(active,progress))

static func draw_recovery(canvas: CanvasItem,family: String,origin: Vector2,radius: float,progress: float) -> void:
	_draw_timeline(canvas,family,origin,radius,timeline(false,progress,true),1.0-smoothstep(.55,1,progress))

static func blink_timeline(progress: float, ending: bool=false, departing: bool=false) -> Dictionary:
	var p: float=clampf(progress,0,1)
	# Departure snaps shut early; arrival opens quickly, holds briefly and
	# leaves a short collapse. Both retain the approved eight source poses.
	var frames: Array=[0,1,2,3] if not ending else ([4,5,6,7] if departing else [1,3,4,5,6,7])
	var ends: Array=[.20,.52,.82,1.0] if not ending else ([.12,.28,.48,1.0] if departing else [.12,.26,.54,.72,.90,1.0])
	var i: int=0
	while i<frames.size()-1 and p>=float(ends[i]): i+=1
	return {"index":frames[i],"alpha":1.0 if not ending else 1.0-smoothstep(.48 if departing else .72,1.0,p)}

static func draw_blink(canvas: CanvasItem, origin: Vector2, progress: float, ending: bool=false, departing: bool=false) -> void:
	var sample: Dictionary=blink_timeline(progress,ending,departing)
	draw_frame(canvas,"blink",int(sample.index),origin,58.0,float(sample.alpha))

static func draw_seed(canvas: CanvasItem, origin: Vector2, direction: Vector2, radius: float) -> void:
	prepare()
	var frame: Dictionary=_data.spore.frames[0]
	var values: Array=frame.region
	var region:=Rect2(values[0],values[1],values[2],values[3])
	var source:=Vector2(_data.spore.source_size[0],_data.spore.source_size[1])
	var scale_value: float=radius*2.0/maxf(region.size.x,region.size.y)
	var points:=PackedVector2Array()
	var uv:=PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO,Vector2(region.size.x,0),region.size,Vector2(0,region.size.y)]:
		points.append(origin+((corner-region.size*.5)*scale_value).rotated(direction.angle()+PI*.5))
		uv.append((region.position+corner)/source)
	canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,_textures.spore)

static func cache_stats() -> Dictionary:
	prepare()
	var bytes: int=0
	for texture: CanvasTexture in _textures.values(): bytes+=texture.get_width()*texture.get_height()*4
	bytes+=_supplement.get_width()*_supplement.get_height()*4
	return {"textures":_textures.size()+1,"bytes":bytes,"max_bytes":10*1024*1024}
