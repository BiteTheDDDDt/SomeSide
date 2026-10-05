extends SceneTree

const Art = preload("res://scripts/weapon_art.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	var fingerprints: Dictionary = {}
	for id: String in Art.IDS:
		var body: String = Art._body(id)
		var texture: CanvasTexture = Art._texture(id, body)
		_check(texture != null and texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, id + " bakes once with pixel sampling")
		var bitmap: Image = texture.diffuse_texture.get_image()
		var bounds: Rect2i = bitmap.get_used_rect()
		var endpoint: int = int(Pose.muzzle_length(id) - Art.BOUNDS.position.x)
		_check(bounds.size.x > 30 and bounds.size.y > 5 and bounds.end.x == endpoint, id + " physical muzzle matches visible silhouette endpoint")
		_check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.y < bitmap.get_height(), id + " material has transparent breathing room and no clipping")
		var markup: String = Art.icon_drawing(id)
		var icon := Image.new()
		var error: Error = icon.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">' + markup + '</svg>')
		var icon_bounds: Rect2i = icon.get_used_rect() if error == OK else Rect2i()
		_check(error == OK and maxi(icon_bounds.size.x,icon_bounds.size.y) >= 50 and icon_bounds.position.x >= 3 and icon_bounds.position.y >= 3 and icon_bounds.end.x <= 61 and icon_bounds.end.y <= 61, id + " icon fills its available area without clipping")
		fingerprints[bitmap.get_data().hex_encode().hash()] = true
		_check(Art._texture(id, body) == texture, id + " repeated requests retain texture identity")
	for part: String in ["pump", "vent_top", "vent_bottom"]:
		var texture: CanvasTexture = Art._texture(part, Art._part(part))
		_check(texture != null and texture.diffuse_texture.get_image().get_used_rect().has_area(), part + " movable mechanism rasterizes separately")
	_check(fingerprints.size() == 8, "Every held weapon has a unique visible silhouette and material image")
	_check(Art.cache_stats().textures == 11 and Art.cache_stats().bytes < 110000, "All eight weapons and moving parts remain in a fixed small cache")
	_check(Art.icon_drawing("not_a_weapon").is_empty(), "Unknown icons do not silently show the wrong equipment")
	print("WEAPON_ART_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
