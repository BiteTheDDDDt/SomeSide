class_name SideSelectedEnemyFX
extends RefCounted

## User-selected spore A / stone C. Original PNGs remain unmodified; source
## rectangles and fixed baseline anchors are authored metadata, not new images.
const MANIFEST: String="res://assets/fx/v0209/manifest.json"
static var _data: Dictionary={}
static var _textures: Dictionary={}
static func prepare() -> void:
	if not _data.is_empty(): return
	_data=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
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
	var frame: Dictionary=data.frames[clampi(index,0,7)]
	var values: Array=frame.region
	var region:=Rect2(values[0],values[1],values[2],values[3])
	var reference:=Vector2(data.reference[0],data.reference[1])
	var scale_value: float=minf(radius*2/reference.x,(radius+ground_offset)/reference.y) if family!="blink" else radius/reference.y
	var anchor:=Vector2(frame.anchor[0],frame.anchor[1])
	var base: Vector2=origin+(Vector2(0,ground_offset) if family!="blink" else Vector2.ZERO)
	return {"region":region,"rect":Rect2(base-anchor*scale_value,region.size*scale_value),"source":Vector2(data.source_size[0],data.source_size[1]),"texture":_textures[family],"anchor":base}

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

static func draw_area(canvas: CanvasItem, origin: Vector2, sample: Dictionary) -> void:
	var family: String="spore" if str(sample.family).begins_with("spore") else "stone"
	var progress: float=clampf(float(sample.phase),0,1)
	var active: bool=bool(sample.active)
	var radius: float=float(sample.radius)
	if active:
		# Filled footprint exists only during damage; no orange/red boundary.
		canvas.draw_circle(origin,radius,Color("8e9b5f",.12) if family=="spore" else Color("a18c72",.12),true,-1,true)
	var count: int=3 if active else 4
	var phase: float=progress*count
	var index: int=frame_index(active,progress)
	var next: int=mini(index+1,6 if active else 3)
	var blend: float=smoothstep(.35,.85,fposmod(phase,1.0)) if next!=index else 0.0
	draw_frame(canvas,family,index,origin,radius,1.0-blend)
	if blend>0: draw_frame(canvas,family,next,origin,radius,blend)

static func draw_blink(canvas: CanvasItem, origin: Vector2, progress: float, ending: bool=false, departing: bool=false) -> void:
	var phase: float=clampf(progress,0,1)
	var index: int=clampi(int(phase*4),0,3) if not ending else (clampi(4+int(phase*4),4,7) if departing else clampi(4+int(phase*3),4,6))
	draw_frame(canvas,"blink",index,origin,58.0,1.0 if not ending else 1.0-smoothstep(.65,1,phase))

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
	return {"textures":_textures.size(),"bytes":bytes,"max_bytes":7*1024*1024}
