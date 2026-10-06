extends SceneTree
const Fx = preload("res://scripts/attack_fx_sprites.gd")
var passed: int = 0
var failed: int = 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ",label)
	else: failed += 1; push_error("FAIL: "+label)
func _run() -> void:
	var manifest: Dictionary = {"families":{}}
	for path: String in Fx.MANIFEST_PATHS:
		var part: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		manifest.families.merge(part.families)
	Fx.prepare()
	var cache: Dictionary = Fx.cache_stats()
	_check(cache.textures==8 and cache.families==18 and cache.bytes<=32*1024*1024,"Eighteen animation families share eight imported sheets within the 32 MiB runtime cap")
	var source_textures: Dictionary = {}
	var total_frames: int = 0
	for family: String in manifest.families:
		var info: Dictionary = manifest.families[family]
		var count: int = Array(info.frames).size()
		total_frames += count
		var raw := Image.new()
		_check(raw.load_png_from_buffer(FileAccess.get_file_as_bytes(info.path))==OK and raw.get_format()==Image.FORMAT_RGBA8,family+": original authored PNG has real RGBA alpha")
		var hashes: Dictionary = {}
		var bounded: bool = true
		var nonempty: bool = true
		var clear_border: bool = true
		var footprint_matches: bool = true
		var stable_reference: bool = true
		var maximum_extent: Rect2 = Rect2(Vector2.ZERO,Vector2(raw.get_size()))
		for index: int in range(count):
			var frame: Dictionary=Fx.frame_data(family,float(index)/count+.001)
			var region: Rect2 = frame.region
			bounded = bounded and maximum_extent.encloses(region) and frame.index==index
			var pixels: Image=raw.get_region(Rect2i(region))
			hashes[pixels.get_data().hex_encode().sha256_text()]=true
			var opaque: int=0
			var edge: int=0
			var minimum := Vector2(pixels.get_size())
			var maximum := Vector2.ZERO
			for y: int in range(pixels.get_height()):
				for x: int in range(pixels.get_width()):
					if pixels.get_pixel(x,y).a>.3:
						opaque+=1
						minimum = minimum.min(Vector2(x, y))
						maximum = maximum.max(Vector2(x + 1, y + 1))
						if x==0 or x==pixels.get_width()-1 or y==0 or y==pixels.get_height()-1: edge+=1
			nonempty = nonempty and opaque>80
			clear_border = clear_border and edge<10
			if family.ends_with("_hit") or family == "laser":
				footprint_matches = footprint_matches and (minimum - Vector2(frame.anchor)).is_equal_approx(-Vector2(frame.reference) * .5) and (maximum - Vector2(frame.anchor)).is_equal_approx(Vector2(frame.reference) * .5)
			else:
				stable_reference = stable_reference and Vector2(frame.reference) == Vector2(info.reference[0], info.reference[1])
			var again: Dictionary=Fx.frame_data(family,float(index)/count+.001)
			bounded = bounded and frame.texture==again.texture and frame.region==again.region and frame.anchor==again.anchor
		_check(bounded,family+": all fixed regions/anchors are in bounds and repeated samples share the texture")
		_check(nonempty and hashes.size()==count,family+": genuinely different animation frames remain visible")
		_check(clear_border,family+": no substantial opaque body is cut at any selected crop edge")
		_check(Fx.frame_index(family,-1)==0 and Fx.frame_index(family,1)==count-1,family+": one-shots clamp cleanly at both ends")
		var first: Dictionary = Fx.frame_data(family, 0)
		if source_textures.has(info.path):
			_check(first.texture == source_textures[info.path], family+": sibling families share the same cached GPU texture")
		else:
			source_textures[info.path] = first.texture
		if str(info.path).contains("v0202"):
			_check(first.texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, family+": pixel clusters retain nearest filtering")
			if family.ends_with("_hit") or family == "laser":
				_check(footprint_matches, family+": every active frame fills the complete centered attack footprint")
			else:
				_check(stable_reference, family+": preparation and projectile frames keep one stable reference scale")
		if family=="missile":
			var frame: Dictionary=Fx.frame_data(family,0)
			var nose: Vector2=frame.region.position+frame.anchor
			_check(raw.get_pixelv(Vector2i(nose)).a>.6,"Missile collision origin sits on the solid warhead, not its exhaust")
	_check(total_frames == 96 and source_textures.size() == cache.textures, "All 96 animation frames use eight unique atlas sources")
	var before: Dictionary=Fx.cache_stats()
	for repeat: int in range(100):
		Fx.prepare(); Fx.frame_data("charge",float(repeat%8)/8)
	_check(Fx.cache_stats()==before,"Repeated animation samples and scene preparation allocate no extra atlas textures")
	_check(Fx.frame_data("missing",.5).is_empty(),"Unknown families have a safe empty sample")
	print("ATTACK_FX_SPRITES_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
