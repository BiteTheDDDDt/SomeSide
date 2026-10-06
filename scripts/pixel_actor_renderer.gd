class_name SidePixelActorRenderer
extends RefCounted

## Authored sprites replace only the actor body. The caller supplies its existing
## local facing transform; weapons, relics, health bars and telegraphs stay live.
## Every frame owns an explicit crop and center anchor, never an assumed grid.
const MANIFEST_PATH: String = "res://assets/sprites/actors.json"
const Gait = preload("res://scripts/player_gait.gd")
const EnemyAttackArt = preload("res://scripts/enemy_attack_visual.gd")
const MAX_ACTORS: int = 32
const MAX_FRAMES: int = 64
const MAX_TEXTURE_BYTES: int = 64 * 1024 * 1024
const MAX_BAKED_BYTES: int = 8 * 1024 * 1024
# At fractional viewport scales a screen pixel can land exactly between two
# logical texels. Give nearest sampling a consistent tie direction; otherwise
# interpolated UV rounding can change one column when an integer origin moves.
const SAMPLE_TIE_BIAS: float = 1.0 / 1024.0
const TRACK_META: StringName = &"someside_actor_animation_tracks"
const MAX_TRACKS: int = 256
const ONE_SHOTS: Array[String] = ["rise", "fall", "jump", "dash", "land", "windup", "attack", "dead"]
static var _manifest_revision: int = 0
static var _loaded: bool = false
static var _actors: Dictionary = {}
static var _textures: Dictionary = {}
static var _errors: Array[String] = []
static var _texture_bytes: int = 0
static var _baked_bytes: int = 0

static func _ensure_loaded() -> void:
	if not _loaded:
		reload_manifest()

static func reload_manifest(path: String = MANIFEST_PATH) -> void:
	_actors.clear()
	_textures.clear()
	_errors.clear()
	_texture_bytes = 0
	_baked_bytes = 0
	_loaded = true
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		_errors.append("Manifest must be a JSON object: " + path)
		return
	install_manifest(data)

## Also used by isolated rendering tests with in-memory Texture2D fixtures.
## Ownership stays with this presentation module, never with game snapshots.
static func install_manifest(data: Dictionary, supplied_textures: Dictionary = {}) -> void:
	_manifest_revision += 1
	_actors.clear()
	_textures.clear()
	_errors.clear()
	_texture_bytes = 0
	_baked_bytes = 0
	_loaded = true
	if int(data.get("version", 0)) != 1 or not data.get("actors", {}) is Dictionary:
		_errors.append("Unsupported actor manifest version or actor table")
		return
	var records: Dictionary = data.get("actors", {})
	var images: Dictionary = {}
	for id_value: Variant in records:
		if _actors.size() >= MAX_ACTORS:
			_errors.append("Actor budget exceeded")
			break
		var id: String = str(id_value)
		if not records[id_value] is Dictionary:
			_errors.append("Invalid actor record: " + id)
			continue
		var source: Dictionary = records[id_value]
		var path: String = str(source.get("texture", ""))
		var texture: Texture2D = _load_texture(path, supplied_textures)
		if texture == null:
			_errors.append("Missing or oversized texture for " + id + ": " + path)
			continue
		var scale_value: float = float(source.get("scale", 1.0))
		if not is_finite(scale_value) or scale_value <= 0.0 or scale_value > 8.0:
			_errors.append("Invalid actor scale: " + id)
			continue
		var frame_values: Variant = source.get("frames", [])
		if not frame_values is Array or frame_values.is_empty() or frame_values.size() > MAX_FRAMES:
			_errors.append("Invalid frame count: " + id)
			continue
		var frames: Array = []
		var union: Rect2 = Rect2()
		for frame_value: Variant in frame_values:
			if not frame_value is Dictionary:
				break
			var frame: Dictionary = frame_value
			var frame_path: String = str(frame.get("texture", path))
			var frame_texture: Texture2D = _load_texture(frame_path, supplied_textures)
			var frame_scale: float = float(frame.get("scale", scale_value))
			if frame_texture == null or not is_finite(frame_scale) or frame_scale <= 0.0 or frame_scale > 8.0:
				break
			if not _numbers(frame.get("rect"), 4) or not _numbers(frame.get("anchor"), 2):
				break
			var rect: Rect2 = _rect(frame.rect)
			var anchor: Vector2 = Vector2(float(frame.anchor[0]), float(frame.anchor[1]))
			var duration: float = float(frame.get("duration", 0.12))
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not Rect2(Vector2.ZERO, frame_texture.get_size()).encloses(rect) or not is_finite(duration) or duration <= 0.0:
				break
			# Anchors may sit just outside a tightly cropped image, but not explode
			# geometry if a malformed manifest uses an unbounded value.
			if anchor.abs().x > 8192.0 or anchor.abs().y > 8192.0:
				break
			# Attachments use actor-local logical pixels, independent of source PNG
			# scale. Only presentation follows this point; ballistic aim stays fixed.
			var shoulder := Vector2(0.0, -5.0)
			if frame.has("shoulder"):
				if not _numbers(frame.shoulder, 2):
					break
				shoulder = Vector2(float(frame.shoulder[0]), float(frame.shoulder[1]))
				if shoulder.abs().x > 64.0 or shoulder.abs().y > 64.0:
					break
			var target: Rect2 = Rect2(-anchor * frame_scale, rect.size * frame_scale)
			var atlas := AtlasTexture.new()
			atlas.atlas = frame_texture
			atlas.region = rect
			atlas.filter_clip = true
			frames.append({"source": rect, "source_path": frame_path, "source_scale": frame_scale, "anchor": anchor, "target": target, "duration": clampf(duration, 0.016, 5.0), "texture": atlas, "shoulder": shoulder})
			if not images.has(frame_path):
				images[frame_path] = frame_texture.diffuse_texture.get_image()
			union = target if frames.size() == 1 else union.merge(target)
		if frames.size() != frame_values.size():
			_errors.append("Invalid crop, anchor, timing or shoulder: " + id)
			continue
		# Downsample once at a fixed actor-local phase. Sampling a 1536px sheet
		# directly at 0.125 scale selected different source texels each time the
		# camera moved by a fraction of a pixel, making an unchanged pose shimmer.
		if not _bake_frames(images, frames, union):
			_errors.append("Invalid or oversized logical-pixel canvas: " + id)
			continue
		var animations: Dictionary = {}
		var declared: Dictionary = source.get("animations", {}) if source.get("animations", {}) is Dictionary else {}
		for animation_key: Variant in declared:
			var indices: Variant = declared[animation_key]
			if not indices is Array or indices.is_empty() or indices.size() > MAX_FRAMES:
				continue
			var valid: bool = true
			for index: Variant in indices:
				valid = valid and (index is int or index is float) and float(index) == floorf(float(index)) and int(index) >= 0 and int(index) < frames.size()
			if valid:
				animations[str(animation_key)] = indices.duplicate()
		if not animations.has("idle"):
			animations["idle"] = [0]
		var bounds: Rect2 = union
		if _numbers(source.get("bounds"), 4):
			var declared_bounds: Rect2 = _rect(source.bounds)
			if declared_bounds.size.x > 0 and declared_bounds.size.y > 0:
				bounds = bounds.merge(declared_bounds)
		var modes: Dictionary = {}
		var declared_modes: Dictionary = source.get("animation_modes", {}) if source.get("animation_modes", {}) is Dictionary else {}
		for animation: String in animations:
			var default_mode: String = "once" if animation in ONE_SHOTS else "loop"
			var mode: String = str(declared_modes.get(animation, default_mode))
			modes[animation] = mode if mode in ["once", "loop"] else default_mode
		var movement_speed: float = float(source.get("movement_speed", 245.0 if id in ["ranger", "vanguard"] else 110.0))
		if not is_finite(movement_speed) or movement_speed <= 0.0:
			movement_speed = 245.0 if id in ["ranger", "vanguard"] else 110.0
		# World pixels covered by one complete two-step cycle. Optional so older
		# enemy/fixture sheets retain their authored time-driven wing/leg cycles.
		var stride_distance: float = float(source.get("stride_distance", 0.0))
		if not is_finite(stride_distance) or stride_distance < 0.0 or stride_distance > 4096.0:
			stride_distance = 0.0
		var stride_distances: Dictionary = {}
		var declared_strides: Dictionary = source.get("stride_distances", {}) if source.get("stride_distances", {}) is Dictionary else {}
		for animation: String in animations:
			var distance: float = float(declared_strides.get(animation, stride_distance))
			stride_distances[animation] = distance if is_finite(distance) and distance >= 0.0 and distance <= 4096.0 else stride_distance
		_actors[id] = {"path": path, "frames": frames, "animations": animations, "animation_modes": modes, "movement_speed": movement_speed, "stride_distance": stride_distance, "stride_distances": stride_distances, "bounds": bounds, "scale": scale_value}

static func _bake_frames(images: Dictionary, frames: Array, union: Rect2) -> bool:
	# Every animation frame shares this integer pivot and size. A differently
	# cropped hand/foot may move, but cannot change the sampling phase of the torso.
	var target := Rect2(union.position.floor(), union.end.ceil() - union.position.floor())
	var size_value := Vector2i(target.size)
	if size_value.x <= 0 or size_value.y <= 0 or size_value.x > 512 or size_value.y > 512:
		return false
	var columns: int = int(ceil(sqrt(float(frames.size()))))
	var rows: int = int(ceil(float(frames.size()) / columns))
	var cost: int = size_value.x * columns * size_value.y * rows * 4
	if _baked_bytes + cost > MAX_BAKED_BYTES:
		return false
	var baked := Image.create(size_value.x * columns, size_value.y * rows, false, Image.FORMAT_RGBA8)
	baked.fill(Color.TRANSPARENT)
	for index: int in range(frames.size()):
		var frame: Dictionary = frames[index]
		var image: Image = images.get(frame.source_path)
		if image == null or image.is_empty() or (image.is_compressed() and image.decompress() != OK):
			return false
		var scale_value: float = float(frame.source_scale)
		var rect: Rect2 = frame.source
		var anchor: Vector2 = frame.anchor
		var offset := Vector2i((index % columns) * size_value.x, (index / columns) * size_value.y)
		for y: int in range(size_value.y):
			for x: int in range(size_value.x):
				var local: Vector2 = (target.position + Vector2(x + 0.5, y + 0.5)) / scale_value + anchor
				if local.x >= 0 and local.y >= 0 and local.x < rect.size.x and local.y < rect.size.y:
					var source: Vector2i = Vector2i((rect.position + local).floor())
					baked.set_pixel(x + offset.x, y + offset.y, image.get_pixel(source.x, source.y))
		frame["draw_target"] = target
		frame["baked_region"] = Rect2(Vector2(offset), Vector2(size_value))
	var nearest := CanvasTexture.new()
	nearest.diffuse_texture = ImageTexture.create_from_image(baked)
	nearest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	nearest.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	for frame: Dictionary in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = nearest
		atlas.region = Rect2(frame.baked_region.position + Vector2.ONE * SAMPLE_TIE_BIAS, frame.baked_region.size)
		atlas.filter_clip = true
		frame.texture = atlas
	_baked_bytes += cost
	return true

## Snap after the actual viewport stretch, including noninteger fullscreen
## scaling. Physics, camera coordinates, aim and network snapshots stay exact.
static func snap_position(canvas: CanvasItem, position_value: Vector2) -> Vector2:
	var transform_value: Transform2D = canvas.get_viewport_transform() * canvas.get_global_transform()
	if absf(transform_value.determinant()) < 0.00001:
		return position_value
	return transform_value.affine_inverse() * (transform_value * position_value).round()

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true

static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

static func _load_texture(path: String, supplied: Dictionary) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var source: Texture2D = supplied.get(path) as Texture2D
	if source == null and path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
		source = load(path) as Texture2D
	if source == null or source.get_width() <= 0 or source.get_height() <= 0 or source.get_width() > 4096 or source.get_height() > 4096:
		return null
	var bytes: int = source.get_width() * source.get_height() * 4
	if _texture_bytes + bytes > MAX_TEXTURE_BYTES:
		return null
	# A per-texture sampler avoids changing filtering on the world canvas, which
	# still draws smooth vector-cache textures, weapons and UI-independent FX.
	var nearest := CanvasTexture.new()
	nearest.diffuse_texture = source
	nearest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	nearest.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_textures[path] = nearest
	_texture_bytes += bytes
	return nearest

static func available(id: String) -> bool:
	_ensure_loaded()
	return _actors.has(id)

static func actor_ids() -> Array:
	_ensure_loaded()
	return _actors.keys()

static func stats() -> Dictionary:
	_ensure_loaded()
	return {"actors": _actors.size(), "textures": _textures.size(), "bytes": _texture_bytes, "max_bytes": MAX_TEXTURE_BYTES, "baked_bytes": _baked_bytes, "max_baked_bytes": MAX_BAKED_BYTES, "errors": _errors.duplicate()}

static func enemy_id(enemy: Dictionary) -> String:
	if str(enemy.get("kind", "crawler")) != "boss":
		return str(enemy.get("kind", "crawler"))
	var style: String = str(enemy.get("boss_style", ""))
	if style.is_empty():
		style = {"rainforest": "spore", "canyon": "stone", "ruins": "prism"}.get(str(enemy.get("biome", "rainforest")), "spore")
	return "boss_" + style

static func bounds(id: String) -> Rect2:
	_ensure_loaded()
	return _actors[id].bounds if _actors.has(id) else Rect2()

static func animation_for(state: Dictionary, player: bool = false) -> String:
	if bool(state.get("dead", false)):
		return "dead"
	var velocity: Vector2 = state.get("vel", Vector2.ZERO)
	if player:
		if float(state.get("dash_timer", 0.0)) > 0.0:
			return "dash"
		if not bool(state.get("grounded", false)):
			return "rise" if velocity.y < 0.0 else "fall"
		if absf(velocity.x) <= 15.0:
			return "idle"
		var facing: float = 1.0 if Vector2(state.get("aim", Vector2.RIGHT)).x >= 0.0 else -1.0
		return "backpedal" if velocity.x * facing < 0.0 else "run"
	if float(state.get("telegraph", 0.0)) > 0.0:
		return "windup"
	if float(state.get("charge_timer", 0.0)) > 0.0 or (not str(state.get("attack_kind", "")).is_empty() and float(state.get("attack_cd", 0.0)) > float(state.get("attack_cooldown", 3.0)) - 0.18):
		return "attack"
	return "move" if velocity.length_squared() > 100.0 or bool(state.get("flying", false)) else "idle"

## Pure sampling remains useful for portraits and asset inspection. Live drawing
## uses tracked_frame_for so changing actions cannot jump to a global-clock pose.
static func frame_for(id: String, state: Dictionary, clock: float, player: bool = false) -> Dictionary:
	_ensure_loaded()
	if not _actors.has(id):
		return {}
	var actor: Dictionary = _actors[id]
	var animation: String = _resolve_animation(actor, animation_for(state, player))
	var elapsed: float = maxf(0.0, clock) if is_finite(clock) else 0.0
	if not player:
		elapsed = _enemy_action_time(actor, animation, state, elapsed)
	return _sample_frame(id, actor, state, animation, elapsed, player)

static func _resolve_animation(actor: Dictionary, requested: String) -> String:
	var animation: String = requested
	var aliases: Dictionary = {"backpedal": "run", "run": "move", "move": "run", "rise": "jump", "fall": "jump", "dash": "run", "land": "idle", "attack": "move", "windup": "idle", "dead": "idle"}
	if not actor.animations.has(animation):
		animation = str(aliases.get(animation, "idle"))
	if not actor.animations.has(animation):
		animation = "idle"
	return animation

static func _duration(actor: Dictionary, animation: String) -> float:
	var duration: float = 0.0
	for index: Variant in actor.animations[animation]:
		duration += float(actor.frames[int(index)].duration)
	return duration

static func _enemy_action_time(actor: Dictionary, animation: String, state: Dictionary, fallback: float) -> float:
	if animation == "windup" and float(state.get("telegraph_max", 0.0)) > 0.0:
		# The same replicated warning timer drives every client's anticipation,
		# including enemies that enter the viewport halfway through a windup.
		var progress: float = 1.0 - float(state.get("telegraph", 0.0)) / float(state.telegraph_max)
		return clampf(progress, 0.0, 1.0) * _duration(actor, animation)
	if animation == "attack" and state.has("attack_cd") and state.has("attack_cooldown"):
		return maxf(0.0, float(state.attack_cooldown) - float(state.attack_cd))
	return fallback

static func reset_tracks(canvas: CanvasItem) -> void:
	if canvas.has_meta(TRACK_META):
		canvas.remove_meta(TRACK_META)
	Gait.reset(canvas)

## Tracks belong to the drawing canvas, not to snapshots or static global
## identities. A new world/preview gets its own clock and frees its own history.
static func tracked_frame_for(canvas: CanvasItem, id: String, state: Dictionary, clock: float, player: bool = false) -> Dictionary:
	_ensure_loaded()
	if not _actors.has(id):
		return {}
	var actor: Dictionary = _actors[id]
	var safe_clock: float = maxf(0.0, clock) if is_finite(clock) else 0.0
	var cache: Dictionary = canvas.get_meta(TRACK_META, {})
	if int(cache.get("revision", -1)) != _manifest_revision or safe_clock < float(cache.get("clock", safe_clock)):
		cache = {"revision": _manifest_revision, "clock": safe_clock, "pruned": safe_clock, "tracks": {}}
	var tracks: Dictionary = cache.tracks
	if safe_clock - float(cache.pruned) > 2.0:
		for old_key: Variant in tracks.keys():
			if safe_clock - float(tracks[old_key].clock) > 2.0:
				tracks.erase(old_key)
		cache.pruned = safe_clock
	var key: String = ("p:" if player else "e:") + str(state.get("id", 0)) + ":" + id
	var track: Dictionary = tracks.get(key, {})
	var requested: String = animation_for(state, player)
	var animation: String = _resolve_animation(actor, requested)
	var grounded: bool = bool(state.get("grounded", false))
	var position_value: Vector2 = state.get("pos", Vector2.ZERO)
	var attack_count: int = int(state.get("attack_count", 0))
	var dt: float = safe_clock - float(track.get("clock", safe_clock))
	var reset: bool = track.is_empty() or dt < 0.0 or dt > 0.5 or position_value.distance_squared_to(track.get("pos", position_value)) > 180.0 * 180.0
	var restart: bool = false
	var land_position: Vector2 = track.get("land_position", position_value)
	if not reset and player:
		var landing: bool = grounded and not bool(track.grounded) and requested not in ["dash", "dead"] and actor.animations.has("land")
		var firing: bool = requested == "idle" and attack_count > int(track.attack_count) and actor.animations.has("attack")
		if landing or firing:
			animation = "land" if landing else "attack"
			restart = true
			if landing:
				land_position = position_value
		elif requested in ["idle", "run", "backpedal"] and str(track.animation) in ["land", "attack"] and float(track.elapsed) + dt < _duration(actor, str(track.animation)):
			# A landing is visual only: walking, aiming and firing remain live.
			# Running immediately interrupts a standing attack pose.
			var left_contact: bool = str(track.animation) == "land" and requested in ["run", "backpedal"] and dt > 0.0 and absf(position_value.x - land_position.x) > 4.0
			if not left_contact and (str(track.animation) == "land" or requested == "idle"):
				animation = str(track.animation)
	var velocity: Vector2 = state.get("vel", Vector2.ZERO)
	var rate: float = 1.0
	if animation in ["run", "backpedal", "move"]:
		var speed: float = absf(velocity.x) if player or not bool(state.get("flying", false)) else velocity.length()
		# Hovering still has a full wing cycle; ground feet follow travel speed.
		rate = clampf(speed / float(actor.movement_speed), 0.4, 2.0)
		if not player and bool(state.get("flying", false)):
			rate = maxf(1.0, rate)
	var elapsed: float = 0.0
	var tracked_position: Vector2 = position_value
	var previous_animation: String = str(track.get("animation", ""))
	var changing_gait: bool = player and animation in ["run", "backpedal"] and previous_animation in ["run", "backpedal"]
	if not reset and not restart and (animation == previous_animation or changing_gait):
		elapsed = float(track.elapsed)
		if changing_gait and animation != previous_animation:
			# Keep the same planted leg when aim or travel changes direction.
			elapsed *= _duration(actor, animation) / _duration(actor, previous_animation)
		var stride: float = float(actor.stride_distances.get(animation, 0.0))
		if player and animation in ["run", "backpedal"] and stride > 0.0:
			# A planted foot must sweep opposite actual travel. Aim mirrors the
			# body independently, so backpedalling reverses the gait. Measure the
			# rendered position: no skating through stops, clamped haste cadence,
			# or phase drift while interpolation and simulation use different Hz.
			if dt > 0.0:
				var facing: float = 1.0 if Vector2(state.get("aim", Vector2.RIGHT)).x >= 0.0 else -1.0
				var travel: float = position_value.x - Vector2(track.pos).x
				# A dedicated retreat clip is authored in its own forward order.
				# Old sheets without it retain the backwards-compatible reversed run.
				var gait_travel: float = absf(travel) if actor.animations.has("backpedal") else travel * facing
				elapsed += gait_travel * _duration(actor, animation) / stride
			else:
				# A projectile may ask for its muzzle during set_frame, before the
				# world clock advances. Keep that travel for the next render sample.
				tracked_position = track.pos
		else:
			# Integrate flying/enemy cadence instead of rescaling the world clock.
			elapsed += dt * float(track.get("rate", rate))
	elif not player and animation in ["idle", "move", "run"]:
		elapsed = float(posmod(int(state.get("id", 0)), 37)) * 0.071
	if not player:
		elapsed = _enemy_action_time(actor, animation, state, elapsed)
	if not tracks.has(key) and tracks.size() >= MAX_TRACKS:
		var oldest: String = ""
		var oldest_clock: float = INF
		for existing_key: String in tracks:
			if float(tracks[existing_key].clock) < oldest_clock:
				oldest_clock = float(tracks[existing_key].clock)
				oldest = existing_key
		tracks.erase(oldest)
	tracks[key] = {"clock": safe_clock, "animation": animation, "elapsed": elapsed, "rate": rate, "grounded": grounded, "attack_count": attack_count, "pos": tracked_position, "land_position": land_position}
	cache.clock = safe_clock
	canvas.set_meta(TRACK_META, cache)
	return _sample_frame(id, actor, state, animation, elapsed, player)

static func _sample_frame(id: String, actor: Dictionary, state: Dictionary, animation: String, elapsed: float, player: bool) -> Dictionary:
	var indices: Array = actor.animations[animation]
	var duration: float = _duration(actor, animation)
	var loop: bool = str(actor.animation_modes[animation]) == "loop"
	var phase: float = fposmod(elapsed, duration) if loop else clampf(elapsed, 0.0, duration)
	var chosen: int = int(indices.back())
	for index: Variant in indices:
		chosen = int(index)
		phase -= float(actor.frames[chosen].duration)
		if phase < -0.000001:
			break
	var frame: Dictionary = actor.frames[chosen]
	var flash: bool = float(state.get("hurt_timer", 0.0)) > 5.87 if player else float(state.get("flash", 0.0)) > 0.0
	var tint: Color = Color(1.75, 1.75, 1.65, 1.0) if flash else Color.WHITE
	if not player and bool(state.get("elite", false)):
		tint *= Color(1.08, 1.02, 0.91, 1.0)
	return {"actor": id, "animation": animation, "index": chosen, "texture": frame.texture, "source": frame.source, "target": frame.target, "draw_target": frame.draw_target, "tint": tint, "elapsed": elapsed, "duration": duration, "loop": loop, "shoulder": frame.shoulder}

static func draw_player(canvas: Node2D, player: Dictionary, clock: float) -> bool:
	var character: String = str(player.get("character", "ranger"))
	var frame: Dictionary = tracked_frame_for(canvas, character, player, clock, true)
	var motion: Dictionary = player.get("_melee_pose", {})
	if not frame.is_empty() and frame.draw_target.size.y >= 32 and character in ["ranger", "vanguard"]:
		var gait: Dictionary = Gait.sample(canvas, player, clock, str(frame.animation))
		if bool(gait.active):
			# Ground motion owns two articulated legs, never the PNG's lower body.
			# A stable authored torso avoids both eight-frame near/far-leg swaps
			# and incidental torso flicker while the feet traverse their real paths.
			frame = _sample_frame(character, _actors[character], player, str(frame.animation), 0.0, true)
			Gait.draw(canvas, gait, character, frame.tint)
			_draw_upper_body(canvas, frame, motion, Gait.CUT_Y)
			return true
	if frame.is_empty() or not bool(motion.get("active", false)) or not motion.has("draw_origin"):
		return _draw(canvas, frame)
	# Keep the original running/jumping legs. Rotate only the upper-body crop
	# around the waist, with no resampling, source edits, or shifted foot anchor.
	var target: Rect2 = frame.draw_target
	var waist: float = clampf(5.0, target.position.y + 1.0, target.end.y - 1.0)
	var top_height: float = waist - target.position.y
	var lower := Rect2(Vector2(target.position.x, waist), Vector2(target.size.x, target.end.y - waist))
	canvas.draw_texture_rect_region(frame.texture, lower, Rect2(Vector2(0, top_height), lower.size), frame.tint)
	var facing: float = float(motion.facing)
	canvas.draw_set_transform(Vector2(motion.draw_origin) + Vector2(0, waist), float(motion.body_angle) * facing, Vector2(facing, 1))
	canvas.draw_texture_rect_region(frame.texture, Rect2(target.position - Vector2(0, waist), Vector2(target.size.x, top_height)), Rect2(Vector2.ZERO, Vector2(target.size.x, top_height)), frame.tint)
	canvas.draw_set_transform(motion.draw_origin, 0.0, Vector2(facing, 1))
	return true

static func _draw_upper_body(canvas: Node2D, frame: Dictionary, motion: Dictionary, cut: float) -> void:
	var target: Rect2 = frame.draw_target
	var height: float = cut - target.position.y
	var destination := Rect2(target.position, Vector2(target.size.x, height))
	var source := Rect2(Vector2.ZERO, destination.size)
	if not bool(motion.get("active", false)) or not motion.has("draw_origin"):
		canvas.draw_texture_rect_region(frame.texture, destination, source, frame.tint)
		return
	var facing: float = float(motion.facing)
	var waist := Vector2(0,5)
	canvas.draw_set_transform(Vector2(motion.draw_origin)+waist,float(motion.body_angle)*facing,Vector2(facing,1))
	destination.position -= waist
	canvas.draw_texture_rect_region(frame.texture,destination,source,frame.tint)
	canvas.draw_set_transform(motion.draw_origin,0.0,Vector2(facing,1))

static func draw_enemy(canvas: Node2D, enemy: Dictionary, clock: float) -> bool:
	var frame: Dictionary = tracked_frame_for(canvas, enemy_id(enemy), enemy, clock)
	if frame.is_empty(): return false
	canvas.draw_texture_rect(frame.texture,EnemyAttackArt.body_rect(frame.draw_target,enemy),false,frame.tint)
	return true

static func _draw(canvas: Node2D, frame: Dictionary) -> bool:
	if frame.is_empty():
		return false
	canvas.draw_texture_rect(frame.texture, frame.draw_target, false, frame.tint)
	return true
