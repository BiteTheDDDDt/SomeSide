class_name SidePixelActorRenderer
extends RefCounted

## Authored sprites replace only the actor body. The caller supplies its existing
## local facing transform; weapons, relics, health bars and telegraphs stay live.
## Every frame owns an explicit crop and center anchor, never an assumed grid.
const MANIFEST_PATH: String = "res://assets/sprites/actors.json"
const MAX_ACTORS: int = 32
const MAX_FRAMES: int = 64
const MAX_TEXTURE_BYTES: int = 64 * 1024 * 1024
static var _loaded: bool = false
static var _actors: Dictionary = {}
static var _textures: Dictionary = {}
static var _errors: Array[String] = []
static var _texture_bytes: int = 0

static func _ensure_loaded() -> void:
	if not _loaded:
		reload_manifest()

static func reload_manifest(path: String = MANIFEST_PATH) -> void:
	_actors.clear()
	_textures.clear()
	_errors.clear()
	_texture_bytes = 0
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
	_actors.clear()
	_textures.clear()
	_errors.clear()
	_texture_bytes = 0
	_loaded = true
	if int(data.get("version", 0)) != 1 or not data.get("actors", {}) is Dictionary:
		_errors.append("Unsupported actor manifest version or actor table")
		return
	var records: Dictionary = data.get("actors", {})
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
			if not _numbers(frame.get("rect"), 4) or not _numbers(frame.get("anchor"), 2):
				break
			var rect: Rect2 = _rect(frame.rect)
			var anchor: Vector2 = Vector2(float(frame.anchor[0]), float(frame.anchor[1]))
			var duration: float = float(frame.get("duration", 0.12))
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(rect) or not is_finite(duration) or duration <= 0.0:
				break
			# Anchors may sit just outside a tightly cropped image, but not explode
			# geometry if a malformed manifest uses an unbounded value.
			if anchor.abs().x > 8192.0 or anchor.abs().y > 8192.0:
				break
			var target: Rect2 = Rect2(-anchor * scale_value, rect.size * scale_value)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = rect
			atlas.filter_clip = true
			frames.append({"source": rect, "anchor": anchor, "target": target, "duration": clampf(duration, 0.016, 5.0), "texture": atlas})
			union = target if frames.size() == 1 else union.merge(target)
		if frames.size() != frame_values.size():
			_errors.append("Invalid crop, anchor or timing: " + id)
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
		_actors[id] = {"path": path, "frames": frames, "animations": animations, "bounds": bounds, "scale": scale_value}

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
	return {"actors": _actors.size(), "textures": _textures.size(), "bytes": _texture_bytes, "max_bytes": MAX_TEXTURE_BYTES, "errors": _errors.duplicate()}

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
		return "run" if absf(velocity.x) > 15.0 else "idle"
	if float(state.get("telegraph", 0.0)) > 0.0:
		return "windup"
	if float(state.get("charge_timer", 0.0)) > 0.0 or (not str(state.get("attack_kind", "")).is_empty() and float(state.get("attack_cd", 0.0)) > float(state.get("attack_cooldown", 3.0)) - 0.18):
		return "attack"
	return "move" if velocity.length_squared() > 100.0 or bool(state.get("flying", false)) else "idle"

static func frame_for(id: String, state: Dictionary, clock: float, player: bool = false) -> Dictionary:
	_ensure_loaded()
	if not _actors.has(id):
		return {}
	var actor: Dictionary = _actors[id]
	var animation: String = animation_for(state, player)
	var aliases: Dictionary = {"run": "move", "move": "run", "rise": "jump", "fall": "jump", "dash": "run", "attack": "move", "windup": "idle", "dead": "idle"}
	if not actor.animations.has(animation):
		animation = str(aliases.get(animation, "idle"))
	if not actor.animations.has(animation):
		animation = "idle"
	var indices: Array = actor.animations[animation]
	var duration: float = 0.0
	for index: Variant in indices:
		duration += float(actor.frames[int(index)].duration)
	var safe_clock: float = maxf(0.0, clock) if is_finite(clock) else 0.0
	var phase: float = fposmod(safe_clock + (0.0 if player else float(int(state.get("id", 0)) % 37) * 0.071), duration)
	var chosen: int = int(indices.back())
	for index: Variant in indices:
		chosen = int(index)
		phase -= float(actor.frames[chosen].duration)
		if phase < 0.0:
			break
	var frame: Dictionary = actor.frames[chosen]
	var flash: bool = float(state.get("hurt_timer", 0.0)) > 5.87 if player else float(state.get("flash", 0.0)) > 0.0
	var tint: Color = Color(1.75, 1.75, 1.65, 1.0) if flash else Color.WHITE
	if not player and bool(state.get("elite", false)):
		tint *= Color(1.08, 1.02, 0.91, 1.0)
	return {"actor": id, "animation": animation, "index": chosen, "texture": frame.texture, "source": frame.source, "target": frame.target, "tint": tint}

static func draw_player(canvas: Node2D, player: Dictionary, clock: float) -> bool:
	return _draw(canvas, frame_for(str(player.get("character", "ranger")), player, clock, true))

static func draw_enemy(canvas: Node2D, enemy: Dictionary, clock: float) -> bool:
	return _draw(canvas, frame_for(enemy_id(enemy), enemy, clock))

static func _draw(canvas: Node2D, frame: Dictionary) -> bool:
	if frame.is_empty():
		return false
	canvas.draw_texture_rect(frame.texture, frame.target, false, frame.tint)
	return true
