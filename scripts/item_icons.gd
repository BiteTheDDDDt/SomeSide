class_name SideItemIcons
extends RefCounted

## Original vector pictograms shared by ground loot, loadout slots and inventory.
## Text-free silhouettes stay readable at 24 px; SVGs are rasterized once per size.
static var _textures: Dictionary = {}
const Content = preload("res://scripts/content.gd")


static func rarity_color(rarity: String) -> Color:
	return Content.rarity_color(rarity)


static func rarity_rank(rarity: String) -> int:
	return Content.rarity_rank(rarity)


static func texture(id: String, size: int = 64) -> Texture2D:
	var pixels: int = clampi(size, 16, 256)
	var key: String = id + ":" + str(pixels)
	if _textures.has(key):
		return _textures[key]
	var accent: String = color(id).to_html(false)
	var icon: String = _drawing(id)
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="2" y="2" width="60" height="60" rx="11" fill="#10252d"/><path d="M13 3H51Q61 3 61 13V51Q61 61 51 61H13Q3 61 3 51V13Q3 3 13 3Z" fill="none" stroke="#' + accent + '" stroke-opacity=".34" stroke-width="2"/><path d="M9 17L17 9H43" fill="none" stroke="#' + accent + '" stroke-opacity=".18" stroke-width="2"/><circle cx="32" cy="31" r="23" fill="#' + accent + '" fill-opacity=".07"/><g stroke-linecap="round" stroke-linejoin="round">' + icon.replace("ACCENT", "#" + accent) + '</g></svg>'
	var bitmap: Image = Image.new()
	var error: Error = bitmap.load_svg_from_string(svg, float(pixels) / 64.0)
	if error != OK:
		push_error("SomeSide icon could not rasterize: " + id)
		bitmap = Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
		bitmap.fill(color(id))
	var result: ImageTexture = ImageTexture.create_from_image(bitmap)
	_textures[key] = result
	return result


static func color(id: String) -> Color:
	match id:
		"phase_dash": return Color("6cd6bd")
		"shoulder_rush": return Color("f2b96d")
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
	match id:
		"overclock":
			return '<path d="M27 13H37L39 19L45 20L50 29L46 34L47 40L39 46L33 43L27 47L18 42L19 36L14 31L18 22L24 21Z" fill="#23424b" stroke="ACCENT" stroke-width="2.5"/><path d="M34 17L24 33H32L29 46L41 28H33Z" fill="ACCENT"/><path d="M20 14L17 17M46 46L43 49" stroke="#e9f3da" stroke-width="2"/>'
		"capacitor":
			return '<rect x="15" y="20" width="13" height="29" rx="4" fill="#3b453b" stroke="ACCENT" stroke-width="2.5"/><rect x="36" y="20" width="13" height="29" rx="4" fill="#3b453b" stroke="ACCENT" stroke-width="2.5"/><path d="M19 20V15H24V20M40 20V15H45V20M18 35H25M21.5 31V39M39 35H46" fill="none" stroke="#f3e2b9" stroke-width="2.5"/><path d="M29 24L34 19L31 33L36 29" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"lens":
			return '<path d="M42 42L51 51" stroke="#dbc8cb" stroke-width="7"/><circle cx="28" cy="28" r="17" fill="#493345" stroke="ACCENT" stroke-width="3"/><circle cx="28" cy="28" r="11" fill="#263b48" stroke="#eddae3" stroke-width="2"/><path d="M21 28Q21 21 28 21" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M34 12V18M45 23H39" stroke="ACCENT" stroke-width="2"/>'
		"vitality":
			return '<path d="M32 49L15 33C5 22 20 10 32 23C44 10 59 22 49 33Z" fill="#315c4c" stroke="ACCENT" stroke-width="3"/><path d="M16 32H25L29 26L34 39L39 31H48" fill="none" stroke="#e6f2d4" stroke-width="2.5"/>'
		"thruster":
			return '<path d="M24 38L19 31L21 19L32 9L43 19L45 31L40 38Z" fill="#3c435b" stroke="ACCENT" stroke-width="2.5"/><path d="M21 29L14 37V44L25 39M43 29L50 37V44L39 39" fill="ACCENT"/><circle cx="32" cy="24" r="5" fill="#e1e9f1"/><path d="M26 42L28 51L32 55L36 51L38 42" fill="ACCENT"/><path d="M31 42V49" stroke="#eef1e0" stroke-width="3"/>'
		"arc":
			return '<path d="M18 18C5 33 18 50 32 48C46 46 53 29 41 17" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M13 26L21 29M14 37L22 36M21 45L25 39M35 47L34 40M45 39L38 35M47 27L39 29" stroke="#d9efe6" stroke-width="2.5"/><path d="M33 9L24 30H33L29 43L44 22H34Z" fill="ACCENT"/>'
		"ember":
			return '<path d="M33 9C38 25 22 26 29 35C33 32 41 29 40 20C57 38 47 53 32 53C14 53 9 35 20 25C18 39 28 35 27 27C26 20 31 17 33 9Z" fill="ACCENT"/><path d="M32 35C40 41 38 49 32 49C26 49 24 42 32 35Z" fill="#fff0c3"/>'
		"moss":
			return '<path d="M31 52V32M32 39Q21 35 16 26M32 31Q39 24 47 20" fill="none" stroke="#d5e4bb" stroke-width="3"/><path d="M30 35C13 39 11 26 12 18C27 19 33 25 30 35Z" fill="#538465" stroke="ACCENT" stroke-width="2.5"/><path d="M33 29C30 15 41 11 52 13C50 26 44 32 33 29Z" fill="ACCENT"/><path d="M34 29L44 20M19 26L29 34" stroke="#e8edc5" stroke-width="2"/><path d="M22 53H42" stroke="ACCENT" stroke-width="3"/>'
		"siphon":
			return '<path d="M13 51L23 41" stroke="#ecdfed" stroke-width="2"/><path d="M20 35L35 20L45 30L30 45Z" fill="#543a59" stroke="ACCENT" stroke-width="2.5"/><path d="M25 33L33 41L41 33L33 25Z" fill="ACCENT"/><path d="M37 23L43 17M41 27L47 21M39 13L51 25M19 34L31 46" stroke="#e8d5e9" stroke-width="3"/><path d="M30 29L34 33" stroke="#152a32" stroke-width="2"/>'
		"coolant":
			return '<path d="M32 11V53M14 22L50 43M14 43L50 22" stroke="ACCENT" stroke-width="3"/><path d="M26 15L32 21L38 15M26 49L32 43L38 49M14 29L23 27L22 18M42 46L41 37L50 35M13 35L23 37L22 46M42 18L41 27L50 29" fill="none" stroke="#d9edee" stroke-width="2.5"/><circle cx="32" cy="32" r="4" fill="#e8f1ec"/>'
		"feather":
			return '<path d="M18 48C10 33 20 16 49 10C49 31 41 46 25 43Z" fill="#4b5676" stroke="ACCENT" stroke-width="2.5"/><path d="M16 53L42 20M24 42L21 32M30 35L29 24M36 29L36 19M27 38L38 39M34 29L43 29" fill="none" stroke="#e0e5f3" stroke-width="2.5"/><path d="M45 45V54M41 49L45 45L49 49" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"glass":
			return '<path d="M17 12L36 17L27 49L13 35Z" fill="#563947" stroke="ACCENT" stroke-width="2.5"/><path d="M42 9L52 32L34 41Z" fill="#8c6470" stroke="#f4d7db" stroke-width="2"/><path d="M39 44L50 48L35 55Z" fill="ACCENT"/><path d="M22 17L18 30L26 35" fill="none" stroke="#f8e5e5" stroke-width="2"/><path d="M32 17L25 27L30 30" fill="none" stroke="ACCENT" stroke-width="1.5"/>'
		"plating":
			return '<path d="M16 18L32 11L48 18L44 36L32 48L20 36Z" fill="#3c5661" stroke="ACCENT" stroke-width="2.5"/><path d="M16 27L32 34L48 27M20 38L32 44L44 38M22 44L32 53L42 44" fill="none" stroke="#e3e7db" stroke-width="2.5"/><path d="M24 21L32 18L40 21L32 28Z" fill="ACCENT"/>'
		"magnet":
			return '<path d="M13 16H25V34C25 44 39 44 39 34V16H51V35C51 61 13 61 13 35Z" fill="#674156" stroke="ACCENT" stroke-width="2.5"/><path d="M13 16H25V27H13ZM39 16H51V27H39Z" fill="#d8ddd6"/><path d="M29 13L33 9L35 15M28 25L32 21L36 25" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"harvest":
			return '<path d="M20 53L36 18M23 44L17 30M27 35L21 22M32 25L29 14" fill="none" stroke="#eae4b9" stroke-width="3"/><path d="M36 18C41 6 51 13 44 21C42 24 38 23 36 18ZM30 30C34 18 45 25 38 33C35 36 32 35 30 30ZM25 42C29 30 40 37 33 45C30 48 27 47 25 42Z" fill="ACCENT"/><path d="M17 30C4 25 12 16 19 23ZM21 22C11 13 23 8 27 17Z" fill="#869c6c"/>'
		"battery":
			return '<rect x="19" y="15" width="26" height="39" rx="5" fill="#555f41" stroke="ACCENT" stroke-width="2.5"/><path d="M26 15V10H38V15" fill="#e6e8c9"/><path d="M32 20L24 35H32L29 47L41 30H33Z" fill="ACCENT"/><path d="M13 23V45M51 23V45" stroke="#c0ca9c" stroke-width="2"/>'
		"frost":
			return '<path d="M18 16L27 10L34 19L28 48L23 54L17 39ZM35 15L45 10L51 22L42 44L35 38Z" fill="#476579" stroke="ACCENT" stroke-width="2.5"/><path d="M23 17L24 40M42 19L40 34" stroke="#f0f1e9" stroke-width="2"/><path d="M12 43L16 48M48 43L53 48M11 31H6M53 31H58" stroke="ACCENT" stroke-width="2"/>'
		"momentum":
			return '<circle cx="37" cy="34" r="17" fill="#2e5759" stroke="ACCENT" stroke-width="3"/><circle cx="37" cy="34" r="5" fill="#dbe9d3"/><path d="M37 17V26M54 34H45M37 51V42M20 34H29M49 22L43 28M49 46L43 40M25 46L31 40" stroke="ACCENT" stroke-width="2.5"/><path d="M8 18H24M5 27H18M8 43H17M16 10H34" stroke="#d1e4d6" stroke-width="2.5"/>'
		"toxin":
			return '<path d="M24 10H40V17H37V28L50 46Q52 54 44 54H20Q12 54 14 46L27 28V17H24Z" fill="#334e40" stroke="ACCENT" stroke-width="2.5"/><path d="M21 39H43L48 48Q49 51 43 51H21Q15 51 17 47Z" fill="ACCENT"/><circle cx="28" cy="43" r="2" fill="#234039"/><circle cx="36" cy="47" r="2.5" fill="#234039"/><path d="M31 20V28L24 36" stroke="#e3edc2" stroke-width="2" fill="none"/>'
		"echo":
			return '<path d="M12 26H21L32 17V48L21 40H12Z" fill="#5b4a71" stroke="ACCENT" stroke-width="2.5"/><path d="M38 24Q47 32 38 41M45 16Q62 32 45 49" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M16 30V36M25 27V39" stroke="#ece1ec" stroke-width="2"/>'
		"piercer":
			return '<path d="M13 49L36 26L31 21L55 9L43 34L38 29L17 53Z" fill="#c7be97" stroke="ACCENT" stroke-width="2"/><path d="M26 14V25M13 38H24M38 51V40M49 27H58" stroke="ACCENT" stroke-width="2.5"/><path d="M16 15L23 22M44 43L51 50" stroke="#e2daba" stroke-width="2"/>'
		"resonator":
			return '<path d="M17 11V27C17 37 23 40 29 40V53H35V40C42 40 47 36 47 27V11H39V27C39 36 25 36 25 27V11Z" fill="#436f79" stroke="ACCENT" stroke-width="2.5"/><path d="M32 9L38 19L32 28L26 19Z" fill="#e2efe3"/><path d="M9 18V28M55 18V28M12 36L16 40M48 40L52 36" stroke="ACCENT" stroke-width="2"/>'
		"phoenix":
			return '<path d="M32 19L38 27L55 12L51 31L39 37L45 51L33 44L23 54L25 37L12 31L9 13L27 27Z" fill="#b76f54" stroke="ACCENT" stroke-width="2.5"/><path d="M18 26L28 31L32 27L36 31L47 26M29 32L32 39L35 32M32 19L37 13L43 17L36 21" fill="none" stroke="#ffe5b7" stroke-width="2.5"/><path d="M22 45L15 50M44 43L51 47" stroke="ACCENT" stroke-width="2"/>'
		"nova":
			return '<path d="M32 7L37 23L53 13L43 29L59 34L43 38L50 54L35 43L28 59L25 42L8 48L20 34L5 26L24 25Z" fill="#775576" stroke="ACCENT" stroke-width="2"/><circle cx="32" cy="33" r="10" fill="#eee3de"/><circle cx="32" cy="33" r="5" fill="ACCENT"/><path d="M13 12L18 17M49 7L46 14M56 46L60 48" stroke="ACCENT" stroke-width="2"/>'
		"flamethrower":
			return '<path d="M9 29H37V23H43V30H52V38H33L29 45H22L19 52H12L16 39H9Z" fill="#745444" stroke="#dfccaa" stroke-width="2"/><rect x="22" y="37" width="13" height="18" rx="4" fill="#925b46" stroke="ACCENT" stroke-width="2"/><path d="M36 25V16Q30 10 23 17V28" fill="none" stroke="ACCENT" stroke-width="2.5"/><path d="M50 27C57 22 51 17 55 12C63 21 60 27 55 30Z" fill="ACCENT"/><path d="M14 31H29" stroke="ACCENT" stroke-width="3"/>'
		"boomerang":
			return '<path d="M11 14L31 26L53 11L42 35L32 44L23 35Z" fill="#426c67" stroke="ACCENT" stroke-width="3"/><path d="M18 20L31 33L46 19M27 33L32 39L36 34" fill="none" stroke="#e2e8d4" stroke-width="2"/><path d="M11 40Q9 56 32 56Q52 56 55 38M50 42L55 37L58 44" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"storm_staff":
			return '<path d="M17 54L37 21" stroke="#dfd8bd" stroke-width="5"/><path d="M28 18L30 7L39 14L51 12L48 25L37 30Z" fill="#39627a" stroke="ACCENT" stroke-width="2.5"/><path d="M41 7L34 20H42L36 34L51 18H43Z" fill="ACCENT"/><path d="M12 42L25 49M9 30L15 34M53 34L58 28" stroke="ACCENT" stroke-width="2.5"/>'
		"sun_lance":
			return '<path d="M10 54L43 21" stroke="#e5d8a9" stroke-width="5"/><path d="M32 17L51 7L57 12L45 31L40 24Z" fill="#9e8857" stroke="ACCENT" stroke-width="2"/><circle cx="43" cy="21" r="7" fill="#fff0c3"/><path d="M27 9L31 14M55 30L60 32M42 4V8M58 18H62M24 34L32 42" stroke="ACCENT" stroke-width="2.5"/><path d="M29 24L39 35" stroke="#be985f" stroke-width="4"/>'
		"graviton":
			return '<ellipse cx="32" cy="33" rx="26" ry="11" transform="rotate(-24 32 33)" fill="none" stroke="ACCENT" stroke-width="3"/><circle cx="32" cy="33" r="14" fill="#090f24" stroke="#e1cfef" stroke-width="2"/><path d="M20 32Q24 20 35 23M18 47L13 51M47 18L52 14" fill="none" stroke="ACCENT" stroke-width="2.5"/><circle cx="20" cy="12" r="2" fill="ACCENT"/><circle cx="49" cy="47" r="3" fill="ACCENT"/>'
		"turret":
			return '<path d="M17 20H37L44 25H56V31H37L30 38H17Z" fill="#5d7059" stroke="ACCENT" stroke-width="2.5"/><path d="M24 38V44M14 53L25 42H35L45 53M30 43V55" fill="none" stroke="#d7dfc1" stroke-width="4"/><path d="M13 24H6V33H17M23 20V14H37V20" fill="none" stroke="ACCENT" stroke-width="2.5"/><circle cx="29" cy="29" r="4" fill="#e7ebc9"/>'
		"meteor":
			return '<path d="M12 34L19 27L51 9L40 29L54 19L41 40L32 49L19 52L10 44Z" fill="#965d50" stroke="ACCENT" stroke-width="2.5"/><path d="M19 32L32 34L38 43L27 51L16 45Z" fill="#463f40" stroke="#edc89c" stroke-width="2"/><path d="M25 39L29 41M39 13L33 21M55 33L48 41M19 18L13 24" stroke="ACCENT" stroke-width="2.5"/>'
		"time_warp":
			return '<path d="M22 16H42V23L35 32L42 42V49H22V42L29 32L22 23Z" fill="#396879" stroke="ACCENT" stroke-width="2.5"/><path d="M26 21H38L32 28ZM26 45L32 37L38 45Z" fill="#e3e9d4"/><path d="M11 35Q6 10 30 7Q48 5 54 22M49 18L55 23L57 16M53 35Q57 57 34 58Q16 58 10 44M7 49L9 42L15 46" fill="none" stroke="ACCENT" stroke-width="2.5"/>'
		"pulse_rifle":
			return '<path d="M9 27H39V24H47V29H57V35H38L35 40H29L25 49H17L20 36H9Z" fill="#547270" stroke="#d5e6d6" stroke-width="2"/><path d="M14 27V23H28V27M42 31H56M25 30H34" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M11 30V34M16 30V34" stroke="#193039" stroke-width="2"/><path d="M32 16H43" stroke="ACCENT" stroke-width="2"/>'
		"arc_blade":
			return '<path d="M23 39L41 12L53 9L50 23L28 43Z" fill="#c8d7cc" stroke="ACCENT" stroke-width="2"/><path d="M28 36L46 17" stroke="#46736c" stroke-width="3"/><path d="M15 36L31 49" stroke="ACCENT" stroke-width="5"/><path d="M22 44L14 53" stroke="#e7d4af" stroke-width="6"/><path d="M38 11L30 19" stroke="ACCENT" stroke-width="2"/>'
		"scattergun":
			return '<path d="M8 31L15 25H42V22H56V31H42V36H56V44H40V39H26L21 48H13L16 36H8Z" fill="#806b50" stroke="#e7d6b5" stroke-width="2"/><path d="M28 28H41M28 34H41M46 26H54M46 40H54" stroke="ACCENT" stroke-width="3"/><path d="M18 28V34M22 28V34M26 28V34" stroke="#20333b" stroke-width="2"/>'
		"railgun":
			return '<path d="M7 32L13 27H27V23H36V27H56V32H33V36H56V40H27L24 49H16L18 39H7Z" fill="#46647a" stroke="#d4e1e9" stroke-width="2"/><path d="M34 30H55M34 38H55" stroke="ACCENT" stroke-width="2.5"/><path d="M20 29V36M25 29V36M30 17H41M35 17V23" fill="none" stroke="ACCENT" stroke-width="2.5"/><circle cx="48" cy="34" r="2" fill="#eff5e1"/>'
		"grenade":
			return '<path d="M25 19H38V25L44 30L47 44L40 53H23L16 44L19 30L25 25Z" fill="#626c4b" stroke="ACCENT" stroke-width="2.5"/><path d="M22 33H41M20 42H44M29 28V49M36 28V49" stroke="#1b3235" stroke-width="2.5"/><path d="M27 19V13H39L46 28" fill="none" stroke="#eedeb6" stroke-width="3"/><circle cx="23" cy="12" r="4" fill="none" stroke="ACCENT" stroke-width="2"/>'
		"shockwave":
			return '<path d="M29 11H37V29H29Z" fill="#d7c7a3"/><path d="M19 24L33 20L46 24V36L33 42L19 36Z" fill="#80634d" stroke="ACCENT" stroke-width="2.5"/><path d="M12 35L7 40L13 44M51 35L57 40L51 44M12 51L21 47M43 47L52 51M25 53L33 46L40 53" fill="none" stroke="ACCENT" stroke-width="3"/><path d="M25 28L33 25L40 28L33 32Z" fill="#f3dfb5"/>'
		"repair_field":
			return '<path d="M10 47V37C10 10 54 10 54 37V47" fill="#294d43" fill-opacity=".8" stroke="ACCENT" stroke-width="2.5" stroke-dasharray="5 4"/><path d="M26 24H38V31H45V41H38V48H26V41H19V31H26Z" fill="ACCENT"/><path d="M10 52H54" stroke="#e2eccb" stroke-width="3"/>'
		"aegis":
			return '<path d="M32 10L51 17V32C51 44 39 51 32 55C25 51 13 44 13 32V17Z" fill="#385777" stroke="ACCENT" stroke-width="3"/><path d="M32 17L43 22V32C43 39 37 44 32 47Z" fill="ACCENT"/><path d="M23 23V32C23 36 27 40 29 41" fill="none" stroke="#e4f0ed" stroke-width="2.5"/>'
		"dash", "phase_dash":
			return '<path d="M30 16H39L37 33L49 41V49H28L20 42L25 31Z" fill="#626a88" stroke="ACCENT" stroke-width="2.5"/><path d="M28 45H46M11 25H24M8 33H20M10 41H17" stroke="#e1e5ef" stroke-width="3"/><path d="M33 21L29 32L34 35" fill="none" stroke="ACCENT" stroke-width="3"/>'
		"shoulder_rush":
			return '<path d="M28 13L43 18L51 31L44 47L29 52L23 35Z" fill="#72583d" stroke="ACCENT" stroke-width="3"/><path d="M31 21L39 24L44 32L39 42L32 45L28 34Z" fill="ACCENT"/><path d="M7 23H21M4 32H18M7 41H21" stroke="#e7d9bd" stroke-width="3"/><path d="M49 17L55 13M54 30H59M50 44L56 49" stroke="ACCENT" stroke-width="2.5"/>'
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
