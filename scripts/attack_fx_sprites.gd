class_name SideAttackFxSprites
extends RefCounted

## Authored transparent animation sheets. Regions and anchors are fixed data;
## drawing allocates no textures and never changes the caller's transform.
const MANIFEST_PATH: String = "res://assets/fx/v020/manifest.json"
const MANIFEST_PATHS: Array[String] = [MANIFEST_PATH, "res://assets/fx/v0202/manifest.json"]
const MAX_BYTES: int = 32 * 1024 * 1024
static var _families: Dictionary = {}
static var _textures: Dictionary = {}
static var _sources: Dictionary = {}
static var _loaded: bool = false
static var _bytes: int = 0

static func prepare() -> void:
	if _loaded: return
	_loaded = true
	for path: String in MANIFEST_PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary: _families.merge(parsed.get("families", {}))
	for family: String in _families:
		var info: Dictionary = _families[family]
		var source_path: String = str(info.path)
		if _sources.has(source_path):
			_textures[family] = _sources[source_path]
			continue
		var texture: Texture2D = load(source_path) as Texture2D
		if texture == null: continue
		var memory: int = texture.get_width() * texture.get_height() * 4
		if _bytes + memory > MAX_BYTES: continue
		var sampled := CanvasTexture.new()
		sampled.diffuse_texture = texture
		sampled.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if info.get("filter", "linear") == "nearest" else CanvasItem.TEXTURE_FILTER_LINEAR
		_textures[family] = sampled
		_sources[source_path] = sampled
		_bytes += memory

static func frame_index(family: String, progress: float) -> int:
	prepare()
	var count: int = Array(Dictionary(_families.get(family, {})).get("frames", [])).size()
	return clampi(int(floor(clampf(progress, 0.0, 1.0) * count)), 0, count - 1) if count > 0 else -1

static func frame_data(family: String, progress: float) -> Dictionary:
	var index: int = frame_index(family, progress)
	if index < 0 or not _textures.has(family): return {}
	var info: Dictionary = _families[family]
	var frame: Dictionary = info.frames[index]
	var source: Array = frame.region
	var source_size: Array = info.source_size
	var reference: Array = frame.get("reference", info.reference)
	var anchor: Array = frame.anchor
	return {"texture": _textures[family], "index": index,
		"region": Rect2(source[0], source[1], source[2], source[3]),
		"source_size": Vector2(source_size[0], source_size[1]),
		"reference": Vector2(reference[0], reference[1]),
		"anchor": Vector2(anchor[0], anchor[1])}

static func draw_family(canvas: CanvasItem, family: String, rect: Rect2, progress: float, tint: Color = Color.WHITE) -> bool:
	return draw_oriented(canvas, family, rect.get_center(), rect.size, 0.0, progress, tint)

static func draw_oriented(canvas: CanvasItem, family: String, origin: Vector2, size: Vector2, angle: float, progress: float, tint: Color = Color.WHITE) -> bool:
	var frame: Dictionary = frame_data(family, progress)
	if frame.is_empty() or size.x <= 0.0 or size.y <= 0.0: return false
	var region: Rect2 = frame.region
	var scale_value: Vector2 = size / Vector2(frame.reference)
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(region.size.x, 0), region.size, Vector2(0, region.size.y)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(origin + ((corner - Vector2(frame.anchor)) * scale_value).rotated(angle))
		uv.append((region.position + corner) / Vector2(frame.source_size))
	canvas.draw_polygon(points, PackedColorArray([tint, tint, tint, tint]), uv, frame.texture)
	return true

static func cache_stats() -> Dictionary:
	prepare()
	return {"families": _textures.size(), "textures": _sources.size(), "bytes": _bytes, "max_bytes": MAX_BYTES}
