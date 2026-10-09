extends SceneTree

const Icons = preload("res://scripts/item_icons.gd")
const Content = preload("res://scripts/content.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(description)

func _run() -> void:
	# Keep an actual live resource while a catalogue larger than the cache is
	# visited. Eviction must not invalidate a displayed TextureRect or pickup.
	var retained: Texture2D = Icons.pickup_texture("pulse_rifle", 16)
	var retained_digest: int = hash(retained.get_image().get_data())
	var records: Array = Content.passives() + Content.weapons() + Content.equipment()
	var fingerprints: Dictionary = {}
	for record: Dictionary in records:
		var geometry_ok: bool = true
		var source_ok: bool = true
		var cache_ok: bool = true
		var alpha_ok: bool = true
		for pixels: int in [16,24,28,30,32,34,42,48,64,128,256]:
			var framed: Texture2D = Icons.texture(str(record.id), pixels)
			var object: Texture2D = Icons.pickup_texture(str(record.id), pixels)
			cache_ok = cache_ok and framed == Icons.texture(str(record.id), pixels) and object == Icons.pickup_texture(str(record.id), pixels) and framed != object
			for texture: Texture2D in [framed, object]:
				var image: Image = texture.get_image()
				geometry_ok = geometry_ok and texture.get_size() == Vector2(pixels,pixels)
				source_ok = source_ok and texture is CanvasTexture and texture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and texture.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED
				source_ok = source_ok and image.get_size() == Vector2i(mini(pixels*4,256),mini(pixels*4,256)) and image.has_mipmaps() and image.get_data_size() > image.get_width()*image.get_height()*4
				if texture == object:
					var edge: int = image.get_width()-1
					for corner: Vector2i in [Vector2i.ZERO,Vector2i(edge,0),Vector2i(0,edge),Vector2i(edge,edge)]:
						alpha_ok = alpha_ok and is_zero_approx(image.get_pixelv(corner).a)
			if pixels == 64:
				fingerprints[hash(object.get_image().get_data())] = true
		_check(geometry_ok, str(record.id)+" retains every logical UI / pickup size")
		_check(source_ok, str(record.id)+" uses bounded supersampling, mipmaps and a texture-owned linear sampler")
		_check(cache_ok, str(record.id)+" reuses hot entries and keeps framed / transparent caches distinct")
		_check(alpha_ok, str(record.id)+" has no opaque background in its transparent pickup texture")
	_check(fingerprints.size() == 46, "All 46 physical item silhouettes remain distinct")
	var stats: Dictionary = Icons.cache_stats()
	var measured: int = 0
	for texture: Texture2D in Icons._textures.values():
		measured += texture.get_image().get_data_size()
	_check(stats.bytes == measured and measured <= Icons.MAX_CACHE_BYTES, "The cache budget accounts for actual mipmap allocation")
	_check(not Icons._textures.has("object:pulse_rifle:16"), "The old entry is evicted after visiting more than the cache budget")
	_check(retained.get_size() == Vector2(16,16) and hash(retained.get_image().get_data()) == retained_digest, "A displayed texture remains valid after its cache reference is evicted")
	var restored: Texture2D = Icons.pickup_texture("pulse_rifle",16)
	_check(restored != retained and restored.get_size() == Vector2(16,16) and hash(restored.get_image().get_data()) == retained_digest, "Revisiting an evicted icon recreates the same complete image")
	var generation: int = int(Icons.cache_stats().rasterizations)
	for frame: int in range(180):
		Icons.pickup_texture("pulse_rifle",16)
	_check(int(Icons.cache_stats().rasterizations) == generation, "Repeated draw requests do not rasterize SVG per frame")
	for id: String in ["phase_dash","guard_burst","pursuit_protocol","reactive_plating","shoulder_rush","cache","choice","blood","combat","equipment_cache","gate","revive","unknown"]:
		var texture: Texture2D = Icons.texture(id,34)
		_check(texture.get_size() == Vector2(34,34) and texture is CanvasTexture and texture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, id+" uses the same smooth logical-size API")
	_check(Icons.texture("grenade",1).get_size() == Vector2(16,16) and Icons.pickup_texture("grenade",999).get_size() == Vector2(256,256), "Public size limits remain 16 through 256")
	var edge_image: Image = restored.get_image()
	var fractional_alpha: bool = false
	for y: int in range(edge_image.get_height()):
		for x: int in range(edge_image.get_width()):
			var alpha: float = edge_image.get_pixel(x,y).a
			if alpha > 0.0 and alpha < 1.0:
				fractional_alpha = true
	_check(fractional_alpha, "The diagonal weapon silhouette retains antialiased edge coverage")
	var innate_images: Dictionary = {}
	for id: String in ["phase_dash", "guard_burst", "pursuit_protocol", "reactive_plating"]:
		var image: Image = Icons.pickup_texture(id, 24).get_image()
		innate_images[hash(image.get_data())] = true
		_check(image.get_used_rect().size.x >= 50 and image.get_used_rect().size.y >= 50, id + " retains a readable physical silhouette in the 24px preview")
	_check(innate_images.size() == 4, "Both active and passive class abilities have independent silhouettes")
	print("ITEM_ICONS_CACHE ",JSON.stringify(Icons.cache_stats()))
	print("ITEM_ICONS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
