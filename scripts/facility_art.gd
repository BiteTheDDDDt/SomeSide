class_name SideFacilityArt
extends RefCounted

## Five small machines, baked on demand. All state variants share a 64px
## logical footprint; physics and interaction radii remain in the simulation.
const Style = preload("res://scripts/art_style.gd")
const KINDS: Array[String] = ["cache", "choice", "blood", "combat", "equipment"]
const BOUNDS := Rect2(-32,-54,64,64)
const MAX_TEXTURES: int = 16
static var _textures: Dictionary = {}
static var _bytes: int = 0

static func state_for(chest: Dictionary) -> String:
	if bool(chest.get("locked",false)): return "locked"
	if bool(chest.get("opened",false)) or str(chest.get("status",""))=="cleared": return "open"
	return "active" if str(chest.get("type",""))=="combat" and str(chest.get("status",""))=="active" else "idle"

static func accent(kind: String) -> Color:
	match kind:
		"choice": return Color("7df3d0")
		"blood": return Color("f69c9f")
		"combat": return Color("fa8855")
		"equipment": return Color("8dc8ed")
	return Color("ffc176")

static func texture(kind: String, state: String="idle") -> Texture2D:
	if kind not in KINDS: kind="cache"
	if state not in ["idle","open","locked"] and not (kind=="combat" and state=="active"): state="idle"
	var key: String=kind+":"+state
	if _textures.has(key): return _textures[key]
	var tint: Color=Color("617a78") if state in ["open","locked"] else accent(kind)
	var drawing: String=Style.svg(_drawing(kind,state)).replace("ACCENT","#"+tint.to_html(false))
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-32 -54 64 64" shape-rendering="geometricPrecision"><g stroke-linejoin="round">'+drawing+'</g></svg>'
	var image:=Image.new()
	if image.load_svg_from_string(svg,4.0)!=OK:
		push_error("Facility SVG could not load: "+key)
		return null
	image.fix_alpha_edges(); image.generate_mipmaps()
	var source:=ImageTexture.create_from_image(image)
	source.set_size_override(Vector2i(64,64))
	var result:=CanvasTexture.new()
	result.diffuse_texture=source
	result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	_textures[key]=result
	_bytes+=image.get_data_size()
	return result

static func cache_stats() -> Dictionary:
	return {"textures":_textures.size(),"bytes":_bytes,"max_textures":MAX_TEXTURES,"max_bytes":MAX_TEXTURES*349524}

static func _drawing(kind: String, state: String) -> String:
	return Style.facility(kind,state)
