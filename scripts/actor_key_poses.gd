class_name SideActorKeyPoses
extends RefCounted

## Supplemental original poses. Source pixels remain unchanged; rectangles,
## ground baselines and organ sockets are explicit asset metadata.
const PATH = "res://assets/art/motion-v0210/manifest.json"
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _frames: Dictionary = {}

static func prepare() -> void:
	if not _data.is_empty(): return
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for path: String in _data.sheets:
		var texture := CanvasTexture.new()
		texture.diffuse_texture = load(path)
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_textures[path] = texture

static func frame(actor: String, index: int) -> Dictionary:
	prepare()
	if not _data.actors.has(actor) or index<0 or index>=_data.actors[actor].frames.size(): return {}
	var key: String = actor + ":" + str(index)
	if _frames.has(key): return _frames[key]
	if not _data.actors.has(actor): return {}
	var description: Dictionary = _data.actors[actor]
	var pose: Dictionary = description.frames[clampi(index, 0, description.frames.size()-1)]
	var r: Array = pose.region
	var region := Rect2(r[0],r[1],r[2],r[3])
	var anchor := Vector2(pose.anchor[0],pose.anchor[1])
	var factor: float = description.scale
	var baseline: float = description.baseline
	var target := Rect2(Vector2(0,baseline)-anchor*factor,region.size*factor)
	var atlas := AtlasTexture.new()
	atlas.atlas = _textures[description.path]
	var ratio: Vector2 = _textures[description.path].get_size()/Vector2(description.source_size[0],description.source_size[1])
	atlas.region = Rect2(region.position*ratio,region.size*ratio)
	atlas.filter_clip = true
	var organ := Vector2(pose.socket[0],pose.socket[1])
	_frames[key] = {"texture":atlas,"region":region,"target":target,
		"sole":target.position+anchor*factor,"socket":organ,"shoulder":target.position+organ*factor,"source_size":_textures[description.path].get_size()}
	return _frames[key]

static func stats() -> Dictionary:
	prepare()
	var bytes: int = 0
	for texture: Texture2D in _textures.values(): bytes += texture.get_width()*texture.get_height()*4
	return {"textures":_textures.size(),"bytes":bytes,"frames":_frames.size(),"max_bytes":14*1024*1024}
