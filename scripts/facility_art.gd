class_name SideFacilityArt
extends RefCounted

## Five small machines, baked on demand. All state variants share a 64px
## logical footprint; physics and interaction radii remain in the simulation.
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
	var drawing: String=_drawing(kind,state).replace("ACCENT","#"+tint.to_html(false))
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
	var art: String='<ellipse cx="0" cy="7" rx="29" ry="3" fill="#04131b" opacity=".6"/>'
	match kind:
		"cache":
			art+='<path d="M-27-17L-21-24H21L27-17V6L23 9H-23L-27 6Z" fill="#07151e"/><path d="M-24-14H24V5H-24Z" fill="#795f47"/><path d="M-23-13H-11V2H-23ZM11-13H23V2H11Z" fill="#4c5148"/><path d="M-21-11H-13V-8H-21ZM13-11H21V-8H13Z" fill="#acaa8c"/><path d="M-24 2H24V6H-24Z" fill="#34484b"/><path d="M-19 4H-10V7H-19ZM10 4H19V7H10Z" fill="#9a8d70"/><path d="M-10-14H-6V5H-10ZM6-14H10V5H6Z" fill="#b0b39c"/><path d="M-8-13H-6V2H-8ZM8-13H10V2H8Z" fill="#52676a"/>'
			if state=="open":
				art+='<path d="M-24-17V-36L-18-43H18L24-36V-17Z" fill="#0a1e27" stroke="#07151e" stroke-width="3"/><path d="M-21-35L-16-39H16L21-35V-22H-21Z" fill="#3d565c"/><path d="M-18-34H18V-31H-18Z" fill="#9ca994"/><path d="M-24-18H24V-11H-24Z" fill="#071219"/><path d="M-19-14H19" stroke="#85938a" stroke-width="2"/>'
			else:
				art+='<path d="M-26-17L-20-25H20L26-17V-11H-26Z" fill="#916f4e" stroke="#07151e" stroke-width="2"/><path d="M-20-23H20L23-19H-23Z" fill="#c5b995"/><path d="M-24-17H24V-13H-24Z" fill="#4b615f"/><path d="M-10-23H-6V-12H-10ZM6-23H10V-12H6Z" fill="#688480"/><path d="M-4-15H4V-6H-4Z" fill="#142c36" stroke="#bea77e"/><path d="M-2-13H2V-9H-2Z" fill="ACCENT"/>'
		"choice":
			art+='<path d="M-26 8L-23 1H-15L-12-17H12L15 1H23L26 8Z" fill="#081920"/><path d="M-22 6L-20 3H20L22 6Z" fill="#91aaa1"/><path d="M-12 1L-10-14H10L12 1Z" fill="#34515b"/><path d="M-8-11H8V-3H-8Z" fill="#142932" stroke="#748e88"/><path d="M-5-8H5V-6H-5Z" fill="ACCENT"/><path d="M-16-17L-12-21H12L16-17V-13H-16Z" fill="#0b2029"/><path d="M-12-19H12L14-16H-14Z" fill="#9cb6ae"/><path d="M-10-17H10V-15H-10Z" fill="ACCENT"/><path d="M-16-1H-12V3H-16ZM12-1H16V3H12Z" fill="#ad9570"/><path d="M-19 6H-13M13 6H19" stroke="#274650" stroke-width="2"/>'
		"blood":
			art+='<path d="M-27 8L-22 2H-19L-18-26L-11-40L-5-44H5L11-40L18-26L19 2H22L27 8Z" fill="#08151e"/><path d="M-23 5H23L25 7H-25Z" fill="#859895"/><path d="M-16 1L-15-24L-9-36L-6-34L-11-22L-12 1ZM16 1L15-24L9-36L6-34L11-22L12 1Z" fill="#607b7c"/><path d="M-15-25L-9-38M15-25L9-38" stroke="#c0bcb0" stroke-width="2"/><path d="M-8-26L0-36L8-26V-8L3-3H-3L-8-8Z" fill="#472e42" stroke="#0c202a" stroke-width="2"/><path d="M-5-25L0-31L5-25V-10L2-7H-2L-5-10Z" fill="#a35066"/><path d="M-3-19H4V-10L1-8L-3-11Z" fill="ACCENT"/><path d="M-5-24L-2-28V-14H-5Z" fill="#efc6bd"/><path d="M-9-26H9M-9-7H9" stroke="#a2b2a9" stroke-width="3"/><path d="M-3-41H3V-35H-3Z" fill="#758f8d"/><path d="M-5-2H5V4H-5Z" fill="#253e48"/><path d="M-11-13H-20V1H-15M11-13H20V1H15" fill="none" stroke="#806255" stroke-width="3"/>'
		"combat":
			art+='<path d="M-27 8L-22 2H-19L-21-24L-13-34H13L21-24L19 2H22L27 8Z" fill="#081820"/><path d="M-22 5H22L25 7H-25Z" fill="#9da796"/><path d="M-17-22L-11-30H11L17-22L15 1H-15Z" fill="#526773"/><path d="M-15-24L-10-28H10L15-24H-15Z" fill="#bcc3ae"/><path d="M-12-21H12V-3L7 2H-7L-12-3Z" fill="#122c39"/><path d="M-9-18L0-25L9-18V-5L0 0L-9-5Z" fill="#a0704a"/><path d="M-6-17L0-21L6-17V-8L0-4L-6-8Z" fill="#302d2c"/><path d="M-5-16L0-12L5-16V-12L0-8L-5-12Z" fill="ACCENT"/><path d="M-20-18H-16V-4H-20ZM16-18H20V-4H16Z" fill="#b19469"/><path d="M-20-13H-16M16-13H20" stroke="#283f48" stroke-width="2"/><path d="M-7 3H7V6H-7Z" fill="#283f47"/>'
		"equipment":
			art+='<path d="M-27 7V-33L-19-44H19L27-33V7Z" fill="#081923"/><path d="M-24-32L-17-40H17L24-32V4H-24Z" fill="#5d7b85"/><path d="M-18-38H18L21-34H-21Z" fill="#b4c7bd"/><path d="M-17-31H17V1H-17Z" fill="#102d3a" stroke="#071820" stroke-width="2"/><path d="M-21-30H-18V-1H-21ZM18-30H21V-1H18Z" fill="ACCENT"/><path d="M-24 3H24V7H-24Z" fill="#2b4754"/><path d="M-14 4H-7V7H-14ZM7 4H14V7H7Z" fill="#a9ae9a"/><path d="M-6-38H6V-35H-6Z" fill="#16323e"/><path d="M-2-38H3V-36H-2Z" fill="ACCENT"/>'
			if state=="open": art+='<path d="M-19-27L-27-32V-8L-19-4ZM19-27L27-32V-8L19-4Z" fill="#203a47" stroke="#9aafa9"/>'
	if state=="locked":
		art+='<path d="M-6-14V-20Q0-27 6-20V-14" fill="none" stroke="#a4b1a5" stroke-width="2"/><path d="M-8-15H8V-3H-8Z" fill="#132b35" stroke="#83938c"/><path d="M0-12V-6" stroke="#abb4a6" stroke-width="2"/>'
	elif state=="open" and kind!="cache":
		art+='<path d="M-6-14L-1-9L8-19" fill="none" stroke="#9cbfaf" stroke-width="2.5"/>'
	elif state=="active":
		art+='<path d="M-23-24H-20V-16H-23ZM20-24H23V-16H20Z" fill="#ffc18b"/><path d="M-3-35H3V-31H-3Z" fill="#ffdd9f"/>'
	return art
