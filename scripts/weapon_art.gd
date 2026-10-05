class_name SideWeaponArt
extends RefCounted

## The same material plates form held weapons and all inventory/loot icons.
## Coordinates are gameplay weapon space: grip at x=7.5, fire along local +X.
## SVG is baked once at 4x resolution with filtered mipmaps. Animation moves
## cached parts at the same logical size; no vector rasterization runs per frame.
const IDS: Array[String] = ["pulse_rifle","arc_blade","scattergun","railgun","flamethrower","boomerang","storm_staff","sun_lance"]
const BOUNDS := Rect2(-6,-18,66,36)
const RASTER_SCALE: float = 4.0
static var _cache: Dictionary = {}
static var _cache_bytes: int = 0
static var _icon_layouts: Dictionary = {}

static func _body(id: String) -> String:
	match id:
		"pulse_rifle":
			return '<path d="M-3-4H3L7-6H23L25-3H33V-2H36V2H25L22 5H19V10H14L13 4H10L9 9H5L6 2H1L-3 4Z" fill="#0c1921"/><path d="M-2-3H2L6-1V2H2L-2 3Z" fill="#51676a"/><path d="M-2-3H2V-1H-2Z" fill="#acb6a5"/><path d="M5-4H22L24-2V2L21 3H6Z" fill="#6f8580"/><path d="M6-4H21V-2H6Z" fill="#bec8b1"/><path d="M6 1H23L21 3H11V1Z" fill="#344e54"/><path d="M7 4H9L8 8H6Z" fill="#766b59"/><path d="M14 4H18V8H15Z" fill="#43585c"/><path d="M15 5H17V6H15ZM15 7H17V8H15Z" fill="#8d9d90"/><path d="M23-2H35V1H23Z" fill="#465b62"/><path d="M25-2H34V-1H25Z" fill="#c9cbb6"/><path d="M34-2H36V2H34Z" fill="#253840"/><path d="M35-1H36V1H35Z" fill="#95aea6"/><path d="M10-7H17V-5H10Z" fill="#0c1921"/><path d="M11-7H16V-6H11Z" fill="#9bafaa"/><path d="M15-2H22V0H15Z" fill="#192f38"/><path d="M16-2H21V-1H16Z" fill="#70c7b7"/><path d="M8-2H10V0H8Z" fill="#b58d63"/><path d="M24-1H25V2H24ZM29-1H30V1H29Z" fill="#263c43"/>'
		"scattergun":
			return '<path d="M-4-4H2L6-6H18L21-4H38V2H35V5H18L14 3L12 10H7L8 2H3L-4 4Z" fill="#0c1921"/><path d="M-3-3H2L6-1V2H2L-3 3Z" fill="#87664c"/><path d="M-2-3H2L5-1H-2Z" fill="#c2a378"/><path d="M5-4H17L20-2V2H6Z" fill="#717d79"/><path d="M6-4H17V-2H6Z" fill="#bac4b0"/><path d="M6 1H17L14 3H9Z" fill="#394e53"/><path d="M9 3H12L10 9H8Z" fill="#947052"/><path d="M9 4H11V5H9ZM8 7H10V8H8Z" fill="#57473b"/><path d="M17-3H37V0H17Z" fill="#465b62"/><path d="M20-3H35V-2H20Z" fill="#c5c9b6"/><path d="M19 2H34V4H19Z" fill="#566863"/><path d="M36-3H38V2H36Z" fill="#768c88"/><path d="M37-1H38V1H37Z" fill="#202e37"/><path d="M27-5H30V-3H27Z" fill="#c0a27a"/><path d="M10-2H15V0H10Z" fill="#273943"/><path d="M11-2H14V-1H11Z" fill="#b89b71"/><path d="M17-1H19V1H17Z" fill="#c49867"/>'
		"railgun":
			return '<path d="M-5-4H1L6-6H25L29-4H52V4H30L25 6H19L17 11H12L12 5H8L6 9H2L4 2H-2L-5 4Z" fill="#0c1921"/><path d="M-4-3H0L5-1V2H-1L-4 3Z" fill="#627985"/><path d="M-4-3H0V-1H-4Z" fill="#bbc9c6"/><path d="M5-4H24L28-2V3H6Z" fill="#637d90"/><path d="M6-4H23V-2H6Z" fill="#b1bec2"/><path d="M6 1H27L24 4H16L12 3H6Z" fill="#344b60"/><path d="M4 4H7L5 8H3Z" fill="#8c816a"/><path d="M13 5H18L16 10H13Z" fill="#405765"/><path d="M14 6H17V7H14ZM14 8H16V9H14Z" fill="#a7aeac"/><path d="M12-10H24V-6H12Z" fill="#0c1921"/><path d="M13-9H22V-7H13Z" fill="#5c7181"/><path d="M14-9H21V-8H14Z" fill="#b9c8c7"/><path d="M23-9H24V-7H23Z" fill="#70bbc5"/><path d="M27-3H50V-1H27ZM28 1H50V3H28Z" fill="#7f9ba5"/><path d="M29-3H49V-2H29Z" fill="#d0d3c0"/><path d="M30 2H48V3H30Z" fill="#334f64"/><path d="M28-1H49V1H28Z" fill="#1f3949"/><path d="M31-1H45V0H31Z" fill="#739bb8"/><path d="M49-3H52V4H49Z" fill="#314652"/><path d="M50-3H52V-1H50ZM50 2H52V3H50Z" fill="#a3b3b0"/><path d="M9-2H11V0H9Z" fill="#c39c71"/><path d="M24-1H26V2H24Z" fill="#ad875e"/>'
		"flamethrower":
			return '<path d="M-3-4H3L7-6H25L29-4H41L46-3V3L41 5H29L25 3V13L22 16H13L10 13V5H8L7 10H3L4 3H0L-3 4Z" fill="#0c1921"/><path d="M-2-3H2L6-1V2H1L-2 3Z" fill="#6c7168"/><path d="M5-4H24L28-2V2H7Z" fill="#8f7359"/><path d="M7-4H24V-2H7Z" fill="#d0b891"/><path d="M7 1H26L24 3H9Z" fill="#4c4d45"/><path d="M5 4H8L6 9H4Z" fill="#635b4d"/><path d="M12 5H23V12L21 14H14L12 12Z" fill="#a96e48"/><path d="M13 6H16V12H13Z" fill="#d5a06c"/><path d="M21 6H23V12L21 14H18V13H21Z" fill="#6b4a3a"/><path d="M11 8H24V10H11Z" fill="#35474d"/><path d="M15 3H21V5H15Z" fill="#3b4a4c"/><path d="M25-3H40V3H25Z" fill="#566968"/><path d="M27-3H40V-2H27Z" fill="#b9baa6"/><path d="M28-1H30V2H28ZM32-1H34V2H32ZM36-1H38V2H36Z" fill="#172b32"/><path d="M40-3H45V3H40Z" fill="#a0805c"/><path d="M41-2H46V-1H41ZM41 2H46V3H41Z" fill="#d1b88d"/><path d="M44-1H46V2H44Z" fill="#332d2c"/><path d="M44 0H45V1H44Z" fill="#dc9960"/><path d="M22 11H27V7H33V5H25V9H22Z" fill="#87684e"/><path d="M10-2H15V0H10Z" fill="#263a3d"/><path d="M11-2H14V-1H11Z" fill="#b5bf9d"/>'
		"boomerang":
			return '<path d="M2-3H14L12-11L13-17L18-16L29-9L36-1V1L29 9L18 16L13 17L12 11L14 3H2Z" fill="#0c1921"/><path d="M3-2H14V2H3Z" fill="#6b776f"/><path d="M4-2H12V-1H4Z" fill="#b8c1ab"/><path d="M5-1H7V2H5ZM9-1H11V2H9Z" fill="#3a4f4f"/><path d="M14-15L18-14L28-8L34-1H29L21-7L15-10Z" fill="#a7b8ab"/><path d="M14-15L18-14L27-8H24L16-12Z" fill="#e0dfc4"/><path d="M15-10L21-7L29-1H25L17-6Z" fill="#4c7372"/><path d="M14 15L18 14L28 8L34 1H29L21 7L15 10Z" fill="#7c9a92"/><path d="M14 15L18 14L27 8H24L16 12Z" fill="#c1c8af"/><path d="M15 10L21 7L29 1H25L17 6Z" fill="#35595b"/><path d="M14-4H24L36-1V1L24 4H14Z" fill="#47656b"/><path d="M15-3H23L29-1H24L15-1Z" fill="#a9b9b0"/><path d="M18-3H22V3H18Z" fill="#ab8963"/><path d="M19-2H21V2H19Z" fill="#263d45"/><path d="M25-1H34V0H25Z" fill="#68b3a4"/>'
		"storm_staff":
			return '<path d="M-2-3H23L27-5H32L32-8L37-12H43L47-7L48-2V2L47 7L43 12H37L32 8V5H27L23 3H-2Z" fill="#0c1921"/><path d="M-1-2H25V2H-1Z" fill="#5d7580"/><path d="M0-2H24V-1H0Z" fill="#b8bdae"/><path d="M4-3H13V3H4Z" fill="#423f48"/><path d="M5-2H6V2H5ZM8-2H9V2H8ZM11-2H12V2H11Z" fill="#a69585"/><path d="M18-3H20V3H18Z" fill="#ac895f"/><path d="M24-3H33V3H24Z" fill="#736f87"/><path d="M25-3H32V-1H25Z" fill="#b5b3be"/><path d="M26 1H32V3H26Z" fill="#46465b"/><path d="M33-5L34-8L38-10H42L45-6L46-2H43L41-6H38L37-3Z" fill="#8797a6"/><path d="M35-8L38-10H42L44-7H41L40-8H38Z" fill="#d4d3c2"/><path d="M33 5L34 8L38 10H42L45 6L46 2H43L41 6H38L37 3Z" fill="#607b88"/><path d="M35 7L38 9H42L43 7H39Z" fill="#acbcb2"/><path d="M34-2H46V2H34Z" fill="#384e60"/><path d="M37-1H46V1H37Z" fill="#6bbab9"/><path d="M44-2H48V2H44Z" fill="#6b8187"/><path d="M46-1H48V1H46Z" fill="#bedbd0"/><path d="M30-2H32V0H30Z" fill="#b98d67"/>'
		"sun_lance":
			return '<path d="M-4-2H26L29-7H33L34-5L43-5L58 0L43 5H34L33 7H29L26 2H-4Z" fill="#0c1921"/><path d="M-3-1H28V1H-3Z" fill="#af9773"/><path d="M-1-1H23V0H-1Z" fill="#e0cc9f"/><path d="M2-3H12V3H2Z" fill="#393f42"/><path d="M3-2H4V2H3ZM6-2H7V2H6ZM9-2H10V2H9Z" fill="#8c8070"/><path d="M19-2H22V2H19Z" fill="#667971"/><path d="M27-3L30-6H32V-3L30-1L32 3V6H30L27 3Z" fill="#a58558"/><path d="M28-3L30-5H31V-3L29-1Z" fill="#dfc693"/><path d="M33-3L43-4L57 0L43 3H33Z" fill="#bdc4b0"/><path d="M34-3L43-4L56 0L44-1H34Z" fill="#e1dfbf"/><path d="M34 1L44 0L55 0L43 3H34Z" fill="#6c7c75"/><path d="M32-1H43L54 0L43 1H32Z" fill="#b99c60"/><path d="M34-1H43L49 0H34Z" fill="#efce87"/>'
		"arc_blade":
			return '<path d="M0-3H10L11-7H14L15-4H34L47 0L36 4H15L14 7H11L10 3H0Z" fill="#0c1921"/><path d="M1-2H10V2H1Z" fill="#786c59"/><path d="M2-2H9V-1H2Z" fill="#bcb391"/><path d="M3-1H4V2H3ZM6-1H7V2H6Z" fill="#3c4543"/><path d="M0-2H2V2H0Z" fill="#a9a58a"/><path d="M11-5H13L14-2V2L13 5H11Z" fill="#98734e"/><path d="M11-5H12V4H11Z" fill="#d4b17a"/><path d="M15-3H34L46 0L35 3H15Z" fill="#869d9a"/><path d="M15-3H34L45 0L34-1H15Z" fill="#d8dfcc"/><path d="M15 1H35L44 0L35 3H15Z" fill="#475f64"/><path d="M16-1H35L44 0H16Z" fill="#bdc9b4"/><path d="M17 0H33L36 1H17Z" fill="#b08c54"/><path d="M16-2H19V-1H16Z" fill="#f1e3b8"/>'
	return ""

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
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="66" height="36" viewBox="-6 -18 66 36" shape-rendering="geometricPrecision">'+drawing+'</svg>'
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
