class_name SideItemIcons
extends RefCounted

## Original equipment miniatures shared by loot, loadout and inventory.
## Smooth SVG miniatures retain logical UI dimensions independently of their
## supersampled backing images. The sampler belongs to each texture so pixel
## actors can keep nearest filtering on the same canvas.
const MAX_RASTER_SIZE: int = 256
const MAX_CACHE_BYTES: int = 32 * 1024 * 1024
static var _textures: Dictionary = {}
static var _texture_costs: Dictionary = {}
static var _last_use: Dictionary = {}
static var _cache_bytes: int = 0
static var _use_order: int = 0
static var _rasterizations: int = 0
const Content = preload("res://scripts/content.gd")
const WeaponArt = preload("res://scripts/weapon_art.gd")


static func rarity_color(rarity: String) -> Color:
	return Content.rarity_color(rarity)


static func rarity_rank(rarity: String) -> int:
	return Content.rarity_rank(rarity)


static func texture(id: String, size: int = 64) -> Texture2D:
	return _texture(id, size, true)


## Ground loot uses the same object without an inventory tile or rarity badge.
static func pickup_texture(id: String, size: int = 32) -> Texture2D:
	return _texture(id, size, false)


static func _texture(id: String, size: int, framed: bool) -> Texture2D:
	var pixels: int = clampi(size, 16, 256)
	var key: String = ("tile:" if framed else "object:") + id + ":" + str(pixels)
	_use_order += 1
	if _textures.has(key):
		_last_use[key] = _use_order
		return _textures[key]
	var raster_size: int = mini(pixels * 4, MAX_RASTER_SIZE)
	var accent: String = color(id).to_html(false)
	var icon: String = _drawing(id)
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="geometricPrecision">' + (_backplate(id) if framed else "") + '<g stroke-linecap="square" stroke-linejoin="miter">' + icon.replace("ACCENT", "#" + accent) + '</g></svg>'
	var bitmap: Image = Image.new()
	var error: Error = bitmap.load_svg_from_string(svg, float(raster_size) / 64.0)
	if error != OK:
		push_error("SomeSide icon could not rasterize: " + id)
		bitmap = Image.create(raster_size, raster_size, false, Image.FORMAT_RGBA8)
		bitmap.fill(color(id))
	bitmap.fix_alpha_edges()
	bitmap.generate_mipmaps()
	var backing: ImageTexture = ImageTexture.create_from_image(bitmap)
	backing.set_size_override(Vector2i(pixels, pixels))
	var result := CanvasTexture.new()
	result.diffuse_texture = backing
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var cost: int = bitmap.get_data_size()
	_make_cache_room(cost)
	_textures[key] = result
	_texture_costs[key] = cost
	_last_use[key] = _use_order
	_cache_bytes += cost
	_rasterizations += 1
	return result


## Eviction only releases our reference; visible controls keep their textures.
## Normal UI sizes stay hot, while exhaustive catalogues cannot grow without
## limit. SVG rasterization occurs only when a requested cache entry is absent.
static func _make_cache_room(cost: int) -> void:
	while _cache_bytes + cost > MAX_CACHE_BYTES and not _textures.is_empty():
		var oldest: String = ""
		var order: int = _use_order + 1
		for key: String in _last_use:
			if int(_last_use[key]) < order:
				oldest = key
				order = int(_last_use[key])
		_cache_bytes -= int(_texture_costs[oldest])
		_textures.erase(oldest)
		_texture_costs.erase(oldest)
		_last_use.erase(oldest)


static func cache_stats() -> Dictionary:
	return {"textures": _textures.size(), "bytes": _cache_bytes,
		"max_bytes": MAX_CACHE_BYTES, "max_raster_size": MAX_RASTER_SIZE,
		"rasterizations": _rasterizations}


static func _backplate(id: String) -> String:
	var plate: String = '<path d="M8 2H56L62 8V56L56 62H8L2 56V8Z" fill="#07151c"/><path d="M8 3H56L61 8V56L56 61H8L3 56V8Z" fill="#10232b" stroke="#29404a"/><path d="M9 6H54L58 10V28H6V10Z" fill="#152b33"/><path d="M6 48H58V55L54 58H10L6 54Z" fill="#0b1b23"/><path d="M9 8H23M7 10V19" fill="none" stroke="#35505a"/>'
	var definition: Dictionary = Content.definition(id)
	if not definition.is_empty():
		var rank: int = rarity_rank(str(definition.rarity))
		var tint: String = rarity_color(str(definition.rarity)).to_html(false)
		for index: int in range(rank+1):
			plate += '<rect x="%d" y="57" width="3" height="2" fill="#%s"/>' % [54-index*5,tint]
	return plate


static func color(id: String) -> Color:
	match id:
		"phase_dash": return Color("6cd6bd")
		"pursuit_protocol": return Color("7ee9c8")
		"reactive_plating": return Color("f2c18c")
		"missile_pod": return Color("ffb37d")
		"landing_coil": return Color("8eddf0")
		"frost_halo": return Color("a8cfff")
		"shoulder_rush", "guard_burst": return Color("f2b96d")
		"overclock": return Color("67e5ef")
		"capacitor": return Color("ffd06f")
		"lens": return Color("ff84be")
		"vitality": return Color("98e39b")
		"thruster", "feather", "dash": return Color("a0b4ff")
		"arc", "pulse_rifle": return Color("9bf5ff")
		"ember", "grenade", "shockwave", "combat", "gate": return Color("ff9b61")
		"moss", "repair_field", "revive": return Color("b6e89f")
		"siphon": return Color("de8be4")
		"coolant", "railgun", "aegis", "equipment_cache": return Color("90caff")
		"glass", "blood": return Color("f89ba5")
		"arc_blade", "scattergun", "cache": return Color("ffd296")
		"choice": return Color("7de5c8")
		"plating": return Color("b9ced3")
		"magnet": return Color("f293bd")
		"harvest", "battery": return Color("e5d47f")
		"frost": return Color("b3e6fa")
		"momentum", "boomerang": return Color("9be0cf")
		"toxin": return Color("a6d884")
		"echo", "graviton": return Color("c7a8f0")
		"piercer", "sun_lance": return Color("ffe2a0")
		"resonator", "storm_staff", "time_warp": return Color("89dbec")
		"phoenix", "meteor", "flamethrower": return Color("ffa77a")
		"nova": return Color("f5c4f5")
		"turret": return Color("b3c8a0")
		_: return Color("b8d7cb")


static func _drawing(id: String) -> String:
	if id in ["pulse_rifle","arc_blade","scattergun","railgun","flamethrower","boomerang","storm_staff","sun_lance"]:
		return WeaponArt.icon_drawing(id)
	match id:
		"overclock":
			return '<path d="M17 8H43L52 17V43L43 52H17L8 43V17Z" fill="#456967" stroke="#071219" stroke-width="3"/><path d="M17 11H42L48 17H18V47H12V18Z" fill="#81a397"/><path d="M21 18H42V41H21Z" fill="#0b222b" stroke="#b2bba0" stroke-width="3"/><path d="M25 23H38V36H25Z" fill="ACCENT"/><path d="M27 25H34V29H27Z" fill="#dcf5dd"/><path d="M17 23H10M17 32H10M17 41H10M46 23H54M46 32H54M46 41H54M23 10V5M32 10V5M41 10V5M23 49V55M32 49V55M41 49V55" stroke="#d2c294" stroke-width="3"/><path d="M39 43H45V46H39ZM20 43H25V46H20Z" fill="#bb9461"/>'
		"capacitor":
			return '<path d="M12 18L18 12H25L30 18V46L25 51H16L12 47ZM34 18L40 12H47L52 18V46L47 51H38L34 47Z" fill="#806c43" stroke="#071219" stroke-width="3"/><path d="M15 22H26V43H15ZM37 22H48V43H37Z" fill="ACCENT"/><path d="M15 22H19V43H15ZM37 22H41V43H37Z" fill="#fff1b4"/><path d="M23 22H26V43H23ZM45 22H48V43H45Z" fill="#b98736"/><path d="M14 18H28M14 46H28M36 18H50M36 46H50M20 13V7H43V13" fill="none" stroke="#cbd0b8" stroke-width="4"/><path d="M18 28H24M40 35H46" stroke="#715835" stroke-width="2"/><path d="M29 36H35V41H29Z" fill="#839893"/>'
		"lens":
			return '<path d="M9 29L17 17H42L53 24V40L45 46H36L30 52H21L17 40H9Z" fill="#56666c" stroke="#071219" stroke-width="3"/><path d="M13 28L20 20H41L46 24H20V38H13Z" fill="#b5c0b6"/><path d="M22 25L29 18H43L50 26V37L43 44H29L22 37Z" fill="#293843" stroke="#071219" stroke-width="2"/><path d="M29 26L34 23H41L46 28V35L40 40H32L27 34Z" fill="#763b68"/><path d="M31 26L40 24L45 29L31 35Z" fill="ACCENT"/><path d="M32 26H38L30 32H28Z" fill="#fbe2e8"/><path d="M20 42H28V47H22ZM10 27H15V33H10Z" fill="#899d9b"/><path d="M48 18V13H53V23M15 19V13H21" fill="none" stroke="#bca78c" stroke-width="3"/>'
		"vitality":
			return '<path d="M23 8H39L47 17V42L40 53H23L16 43V18Z" fill="#607367" stroke="#071219" stroke-width="3"/><path d="M23 13H38L42 20V40L36 47H25L20 40V21Z" fill="#173f3d"/><path d="M23 20H39V38L34 44H27L23 38Z" fill="#386958"/><path d="M28 21L36 24L39 32L34 40L27 37L25 29Z" fill="ACCENT"/><path d="M28 25L33 23L35 29L31 32L28 29Z" fill="#dcf2bd"/><path d="M18 17H45M19 44H44" stroke="#b0c0a5" stroke-width="4"/><path d="M24 8V4H37V8M25 52V57H38V52" fill="#718c79" stroke="#071219" stroke-width="2"/><path d="M13 22H18V37H13M44 24H50V34H44" fill="#81998b" stroke="#071219" stroke-width="2"/>'
		"thruster":
			return '<path d="M20 12L29 16V39L22 49H10L13 37V19ZM44 12L51 19V37L55 49H42L35 39V16Z" fill="#77838b" stroke="#071219" stroke-width="3"/><path d="M20 16L25 19V36L18 38L17 24ZM40 19L45 16L48 24L46 38L39 36Z" fill="#c1cbc1"/><path d="M17 38H26L23 48H13ZM38 38H47L51 48H41Z" fill="#343b51" stroke="#071219" stroke-width="2"/><path d="M17 44H23L19 55H16ZM41 44H47L49 55H45Z" fill="ACCENT"/><path d="M25 18H39V39H25Z" fill="#414f63" stroke="#071219" stroke-width="2"/><path d="M28 23H36V31H28Z" fill="ACCENT"/><path d="M30 24H35V27H30Z" fill="#e6eee8"/><path d="M10 24L5 32V42L14 36M51 24L58 32V42L50 36" fill="#535d76" stroke="#071219" stroke-width="2"/>'
		"arc":
			return '<path d="M21 8H43L49 14V20L44 24L48 42L43 50H20L15 43L19 23L14 19V14Z" fill="#728c8d" stroke="#071219" stroke-width="3"/><path d="M23 13H41V19H23Z" fill="#d9dfca"/><path d="M24 20H40L42 44H22Z" fill="#263a46"/><path d="M20 23L42 28M19 31L43 36M19 39L42 44" stroke="#47797e" stroke-width="6"/><path d="M20 21L42 26M19 29L43 34M19 37L42 42" stroke="ACCENT" stroke-width="3"/><path d="M22 47H42V52H22Z" fill="#aec0b1"/><path d="M28 8V4H35V8M28 51V58H35V51" fill="#9d835a" stroke="#071219" stroke-width="2"/><path d="M12 26H17V42H12M47 26H52V42H47" fill="#4e686f"/>'
		"ember":
			return '<path d="M24 10L38 8L49 21L47 37L40 47H22L14 37L13 22Z" fill="#805542" stroke="#071219" stroke-width="3"/><path d="M24 13L35 11L28 22L17 25Z" fill="#b58359"/><path d="M36 15L45 22L39 30L32 24ZM20 28L29 25L33 35L26 41L19 37ZM38 34L44 30L42 40L37 44Z" fill="ACCENT"/><path d="M25 29L29 29L30 33L25 35ZM39 20L42 23L39 26Z" fill="#ffe3ac"/><path d="M11 33L17 35L22 44H41L47 35L53 33L50 46L42 53H21L13 46Z" fill="#566970" stroke="#071219" stroke-width="3"/><path d="M19 45H44M25 52V57H37V52" fill="none" stroke="#b5b6a1" stroke-width="3"/>'
		"moss":
			return '<path d="M19 13L26 8H38L45 13L49 41H15Z" fill="#5c817d" stroke="#071219" stroke-width="3"/><path d="M23 15L27 12H37L41 16L44 38H20Z" fill="#233e3b"/><path d="M23 18H27V32H23Z" fill="#a2c4b1"/><path d="M18 39L22 31L27 33L31 26L38 30L43 28L47 40Z" fill="#557e4c"/><path d="M22 35L26 32L30 35L34 29L40 34L43 31L45 37H22Z" fill="ACCENT"/><path d="M28 37L34 34L39 40H23Z" fill="#91a978"/><path d="M12 40H52V47L45 54H19L12 47Z" fill="#5c675d" stroke="#071219" stroke-width="3"/><path d="M16 42H48V46H16Z" fill="#b5bda3"/><path d="M20 49H26V52H20ZM37 49H43V52H37Z" fill="#263b36"/>'
		"siphon":
			return '<g transform="rotate(36 32 32)"><path d="M27 5H37V12H27Z" fill="#bcc9c1" stroke="#071219" stroke-width="2"/><path d="M29 12H35V20H29Z" fill="#667f84"/><path d="M21 19H43V25H21Z" fill="#a1b3ac" stroke="#071219" stroke-width="2"/><path d="M24 25H40V45L36 49H28L24 45Z" fill="#395865" stroke="#071219" stroke-width="3"/><path d="M27 28H37V43L34 46H30L27 43Z" fill="#6c3e6c"/><path d="M27 34H37V43L34 46H30L27 43Z" fill="ACCENT"/><path d="M27 28H30V39H27Z" fill="#ddcde2"/><path d="M34 29H39M34 33H39M34 37H39" stroke="#263944" stroke-width="2"/><path d="M29 48H35V53H29Z" fill="#a0b4ac"/><path d="M32 53V62" stroke="#d5e1d4" stroke-width="2"/></g>'
		"coolant":
			return '<path d="M11 15H38L43 20V50H11Z" fill="#597781" stroke="#071219" stroke-width="3"/><path d="M14 18H22V47H14Z" fill="#bdcfca"/><path d="M25 22H37M25 28H37M25 34H37M25 40H37M25 46H37" stroke="#213c49" stroke-width="4"/><path d="M14 25H20M14 33H20M14 41H20" stroke="ACCENT" stroke-width="3"/><path d="M39 10H49V16H39Z" fill="#97acaf" stroke="#071219" stroke-width="2"/><path d="M42 16H50L55 23V43L50 49H41V25Z" fill="#22475c" stroke="#071219" stroke-width="3"/><path d="M44 23H51V39L48 44H44Z" fill="ACCENT"/><path d="M44 22H47V38H44Z" fill="#d5e9dd"/><path d="M17 15V9H34V14M43 50V55H26V50" fill="none" stroke="#587e8a" stroke-width="4"/>'
		"feather":
			return '<path d="M27 17L11 8L6 16L13 37L25 49L32 42L39 49L51 37L58 16L53 8L37 17Z" fill="#617089" stroke="#071219" stroke-width="3"/><path d="M11 13L27 24V32L15 24ZM14 28L27 36V43L18 35ZM53 13L37 24V32L49 24ZM50 28L37 36V43L46 35Z" fill="ACCENT"/><path d="M13 13L25 22M51 13L39 22M18 29L25 34M46 29L39 34" stroke="#e4e9df" stroke-width="2"/><path d="M28 13H36L40 24L37 43H27L24 24Z" fill="#a3b3b9" stroke="#071219" stroke-width="2"/><path d="M28 24H36V35H28Z" fill="#263b51"/><path d="M30 25H34V32H30Z" fill="ACCENT"/><path d="M28 44H36L34 54H30Z" fill="#869ae0" stroke="#071219" stroke-width="2"/>'
		"glass":
			return '<path d="M25 7L40 11L50 29L42 45L25 50L14 31Z" fill="#ac7888" stroke="#071219" stroke-width="3"/><path d="M26 11L37 14L31 27L18 30Z" fill="#f2c4c4"/><path d="M37 14L46 28L32 27Z" fill="ACCENT"/><path d="M18 31L31 29L27 45Z" fill="#d888a3"/><path d="M33 29L46 29L39 42L29 46Z" fill="#644a65"/><path d="M32 13L28 24L35 29L29 34L33 40" fill="none" stroke="#fff0dc" stroke-width="2"/><path d="M12 35L19 37L25 47H39L44 37L51 35L48 48L41 55H23L16 49Z" fill="#566975" stroke="#071219" stroke-width="3"/><path d="M22 49H40M27 54V59H36V54" fill="none" stroke="#b3c4c0" stroke-width="3"/>'
		"plating":
			return '<path d="M14 14L32 7L50 14L47 39L37 54H26L17 41Z" fill="#728990" stroke="#071219" stroke-width="3"/><path d="M17 17L31 12L46 17L43 27H20Z" fill="#d0d3bd"/><path d="M20 29H43L41 38L34 44H28L22 38Z" fill="#9da99d"/><path d="M24 41L30 47H34L40 41L35 51H29Z" fill="#b8c5b5"/><path d="M31 12V24M23 26H41M28 40H36" stroke="#536d73" stroke-width="2"/><path d="M16 21H20V25H16ZM43 21H47V25H43ZM23 36H27V40H23ZM37 36H41V40H37Z" fill="#23373d"/><path d="M29 29H35V33H29Z" fill="ACCENT"/>'
		"magnet":
			return '<path d="M20 10H43L54 22V41L43 52H20L9 40V22Z" fill="#5b6870" stroke="#071219" stroke-width="3"/><path d="M22 14H41L48 23V38L40 47H23L15 38V24Z" fill="#abbdba"/><path d="M24 21H39L43 27V36L37 41H26L20 35V28Z" fill="#132b37" stroke="#071219" stroke-width="2"/><path d="M8 23H22V38H8ZM41 23H55V38H41ZM23 44H41V56H23Z" fill="#814962" stroke="#071219" stroke-width="2"/><path d="M10 25H19V29H10ZM45 25H53V29H45ZM25 46H39V50H25Z" fill="ACCENT"/><path d="M10 32H18M47 32H53M28 53H36" stroke="#c5acb8" stroke-width="2"/><path d="M28 11H36V17H28Z" fill="#e6d1a2"/>'
		"harvest":
			return '<path d="M10 21L19 14H43L52 24V48L44 54H16L10 47Z" fill="#677867" stroke="#071219" stroke-width="3"/><path d="M14 24L21 18H40L46 24V42H14Z" fill="#b3b9a0"/><path d="M18 26H43V39H18Z" fill="#283d39"/><path d="M20 33L25 28L29 31L35 24L42 29V37H20Z" fill="#d7bf64"/><path d="M12 42H51V48H12Z" fill="#4c6256"/><path d="M18 43H25V46H18ZM38 44H46V50H38Z" fill="ACCENT"/><path d="M27 50H34V56H27Z" fill="#a9b89c" stroke="#071219" stroke-width="2"/><path d="M43 10L50 7L55 11V20L49 24L43 20Z" fill="#c99545" stroke="#071219" stroke-width="2"/><path d="M47 10L50 9L53 12V18L49 21L46 18Z" fill="#ffe49a"/><path d="M48 13V18" stroke="#a66c39" stroke-width="2"/>'
		"battery":
			return '<path d="M24 5H40V13H24Z" fill="#a0aca2" stroke="#071219" stroke-width="2"/><path d="M18 13H46L50 19V47L43 55H19L14 48V20Z" fill="#768167" stroke="#071219" stroke-width="3"/><path d="M20 16H42V20H20Z" fill="#e2dbc0"/><path d="M21 24H39V44H21Z" fill="#323d39"/><path d="M23 26H37V30H23ZM23 33H37V37H23ZM23 40H37V43H23Z" fill="ACCENT"/><path d="M23 26H27V43H23Z" fill="#f2e9b0"/><path d="M17 24H20V45H17ZM42 24H47V45H42Z" fill="#4a6056"/><path d="M22 48H38V52H22Z" fill="#b6bea4"/><path d="M43 8H48V14H43M9 25H14V39H9" fill="#859b91" stroke="#071219" stroke-width="2"/>'
		_:
			return _secondary_drawing(id)


static func _secondary_drawing(id: String) -> String:
	match id:
		"missile_pod":
			return '<path d="M13 16L22 9H43L52 18V48L44 55H18L10 47V24Z" fill="#5c6f77" stroke="#071219" stroke-width="3"/><path d="M16 19L23 13H41L47 19V23H16Z" fill="#b8bdab"/><path d="M15 26H46V46H15Z" fill="#24343d"/><path d="M17 28H29V44H17ZM33 28H45V44H33Z" fill="#94704e" stroke="#071219" stroke-width="2"/><path d="M19 30H27V40L23 43L19 40ZM35 30H43V40L39 43L35 40Z" fill="#dae0c9"/><path d="M23 24L27 30H19ZM39 24L43 30H35Z" fill="ACCENT"/><path d="M21 34H25V39H21ZM37 34H41V39H37Z" fill="#526c78"/><path d="M13 48H47V51H13Z" fill="#9ca995"/><path d="M22 52H39V57H22Z" fill="#495e63" stroke="#071219" stroke-width="2"/><path d="M48 23H55V42H48Z" fill="#85938b" stroke="#071219" stroke-width="2"/><path d="M50 27H53V34H50Z" fill="ACCENT"/><path d="M18 18H28M37 18H43" stroke="#ece8cc" stroke-width="2"/>'
		"landing_coil":
			return '<path d="M22 6H41L45 13V34L52 43V53H12V42L20 32V13Z" fill="#5c737d" stroke="#071219" stroke-width="3"/><path d="M24 10H38V18H24Z" fill="#c4d0bd"/><path d="M23 20H41V31H23Z" fill="#233d4c"/><path d="M24 22H39V25H24ZM24 28H39V31H24Z" fill="ACCENT"/><path d="M20 34H44L48 40H16Z" fill="#aec0af" stroke="#071219" stroke-width="2"/><path d="M16 42H48V48H16Z" fill="#21333b"/><path d="M18 43H25V47H18ZM28 43H35V47H28ZM38 43H45V47H38Z" fill="ACCENT"/><path d="M12 50H52V55H12Z" fill="#8c9484" stroke="#071219" stroke-width="2"/><path d="M15 53H24M29 53H38M43 53H49" stroke="#dde0bf" stroke-width="2"/><path d="M14 18H20V30H14ZM44 18H50V30H44Z" fill="#a18b69" stroke="#071219" stroke-width="2"/><path d="M16 20H19M45 20H48" stroke="#efe4ba" stroke-width="2"/>'
		"frost_halo":
			return '<path d="M21 9H43L55 21V43L43 55H21L9 43V21Z" fill="#5f7890" stroke="#071219" stroke-width="3"/><path d="M23 14H41L49 23V41L41 49H23L15 41V23Z" fill="#c5d6cf"/><path d="M26 20H38L44 26V38L38 44H26L20 38V26Z" fill="#243d55" stroke="#071219" stroke-width="2"/><path d="M30 23L38 28L37 37L30 41L25 32Z" fill="ACCENT"/><path d="M30 25L33 27L29 35L27 32Z" fill="#edfff0"/><path d="M26 5H38V17H26ZM47 26H59V38H47ZM26 47H38V59H26ZM5 26H17V38H5Z" fill="#7898a9" stroke="#071219" stroke-width="2"/><path d="M29 8H35V14H29ZM50 29H56V35H50ZM29 50H35V56H29ZM8 29H14V35H8Z" fill="ACCENT"/><path d="M23 15L18 21M43 15L48 21M18 43L23 48M43 48L48 43" stroke="#e3ecd7" stroke-width="2"/>'
		"frost":
			return '<path d="M25 5L38 10L44 30L37 46L22 42L15 25Z" fill="#527b91" stroke="#071219" stroke-width="3"/><path d="M25 9L32 13L29 34L21 38L19 25Z" fill="#d7efdf"/><path d="M33 13L37 15L40 29L34 39L29 34Z" fill="ACCENT"/><path d="M30 18L25 26L28 31L24 36" fill="none" stroke="#8eb8c5" stroke-width="2"/><path d="M42 14L50 10L55 26L46 35L41 29Z" fill="#84b9c5" stroke="#071219" stroke-width="2"/><path d="M47 15L50 14L51 24L45 30Z" fill="#e9f2df"/><path d="M14 35L22 39L36 42L44 35L48 41L40 52H24L16 46Z" fill="#566f7d" stroke="#071219" stroke-width="3"/><path d="M21 43H39M26 53V58H35V53" fill="none" stroke="#bacbbd" stroke-width="3"/>'
		"momentum":
			return '<path d="M20 7H42L54 20V42L42 54H20L8 42V20Z" fill="#597974" stroke="#071219" stroke-width="3"/><path d="M20 12H40L48 20V40L40 48H21L14 40V22Z" fill="#a8c2ae"/><path d="M24 17H39L43 23V38L37 43H24L19 37V24Z" fill="#243d45"/><path d="M31 19V43M20 31H43M23 23L40 40M23 40L40 23" stroke="#657f7b" stroke-width="5"/><path d="M26 26H37V37H26Z" fill="#c8d4b8" stroke="#071219" stroke-width="2"/><path d="M29 29H34V34H29Z" fill="ACCENT"/><path d="M17 9H26V16H17ZM43 17H51V26H43ZM35 44H44V52H35ZM10 35H18V44H10Z" fill="ACCENT"/><path d="M26 53V58H38V53" fill="#b5ae88" stroke="#071219" stroke-width="2"/>'
		"toxin":
			return '<g transform="rotate(20 32 32)"><path d="M22 7H42V15H22Z" fill="#899e82" stroke="#071219" stroke-width="3"/><path d="M24 15H40V45L35 52H28L22 44V19Z" fill="#456955" stroke="#071219" stroke-width="3"/><path d="M26 19H37V42L33 47H29L26 41Z" fill="#233c36"/><path d="M26 30L31 27L36 31V42L33 46H29L26 41Z" fill="ACCENT"/><path d="M27 20H30V32H27Z" fill="#d2e5bc"/><path d="M30 35H34V39H30Z" fill="#517340"/><path d="M23 48H40V54H23Z" fill="#a5b399" stroke="#071219" stroke-width="2"/><path d="M17 20H22V40H17ZM40 20H46V40H40Z" fill="#6e8279" stroke="#071219" stroke-width="2"/><path d="M17 26H22M40 32H46" stroke="#b9c7ae" stroke-width="2"/></g>'
		"echo":
			return '<path d="M11 19H43L50 27V47L44 53H12L8 45V26Z" fill="#71677b" stroke="#071219" stroke-width="3"/><path d="M14 22H39L44 27H14Z" fill="#c3b9c7"/><path d="M13 29H27V43H13Z" fill="#243442"/><path d="M16 32H24V40H16Z" fill="#9585ae"/><path d="M19 34H23V38H19Z" fill="ACCENT"/><path d="M32 28H45V45H32Z" fill="#283641"/><path d="M35 31H42V34H35ZM35 37H42V41H35Z" fill="ACCENT"/><path d="M13 47H30M37 49H44" stroke="#c1b0bb" stroke-width="2"/><path d="M19 18V10H25V18M38 21V7H44V24" fill="#72868b" stroke="#071219" stroke-width="2"/><path d="M21 11V15M40 9V18" stroke="ACCENT" stroke-width="2"/><path d="M48 30L55 34V42L48 45Z" fill="#ac9ca7" stroke="#071219" stroke-width="2"/>'
		"piercer":
			return '<g transform="rotate(42 32 32)"><path d="M32 2L39 18V39L35 48H29L25 39V18Z" fill="#959f8f" stroke="#071219" stroke-width="3"/><path d="M32 6V32L28 38V19Z" fill="#eee8ca"/><path d="M33 19H36V38H33Z" fill="ACCENT"/><path d="M22 34L26 30L28 42L24 50L20 49ZM38 30L43 35L45 49L40 50L36 42Z" fill="#76888c" stroke="#071219" stroke-width="2"/><path d="M27 44H37V51H27Z" fill="#bda576" stroke="#071219" stroke-width="2"/><path d="M30 51H34V60H30Z" fill="#4a626c" stroke="#071219" stroke-width="2"/><path d="M30 52H34V55H30Z" fill="#e6d8b0"/></g>'
		"resonator":
			return '<path d="M19 12L26 16L23 27V37L28 42V53H19L12 40V23ZM45 12L52 23V40L45 53H36V42L41 37V27L38 16Z" fill="#719099" stroke="#071219" stroke-width="3"/><path d="M16 24L21 17L22 20L18 29V38L23 45M43 18L48 26V39L42 47" fill="none" stroke="#c5d3c4" stroke-width="3"/><path d="M28 9H36V16H28ZM27 46H37V58H27Z" fill="#bba171" stroke="#071219" stroke-width="2"/><path d="M24 23L32 17L40 24V35L32 41L24 35Z" fill="#254f67" stroke="#071219" stroke-width="2"/><path d="M28 25L33 21L36 26V33L31 36L28 32Z" fill="ACCENT"/><path d="M28 25L33 21V28H28Z" fill="#e2f2da"/><path d="M11 32H6M53 32H58" stroke="ACCENT" stroke-width="3"/>'
		"phoenix":
			return '<path d="M22 12L32 6L42 12L49 29L44 42L35 52H27L18 43L13 29Z" fill="#7c6552" stroke="#071219" stroke-width="3"/><path d="M24 15L32 10L39 15L42 28L35 43H28L21 28Z" fill="#442f31"/><path d="M31 16L36 23L34 29L39 33L33 42L26 38L24 30Z" fill="ACCENT"/><path d="M31 26L34 32L31 38L28 33Z" fill="#fff0be"/><path d="M14 16L23 22L20 30L24 40L18 39L9 28L7 17ZM50 16L57 17L55 28L46 39L40 40L44 30L41 22Z" fill="#b59468" stroke="#071219" stroke-width="2"/><path d="M12 20L17 24M47 24L52 20M21 43L27 49H36L42 43" fill="none" stroke="#e5c493" stroke-width="3"/><path d="M26 53H38V58H26Z" fill="#886547" stroke="#071219" stroke-width="2"/>'
		"nova":
			return '<path d="M24 9H40L53 23V40L40 53H23L10 39V24Z" fill="#8b7990" stroke="#071219" stroke-width="3"/><path d="M25 16H38L45 24V38L37 45H25L18 37V25Z" fill="#463750"/><path d="M28 21L39 24L41 34L34 40L24 35L23 27Z" fill="ACCENT"/><path d="M29 25H35L37 31L32 36L27 32Z" fill="#fff2de"/><path d="M25 9L28 18H36L39 9M51 24L42 27V35L51 39M39 52L36 43H28L24 52M11 39L20 36V28L11 24" fill="#bcb9ac" stroke="#071219" stroke-width="2"/><path d="M28 5H36M55 28V36M28 57H36M6 28V36" stroke="#c5a676" stroke-width="3"/><path d="M25 17L22 23M42 38L39 43" stroke="#dce3d3" stroke-width="2"/>'
		"grenade":
			return '<path d="M23 20H40L48 31V45L40 54H23L15 45V32Z" fill="#6d7756" stroke="#071219" stroke-width="3"/><path d="M23 24H30V48H24L19 43V32Z" fill="#a8b08b"/><path d="M33 24H39L44 32V43L38 49H33Z" fill="#485548"/><path d="M16 33H46M17 43H45M31 23V51" stroke="#243a37" stroke-width="3"/><path d="M23 35H29V41H23ZM34 35H41V41H34Z" fill="ACCENT"/><path d="M25 12H39V21H25Z" fill="#c1c2a5" stroke="#071219" stroke-width="2"/><path d="M38 13L47 22L49 37" fill="none" stroke="#8e9d93" stroke-width="5"/><path d="M19 9H27V16H19Z" fill="none" stroke="#d9d0ac" stroke-width="3"/><path d="M23 53H39" stroke="#89977b" stroke-width="2"/>'
		"shockwave":
			return '<path d="M21 10H41L45 17V39L39 46H24L17 39V17Z" fill="#776d61" stroke="#071219" stroke-width="3"/><path d="M23 13H39V20H23Z" fill="#c4b9a0"/><path d="M21 24H42V37H21Z" fill="#384950"/><path d="M25 25H38V29H25ZM25 32H38V36H25Z" fill="ACCENT"/><path d="M11 30L19 25V41L25 45V51H16L8 42ZM45 25L53 30L56 42L48 51H39V45L45 41Z" fill="#aa9171" stroke="#071219" stroke-width="2"/><path d="M12 34V40L18 46M51 34V40L45 46" fill="none" stroke="#e9d3a8" stroke-width="3"/><path d="M24 47H40L43 55H21Z" fill="#d0c4a1" stroke="#071219" stroke-width="2"/><path d="M26 51H38" stroke="#5c706e" stroke-width="3"/>'
		"repair_field":
			return '<path d="M22 13L32 8L42 13L46 29L41 43H23L18 29Z" fill="#73927e" stroke="#071219" stroke-width="3"/><path d="M24 17H40V31H24Z" fill="#264e43"/><path d="M29 18H35V22H39V28H35V32H29V28H25V22H29Z" fill="ACCENT"/><path d="M30 19H33V23H30Z" fill="#e6f0cf"/><path d="M21 35H43V40H21Z" fill="#bec8ac"/><path d="M15 31L20 33L16 46L9 54H5V48L11 42ZM44 33L49 31L53 42L59 48V54H55L48 46Z" fill="#829987" stroke="#071219" stroke-width="2"/><path d="M29 41H35V54H29Z" fill="#a3b99f" stroke="#071219" stroke-width="2"/><path d="M9 49H17M47 49H55M26 55H38" stroke="#d5dcc2" stroke-width="3"/><path d="M18 21H12V27H18M46 21H52V27H46" fill="ACCENT" stroke="#071219" stroke-width="2"/>'
		"aegis":
			return '<path d="M20 9H44L51 18V36L43 48L32 55L21 48L13 36V18Z" fill="#698596" stroke="#071219" stroke-width="3"/><path d="M22 13H41L46 20V33L39 43L32 48L24 42L18 33V20Z" fill="#d0d8c9"/><path d="M25 20H39L42 25V34L32 43L22 34V25Z" fill="#214360"/><path d="M27 23H36L39 28V32L32 39L26 33Z" fill="ACCENT"/><path d="M28 23H34L28 30H26Z" fill="#e6efdf"/><path d="M15 20H20V29H15ZM44 20H49V29H44Z" fill="#b59c70"/><path d="M20 38L24 43M40 43L44 38M29 49H35" stroke="#789daf" stroke-width="3"/>'
		"graviton":
			return '<path d="M21 10H43L53 21V43L43 53H21L10 42V21Z" fill="#80738b" stroke="#071219" stroke-width="3"/><path d="M24 17H40L46 24V40L39 46H24L17 39V24Z" fill="#273447"/><path d="M25 23L33 19L41 26V37L33 44L23 36Z" fill="#604575"/><path d="M28 27L34 24L38 29V35L33 39L27 34Z" fill="#121d31" stroke="ACCENT" stroke-width="2"/><path d="M19 9H27V20L18 27H9V19ZM38 9H45L55 19V27H46L38 19ZM9 38H18L27 45V55H19L9 45ZM46 38H55V45L45 55H38V46Z" fill="#a7aaa5" stroke="#071219" stroke-width="2"/><path d="M17 17L22 21M43 18L47 22M18 44L22 47M44 43L47 46" stroke="ACCENT" stroke-width="3"/>'
		"turret":
			return '<path d="M12 19H34L41 25H55V34H34L28 40H14L9 34V24Z" fill="#6d806d" stroke="#071219" stroke-width="3"/><path d="M15 22H31L35 26H15Z" fill="#bdc4a5"/><path d="M14 28H26V34H14Z" fill="#273f3c"/><path d="M17 29H24V32H17Z" fill="ACCENT"/><path d="M34 27H55V30H34Z" fill="#a6b69f"/><path d="M29 39V45M14 54L26 44H35L48 54M31 45V56" fill="none" stroke="#13272c" stroke-width="7"/><path d="M29 40V45M15 53L26 44H35L47 53M31 45V55" fill="none" stroke="#a9b79d" stroke-width="3"/><path d="M18 18V12H30V18" fill="#678481" stroke="#071219" stroke-width="2"/><path d="M20 13H28V16H20Z" fill="ACCENT"/><path d="M6 54H19M25 57H36M43 54H54" stroke="#637a6d" stroke-width="4"/>'
		"meteor":
			return '<path d="M19 15L26 8H43L50 15V43L42 51H22L15 43V23Z" fill="#8d7160" stroke="#071219" stroke-width="3"/><path d="M23 12H41L46 17H24V39H20V19Z" fill="#d4c7a7"/><path d="M28 19H43V35H28Z" fill="#4b3840" stroke="#23323a" stroke-width="2"/><path d="M33 21H41V24L33 31H30V28Z" fill="ACCENT"/><path d="M30 33H38V39H30Z" fill="#e4ad6b"/><path d="M18 39H28V48H18ZM41 40H49V48H41Z" fill="#536c71"/><path d="M25 43H39V48H25Z" fill="#352e33"/><path d="M28 44H36V46H28Z" fill="ACCENT"/><path d="M45 17L53 10V5H57V13L49 23M19 23L9 18V12H13V16L21 19" fill="#9caca1" stroke="#071219" stroke-width="2"/><path d="M27 52H40V57H27Z" fill="#a78f70" stroke="#071219" stroke-width="2"/>'
		"time_warp":
			return '<path d="M11 17L20 10L27 19H37L44 10L53 17V43L43 52H21L11 42Z" fill="#718b8f" stroke="#071219" stroke-width="3"/><path d="M15 19L20 16L25 24H39L44 16L49 20V28H15Z" fill="#cabd92"/><path d="M18 30H46V42L39 48H25L18 42Z" fill="#223c50"/><path d="M22 32L28 27H37L43 32V40L37 45H28L22 40Z" fill="#6d919b" stroke="#071219" stroke-width="2"/><path d="M27 32H37V41H27Z" fill="#243951"/><path d="M31 30V36L37 39" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M13 33H18V40H13ZM46 33H51V40H46Z" fill="ACCENT"/><path d="M29 12H35V21H29Z" fill="#d9e3cb" stroke="#071219" stroke-width="2"/><path d="M22 51V56H41V51" fill="#a8956c" stroke="#071219" stroke-width="2"/>'
		_:
			return _utility_drawing(id)


static func _utility_drawing(id: String) -> String:
	match id:
		"pursuit_protocol":
			return '<path d="M10 21L20 13H44L54 23V42L45 51H18L9 42Z" fill="#4c7475" stroke="#071219" stroke-width="3"/><path d="M15 23L22 18H40L47 23V28H15Z" fill="#b9cabe"/><path d="M17 29H46V42H17Z" fill="#152e3e"/><path d="M20 31H43V39H20Z" fill="ACCENT"/><path d="M22 32H28V35H22Z" fill="#e1ffe2"/><path d="M32 29V42M27 35H38" stroke="#214855" stroke-width="2"/><path d="M22 45H40V50H22Z" fill="#8b9d87"/><path d="M5 28H11V40H5ZM53 28H59V40H53Z" fill="#9a8c6d" stroke="#071219" stroke-width="2"/><path d="M19 11V7H25V13M40 13V7H46V12" fill="none" stroke="#7eab9c" stroke-width="3"/>'
		"reactive_plating":
			return '<path d="M15 12L32 6L49 12V36L42 48L32 57L21 48L14 36Z" fill="#6a797a" stroke="#071219" stroke-width="3"/><path d="M18 16L32 11L45 16V23L32 28L18 23Z" fill="#e0d3ac"/><path d="M18 26L32 31L45 26V35L39 42L32 47L24 42L18 35Z" fill="#a78e69"/><path d="M24 30H39V37L32 42L25 37Z" fill="#243c47"/><path d="M28 31H35V35H38V38H34V42H30V38H26V35H28Z" fill="ACCENT"/><path d="M24 44L32 50L40 44L35 52H29Z" fill="#d8c9a6"/><path d="M10 20H15V32H10ZM49 20H54V32H49Z" fill="#ac9677" stroke="#071219" stroke-width="2"/><path d="M22 18L30 15M36 15L42 18" stroke="#fff1ce" stroke-width="2"/>'
		"dash", "phase_dash":
			return '<path d="M30 16H39L37 33L49 41V49H28L20 42L25 31Z" fill="#626a88" stroke="ACCENT" stroke-width="2.5"/><path d="M28 45H46M11 25H24M8 33H20M10 41H17" stroke="#e1e5ef" stroke-width="3"/><path d="M33 21L29 32L34 35" fill="none" stroke="ACCENT" stroke-width="3"/>'
		"shoulder_rush":
			return '<path d="M28 13L43 18L51 31L44 47L29 52L23 35Z" fill="#72583d" stroke="ACCENT" stroke-width="3"/><path d="M31 21L39 24L44 32L39 42L32 45L28 34Z" fill="ACCENT"/><path d="M7 23H21M4 32H18M7 41H21" stroke="#e7d9bd" stroke-width="3"/><path d="M49 17L55 13M54 30H59M50 44L56 49" stroke="ACCENT" stroke-width="2.5"/>'
		"guard_burst":
			return '<path d="M32 10L48 18V32L42 43L32 50L22 43L16 32V18Z" fill="#72583d" stroke="ACCENT" stroke-width="3"/><path d="M34 18L25 33H32L29 43L40 28H33Z" fill="#fff0c1"/><path d="M7 27H11M53 27H57M11 45L16 42M48 42L53 45M32 54V59" stroke="ACCENT" stroke-width="3"/>'
		"cache":
			return '<path d="M11 30L16 18H48L53 30V50H11Z" fill="#66583f" stroke="ACCENT" stroke-width="2.5"/><path d="M12 31H52M22 20V49M43 20V49" stroke="#debd83" stroke-width="3"/><rect x="28" y="28" width="8" height="12" rx="2" fill="ACCENT"/><path d="M32 32V35" stroke="#23323b" stroke-width="2"/>'
		"choice":
			return '<path d="M8 26L19 21L23 42L12 46Z" fill="#385a51" stroke="ACCENT" stroke-width="2"/><path d="M45 21L56 26L52 46L41 42Z" fill="#385a51" stroke="ACCENT" stroke-width="2"/><rect x="23" y="14" width="18" height="32" rx="3" fill="#285344" stroke="#d2efdd" stroke-width="2.5"/><path d="M28 27L32 23L36 27L32 33Z" fill="ACCENT"/><path d="M27 52L32 48L37 52" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"blood":
			return '<path d="M32 10C28 20 16 31 16 39C16 59 48 59 48 39C48 31 36 20 32 10Z" fill="#693e4a" stroke="ACCENT" stroke-width="3"/><path d="M24 37C21 43 27 48 31 47" fill="none" stroke="#f6dad8" stroke-width="3"/><path d="M29 32H35V37H40V43H35V48H29V43H24V37H29Z" fill="ACCENT"/>'
		"combat":
			return '<path d="M15 11L24 14L47 44L42 48L18 20Z" fill="#d6c6aa" stroke="ACCENT" stroke-width="1.5"/><path d="M49 11L40 14L17 44L22 48L46 20Z" fill="#b9c7b9" stroke="ACCENT" stroke-width="1.5"/><path d="M13 39L28 51M36 51L51 39" stroke="ACCENT" stroke-width="4"/><path d="M19 46L14 53M45 46L50 53" stroke="#f2d1ac" stroke-width="4"/>'
		"equipment_cache":
			return '<rect x="12" y="19" width="40" height="34" rx="5" fill="#365165" stroke="ACCENT" stroke-width="2.5"/><path d="M24 19V13H40V19M19 24V47M45 24V47" fill="none" stroke="#c1deeb" stroke-width="2.5"/><path d="M30 26L26 31L29 36L24 43L28 46L34 39L39 39L42 34L36 35L32 31L34 25Z" fill="ACCENT"/>'
		"gate":
			return '<path d="M14 51V31L22 13H29L21 32V51M50 51V31L42 13H35L43 32V51" fill="#52483f" stroke="ACCENT" stroke-width="2.5"/><ellipse cx="32" cy="34" rx="10" ry="17" fill="#664d36" fill-opacity=".4" stroke="#efd2a3" stroke-width="1.8"/><path d="M8 53H56M27 34H38M34 30L38 34L34 38" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"revive":
			return '<circle cx="23" cy="22" r="6" fill="#d3e9ca"/><path d="M18 33L25 30L34 42L43 45L40 51H26L20 44H12V39H20Z" fill="#55846a" stroke="ACCENT" stroke-width="2.5"/><path d="M41 12V29M33 20H49" stroke="ACCENT" stroke-width="5"/><path d="M10 53H49" stroke="#bcd6b8" stroke-width="2"/>'
		_:
			return '<path d="M32 12L49 23V42L32 53L15 42V23Z" fill="#35534e" stroke="ACCENT" stroke-width="2.5"/><path d="M32 19V46M21 27L32 34L43 27" fill="none" stroke="#e1ead5" stroke-width="2.5"/>'
