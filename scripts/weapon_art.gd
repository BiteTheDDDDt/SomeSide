class_name SideWeaponArt
extends RefCounted

## The same material plates form held weapons and all inventory/loot icons.
## Coordinates are gameplay weapon space: grip at x=7.5, fire along local +X.
## SVG is baked once at 4x resolution with filtered mipmaps. Animation moves
## cached parts at the same logical size; no vector rasterization runs per frame.
const Style = preload("res://scripts/art_style.gd")
const IDS: Array[String] = ["pulse_rifle","arc_blade","scattergun","railgun","flamethrower","boomerang","storm_staff","sun_lance"]
const BOUNDS := Rect2(-6,-18,66,36)
const RASTER_SCALE: float = 4.0
static var _cache: Dictionary = {}
static var _cache_bytes: int = 0
static var _icon_layouts: Dictionary = {}

static func _body(id: String) -> String:
	return Style.weapon(id)

static func _part(id: String) -> String:
	match id:
		"pump": return '<path d="M20 1H31V6L29 8H21L19 6Z" fill="#0c1921"/><path d="M21 2H30V5L28 7H22L20 5Z" fill="#94714d"/><path d="M21 2H30V3H21Z" fill="#c7a778"/><path d="M22 4H23V6H22ZM25 4H26V6H25ZM28 4H29V5H28Z" fill="#5c4b3a"/>'
		"vent_top": return '<path d="M13-6H23V-2H13Z" fill="#14252f"/><path d="M14-5H22V-3H14Z" fill="#8f9aa4"/><path d="M15-5H16V-3H15ZM18-5H19V-3H18ZM21-5H22V-3H21Z" fill="#526476"/><path d="M14-5H21V-4H14Z" fill="#c4c7bc"/>'
		"vent_bottom": return '<path d="M13 2H23V6H13Z" fill="#14252f"/><path d="M14 3H22V5H14Z" fill="#596e7d"/><path d="M15 3H16V5H15ZM18 3H19V5H18ZM21 3H22V5H21Z" fill="#9eaaa9"/>'
	return ""

static func _assembly(id: String) -> String:
	var result: String=_body(id)
	if id=="scattergun": result+=_part("pump")
	elif id=="railgun": result+=_part("vent_top")+_part("vent_bottom")
	return result

static func icon_drawing(id: String) -> String:
	if id not in IDS: return ""
	# Fit the actual rotated silhouette once. A generic barrel rectangle wastes
	# most small inventory cells on empty corners around these slender objects.
	if not _icon_layouts.has(id):
		var probe := Image.new()
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-64 -64 128 128"><g transform="rotate(-42)">'+_assembly(id)+'</g></svg>'
		if probe.load_svg_from_string(svg) != OK: return ""
		var bounds: Rect2i = probe.get_used_rect()
		var center: Vector2 = Vector2(bounds.position) + Vector2(bounds.size)*.5 - Vector2(64,64)
		_icon_layouts[id] = {"center":center,"zoom":54.0/float(maxi(bounds.size.x,bounds.size.y))}
	var layout: Dictionary = _icon_layouts[id]
	return '<g transform="translate(32 32) scale(%.5f) translate(%.3f %.3f) rotate(-42)">%s</g>'%[float(layout.zoom),-Vector2(layout.center).x,-Vector2(layout.center).y,_assembly(id)]

static func _texture(key: String, drawing: String) -> Texture2D:
	if _cache.has(key): return _cache[key]
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="66" height="36" viewBox="-6 -18 66 36" shape-rendering="geometricPrecision">'+Style.svg(drawing)+'</svg>'
	var bitmap:=Image.new()
	if bitmap.load_svg_from_string(svg, RASTER_SCALE)!=OK:
		push_error("Weapon art could not rasterize: "+key)
		return null
	# Colour transparent edge texels before filtering to avoid dark fringes.
	# Mipmaps retain area coverage when this larger image is drawn at 1x.
	bitmap.fix_alpha_edges()
	bitmap.generate_mipmaps()
	var sampler:=CanvasTexture.new()
	sampler.diffuse_texture=ImageTexture.create_from_image(bitmap)
	sampler.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key]=sampler
	_cache_bytes += bitmap.get_data_size()
	return sampler

static func _draw_part(canvas: CanvasItem, id: String, offset: Vector2=Vector2.ZERO) -> void:
	canvas.draw_texture_rect(_texture(id,_part(id)),Rect2(BOUNDS.position+offset,BOUNDS.size),false)

static func draw(canvas: CanvasItem, id: String, mechanism: float=0.0, energy: float=0.0) -> void:
	if id not in IDS: id="pulse_rifle"
	var motion: float=clampf(mechanism,0.0,1.0) if is_finite(mechanism) else 0.0
	var charge: float=clampf(energy,0.0,1.0) if is_finite(energy) else 0.0
	canvas.draw_texture_rect(_texture(id,_body(id)),BOUNDS,false)
	if id=="scattergun": _draw_part(canvas,"pump",Vector2(-roundf(motion*5.0),0))
	elif id=="railgun":
		_draw_part(canvas,"vent_top",Vector2(0,-roundf(motion*2.0)))
		_draw_part(canvas,"vent_bottom",Vector2(0,roundf(motion*2.0)))
	# Energy remains inside the engineered channels; muzzle particles are owned
	# by WorldView. No luminous disc can conceal the tip or the player's head.
	if charge>0.01:
		match id:
			"railgun": canvas.draw_rect(Rect2(31,-1,14,1),Color(0.66,0.78,0.91,charge*.8))
			"flamethrower": canvas.draw_rect(Rect2(44,0,1,1),Color(1,.73,.37,charge))
			"storm_staff": canvas.draw_rect(Rect2(37,-1,10,1),Color(.75,.94,.89,charge))
			"sun_lance": canvas.draw_rect(Rect2(34,-1,9,1),Color(1,.9,.59,charge))

static func cache_stats() -> Dictionary:
	return {"textures":_cache.size(),"bytes":_cache_bytes,"maximum_textures":11}
