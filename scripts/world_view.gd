class_name SideWorldView
extends Node2D

## Presentation only: all authoritative game state lives in SideSimulation.
## Camera position is the world-space CENTER of the view.
var camera_position: Vector2 = Vector2(640.0, 650.0)
var screen_size: Vector2 = Vector2(1280.0, 720.0)
var menu_preview: bool = false
var reduced_motion: bool = false
var fx_scale: float = 1.0
var shake_enabled: bool = true
var interpolate_remote_entities: bool = false
var combat_paused: bool = false
var interaction_target: Dictionary = {}
## Native scenery textures remove repeated triangulation/material draws.
## This switch exists for fidelity/performance regression captures.
var scenery_cache_enabled: bool = true
## Web avoids rebuilding curved background/foliage geometry on every frame.
## The separate switch also permits focused presentation tests on desktop.
var web_background_cache_enabled: bool = OS.has_feature("web")

const ItemIcons = preload("res://scripts/item_icons.gd")
const Biomes = preload("res://scripts/biome_renderer.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const WeaponArt = preload("res://scripts/weapon_art.gd")
const MeleeMotion = preload("res://scripts/melee_motion.gd")
const WeaponAction = preload("res://scripts/weapon_action_motion.gd")
const Appearance = preload("res://scripts/player_appearance.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const ProjectileArt = preload("res://scripts/projectile_renderer.gd")
const EnemyAttackArt = preload("res://scripts/enemy_attack_visual.gd")
const NaturalThreats = preload("res://scripts/natural_threats.gd")
const ProcFeedback = preload("res://scripts/proc_feedback.gd")
const Locale = preload("res://scripts/localization.gd")
const MAX_EFFECTS: int = 384
const MAX_DAMAGE_NUMBERS: int = 32
const PARTICLE_KINDS: Array[String] = ["spark", "fragment", "ember", "smoke"]
const PARTICLE_WIDTHS: Array[float] = [1.0, 2.0, 4.0, 7.0]

const IllustratedFX = preload("res://scripts/illustrated_fx.gd")
const INK: Color = Color("07171e")
const SKY: Color = Color("081e28")
const TEAL: Color = Color("7df3d0")
const GOLD: Color = Color("ffc176")
const ORANGE: Color = Color("fa8855")
const CREAM: Color = Color("e9f3da")

var _frame: Dictionary = {}
var _local_id: int = 1
var _clock: float = 0.0
var _combat_clock: float = 0.0
var _melee_tracks: Dictionary = {}
var _melee_predictions: Dictionary = {}
var _weapon_tracks: Dictionary = {}
var _weapon_predictions: Dictionary = {}
var _camera_ready: bool = false
var _effects: Array[Dictionary] = []
var _numbers: Array[Dictionary] = []
var _particle_batches: int = 0
var _particle_segments: int = 0
var _particle_points: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
var _particle_colors: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _font: Font
var _shake: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _stars: Array[Vector3] = []
var _render_positions: Dictionary = {}
var _fixed_samples: Dictionary = {}
var _render_stage: int = -1
var _last_snapshot_time: float = -1.0
var _snapshot_age: float = 0.0
var _current_biome: String = "rainforest"
var _camera_stage: int = -1
const SCENERY_CACHE_BYTES: int = 48*1024*1024
const SCENERY_CACHE_ENTRIES: int = 40
var _scenery_cache: Dictionary = {}
var _scenery_bytes: int = 0
var _background_cache: Dictionary = {}
var _background_camera: Vector2 = Vector2.INF
var _background_clock: float = -1.0
var _cache_builds_this_frame: int = 0
var _scenery_layout_signature: int = 0
var _background_live: bool = true
const WEB_BACKGROUND_MARGIN: Vector2 = Vector2(256.0, 128.0)
const WEB_BACKGROUND_PARALLAX: float = 0.18
const WEB_BACKGROUND_BLEND_TIME: float = 0.22
const WEB_BACKGROUND_MAX_BYTES: int = 16 * 1024 * 1024
var _web_background: Dictionary = {}
var _web_background_pending: Dictionary = {}
var _web_background_blend_start: float = -1.0
var _web_background_builds: int = 0

class SceneryBake:
	extends Node2D
	const Art = preload("res://scripts/biome_renderer.gd")
	var mode: String = "terrain"
	var screen_size: Vector2
	var offset: Vector2
	var camera: Vector2
	var biome: String
	var world: Vector2
	var rectangle: Rect2
	var platform_index: int
	var landmark: Dictionary
	var clock_value: float
	var background_margin: Vector2 = Vector2.ZERO
	var freeze_foliage: bool = false
	func world_to_screen(p: Vector2) -> Vector2:
		return p-offset
	func _draw() -> void:
		if mode=="web_background":
			# Extend the original sky colors behind the padded art. Art retains its
			# original logical viewport, so padding never moves or enlarges its moon.
			var top: Color = Color("091c28")
			var bottom: Color = Color("294b4b")
			if biome=="canyon": top=Color("252232"); bottom=Color("815c46")
			elif biome=="ruins": top=Color("111526"); bottom=Color("39334d")
			var width: float = screen_size.x+background_margin.x*2.0
			draw_rect(Rect2(0,0,width,background_margin.y+1.0),top)
			for band: int in range(48):
				draw_rect(Rect2(0,background_margin.y+band*screen_size.y/48.0,width,screen_size.y/48.0+1.0),top.lerp(bottom,float(band)/47.0))
			draw_rect(Rect2(0,background_margin.y+screen_size.y,width,background_margin.y+1.0),bottom)
			draw_set_transform(background_margin)
			Art.background(self,biome,camera,screen_size,world,clock_value)
			draw_set_transform(Vector2.ZERO)
		elif mode=="background": Art.background(self,biome,camera,screen_size,world,clock_value)
		elif mode=="landmark": Art.landmarks(self,[landmark],biome,clock_value)
		else: Art.platform(self,rectangle,platform_index,biome,0.0 if freeze_foliage else clock_value,screen_size,world,not freeze_foliage)


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var world_font: FontVariation = FontVariation.new()
		world_font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
		world_font.variation_opentype = {2003265652: 500.0}
		_font = world_font
	_rng.seed = 720451
	for index: int in range(84):
		_stars.append(Vector3(_rng.randf_range(0.0, 1500.0), _rng.randf_range(15.0, 510.0), _rng.randf_range(0.3, 1.35)))
	Entities.prepare(self)
	ProjectileArt.prepare(self)
	set_process(true)


func set_frame(snapshot: Dictionary, local_id: int, delta: float) -> void:
	_frame = snapshot
	_local_id = local_id
	var stage: int = int(_frame.get("stage", 1))
	_current_biome = str(_frame.get("biome", ["rainforest", "canyon", "ruins"][clampi(stage - 1, 0, 2)]))
	var layout_signature: int=hash([_current_biome,_frame.get("world_size",Vector2.ZERO),_frame.get("platforms",[]),_frame.get("landmarks",[])])
	if layout_signature!=_scenery_layout_signature:
		_clear_scenery_cache()
		_scenery_layout_signature=layout_signature
	if stage != _camera_stage:
		_camera_ready = false
		_camera_stage = stage
		_effects.clear()
		_numbers.clear()
		_clear_scenery_cache()
	_update_render_positions(maxf(delta, 0.0))
	var target: Vector2 = camera_position
	var players: Dictionary = _frame.get("players", {})
	if menu_preview:
		var spawn: Vector2 = _frame.get("spawn", Vector2(200.0, 999.0))
		target = spawn + Vector2(660.0 + sin(_clock * 0.06) * 160.0, -220.0)
	elif players.has(local_id):
		var player: Dictionary = players[local_id]
		var position_value: Vector2 = _entity_draw_position("p" + str(local_id), player.get("pos", Vector2(640.0, 750.0)))
		var aim: Vector2 = player.get("aim", Vector2.RIGHT)
		target = position_value + Vector2(aim.x * 92.0, -58.0 + aim.y * 38.0)
		if bool(player.get("dead", false)):
			for other: Variant in players.values():
				var other_player: Dictionary = other
				if not bool(other_player.get("dead", false)):
					target = _entity_draw_position("p" + str(other_player.get("id", -1)), other_player.get("pos", target))
					break
	var world_size: Vector2 = _frame.get("world_size", Vector2(3200.0, 1100.0))
	target.x = clampf(target.x, screen_size.x * 0.5, maxf(screen_size.x * 0.5, world_size.x - screen_size.x * 0.5))
	target.y = clampf(target.y, screen_size.y * 0.5, maxf(screen_size.y * 0.5, world_size.y - screen_size.y * 0.5 + 30.0))
	if not _camera_ready:
		camera_position = target
		_camera_ready = true
	else:
		camera_position = camera_position.lerp(target, 1.0 - exp(-maxf(delta, 0.0) * 5.5))
	_prepare_scenery_cache()
	queue_redraw()


func _clear_scenery_cache() -> void:
	for entry: Dictionary in _scenery_cache.values(): entry.viewport.queue_free()
	_scenery_cache.clear()
	_scenery_bytes=0
	if not _background_cache.is_empty(): _background_cache.viewport.queue_free()
	_background_cache.clear()
	_background_camera=Vector2.INF
	_background_clock=-1.0
	_clear_web_background()


func scenery_cache_stats() -> Dictionary:
	var background_bytes: int = int(_web_background.get("bytes",0))+int(_web_background_pending.get("bytes",0))
	return {"entries":_scenery_cache.size(),"bytes":_scenery_bytes,"max_entries":SCENERY_CACHE_ENTRIES,"max_bytes":SCENERY_CACHE_BYTES,"background_bytes":background_bytes,"background_entries":int(not _web_background.is_empty())+int(not _web_background_pending.is_empty()),"background_builds":_web_background_builds,"background_max_bytes":WEB_BACKGROUND_MAX_BYTES,"cached_foliage":web_background_cache_enabled}


func _clear_web_background() -> void:
	if not _web_background.is_empty(): _web_background.viewport.queue_free()
	if not _web_background_pending.is_empty(): _web_background_pending.viewport.queue_free()
	_web_background.clear()
	_web_background_pending.clear()
	_web_background_blend_start=-1.0


func _web_background_size() -> Vector2i:
	return Vector2i((screen_size+WEB_BACKGROUND_MARGIN*2.0).ceil())


func _new_web_background() -> Dictionary:
	var size_value: Vector2i = _web_background_size()
	# Two complete textures coexist only during a short, bounded crossfade.
	if size_value.x<=0 or size_value.y<=0 or size_value.x>4096 or size_value.y>4096 or size_value.x*size_value.y*8>WEB_BACKGROUND_MAX_BYTES:
		return {}
	var entry: Dictionary = _new_scenery_bake(size_value,Vector2.ZERO,"web_background")
	entry.painter.screen_size=screen_size
	entry.painter.background_margin=WEB_BACKGROUND_MARGIN
	entry.painter.camera=camera_position
	entry.painter.clock_value=_clock
	entry["camera"]=camera_position
	entry["screen_size"]=screen_size
	_web_background_builds+=1
	return entry


func _web_background_offset(entry: Dictionary) -> Vector2:
	return -WEB_BACKGROUND_MARGIN+(Vector2(entry.camera)-camera_position)*WEB_BACKGROUND_PARALLAX


func _web_background_covers(entry: Dictionary) -> bool:
	return Rect2(_web_background_offset(entry),Vector2(entry.viewport.size)).encloses(Rect2(Vector2.ZERO,screen_size))


func _web_background_mix() -> float:
	if _web_background_blend_start<0.0: return 0.0
	return clampf((_clock-_web_background_blend_start)/WEB_BACKGROUND_BLEND_TIME,0.0,1.0)


func _prepare_web_background() -> void:
	if not _web_background.is_empty() and Vector2(_web_background.screen_size)!=screen_size:
		_clear_web_background()
	if _web_background.is_empty():
		_web_background=_new_web_background()
		return
	if not _web_background_pending.is_empty():
		if Engine.get_process_frames()>=int(_web_background_pending.ready):
			if _web_background_blend_start<0.0: _web_background_blend_start=_clock
			if _web_background_mix()>=1.0:
				_web_background.viewport.queue_free()
				_web_background=_web_background_pending
				_web_background_pending={}
				_web_background_blend_start=-1.0
		return
	var distance_value: Vector2 = ((camera_position-Vector2(_web_background.camera))*WEB_BACKGROUND_PARALLAX).abs()
	if distance_value.x>WEB_BACKGROUND_MARGIN.x*0.45 or distance_value.y>WEB_BACKGROUND_MARGIN.y*0.45:
		_web_background_pending=_new_web_background()
		_web_background_blend_start=-1.0


func _draw_web_background() -> bool:
	if _web_background.is_empty() or Engine.get_process_frames()<int(_web_background.ready): return false
	# A same-stage teleport can outrun the padding; use the full live fallback
	# during replacement instead of ever exposing an unpainted edge.
	if not _web_background_covers(_web_background):
		if not _web_background_pending.is_empty() and Engine.get_process_frames()>=int(_web_background_pending.ready) and _web_background_covers(_web_background_pending):
			draw_texture(_web_background_pending.texture,_web_background_offset(_web_background_pending))
			return true
		return false
	draw_texture(_web_background.texture,_web_background_offset(_web_background))
	if not _web_background_pending.is_empty() and Engine.get_process_frames()>=int(_web_background_pending.ready):
		draw_texture(_web_background_pending.texture,_web_background_offset(_web_background_pending),Color(1,1,1,_web_background_mix()))
	return true


func _new_scenery_bake(size_value: Vector2i, origin: Vector2, mode: String) -> Dictionary:
	var viewport: SubViewport=SubViewport.new()
	viewport.size=size_value
	viewport.transparent_bg=mode!="background"
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var painter: SceneryBake=SceneryBake.new()
	painter.mode=mode
	painter.offset=origin
	painter.screen_size=Vector2(size_value)
	painter.biome=_current_biome
	painter.world=_frame.get("world_size",Vector2(3200,1100))
	painter.freeze_foliage=web_background_cache_enabled and mode=="terrain"
	viewport.add_child(painter)
	return {"viewport":viewport,"painter":painter,"texture":viewport.get_texture(),"ready":Engine.get_process_frames()+2,"last":Engine.get_process_frames(),"bytes":size_value.x*size_value.y*4,"origin":origin}


func _cached_scenery(key: String, size_value: Vector2i, origin: Vector2, mode: String) -> Dictionary:
	if _scenery_cache.has(key):
		_scenery_cache[key].last=Engine.get_process_frames()
		return _scenery_cache[key]
	if _cache_builds_this_frame>=2: return {}
	var cost: int=size_value.x*size_value.y*4
	while _scenery_cache.size()>=SCENERY_CACHE_ENTRIES or _scenery_bytes+cost>SCENERY_CACHE_BYTES:
		var oldest: String=""
		var oldest_frame: int=Engine.get_process_frames()
		for candidate: String in _scenery_cache:
			if int(_scenery_cache[candidate].last)<oldest_frame:
				oldest=candidate
				oldest_frame=int(_scenery_cache[candidate].last)
		if oldest.is_empty(): return {}
		_scenery_bytes-=int(_scenery_cache[oldest].bytes)
		_scenery_cache[oldest].viewport.queue_free()
		_scenery_cache.erase(oldest)
	var entry: Dictionary=_new_scenery_bake(size_value,origin,mode)
	_scenery_cache[key]=entry
	_scenery_bytes+=cost
	_cache_builds_this_frame+=1
	return entry


func _terrain_tiles(rectangle: Rect2) -> Vector2i:
	# Ground depth is screen-dependent; retaining its original draw prevents
	# cropped strata at low cameras and avoids allocating world-sized textures.
	var world_size: Vector2=_frame.get("world_size",Vector2(3200,1100))
	if rectangle.size.y>60 or rectangle.position.y>=world_size.y-160: return Vector2i(-1,-1)
	var p: Vector2=world_to_screen(rectangle.position)
	if p.x+rectangle.size.x < -100 or p.x>screen_size.x+100 or p.y>screen_size.y+110 or p.y < -140: return Vector2i(-1,-1)
	return Vector2i(maxi(0,int(floor((-80-p.x)/512.0))),mini(int(ceil(rectangle.size.x/512.0)),int(ceil((screen_size.x+80-p.x)/512.0))))


func _static_landmark(landmark: Dictionary) -> bool:
	var kind: String=str(landmark.get("kind",""))
	return not (_current_biome=="rainforest" and kind=="waterfall") and not (_current_biome=="ruins" and kind not in ["archive","crypt","reactor"])


func _prepare_scenery_cache() -> void:
	if not scenery_cache_enabled or not is_inside_tree(): return
	_cache_builds_this_frame=0
	if web_background_cache_enabled:
		_prepare_web_background()
	else:
		if _background_cache.is_empty() or Vector2(_background_cache.painter.screen_size)!=screen_size:
			if not _background_cache.is_empty(): _background_cache.viewport.queue_free()
			_background_cache=_new_scenery_bake(Vector2i(screen_size),Vector2.ZERO,"background")
			_background_camera=Vector2.INF
		# Parallax is updated on every visible camera change. The only autonomous
		# movement in this layer is a very slow vine (<0.12 px per refresh).
		_background_live=not _background_camera.is_finite() or _background_camera.distance_squared_to(camera_position)>0.0025
		if not _background_live and (_background_clock<0 or _background_cache.painter.camera.distance_squared_to(camera_position)>0.0025 or (_current_biome=="rainforest" and _clock-_background_clock>1.0/30.0)):
			_background_cache.painter.camera=camera_position
			_background_cache.painter.clock_value=_clock
			_background_cache.painter.queue_redraw()
			_background_cache.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			_background_clock=_clock
		if _background_live: _background_clock=-1.0
		_background_camera=camera_position
	var platforms: Array=_frame.get("platforms",[])
	for index: int in range(platforms.size()):
		var rectangle: Rect2=platforms[index]
		var tiles: Vector2i=_terrain_tiles(rectangle)
		if tiles.x<0: continue
		for tile: int in range(tiles.x,tiles.y):
			var origin: Vector2=rectangle.position+Vector2(tile*512-96,-64)
			var entry: Dictionary=_cached_scenery("t%d:%d"%[index,tile],Vector2i(704,256),origin,"terrain")
			if not entry.is_empty():
				entry.painter.rectangle=rectangle
				entry.painter.platform_index=index
	for index: int in range(Array(_frame.get("landmarks",[])).size()):
		var landmark: Dictionary=_frame.landmarks[index]
		if not _static_landmark(landmark): continue
		var scale_value: float=clampf(float(landmark.get("scale",1.0)),0.5,3.0)
		var p: Vector2=world_to_screen(landmark.pos)
		if not Rect2(p-Vector2(400,500)*scale_value,Vector2(800,900)*scale_value).intersects(Rect2(Vector2.ZERO,screen_size)): continue
		var origin: Vector2=Vector2(landmark.pos)-Vector2(400,500)*scale_value
		var entry: Dictionary=_cached_scenery("l%d"%index,Vector2i(Vector2(800,900)*scale_value),origin,"landmark")
		if not entry.is_empty(): entry.painter.landmark=landmark


func _draw_cached_landmarks() -> void:
	var landmarks: Array=_frame.get("landmarks",[])
	for index: int in range(landmarks.size()):
		var entry: Dictionary=_scenery_cache.get("l%d"%index,{}) if scenery_cache_enabled else {}
		if not entry.is_empty() and Engine.get_process_frames()>=int(entry.ready):
			draw_texture(entry.texture,world_to_screen(entry.origin))
		else:
			Biomes.landmarks(self,[landmarks[index]],_current_biome,_clock)


func screen_to_world(screen_position: Vector2) -> Vector2:
	return screen_position + camera_position - screen_size * 0.5 - _shake_offset


func world_to_screen(world_position: Vector2) -> Vector2:
	return world_position - camera_position + screen_size * 0.5 + _shake_offset


func _update_render_positions(delta: float) -> void:
	# This cache never writes into the authoritative or predicted snapshot.
	var stage: int = int(_frame.get("stage", 1))
	var snapshot_time: float = float(_frame.get("time", 0.0))
	if stage != _render_stage or snapshot_time < _last_snapshot_time:
		Pixels.reset_tracks(self)
		_melee_tracks.clear()
		_melee_predictions.clear()
		_weapon_tracks.clear()
		_weapon_predictions.clear()
		_render_positions.clear()
		_fixed_samples.clear()
		_render_stage = stage
	if snapshot_time != _last_snapshot_time:
		_snapshot_age = 0.0
		_last_snapshot_time = snapshot_time
	else:
		_snapshot_age = minf(0.05, _snapshot_age + delta)
	var alive: Dictionary = {}
	var players: Dictionary = _frame.get("players", {})
	for owner: Variant in _melee_tracks.keys():
		if not players.has(owner):
			_melee_tracks.erase(owner)
			_melee_predictions.erase(owner)
	for owner: Variant in _weapon_tracks.keys():
		if not players.has(owner):
			_weapon_tracks.erase(owner)
			_weapon_predictions.erase(owner)
	for player_id: Variant in players:
		var player: Dictionary = players[player_id]
		var key: String = "p" + str(player_id)
		if not interpolate_remote_entities or int(player_id) == _local_id:
			# The local client's position advances on prediction ticks, while its
			# snapshot time only advances on packets. Do not use network age here.
			var tick: float = float(Engine.get_physics_frames()) if interpolate_remote_entities else snapshot_time
			_cache_fixed_position(key, player, tick, delta, 1.0 if interpolate_remote_entities else 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second)))
		else:
			_cache_entity_position(key, player, delta, 28.0)
		alive[key] = true
	for category: String in ["enemies", "projectiles", "coin_pickups"]:
		for value: Variant in _frame.get(category, []):
			var entity: Dictionary = value
			var key: String = ("b" if category == "projectiles" else ("c" if category == "coin_pickups" else "e")) + str(entity.get("id", 0))
			if interpolate_remote_entities:
				_cache_entity_position(key, entity, delta, 42.0 if category == "projectiles" else 28.0)
			else:
				var fresh: bool = not _fixed_samples.has(key)
				_cache_fixed_position(key, entity, snapshot_time, delta)
				if category == "projectiles" and fresh:
					_seed_projectile_motion(key, entity)
			alive[key] = true
	for key: Variant in _render_positions.keys():
		if not alive.has(key):
			_render_positions.erase(key)
			_fixed_samples.erase(key)


func _cache_fixed_position(key: String, entity: Dictionary, tick: float, delta: float, tick_period: float = 1.0 / 60.0) -> void:
	var position_value: Vector2 = entity.get("pos", Vector2.ZERO)
	var dead: bool = bool(entity.get("dead", false))
	var step: float = 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second))
	var sample: Dictionary = _fixed_samples.get(key, {})
	if sample.is_empty() or tick < float(sample.tick) or position_value.distance_squared_to(sample.current) > 180.0 * 180.0 or dead != bool(sample.dead):
		sample = {"previous": position_value, "current": position_value, "tick": tick, "age": 0.0, "span": step, "dead": dead}
	elif tick != float(sample.tick):
		sample.erase("launch_origin")
		var span: float = maxf(step, (tick - float(sample.tick)) / tick_period * step)
		var skipped: bool = span > 0.1
		sample.previous = position_value if skipped else sample.current
		sample.current = position_value
		sample.tick = tick
		sample.span = span
		# Keep the fractional render phase across ticks (including 144/165 Hz),
		# rather than restarting it whenever a physics update happens to arrive.
		sample.age = clampf(float(sample.age) + delta - span, 0.0, step) if not skipped else 0.0
	else:
		# A client's visual reconciliation offset can change between prediction
		# ticks. Apply that offset once, without a second low-pass/velocity guess.
		var correction: Vector2 = position_value - Vector2(sample.current)
		sample.previous += correction
		sample.current = position_value
		sample.age = minf(step, float(sample.age) + delta)
	_fixed_samples[key] = sample
	# Interpolation stays within two known physics positions. Landing, walls and
	# released movement cannot extrapolate through collision geometry.
	var fraction: float = (float(sample.span) - step + float(sample.age)) / float(sample.span)
	_render_positions[key] = Vector2(sample.previous).lerp(sample.current, clampf(fraction, 0.0, 1.0))


func _seed_projectile_motion(key: String, projectile: Dictionary) -> void:
	var step: float = 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second))
	if str(projectile.get("team", "")) != "player" or str(projectile.get("kind", "")) not in ["bullet", "pellet", "rail", "boomerang", "storm", "lance"] or float(projectile.get("age", 1.0)) > step * 1.01:
		return
	var owner: Dictionary = Dictionary(_frame.get("players", {})).get(int(projectile.get("owner", -1)), {})
	if owner.is_empty() or bool(owner.get("dead", false)) or Vector2(projectile.get("origin", Vector2.INF)).distance_to(WeaponPose.muzzle_position(owner)) > 2.0:
		return
	# A newly fired bullet has already advanced one authority step. Give its
	# first visual segment the same interpolated gun origin as the muzzle flash;
	# old network bullets, turrets and active equipment never attach to the gun.
	var origin: Vector2 = weapon_draw_pose(owner).muzzle
	var sample: Dictionary = _fixed_samples[key]
	sample.previous = origin
	sample.launch_origin = origin
	sample.age = 0.0
	_fixed_samples[key] = sample
	_render_positions[key] = origin


func rendered_projectile_trail_length(projectile: Dictionary, draw_position: Vector2, maximum: float) -> float:
	var length: float = projectile_trail_length(projectile, draw_position, maximum)
	var sample: Dictionary = _fixed_samples.get("b" + str(projectile.get("id", 0)), {})
	if sample.has("launch_origin"):
		var direction: Vector2 = Vector2(projectile.get("vel", Vector2.RIGHT)).normalized()
		length = minf(length, maxf(0.0, (draw_position - Vector2(sample.launch_origin)).dot(direction)))
	return length


func _cache_entity_position(key: String, entity: Dictionary, delta: float, response: float) -> void:
	var position_value: Vector2 = entity.get("pos", Vector2.ZERO)
	var velocity: Vector2 = entity.get("vel", Vector2.ZERO)
	var target: Vector2 = position_value + velocity * _snapshot_age
	var previous: Vector2 = _render_positions.get(key, target)
	# Teleports, stage changes, respawns, and large corrections snap immediately.
	_render_positions[key] = target if previous.distance_squared_to(target) > 180.0 * 180.0 else previous.lerp(target, 1.0 - exp(-response * delta))


func _entity_draw_position(key: String, position_value: Vector2) -> Vector2:
	return _render_positions.get(key, position_value)


func _start_melee(event: Dictionary) -> void:
	var owner: int = int(event.get("player", -1))
	if owner < 0:
		return
	var predicted: bool = bool(event.get("predicted", false))
	var id: int = int(event.get("attack_id", 0))
	var existing: Dictionary = _melee_tracks.get(owner, {})
	if not existing.is_empty() and bool(existing.predicted) == predicted and int(existing.id) >= id and id > 0:
		return
	if not predicted and int(_melee_predictions.get(owner, -1)) >= id:
		return
	if predicted:
		_melee_predictions[owner] = maxi(id, int(_melee_predictions.get(owner, -1)))
	_melee_tracks[owner] = {"id": id, "predicted": predicted, "start": _combat_clock,
		"duration": clampf(float(event.get("duration", 0.36)), 0.04, 0.36),
		"aim": WeaponPose.normalized_aim(event.get("aim", Vector2.RIGHT)), "sample_elapsed": -1.0}


func melee_pose(player: Dictionary) -> Dictionary:
	var owner: int = int(player.get("id", -1))
	if bool(player.get("dead", false)) or str(player.get("weapon", "")) != "arc_blade":
		_melee_tracks.erase(owner)
		return {"active": false}
	var track: Dictionary = _melee_tracks.get(owner, {})
	var replicated: Dictionary = player.get("melee", {})
	var authority_id: int = int(replicated.get("id", -1))
	if not replicated.is_empty() and authority_id > int(_melee_predictions.get(owner, -1)) and authority_id >= int(track.get("id", -1)):
		var elapsed: float = float(replicated.get("elapsed", 0.0))
		if track.is_empty() or int(track.id) != authority_id or bool(track.predicted) or not is_equal_approx(float(track.sample_elapsed), elapsed):
			track = {"id": authority_id, "predicted": false,
				"start": _combat_clock - elapsed - (0.0 if combat_paused else _snapshot_age),
				"duration": float(replicated.duration), "aim": replicated.aim, "sample_elapsed": elapsed}
			_melee_tracks[owner] = track
	if track.is_empty():
		return {"active": false}
	var pose: Dictionary = MeleeMotion.sample(_combat_clock - float(track.start), float(track.duration), track.aim)
	pose["id"] = int(track.id)
	pose["predicted"] = bool(track.predicted)
	return pose


func _start_weapon_action(event: Dictionary) -> void:
	var owner: int = int(event.get("player", -1))
	var weapon: String = str(event.get("weapon", ""))
	if owner < 0 or weapon not in WeaponAction.WEAPONS:
		return
	var predicted: bool = bool(event.get("predicted", false))
	var id: int = int(event.get("attack_id", 0))
	var existing: Dictionary = _weapon_tracks.get(owner, {})
	if not existing.is_empty() and str(existing.weapon) == weapon and bool(existing.predicted) == predicted and int(existing.id) >= id and id > 0:
		return
	if not predicted and int(_weapon_predictions.get(owner, -1)) >= id:
		return
	if predicted:
		_weapon_predictions[owner] = maxi(id, int(_weapon_predictions.get(owner, -1)))
	_weapon_tracks[owner] = {"id":id, "weapon":weapon, "predicted":predicted, "start":_combat_clock,
		"duration":float(event.get("duration", WeaponAction.duration(weapon,float(event.get("interval",0.19))))), "sample_elapsed":-1.0}


func weapon_action_pose(player: Dictionary) -> Dictionary:
	var owner: int = int(player.get("id", -1))
	var weapon: String = str(player.get("weapon", ""))
	if bool(player.get("dead", false)) or weapon not in WeaponAction.WEAPONS:
		_weapon_tracks.erase(owner)
		return WeaponAction.rest()
	var track: Dictionary = _weapon_tracks.get(owner, {})
	if not track.is_empty() and str(track.weapon) != weapon:
		_weapon_tracks.erase(owner)
		track = {}
	var replicated: Dictionary = player.get("attack_pose", {})
	var authority_id: int = int(replicated.get("id", -1))
	if not replicated.is_empty() and str(replicated.get("weapon", "")) == weapon and authority_id > int(_weapon_predictions.get(owner, -1)) and authority_id >= int(track.get("id", -1)):
		var elapsed: float = float(replicated.get("elapsed", 0.0))
		if track.is_empty() or int(track.id) != authority_id or bool(track.predicted) or not is_equal_approx(float(track.sample_elapsed), elapsed):
			track = {"id":authority_id, "weapon":weapon, "predicted":false,
				"start":_combat_clock-elapsed-(0.0 if combat_paused else _snapshot_age), "duration":float(replicated.duration), "sample_elapsed":elapsed}
			_weapon_tracks[owner] = track
	if track.is_empty():
		return WeaponAction.rest()
	var pose: Dictionary = WeaponAction.sample(weapon, _combat_clock-float(track.start), float(track.duration))
	pose.merge({"id":int(track.id), "predicted":bool(track.predicted), "elapsed":_combat_clock-float(track.start), "duration":float(track.duration)})
	return pose


func weapon_draw_pose(player: Dictionary) -> Dictionary:
	var position_value: Vector2 = _entity_draw_position("p" + str(player.get("id", -1)), player.get("pos", Vector2.ZERO))
	var aim: Vector2 = WeaponPose.normalized_aim(player.get("aim", Vector2.RIGHT))
	var melee: Dictionary = melee_pose(player)
	var ranged: Dictionary = weapon_action_pose(player)
	if bool(melee.active):
		aim = melee.aim
	# A deep landing pose moves the visible shoulder with the torso. Sampling
	# the same tracked frame again during body drawing is idempotent. Simulation
	# and input continue to use WeaponPose's unchanged physical shoulder/muzzle.
	var displayed: Dictionary = player.duplicate(false)
	displayed.pos = position_value
	displayed.aim = aim
	var frame: Dictionary = Pixels.tracked_frame_for(self, str(player.get("character", "ranger")), displayed, _clock, true)
	var offset: Vector2 = frame.get("shoulder", Vector2(0.0, -5.0))
	var body_motion: Dictionary = melee if bool(melee.active) else ranged
	if bool(body_motion.active):
		var pivot := Vector2(0.0, 5.0)
		offset = pivot + (offset - pivot).rotated(float(body_motion.body_angle))
	offset.x *= 1.0 if aim.x >= 0.0 else -1.0
	var shoulder: Vector2 = position_value + offset
	var result: Dictionary = {"position":position_value, "shoulder":shoulder,
		"muzzle":shoulder + aim * WeaponPose.muzzle_length(str(player.get("weapon", "pulse_rifle"))), "aim":aim, "melee":melee, "ranged":ranged,
		"weapon_origin":shoulder, "weapon_angle":aim.angle(), "weapon_scale":1.0,
		"grip":shoulder+aim*7.5, "tip":shoulder+aim*WeaponPose.muzzle_length(str(player.get("weapon","pulse_rifle")))}
	if bool(melee.active):
		var blade_direction := Vector2.from_angle(float(melee.angle))
		var blade_scale: float = float(melee.weapon_scale)
		var origin: Vector2 = shoulder + aim * float(melee.extension)
		var grip: Vector2 = origin + blade_direction * (7.5 * blade_scale)
		var tip: Vector2 = origin + blade_direction * (WeaponPose.muzzle_length("arc_blade") * blade_scale)
		result.merge({"weapon_angle": float(melee.angle), "grip": grip, "weapon_scale":blade_scale,
			"weapon_origin":origin, "tip":tip, "muzzle":tip}, true)
	elif bool(ranged.active):
		var facing: float = 1.0 if aim.x >= 0.0 else -1.0
		var local_offset: Vector2 = ranged.offset
		local_offset.y *= facing
		var origin: Vector2 = shoulder + local_offset.rotated(aim.angle())
		var angle: float = aim.angle() + float(ranged.angle_offset) * facing
		var axis := Vector2.from_angle(angle)
		var tip: Vector2 = origin + axis * WeaponPose.muzzle_length(str(player.weapon))
		result.merge({"weapon_origin":origin, "weapon_angle":angle, "grip":origin+axis*float(ranged.grip_distance), "muzzle":tip, "tip":tip}, true)
	return result


func muzzle_effect_pose(effect: Dictionary) -> Dictionary:
	var fallback: Dictionary = {"visible":true, "pos":effect.get("pos", Vector2.ZERO),
		"aim":Vector2.from_angle(float(effect.get("angle", 0.0)))}
	if not effect.has("weapon"):
		return fallback
	var player: Dictionary = Dictionary(_frame.get("players", {})).get(int(effect.get("owner", -1)), {})
	if player.is_empty() or bool(player.get("dead", false)) or str(player.get("weapon", "")) != str(effect.weapon):
		fallback.visible = false
		return fallback
	var pose: Dictionary = weapon_draw_pose(player)
	return {"visible":true, "pos":pose.muzzle, "aim":Vector2.from_angle(float(pose.get("weapon_angle", Vector2(pose.aim).angle())))}


static func projectile_trail_length(projectile: Dictionary, draw_position: Vector2, maximum: float) -> float:
	var length: float = maxf(0.0, maximum)
	if str(projectile.get("team", "player")) != "player" or not projectile.has("origin"):
		return length
	length = minf(length, maxf(0.0, float(projectile.get("travel_distance", 0.0))))
	if not bool(projectile.get("returning", false)):
		var direction: Vector2 = Vector2(projectile.get("vel", Vector2.RIGHT)).normalized()
		length = minf(length, maxf(0.0, (draw_position - Vector2(projectile.origin)).dot(direction)))
	return length


static func stack_tier(stacks: int) -> int:
	if stacks >= 8: return 3
	if stacks >= 4: return 2
	if stacks >= 1: return 1
	return 0


func effect_strength(event: Dictionary) -> float:
	var tier: int = 0
	if event.has("visual_stacks"):
		tier = stack_tier(int(event["visual_stacks"]))
	elif event.has("visual_strength"):
		tier = clampi(int(event["visual_strength"]), 0, 3)
	else:
		var owner: int = int(event.get("owner", event.get("player", -1)))
		var players: Dictionary = _frame.get("players", {})
		if players.has(owner):
			var items: Dictionary = Dictionary(players[owner]).get("items", {})
			var stacks: int = 0
			for id: String in ["overclock", "capacitor", "arc", "ember"]:
				stacks += maxi(0, int(items.get(id, 0)))
			tier = stack_tier(stacks)
	return [1.0, 1.3, 1.7, 2.2][tier] * clampf(fx_scale, 0.5, 1.5)


func visual_budget_stats() -> Dictionary:
	return {"effects": _effects.size(), "max_effects": MAX_EFFECTS,
		"damage_numbers": _numbers.size(), "max_damage_numbers": MAX_DAMAGE_NUMBERS,
		"fx_scale": clampf(fx_scale, 0.5, 1.5), "shake": minf(_shake, 5.0),
		"particle_batches": _particle_batches, "max_particle_batches": PARTICLE_WIDTHS.size(),
		"particle_segments": _particle_segments}


func _add_effect(effect: Dictionary) -> void:
	# Reserve 64 slots for readable silhouettes (arcs, impacts, muzzle flashes)
	# so four-player proc chains cannot replace everything with small sparks.
	if str(effect.get("kind", "spark")) in PARTICLE_KINDS and _effects.size() >= MAX_EFFECTS - 64:
		return
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append(effect)


func _process(delta: float) -> void:
	_clock += delta
	if not combat_paused:
		_combat_clock += delta
	_shake = maxf(0.0, _shake - delta * 22.0)
	_shake_offset = Vector2(sin(_clock * 93.0), cos(_clock * 71.0)) * minf(_shake, 5.0) if shake_enabled and not reduced_motion else Vector2.ZERO
	for index: int in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[index]
		effect["age"] = float(effect.get("age", 0.0)) + delta
		if effect["age"] >= effect["life"]:
			_effects.remove_at(index)
	for index: int in range(_numbers.size() - 1, -1, -1):
		var number: Dictionary = _numbers[index]
		number["age"] = float(number.get("age", 0.0)) + delta
		if number["age"] > 0.85:
			_numbers.remove_at(index)
	queue_redraw()


func push_events(events: Array) -> void:
	for event_value: Variant in events:
		var event: Dictionary = event_value
		var kind: String = event.get("type", "")
		if kind in ["shoot", "slash"] and event.has("weapon"):
			_start_weapon_action(event)
		var position_value: Vector2 = event.get("pos", Vector2.ZERO)
		var strength: float = effect_strength(event)
		var direction: Vector2 = event.get("aim", event.get("direction", Vector2.RIGHT))
		if direction.length_squared() < 0.001: direction = Vector2.RIGHT
		direction = direction.normalized()
		match kind:
			"proc":
				var activation: Dictionary = ProcFeedback.activation(event)
				if not activation.is_empty(): _add_effect(activation)
			"shoot":
				var enemy_shot: bool = event.get("enemy", false)
				if enemy_shot:
					# The solid projectile leaves its matching prepared ammunition.
					# A second stationary flash looks like another damaging object.
					continue
				var weapon: String = str(event.get("weapon", event.get("kind", "bullet")))
				var shot_color: Color = Color("f4a08b") if enemy_shot else (Color("a6dfff") if str(event.get("kind", "")) in ["rail", "railgun"] else GOLD)
				if str(event.get("kind", "")) in ["storm", "storm_staff"]: shot_color = Color("89dbec")
				if str(event.get("kind", "")) == "boomerang": shot_color = Color("9be0cf")
				var shot_strength: float = 0.85 if enemy_shot else strength
				var muzzle: Dictionary = {"kind":"muzzle", "style":weapon, "pos":position_value, "angle":direction.angle(), "color":shot_color, "strength":shot_strength, "age":0.0, "life":0.13 if weapon in ["railgun","sun_lance"] else 0.105}
				if event.has("weapon"):
					muzzle.merge({"owner":event.get("player", -1), "weapon":event.weapon})
					var pose: Dictionary = muzzle_effect_pose(muzzle)
					if not bool(pose.visible): continue
					position_value = pose.pos
				_add_effect(muzzle)
				_burst(position_value, shot_color, clampi(int(4.0 + shot_strength * 3.0), 4, 13), 165.0 if weapon=="scattergun" else 115.0, 0.25, direction, 0.8 if weapon=="scattergun" else 0.38, "spark")
				if not enemy_shot and weapon in ["pulse_rifle", "scattergun"]:
					_burst(position_value-direction*9.0,Color("bba477"),2,55.0,0.48,direction.orthogonal()-direction*0.4,0.35,"fragment")
			"hit":
				var family: String = EnemyAttackArt.Geometry.impact_family(str(event.get("attack_kind",""))) if bool(event.get("friendly",false)) else ""
				if not family.is_empty():
					_add_effect({"kind":"hostile_contact","family":family,"pos":position_value,"angle":direction.angle(),"age":0.0,"life":.14})
					if _numbers.size()<MAX_DAMAGE_NUMBERS:
						_numbers.append({"pos":position_value+Vector2(0,-22),"text":str(int(event.get("amount",0))),"age":0.0,"crit":false})
					continue
				var crit: bool = event.get("crit", false)
				var color_value: Color = (Color("f6987d") if bool(event.get("friendly", false)) else GOLD) if crit else CREAM
				var impact_direction: Vector2 = _impact_direction(event)
				_burst(position_value, color_value, clampi(int((8.0 if crit else 5.0) * strength), 4, 22), 190.0 + strength * 24.0, 0.34, impact_direction, 0.95, "spark")
				_burst(position_value, color_value.darkened(0.4), clampi(int(2.0*strength),2,5), 75.0,0.45,impact_direction,1.8,"fragment")
				_add_effect({"kind":"impact", "pos":position_value, "angle":impact_direction.angle(), "crit":crit, "color":color_value, "strength":strength, "age":0.0, "life":0.17})
				if crit or strength >= 1.7:
					_ring(position_value, Color(color_value, 0.65), 14.0 + strength * 5.0, 0.22)
				if event.has("arc_from"):
					_add_effect({"kind": "arc", "pos": position_value, "from": event["arc_from"], "color": TEAL, "strength":strength, "age": 0.0, "life": 0.25})
				if _numbers.size() < MAX_DAMAGE_NUMBERS:
					_numbers.append({"pos": position_value + Vector2(_rng.randf_range(-9.0, 9.0), -22.0), "text": str(int(event.get("amount", 0))), "age": 0.0, "crit": crit})
			"death":
				var material: Dictionary = death_material(str(event.get("kind","crawler")))
				var death_color: Color = material.color
				var elite: bool = bool(event.get("elite",false)) or str(event.get("kind",""))=="boss"
				_burst(position_value,death_color,clampi(int((18.0 if elite else 12.0)*strength),6,30),190.0,0.55,Vector2.UP,PI,str(material.particle))
				_burst(position_value,death_color.lightened(0.3),7 if elite else 4,220.0,0.26,Vector2.UP,PI,"spark")
				_burst(position_value,death_color,4,36.0,0.6,Vector2.UP,0.7,"smoke")
				_add_effect({"kind":"shatter", "pos":position_value,"color":death_color,"radius":(52.0 if elite else 33.0)*sqrt(strength),"strength":strength,"age":0.0,"life":0.38})
			"explosion":
				if str(event.get("team",""))=="enemy":
					var repair: bool = bool(event.get("healing",false))
					# Hazards already animate their release from the snapshot. Never
					# send hostile events through the player's ring/blast path.
					if repair or not bool(event.get("visual_only",false)):
						var extent: float = 22.0 if repair else clampf(float(event.get("radius",48.0))*2.0,32.0,300.0)
						_add_effect({"kind":"hostile_natural", "family":"repair" if repair else NaturalThreats.area_family(str(event.get("kind","")),true), "pos":position_value,
							"size":Vector2.ONE*extent, "color":Color.WHITE, "age":0.0, "life":0.18 if repair else 0.1})
					continue
				var healing: bool = event.get("healing", false)
				var shielding: bool = event.get("shield", false)
				var effect_color: Color = Color("b6e89f") if healing else (Color("90caff") if shielding else GOLD)
				var explosion_kind: String = str(event.get("kind", ""))
				var temporal: bool = explosion_kind == "time_warp"
				if explosion_kind in ["graviton", "echo"]: effect_color = Color("c7a8f0")
				if explosion_kind == "nova": effect_color = Color("f5c4f5")
				if explosion_kind == "meteor": effect_color = Color("ffa77a")
				if temporal: effect_color = Color("89dbec")
				if explosion_kind == "graviton":
					_add_effect({"kind":"gravity", "pos":position_value, "color":effect_color, "radius":clampf(float(event.get("radius",200.0)),40.0,300.0), "strength":strength, "age":0.0, "life":0.75})
				if explosion_kind == "meteor":
					_add_effect({"kind":"meteor", "pos":position_value, "color":effect_color, "strength":strength, "age":0.0, "life":0.35})
				_burst(position_value, effect_color, clampi(int((12.0 if healing or shielding else 18.0) * strength), 8, 36), 90.0 if healing or shielding else 260.0, 0.8 if healing or shielding else 0.55,Vector2.UP,PI,"ember" if healing or shielding else "spark")
				if not healing and not shielding and not temporal:
					_burst(position_value,effect_color.darkened(0.3),clampi(int(4.0*strength),4,10),150.0,0.7,Vector2.UP,PI,"fragment")
					_burst(position_value,effect_color,4,45.0,0.65,Vector2.UP,PI,"smoke")
				_ring(position_value, effect_color, float(event.get("radius", 90.0)), 0.9 if healing or shielding else 0.42)
				if not healing and not shielding and not temporal:
					_add_effect({"kind":"blast", "pos":position_value, "color":effect_color, "strength":strength, "radius":clampf(float(event.get("radius",90.0)),20.0,260.0), "age":0.0, "life":0.48})
				if healing:
					_add_effect({"kind": "heal", "pos": position_value, "color": effect_color, "radius": float(event.get("radius", 260.0)), "age": 0.0, "life": 1.2})
				if not healing and not shielding and not temporal:
					_shake = minf(5.0, maxf(_shake, 1.5 + strength * 0.8))
			"slash":
				if str(event.get("weapon", "")) == "arc_blade":
					_start_melee(event)
					# Keep attack metadata available to existing feedback consumers;
					# the live hand/blade motion draws its own short blade trail.
					_add_effect({"kind":"slash", "melee":true, "pos":position_value, "owner":event.get("player",-1),
						"weapon":"arc_blade", "angle":direction.angle(), "strength":strength, "age":0.0,
						"life":float(event.get("duration",0.36)), "radius":105.0, "color":GOLD})
					continue
				var flame: bool = str(event.get("kind", "")) == "flame"
				var swipe: Dictionary = {"kind": "flame" if flame else "slash", "pos": position_value, "angle": direction.angle(), "age": 0.0, "life": 0.19 if flame else 0.27, "color": Color("ffa77a") if flame else GOLD, "strength":strength, "radius":clampf(float(event.get("radius",170.0 if flame else 85.0)),45.0,180.0 if flame else 160.0)}
				if event.has("weapon"):
					swipe.merge({"owner":event.get("player", -1), "weapon":event.weapon})
					if not bool(muzzle_effect_pose(swipe).visible): continue
				_add_effect(swipe)
				_burst(position_value,Color("ffa45c") if flame else Color("abead8"),clampi(int(3.0*strength),3,9),160.0 if flame else 90.0,0.32,direction,0.33 if flame else 0.8,"ember" if flame else "spark")
			"dash":
				if bool(event.get("enemy",false)):
					var burrowing: bool = str(event.get("kind","")) == "burrow"
					# Burrowing already has an authority-timed eruption; do not
					# add a second effect that outlives its damage window.
					if not burrowing:
						_add_effect({"kind":"hostile_natural", "family":"rift", "pos":position_value,
							"size":Vector2(22,44), "color":Color.WHITE, "age":0.0, "life":0.14})
					continue
				var rushing: bool = str(event.get("ability", "")) == "shoulder_rush"
				var dash_color: Color = GOLD if rushing else (Color("eea27c") if bool(event.get("enemy",false)) else TEAL)
				_spark(position_value, dash_color, clampi(int(8.0 * strength), 4, 24), 95.0, 0.35)
				_add_effect({"kind":"rush" if rushing else "dash", "pos":position_value, "angle":direction.angle(), "color":dash_color, "strength":strength, "age":0.0, "life":0.22})
			"ability_hit":
				if str(event.get("ability", "")) == "shoulder_rush":
					_burst(position_value, GOLD, 7, 135.0, 0.28, direction, 0.8, "spark")
					_add_effect({"kind":"rush_hit", "pos":position_value, "angle":direction.angle(), "color":GOLD, "strength":1.0, "age":0.0, "life":0.20})
					_shake = minf(5.0, maxf(_shake, 1.4))
			"pickup":
				if str(event.get("kind", "")) == "coin":
					_burst(position_value, GOLD, 7, 78.0, 0.30, Vector2.UP, PI, "spark")
					_ring(position_value, GOLD, 24.0, 0.24)
					_add_effect({"kind":"coin_collect", "pos":position_value, "color":GOLD, "age":0.0, "life":0.25})
					if _numbers.size() < MAX_DAMAGE_NUMBERS:
						_numbers.append({"pos":position_value+Vector2(0,-27), "text":"+"+str(int(event.get("amount",0))), "color":GOLD, "age":0.0, "crit":false})
				else:
					_spark(position_value, TEAL, 11, 75.0, 0.5)
					_ring(position_value, TEAL, 32.0, 0.45)
			"coin_drop":
				_burst(position_value, GOLD, 5, 110.0, 0.28, Vector2.UP, 0.9, "spark")
			"ability":
				if str(event.get("ability", "")) == "guard_burst":
					var phase: String = str(event.get("phase", "start"))
					if phase == "release":
						var charge: float = clampf(float(event.get("absorbed", 0.0)) / 40.0, 0.0, 1.0)
						_ring(position_value, GOLD, float(event.get("radius", 145.0)), 0.34)
						_add_effect({"kind":"guard_release", "pos":position_value, "radius":float(event.get("radius",145.0)), "color":GOLD, "strength":1.0+charge, "age":0.0, "life":0.38})
						_burst(position_value, GOLD, int(12+charge*8), 230.0+charge*80.0, 0.38, Vector2.UP, PI, "spark")
						_shake = minf(5.0, maxf(_shake, 1.5 + charge))
					elif phase == "block":
						_ring(position_value, CREAM, 31.0, 0.20)
						_burst(position_value, GOLD, 6, 85.0, 0.23, Vector2.UP, PI, "spark")
					else:
						_ring(position_value, GOLD, 32.0, 0.22)
			"drop", "interact":
				_spark(position_value, GOLD, 8, 70.0, 0.45)
			"gate", "stage", "revive":
				var signal_color: Color = Color("ffa77a") if bool(event.get("phoenix",false)) else TEAL
				_spark(position_value, signal_color, 30, 220.0, 0.8)
				_ring(position_value, signal_color, 165.0, 0.9)
			"win":
				_ring(position_value, GOLD, 220.0, 1.3)


func _impact_direction(event: Dictionary) -> Vector2:
	var destination: Vector2 = event.get("pos",Vector2.ZERO)
	var players: Dictionary = _frame.get("players",{})
	var owner: int = int(event.get("owner",-1))
	var source: Vector2 = destination-Vector2.RIGHT
	if event.has("arc_from"):
		source=event.arc_from
	elif players.has(owner):
		source=players[owner].pos
	var direction: Vector2=(destination-source).normalized()
	return direction if direction.length_squared()>0.001 else Vector2.RIGHT


func death_material(kind: String) -> Dictionary:
	# Cosmetic fragments suggest the creature's material without persistent gore.
	if kind in ["crawler","spitter","spore_moth"] or (kind=="boss" and _current_biome=="rainforest"):
		return {"color":Color("bfda83"),"particle":"ember"}
	if kind in ["charger","burrower"] or (kind=="boss" and _current_biome=="canyon"):
		return {"color":Color("c9956b"),"particle":"fragment"}
	return {"color":Color("a0cbe5") if kind in ["drone","player"] else Color("c5a9ef"),"particle":"fragment"}


func _burst(position_value: Vector2, color_value: Color, count: int, speed: float, life: float, direction: Vector2, spread: float, style: String) -> void:
	var angle: float=direction.angle()
	for index: int in range(clampi(count,0,42)):
		if _effects.size()>=MAX_EFFECTS-64: break
		var velocity: Vector2=Vector2.from_angle(angle+_rng.randf_range(-spread,spread))*_rng.randf_range(speed*0.35,speed)
		var gravity: float=250.0 if style=="fragment" else (-18.0 if style=="ember" or style=="smoke" else 100.0)
		_add_effect({"kind":style,"pos":position_value,"vel":velocity,"color":color_value,"age":0.0,
			"life":clampf(life*_rng.randf_range(0.75,1.2),0.08,1.2),"size":_rng.randf_range(1.4,3.2),
			"gravity":gravity,"drag":3.5 if style=="spark" else 1.2,"spin":_rng.randf_range(-8.0,8.0),"phase":_rng.randf_range(-PI,PI)})


func _spark(position_value: Vector2, color_value: Color, count: int, speed: float, life: float) -> void:
	for index: int in range(count):
		var velocity: Vector2 = Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(speed * 0.25, speed)
		_add_effect({"kind": "spark", "pos": position_value, "vel": velocity, "color": color_value, "age": 0.0, "life": life * _rng.randf_range(0.7, 1.3), "size": _rng.randf_range(1.2, 3.2)})


func _ring(position_value: Vector2, color_value: Color, radius: float, life: float) -> void:
	_add_effect({"kind": "ring", "pos": position_value, "color": color_value, "radius": minf(radius, 300.0), "age": 0.0, "life": life})


func _particle_segment(bucket: int, from: Vector2, to: Vector2, color_value: Color) -> void:
	_particle_points[bucket].append(from)
	_particle_points[bucket].append(to)
	_particle_colors[bucket].append(color_value)
	_particle_segments+=1


func _build_particle_batches() -> void:
	_particle_batches=0
	_particle_segments=0
	for bucket: int in range(PARTICLE_WIDTHS.size()):
		_particle_points[bucket].clear()
		_particle_colors[bucket].clear()
	for effect: Dictionary in _effects:
		var kind: String=str(effect.get("kind",""))
		if kind not in PARTICLE_KINDS: continue
		var age: float=float(effect.get("age",0.0))
		var t: float=clampf(age/maxf(0.01,float(effect.get("life",0.5))),0.0,1.0)
		var velocity: Vector2=effect.get("vel",Vector2.ZERO)
		var drag: float=maxf(0.01,float(effect.get("drag",0.01)))
		var p: Vector2=world_to_screen(effect.pos)+velocity*((1.0-exp(-drag*age))/drag)+Vector2(0,float(effect.get("gravity",160.0))*age*age*0.5)
		if not _visible(p,24.0): continue
		p=p.round()
		var tint: Color=effect.get("color",GOLD)
		tint.a*=pow(1.0-t,0.7)
		var size_value: float=float(effect.get("size",2.0))
		match kind:
			"fragment":
				var axis: Vector2=Vector2.from_angle(float(effect.get("phase",0.0))+age*float(effect.get("spin",3.0)))
				_particle_segment(2,p-axis*size_value,p+axis*size_value,Color(tint.darkened(0.48),tint.a))
				_particle_segment(0,p-axis*size_value+Vector2(0,-1),p+axis*size_value+Vector2(0,-1),tint)
			"ember":
				var drift: Vector2=Vector2(sin(age*9.0+float(effect.get("phase",0.0)))*3.0,0.0)
				_particle_segment(1,p+drift,p+drift+Vector2(0,1),tint)
				if t<0.6: _particle_segment(0,p+drift,p+drift+Vector2(1,0),Color(CREAM,tint.a*0.85))
			"smoke":
				_particle_segment(3,p-Vector2(2+t*3.0,0),p+Vector2(2+t*3.0,0),Color(tint.darkened(0.45),0.12*(1.0-t)))
			_:
				var tail: Vector2=velocity.normalized()*clampf(velocity.length()*0.045*(1.0-t),2.0,14.0)
				_particle_segment(1 if size_value>2.2 else 0,p-tail,p,tint)
				if t<0.4 and size_value>2.2: _particle_segment(0,p,p+velocity.normalized()*2.0,Color(CREAM,tint.a))
	for bucket: int in range(PARTICLE_WIDTHS.size()):
		if not _particle_points[bucket].is_empty(): _particle_batches+=1


func _draw_particle_batches() -> void:
	_build_particle_batches()
	# Four native commands handle every debris/ember/spark color. Thick dim
	# fragments first, then bright pixel edges; enemy warnings are drawn later.
	for bucket: int in range(PARTICLE_WIDTHS.size()-1,-1,-1):
		if not _particle_points[bucket].is_empty():
			draw_multiline_colors(_particle_points[bucket],_particle_colors[bucket],PARTICLE_WIDTHS[bucket],false)


func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	var world: Vector2 = _frame.get("world_size", Vector2(3200.0, 1100.0))
	if scenery_cache_enabled and web_background_cache_enabled and _draw_web_background():
		pass
	elif scenery_cache_enabled and not _background_live and not _background_cache.is_empty() and Engine.get_process_frames()>=int(_background_cache.ready):
		draw_texture(_background_cache.texture,Vector2.ZERO)
	else:
		Biomes.background(self, _current_biome, camera_position, screen_size, world, _clock)
	_draw_cached_landmarks()
	_draw_terrain()
	_draw_gate()
	_draw_chests()
	_draw_deployables()
	_draw_proc_fields()
	_draw_pickups()
	_draw_enemies()
	_draw_players()
	_draw_coin_pickups()
	_draw_effects()
	_draw_projectiles()
	_draw_atmosphere()
	_draw_threat_overlays()


func _draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), SKY)
	for band: int in range(24):
		var y: float = float(band) / 24.0 * screen_size.y
		var weight: float = float(band) / 23.0
		draw_rect(Rect2(0.0, y, screen_size.x, screen_size.y / 24.0 + 1.0), Color("081821").lerp(Color("204c4c"), weight))
	for star: Vector3 in _stars:
		var p: Vector2 = Vector2(fposmod(star.x - camera_position.x * 0.025, screen_size.x), star.y - camera_position.y * 0.045)
		var twinkle: float = 0.36 + 0.14 * sin(_clock * 0.5 + star.x)
		draw_circle(p, star.z, Color(0.65, 0.94, 0.87, twinkle))
	var moon: Vector2 = Vector2(screen_size.x * 0.73 - camera_position.x * 0.025, 160.0 - camera_position.y * 0.06)
	_glow(moon, 150.0, Color(0.41, 0.84, 0.76, 0.024), 5)
	draw_circle(moon, 73.0, Color("74a797"), true, -1.0, true)
	draw_circle(moon + Vector2(-6.0, 0.0), 72.0, Color("5c9188"), true, -1.0, true)
	draw_arc(moon, 72.0, -1.6, 1.45, 64, Color("a6c9ac"), 1.5, true)
	for index: int in range(9):
		var point: Vector2 = moon + Vector2(sin(float(index) * 19.31) * 45.0, cos(float(index) * 9.12) * 47.0)
		draw_circle(point, 4.0 + fposmod(float(index * 7), 13.0), Color(0.24, 0.46, 0.46, 0.26), true, -1.0, true)
	# A fractured orbital ring gives the sky its own recognizable silhouette.
	for index: int in range(3):
		var points: PackedVector2Array = PackedVector2Array()
		var begin: float = -0.55 + float(index) * 2.05
		for step: int in range(42):
			var angle: float = begin + float(step) / 41.0 * 1.72
			var oval: Vector2 = Vector2(cos(angle) * 152.0, sin(angle) * 37.0).rotated(-0.38)
			points.append(moon + oval)
		draw_polyline(points, Color(0.55, 0.8, 0.71, 0.38), 4.0, true)
		draw_polyline(points, Color(0.82, 0.89, 0.72, 0.42), 1.0, true)
	# Thin atmospheric cloud ribbons.
	for index: int in range(7):
		var y: float = 70.0 + float(index) * 58.0
		var x: float = fposmod(float(index) * 317.0 + _clock * 1.6 - camera_position.x * 0.04, screen_size.x + 600.0) - 300.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 260.0, y - 8.0), Vector2(x + 490.0, y + 2.0), Vector2(x + 170.0, y + 7.0)]), Color(0.31, 0.55, 0.53, 0.04))


func _draw_distant_world() -> void:
	var horizon: float = 500.0 - (camera_position.y - 650.0) * 0.2
	for layer: int in range(3):
		var parallax: float = 0.1 + float(layer) * 0.16
		var color_value: Color = [Color("1a4147"), Color("15383d"), Color("112e33")][layer]
		var ground: float = horizon + float(layer) * 70.0
		var polygon: PackedVector2Array = PackedVector2Array()
		for index: int in range(-2, 24):
			var world_x: float = float(index) * 115.0
			var x: float = world_x - fposmod(camera_position.x * parallax, 115.0)
			var height: float = 70.0 + absf(sin(float(index + layer * 9) * 7.231)) * (175.0 - float(layer) * 25.0)
			polygon.append(Vector2(x, ground - height))
			polygon.append(Vector2(x + 28.0, ground - height + 12.0))
			polygon.append(Vector2(x + 67.0, ground - height - 28.0))
			polygon.append(Vector2(x + 95.0, ground - height * 0.4))
		polygon.append(Vector2(polygon[polygon.size() - 1].x, screen_size.y + 100.0))
		polygon.append(Vector2(polygon[0].x, screen_size.y + 100.0))
		draw_colored_polygon(polygon, color_value)
	# Broken pillars and arches behind the play space.
	for index: int in range(-1, 9):
		var x: float = float(index) * 390.0 - fposmod(camera_position.x * 0.37, 390.0)
		var y: float = horizon + 53.0 + sin(float(index) * 7.4) * 43.0
		var height: float = 140.0 + absf(sin(float(index) * 1.8)) * 100.0
		var rock: Color = Color("163a3c")
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 170.0), Vector2(x + 9.0, y - height), Vector2(x + 34.0, y - height - 12.0), Vector2(x + 57.0, y - height + 8.0), Vector2(x + 53.0, y + 170.0)]), rock)
		draw_line(Vector2(x + 16.0, y - height + 18.0), Vector2(x + 12.0, y + 50.0), Color("245153"), 2.0)
		if index % 2 == 0:
			draw_arc(Vector2(x + 105.0, y - height + 73.0), 71.0, PI + 0.15, TAU - 0.38, 32, rock, 15.0, true)
			draw_line(Vector2(x + 8.0, y - height + 49.0), Vector2(x - 27.0, y - height + 140.0), rock, 5.0)
	# Fine drifting waterfalls lend depth without competing with projectiles.
	for index: int in range(5):
		var x: float = float(index) * 470.0 - fposmod(camera_position.x * 0.25, 470.0) + 140.0
		var top: float = horizon - 94.0 + float(index % 3) * 35.0
		draw_line(Vector2(x, top), Vector2(x + 16.0, screen_size.y + 20.0), Color(0.3, 0.75, 0.71, 0.055), 19.0)
		for stripe: int in range(3):
			var shift: float = float(stripe) * 5.0
			draw_line(Vector2(x + shift, top), Vector2(x + shift + 13.0, screen_size.y + 20.0), Color(0.52, 0.89, 0.82, 0.07), 1.0, true)


func _draw_terrain() -> void:
	var platforms: Array = _frame.get("platforms", [])
	var world: Vector2 = _frame.get("world_size", Vector2(3200.0, 1100.0))
	for index: int in range(platforms.size()):
		var rectangle: Rect2=platforms[index]
		var tiles: Vector2i=_terrain_tiles(rectangle)
		var ready: bool=scenery_cache_enabled and tiles.x>=0 and tiles.y>tiles.x
		if ready:
			for tile: int in range(tiles.x,tiles.y):
				var entry: Dictionary=_scenery_cache.get("t%d:%d"%[index,tile],{})
				if entry.is_empty() or Engine.get_process_frames()<int(entry.ready): ready=false; break
		if not ready:
			Biomes.platform(self,rectangle,index,_current_biome,_clock,screen_size,world)
			continue
		for tile: int in range(tiles.x,tiles.y):
			var entry: Dictionary=_scenery_cache["t%d:%d"%[index,tile]]
			var width: float=minf(512.0,rectangle.size.x-tile*512.0)
			var destination: Vector2=world_to_screen(rectangle.position+Vector2(tile*512,-64))
			draw_texture_rect_region(entry.texture,Rect2(destination,Vector2(width,256)),Rect2(96,0,width,256))
		if not web_background_cache_enabled:
			Biomes.platform_animated(self,rectangle,index,_current_biome,_clock,screen_size)


func _draw_flora(p: Vector2, scale_value: float, seed_value: int) -> void:
	var sway: float = sin(_clock * 1.1 + float(seed_value)) * 3.0
	var stem_top: Vector2 = p + Vector2(sway, -26.0 * scale_value)
	draw_line(p, stem_top, Color("3b766b"), 2.0, true)
	for side: float in [-1.0, 1.0]:
		var stem_middle: Vector2 = p + Vector2(sway * 0.6, -13.0 * scale_value)
		draw_colored_polygon(PackedVector2Array([stem_middle, stem_middle + Vector2(side * 15.0, -10.0) * scale_value, stem_middle + Vector2(side * 10.0, 0.0) * scale_value]), Color("35695b"))
	_glow(stem_top, 15.0 * scale_value, Color(0.26, 1.0, 0.72, 0.04), 3)
	draw_colored_polygon(PackedVector2Array([stem_top + Vector2(-8.0, 1.0) * scale_value, stem_top + Vector2(-3.0, -7.0) * scale_value, stem_top + Vector2(4.0, -9.0) * scale_value, stem_top + Vector2(9.0, 1.0) * scale_value]), Color("a2d0a0"))
	draw_line(stem_top + Vector2(-8.0, 1.0) * scale_value, stem_top + Vector2(9.0, 1.0) * scale_value, TEAL, 1.2, true)


func _draw_gate() -> void:
	var gate: Dictionary = _frame.get("gate", {})
	if gate.is_empty():
		return
	var p: Vector2 = world_to_screen(gate.get("pos", Vector2.ZERO)) + Vector2(0.0, 34.0)
	if not _visible(p, 220.0):
		return
	var active: bool = gate.get("active", false)
	var ready: bool = gate.get("ready", false)
	var charge: float = clampf(float(gate.get("charge", 0.0)), 0.0, 100.0)
	if charge > 1.0:
		charge *= 0.01
	var glow_color: Color = TEAL if ready else GOLD
	var center: Vector2 = p + Vector2(0.0, -46.0)
	_glow(center, 72.0, Color(glow_color, 0.018 if active else 0.0), 2)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-64.0, 16.0), p + Vector2(64.0, 16.0), p + Vector2(49.0, -1.0), p + Vector2(-47.0, -1.0)]), Color("15363a"))
	draw_line(p + Vector2(-57.0, 13.0), p + Vector2(57.0, 13.0), Color("508b7e"), 2.0, true)
	# Physical split arch remains readable before activation.
	for side: float in [-1.0, 1.0]:
		var arch: PackedVector2Array = PackedVector2Array()
		for step: int in range(17):
			var t: float=step/16.0
			arch.append(p+Vector2(side*(47+22*sin(t*PI)-31*t),1-104*t))
		for step: int in range(16,-1,-1):
			var t: float=step/16.0
			arch.append(p+Vector2(side*(31+15*sin(t*PI)-15*t),-1-102*t))
		draw_colored_polygon(arch, Color("728581"))
		draw_polyline(PackedVector2Array([p + Vector2(side * 41.0, -7.0), p + Vector2(side * 42.0, -56.0), p + Vector2(side * 24.0, -94.0)]), Color(glow_color, 0.9 if active else 0.46), 2.0, true)
		for rune: int in range(3):
			var rp: Vector2 = p + Vector2(side * 39.0, -19.0 - float(rune) * 13.0)
			draw_line(rp, rp + Vector2(side * 7.0, -3.0), Color(glow_color, 0.7), 1.5, true)
	if active or ready:
		for index: int in range(6):
			var radius: float = 15.0 + float(index) * 5.0 + sin(_clock * 2.0 + float(index)) * 2.0
			var points: PackedVector2Array = PackedVector2Array()
			for step: int in range(48):
				var angle: float = float(step) / 47.0 * TAU
				points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 1.38))
			draw_polyline(points, Color(glow_color, 0.08 + float(index) * 0.028), 2.0, true)
		for index: int in range(12):
			var angle: float = float(index) / 12.0 * TAU + _clock * 0.8
			var dot: Vector2 = center + Vector2(cos(angle) * 35.0, sin(angle) * 48.0)
			draw_circle(dot, 1.6, Color(glow_color, 0.65), true, -1.0, true)
		draw_arc(center, 56.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(charge, 0.005), 60, glow_color, 2.0, true)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -14.0), center + Vector2(8.0, 0.0), center + Vector2(0.0, 14.0), center + Vector2(-8.0, 0.0)]), Color(GOLD, 0.55 + sin(_clock * 2.0) * 0.15))
	if _is_focused("gate", -1):
		_focus_marker(center, Vector2(62.0, 69.0), glow_color)
		_key_hint(p + Vector2(0.0, -128.0), glow_color)


const FacilityArt = preload("res://scripts/facility_art.gd")
const FacilityContent = preload("res://scripts/content.gd")


func _draw_chests() -> void:
	for value: Variant in _frame.get("chests", []):
		var chest: Dictionary = value
		var p: Vector2 = Pixels.snap_position(self, world_to_screen(chest.get("pos", Vector2.ZERO)) + Vector2(0.0, 7.0))
		if not _visible(p, 65.0):
			continue
		var kind: String = str(chest.get("type", "cache"))
		var state: String = FacilityArt.state_for(chest)
		var depleted: bool = state in ["open", "locked"]
		var accent: Color = Color("617a78") if depleted else FacilityArt.accent(kind)
		_draw_facility(p, chest, kind, accent, depleted)
		_draw_facility_label(p, chest, kind)
		if _is_focused("chest", int(chest.get("id", -2))):
			_focus_marker(p + Vector2(0.0, -15.0), Vector2(29.0, 30.0), accent)
			_key_hint(p + Vector2(38.0, -30.0), accent)


func facility_icon_rect(p: Vector2, chest: Dictionary, kind: String) -> Rect2:
	var offset: Vector2 = Vector2(-12.0, -27.0)
	if kind == "choice":
		# The persistent offer ID drives this gentle bob, never screen X.
		var phase: float = fposmod(float(chest.get("id", 0)) * 2.39996323, TAU)
		offset.y = -41.0 + sin(_clock * 2.0 + phase) * 1.5
	elif kind == "cache": offset.y = -55.0
	elif kind == "blood": offset.y = -74.0
	elif kind == "combat": offset.y = -64.0
	return Rect2(Pixels.snap_position(self, p + offset), Vector2(24.0, 24.0))


## Pure display data: rewards and costs were fixed by the host at stage creation.
## No rerolls, local RNG or mutation of the replicated facility record.
func facility_label_data(chest: Dictionary) -> Dictionary:
	var kind: String = str(chest.get("type", "cache"))
	var state: String = FacilityArt.state_for(chest)
	if state in ["open", "locked"]:
		return {"name": "", "cost_text": Locale.text("已锁定" if state == "locked" else ("已完成" if kind == "combat" else "已开启")), "currency": "state", "state": state, "affordable": false}
	var id: String = str(chest.get("item", ""))
	var definition: Dictionary = FacilityContent.definition(id)
	var price: int = maxi(0, int(chest.get("cost", 0)))
	var player: Dictionary = Dictionary(_frame.get("players", {})).get(_local_id, {})
	var cost_text: String = str(price)
	var currency: String = "coin"
	var affordable: bool = int(player.get("coins", 2147483647)) >= price
	if kind == "blood":
		currency = "hp"
		cost_text = Locale.format("%d 生命", [price])
		affordable = float(player.get("hp", INF)) > price
	elif kind == "combat":
		currency = "challenge"
		cost_text = Locale.format("剩余 %d", [int(chest.get("remaining", 0))]) if state == "active" else Locale.text("挑战")
		affordable = state != "active"
	return {"name": Locale.text(str(definition.get("name", id))), "item": id, "cost_text": cost_text, "currency": currency, "state": state, "affordable": affordable}


func _facility_label_size(chest: Dictionary) -> Vector2:
	var info: Dictionary = facility_label_data(chest)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var name_width: float = font.get_string_size(str(info.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var cost_width: float = font.get_string_size(str(info.cost_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + (12.0 if info.currency == "coin" else 0.0)
	return Vector2(ceilf(clampf(maxf(name_width, cost_width) + 16.0, 58.0, 144.0)),20.0 if info.state in ["open","locked"] else 36.0)


func facility_label_rect(p: Vector2, chest: Dictionary, kind: String) -> Rect2:
	var size_value: Vector2 = _facility_label_size(chest)
	var used: bool = FacilityArt.state_for(chest) in ["open","locked"]
	var top: float = -89.0
	if kind == "cache": top = -102.0
	elif kind == "blood": top = -121.0
	elif kind == "combat": top = -111.0
	elif kind == "equipment": top = -87.0
	if used: top = -67.0 if kind in ["cache","blood","equipment"] else -53.0
	var rect := Rect2(p + Vector2(-size_value.x * .5,top),size_value)
	if kind == "choice" and int(chest.get("group",-1)) >= 0:
		# Position the whole group before clipping. Independent per-card clamps
		# would flatten the stagger or squeeze the outer offers at screen edges.
		var group: Array[Dictionary] = []
		for other: Dictionary in _frame.get("chests",[]):
			if str(other.get("type","")) == "choice" and int(other.get("group",-2)) == int(chest.group):
				group.append(other)
		group.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("id",0)) < int(b.get("id",0)))
		var below: bool = false
		for index: int in range(group.size()):
			var relative: Vector2 = Vector2(group[index].get("pos",Vector2.ZERO)) - Vector2(chest.get("pos",Vector2.ZERO))
			if p.y + relative.y + top - (40.0 if not used and index%2==1 else 0.0) < 6.0:
				below = true
		var envelope := Rect2()
		for index: int in range(group.size()):
			var member: Dictionary = group[index]
			var relative: Vector2 = Vector2(member.get("pos",Vector2.ZERO)) - Vector2(chest.get("pos",Vector2.ZERO))
			var member_size: Vector2 = _facility_label_size(member)
			var stagger: float = 40.0 if not used and index%2==1 else 0.0
			var offset_y: float = 22.0 + stagger if below else top - stagger
			var member_rect := Rect2(p+relative+Vector2(-member_size.x*.5,offset_y),member_size)
			envelope = member_rect if index==0 else envelope.merge(member_rect)
			if int(member.get("id",0)) == int(chest.get("id",0)): rect=member_rect
		if not group.is_empty():
			var shift := Vector2.ZERO
			if envelope.position.x < 6.0: shift.x = 6.0-envelope.position.x
			elif envelope.end.x > screen_size.x-6.0: shift.x = screen_size.x-6.0-envelope.end.x
			if envelope.end.y > screen_size.y-6.0: shift.y = screen_size.y-6.0-envelope.end.y
			rect.position += shift
			rect.position = Pixels.snap_position(self,rect.position)
			return rect
	elif rect.position.y < 6.0:
		rect.position.y = p.y + 22.0
	rect.position.x = clampf(rect.position.x,6.0,maxf(6.0,screen_size.x-rect.size.x-6.0))
	rect.position.y = clampf(rect.position.y,6.0,maxf(6.0,screen_size.y-rect.size.y-6.0))
	# Platforms can be only 90px apart. A lower chest's price card must not
	# cover a terminal on the floor above it; use deterministic local fallbacks.
	var obstruction: float = _facility_label_obstruction(rect,p,chest)
	if obstruction > 0.0:
		for offset: Vector2 in [Vector2(-size_value.x*.5,22),Vector2(-size_value.x-40,-24),Vector2(40,-24)]:
			var candidate := Rect2(p+offset,size_value)
			candidate.position.x=clampf(candidate.position.x,6,maxf(6,screen_size.x-size_value.x-6))
			candidate.position.y=clampf(candidate.position.y,6,maxf(6,screen_size.y-size_value.y-6))
			var cost: float=_facility_label_obstruction(candidate,p,chest)
			if cost < obstruction:
				rect=candidate; obstruction=cost
			if is_zero_approx(obstruction): break
	rect.position = Pixels.snap_position(self,rect.position)
	return rect


func _facility_label_obstruction(rect: Rect2, p: Vector2, chest: Dictionary) -> float:
	var area: float=0.0
	for other: Dictionary in _frame.get("chests",[]):
		if int(other.get("id",0))==int(chest.get("id",0)): continue
		var relative: Vector2=Vector2(other.get("pos",Vector2.ZERO))-Vector2(chest.get("pos",Vector2.ZERO))
		var body:=Rect2(p+relative+FacilityArt.BOUNDS.position,FacilityArt.BOUNDS.size)
		if FacilityArt.state_for(other) not in ["open","locked"]:
			body=body.merge(facility_icon_rect(p+relative,other,str(other.get("type","cache"))))
		var intersection: Rect2=rect.intersection(body.grow(4))
		area+=intersection.get_area()
	return area


func _draw_facility(p: Vector2, chest: Dictionary, kind: String, accent: Color, depleted: bool) -> void:
	draw_texture_rect(FacilityArt.texture(kind, FacilityArt.state_for(chest)), Rect2(p + FacilityArt.BOUNDS.position, FacilityArt.BOUNDS.size), false)
	if not depleted:
		var icon_rect: Rect2 = facility_icon_rect(p, chest, kind)
		if kind == "choice":
			draw_line(p + Vector2(-7,-18), icon_rect.position + Vector2(2,24), Color(accent,.18),1.0,true)
			draw_line(p + Vector2(7,-18), icon_rect.position + Vector2(22,24), Color(accent,.18),1.0,true)
		draw_texture_rect(ItemIcons.texture(str(chest.get("item", "")),24), icon_rect, false)
	if kind == "combat" and str(chest.get("status", "idle")) == "active":
		var remaining: int = int(chest.get("remaining",0))
		for index: int in range(4):
			draw_rect(Rect2(p + Vector2(-10 + index*5,-28),Vector2(3,3)), accent if index < remaining else Color("243b43"))


func _draw_facility_label(p: Vector2, chest: Dictionary, kind: String) -> void:
	if _font == null: return
	var info: Dictionary = facility_label_data(chest)
	var rect: Rect2 = facility_label_rect(p, chest, kind)
	var used: bool = info.state in ["open", "locked"]
	var accent: Color = Color("617a78") if used else FacilityArt.accent(kind)
	if not used:
		var target: Vector2 = facility_icon_rect(p,chest,kind).get_center()
		if rect.position.y > p.y:
			draw_line(Vector2(rect.get_center().x,rect.position.y),p+Vector2(0,13),Color(accent,.22),1.0)
		else:
			draw_line(Vector2(rect.get_center().x,rect.end.y),Vector2(target.x,target.y-14),Color(accent,.22),1.0)
	draw_rect(rect,Color("0b2028") if not used else Color(0.035,0.09,0.11,.82))
	draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color(accent,.65),1.0)
	if not used:
		var font_size: int = 11
		while font_size > 9 and _font.get_string_size(str(info.name),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > rect.size.x-12:
			font_size -= 1
		var text_width: float = _font.get_string_size(str(info.name),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(_font,rect.position+Vector2((rect.size.x-text_width)*.5,14),str(info.name),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,CREAM)
	var tint: Color = Color("8caaa3") if used else (GOLD if info.currency=="coin" else FacilityArt.accent(kind))
	if not used and info.currency in ["coin","hp"] and not bool(info.affordable): tint=Color("ee9a8b")
	var cost_width: float = _font.get_string_size(str(info.cost_text),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var baseline: Vector2 = rect.position+Vector2((rect.size.x-cost_width-(12.0 if info.currency=="coin" else 0.0))*.5,14.0 if used else 29.0)
	if info.currency=="coin":
		var center: Vector2=baseline+Vector2(4,-4)
		draw_circle(center,4.0,tint,true,-1,true)
		draw_line(center-Vector2(0,2),center+Vector2(0,2),Color("725139"),1.0)
		baseline.x+=12.0
	draw_string(_font,baseline,str(info.cost_text),HORIZONTAL_ALIGNMENT_LEFT,-1,11,tint)


func _draw_coin_pickups() -> void:
	# One replicated bundle renders a small fan of coins. No unbounded trail
	# history or individual physics bodies; tails are derived from velocity.
	var bundle_count: int = Array(_frame.get("coin_pickups", [])).size()
	var per_bundle: int = clampi((96 if fx_scale >= 0.75 else 64) / maxi(1, bundle_count), 1, 5)
	for coin: Dictionary in _frame.get("coin_pickups", []):
		var center: Vector2 = world_to_screen(_entity_draw_position("c" + str(coin.id), coin.pos))
		if not _visible(center, 100.0): continue
		var age: float = float(coin.get("age", 0.0))
		var seeking: bool = bool(coin.get("seeking", false))
		var velocity: Vector2 = coin.get("vel", Vector2.ZERO)
		var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 1.0 else Vector2.UP
		var fan: float = clampf(age / 0.16, 0.0, 1.0) * (clampf(1.3 - age * 0.65, 0.12, 1.0) if seeking else 1.0)
		var count: int = mini(per_bundle, 5 if int(coin.amount) >= 20 else 3)
		var tail: float = minf(66.0, velocity.length() * 0.035) if seeking else 0.0
		for index: int in range(count):
			var phase: float = float(coin.id) * 2.39996323 + index * 2.1
			var spread: Vector2 = Vector2(sin(phase) * 15.0, cos(phase) * 9.0 - index * 2.0) * fan
			var p: Vector2 = Pixels.snap_position(self, center + spread)
			if fx_scale > 0.0 and tail > 2.0:
				draw_line(p - direction * tail, p - direction * tail * 0.40, Color(GOLD, 0.12 * fx_scale), 3.0, false)
				draw_line(p - direction * tail * 0.40, p, Color(GOLD, 0.62 * fx_scale), 2.0, false)
			var width: float = 1.0 + absf(sin(age * 11.0 + phase)) * 3.0
			var coin_shape:=PackedVector2Array()
			for step: int in range(16): coin_shape.append(p+Vector2(cos(step*TAU/16)*(width+1),sin(step*TAU/16)*5))
			draw_colored_polygon(coin_shape,Color("ad8e63"))
			for step: int in range(16): coin_shape[step]=p+Vector2(cos(step*TAU/16)*width,sin(step*TAU/16)*4)
			draw_colored_polygon(coin_shape,Color("d2b787"))
			draw_line(p + Vector2(-width, -3), p + Vector2(width, -3), CREAM, 1.0)
			draw_line(p + Vector2(0, -2), p + Vector2(0, 2), Color("b77538"), 1.0)
			if fx_scale >= 0.75 and sin(age * 15.0 + phase) > 0.83:
				var glint: Vector2 = p + Vector2(width + 2, -5)
				draw_line(glint - Vector2(3, 0), glint + Vector2(3, 0), CREAM, 1.0)
				draw_line(glint - Vector2(0, 3), glint + Vector2(0, 3), CREAM, 1.0)


func _draw_pickups() -> void:
	# Put the deliberately selected item above overlapping icons, including
	# when F selects an older item that precedes others in the state array.
	var ordered: Array = []
	var selected: Dictionary = {}
	for candidate: Dictionary in _frame.get("pickups", []):
		if _is_focused("pickup", int(candidate.get("id", -1))):
			selected = candidate
		else:
			ordered.append(candidate)
	if not selected.is_empty():
		ordered.append(selected)
	for value: Variant in ordered:
		var pickup: Dictionary = value
		var p: Vector2 = world_to_screen(pickup.get("pos", Vector2.ZERO))
		if not _visible(p, 40.0):
			continue
		var kind: String = pickup.get("kind", "coin")
		var id_value: int = pickup.get("id", 0)
		# Pickup physics settles a 7 px half-height above the platform.
		var ground_anchor: Vector2 = Pixels.snap_position(self, p + Vector2(0, 7))
		if kind == "item":
			p.y -= 16.0
		p.y += sin(_clock * 3.0 + float(id_value)) * 3.0
		if kind == "item":
			p = Pixels.snap_position(self, p)
		var item_id: String = str(pickup.get("item", ""))
		var color_value: Color = GOLD if kind == "coin" else (Color("a7e9a8") if kind == "heal" else ItemIcons.color(item_id))
		_glow(p, 18.0 if kind == "item" else (15.0 if kind == "coin" else 25.0), Color(color_value, 0.022 if kind == "item" else 0.045), 3)
		if kind == "coin":
			var width: float = 2.0 + absf(sin(_clock * 2.3 + float(id_value))) * 2.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -5.0), p + Vector2(width, -2.0), p + Vector2(width, 3.0), p + Vector2(0.0, 6.0), p + Vector2(-width, 2.0), p + Vector2(-width, -3.0)]), GOLD)
			draw_line(p + Vector2(0.0, -2.0), p + Vector2(0.0, 3.0), Color("9a653b"), 1.0)
		elif kind == "heal":
			draw_circle(p, 8.0, Color("1e524c"), true, -1.0, true)
			draw_line(p + Vector2(-4.0, 0.0), p + Vector2(4.0, 0.0), color_value, 3.0)
			draw_line(p + Vector2(0.0, -4.0), p + Vector2(0.0, 4.0), color_value, 3.0)
		else:
			var rarity: String = str(pickup.get("rarity", "common"))
			var beam_color: Color = ItemIcons.rarity_color(rarity)
			var rank: int = ItemIcons.rarity_rank(rarity)
			var focused: bool = _is_focused("pickup", id_value)
			var is_weapon: bool = str(pickup.get("category", "")) == "weapon"
			var icon_size: float = (36.0 if focused else 32.0) if is_weapon else (32.0 if focused else 28.0)
			var beam_height: float = 36.0 + float(rank) * 12.0
			# The object floats independently of its ground marker. Reuse the
			# inventory illustration without a square card hiding its silhouette.
			draw_colored_polygon(PackedVector2Array([ground_anchor + Vector2(-14, 0), ground_anchor + Vector2(-8, -3), ground_anchor + Vector2(8, -3), ground_anchor + Vector2(14, 0), ground_anchor + Vector2(8, 3), ground_anchor + Vector2(-8, 3)]), Color(INK, 0.7))
			draw_colored_polygon(PackedVector2Array([ground_anchor + Vector2(-2, -2), p + Vector2(-3.0 - rank, -beam_height), p + Vector2(3.0 + rank, -beam_height), ground_anchor + Vector2(2, -2)]), Color(beam_color, 0.04 + float(rank) * 0.012))
			draw_line(p + Vector2(0, -beam_height), ground_anchor, Color(beam_color, 0.24 if focused else 0.10 + float(rank) * 0.035), 1.0, false)
			draw_line(ground_anchor + Vector2(-10, 0), ground_anchor + Vector2(10, 0), Color(beam_color, 0.6), 1.0, false)
			draw_texture_rect(ItemIcons.pickup_texture(item_id, int(icon_size)), Rect2(Pixels.snap_position(self, p - Vector2.ONE * icon_size * 0.5), Vector2.ONE * icon_size), false)
			# Small rank pips supplement colour, below the transparent object.
			for pip: int in range(rank + 1):
				var pip_x: float = (float(pip) - float(rank) * 0.5) * 4.0
				draw_rect(Rect2(ground_anchor + Vector2(pip_x - 1, 4), Vector2(2, 2)), beam_color)
			if rank == 3:
				draw_arc(p,21.0,_clock * 0.35,_clock * 0.35 + PI * 0.65,16,Color(beam_color,0.33),1.0,true)
			if not str(pickup.get("warning", "")).is_empty() or item_id == "glass":
				draw_colored_polygon(PackedVector2Array([p + Vector2(13.0, -20.0), p + Vector2(19.0, -9.0), p + Vector2(7.0, -9.0)]), ORANGE)
				draw_line(p + Vector2(13.0, -16.0), p + Vector2(13.0, -13.0), INK, 1.5, true)
			if focused:
				_focus_marker(p, Vector2.ONE * (icon_size * 0.5 + 3.0), beam_color)
				_key_hint(p + Vector2(0.0, -37.0), beam_color)


func _draw_deployables() -> void:
	for device: Dictionary in _frame.get("deployables", []):
		var p: Vector2 = world_to_screen(device.get("pos", Vector2.ZERO))
		if not _visible(p,50.0): continue
		var angle: float = 0.0
		var closest: float = 650.0 * 650.0
		for enemy: Dictionary in _frame.get("enemies", []):
			var offset: Vector2 = Vector2(enemy.get("pos",Vector2.ZERO)) - Vector2(device.get("pos",Vector2.ZERO))
			if offset.length_squared() < closest:
				closest = offset.length_squared()
				angle = offset.angle()
		var tint: Color = Color("b3c8a0")
		draw_polyline(PackedVector2Array([p+Vector2(-16,12),p+Vector2(-6,2),p+Vector2(6,2),p+Vector2(16,12)]), INK,6.0,true)
		draw_polyline(PackedVector2Array([p+Vector2(-16,12),p+Vector2(-6,2),p+Vector2(6,2),p+Vector2(16,12)]), tint,2.5,true)
		draw_line(p,p+Vector2(0,14),tint,3.0,true)
		draw_set_transform(p+Vector2(0,-5),angle,Vector2(.75,.75))
		WeaponArt.draw(self,"pulse_rifle")
		draw_set_transform(Vector2.ZERO)
		draw_arc(p,22.0,0,TAU*clampf(float(device.get("ttl",8.0))/8.0,0.0,1.0),28,Color(tint,0.35),1.0,true)
	for pending: Dictionary in _frame.get("effects", []):
		if str(pending.get("kind","")) != "meteor": continue
		var p: Vector2 = world_to_screen(pending.get("pos",Vector2.ZERO))
		if not _visible(p,180.0): continue
		var radius: float = clampf(float(pending.get("radius",150)),20.0,300.0)
		var delay: float = maxf(float(pending.get("delay",0.0)),0.0)
		var tint: Color = Color("ffd071")
		draw_arc(p,radius,0,TAU,48,Color(tint,0.22),1.0,true)
		draw_arc(p,maxf(8.0,radius*clampf(delay/1.5,0.0,1.0)),_clock,TAU+_clock,36,Color(tint,0.42),1.0,true)
		for ray: int in range(4):
			var dir: Vector2 = Vector2.from_angle(float(ray)*PI*0.5)
			draw_line(p+dir*9.0,p+dir*16.0,Color(tint,0.75),1.5,true)


func _draw_weapon(weapon: String, mechanism: float = 0.0, energy: float = 0.0) -> void:
	WeaponArt.draw(self, weapon, mechanism, energy)


func _draw_proc_fields() -> void:
	var players: Dictionary = _frame.get("players", {})
	var count: int = 0
	for field: Dictionary in _frame.get("proc_effects", []):
		if count >= 8: break
		count += 1
		var owner: int = int(field.get("owner", -1))
		var position_value: Vector2 = field.get("pos", Vector2.ZERO)
		if players.has(owner):
			if bool(players[owner].get("dead", false)): continue
			position_value = weapon_draw_pose(players[owner]).position
		var p: Vector2 = world_to_screen(position_value)
		if not _visible(p, 140.0): continue
		ProcFeedback.draw(self, ProcFeedback.field_sample(field), p, fx_scale)


func _draw_players() -> void:
	var players: Dictionary = _frame.get("players", {})
	for key: Variant in players:
		var player: Dictionary = players[key]
		var pose: Dictionary = weapon_draw_pose(player)
		var p: Vector2 = world_to_screen(pose.position)
		if not _visible(p, 90.0):
			continue
		var character: String = player.get("character", "ranger")
		var weapon: String = player.get("weapon", "pulse_rifle" if character == "ranger" else "arc_blade")
		var color_value: Color = TEAL if character == "ranger" else GOLD
		var dead: bool = player.get("dead", false)
		if dead:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-17.0, 18.0), p + Vector2(-12.0, 10.0), p + Vector2(11.0, 9.0), p + Vector2(20.0, 19.0)]), Color("3f6665"))
			var core: Vector2 = p + Vector2(0.0, -4.0 + sin(_clock * 2.0) * 4.0)
			_glow(core, 24.0, Color(color_value, 0.055), 3)
			draw_circle(core, 4.0, color_value, true, -1.0, true)
			if _is_focused("revive", int(key)):
				_focus_marker(core, Vector2(21.0, 18.0), color_value)
				_key_hint(p + Vector2(0.0, -37.0), color_value)
			elif int(key) == _local_id:
				_world_label(p + Vector2(0.0, -31.0), Locale.text("信号中断"), Color(color_value, 0.9), 12)
			var revive: float = float(player.get("revive", 0.0))
			if revive > 0.0:
				draw_arc(core, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(revive, 0.0, 1.0), 24, color_value, 2.0, true)
			continue
		var aim: Vector2 = pose.aim
		var appearance: Array[Dictionary] = Appearance.build(player.get("items", {}))
		var facing: float = 1.0 if aim.x >= 0.0 else -1.0
		var vel: Vector2 = player.get("vel", Vector2.ZERO)
		var grounded: bool = player.get("grounded", false)
		var running: float = clampf(absf(vel.x) / 100.0, 0.0, 1.0)
		# Illustrated bodies retain continuous subpixel movement; the gait owns foot contact.
		draw_set_transform(p, 0.0, Vector2(facing, 1.0))
		Appearance.draw_layer(self, appearance, true, _clock)
		# Body and weapon sample exactly the same interpolated world position.
		# Keep the authoritative snapshot untouched while feet follow visible travel.
		var displayed: Dictionary = player.duplicate(false)
		displayed.pos = pose.position
		displayed.aim = aim
		if bool(pose.melee.active) or bool(pose.ranged.active):
			var body_motion: Dictionary = (pose.melee if bool(pose.melee.active) else pose.ranged).duplicate(false)
			body_motion["draw_origin"] = p
			body_motion["facing"] = facing
			displayed["_melee_pose"] = body_motion
		Entities.player_body(self, displayed, _clock)
		draw_set_transform(Vector2.ZERO)
		# Accessories mirror with the body; the weapon follows the selected shoulder.
		draw_set_transform(p, 0.0, Vector2(facing, 1.0))
		Appearance.draw_layer(self, appearance, false, _clock)
		if bool(pose.melee.active):
			_draw_melee_actor(player, pose)
		elif bool(pose.ranged.active):
			_draw_ranged_actor(player, pose)
		else:
			_draw_weapon_arm(player,world_to_screen(pose.shoulder),world_to_screen(pose.grip),facing)
			draw_set_transform(world_to_screen(pose.shoulder), aim.angle(), Vector2(1.0, facing))
			_draw_weapon(weapon)
		draw_set_transform(Vector2.ZERO)
		_draw_movement_ability(player, p)
		ProcFeedback.draw(self, ProcFeedback.shield_sample(player), p, fx_scale)
		if float(player.get("chrono_timer", 0.0)) > 0.0:
			var phase: float = _clock * 1.7
			draw_arc(p,32.0,phase,phase+PI*1.2,30,Color(0.54,0.86,0.93,0.42),1.2,true)
			for tick: int in range(3):
				var tick_dir: Vector2 = Vector2.from_angle(phase + float(tick) * TAU / 3.0)
				draw_line(p+tick_dir*30.0,p+tick_dir*35.0,Color("89dbec"),1.5,true)
		if float(player.get("shield", 0.0)) > 0.0:
			var shield_alpha: float = 0.45 if float(player.get("shield_timer", 5.0)) > 1.5 else 0.2 + absf(sin(_clock * 8.0)) * 0.3
			IllustratedFX.shield(self,p,29.0,_clock*.18,IllustratedFX.ICE,shield_alpha)
		if float(player.get("invuln", 0.0)) > 0.0:
			_glow(p, 31.0, Color(color_value, 0.08 + sin(_clock * 36.0) * 0.03), 2)
		if players.size() > 1:
			_world_label(p + Vector2(0.0, -42.0), str(player.get("name", "PILOT")), color_value if int(key) == _local_id else CREAM, 11)
		if int(key) == _local_id:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3.0, -37.0), p + Vector2(3.0, -37.0), p + Vector2(0.0, -33.0)]), Color(color_value, 0.75))


func _draw_movement_ability(player: Dictionary, p: Vector2) -> void:
	# Snapshot/prediction-driven shield: no replayed particles or gameplay writes.
	if float(player.get("guard_timer", 0.0)) <= 0.0:
		return
	var charge: float = clampf(float(player.get("guard_absorbed", 0.0)) / 40.0, 0.0, 1.0)
	var radius: float = 30.0 + charge * 4.0
	IllustratedFX.shield(self,p,radius,PI/6.0,IllustratedFX.GOLD,.8)
	var progress: float = clampf(1.0 - float(player.guard_timer) / 0.8, 0.0, 1.0)
	IllustratedFX.ribbon(self,p,radius+4,-PI/2,-PI/2+maxf(.01,TAU*progress),1.5,Color(CREAM,.75))
	for index: int in range(4):
		var tick: Vector2 = p + Vector2((index - 1.5) * 6.0, -radius - 8.0)
		draw_rect(Rect2(tick, Vector2(4, 3)), GOLD if charge >= float(index+1)*0.25 else Color(GOLD,0.22))


func _draw_melee_actor(player: Dictionary, pose: Dictionary) -> void:
	var motion: Dictionary = pose.melee
	var shoulder: Vector2 = world_to_screen(pose.shoulder)
	var grip: Vector2 = world_to_screen(pose.grip)
	var angle: float = float(pose.weapon_angle)
	var facing: float = float(motion.facing)
	draw_set_transform(Vector2.ZERO)
	if bool(motion.trail):
		# A short ribbon follows the physical sword, and only during the fast cut.
		var trailing: float = angle - 0.85 * facing
		IllustratedFX.ribbon(self,shoulder,68.0,minf(trailing,angle),maxf(trailing,angle),7.0,Color("d9b785",.8))
		IllustratedFX.ribbon(self,shoulder,70.0,minf(trailing+facing*.24,angle),maxf(trailing+facing*.24,angle),1.8,Color("eee7c7",.9))
	_draw_weapon_arm(player, shoulder, grip, facing, float(motion.arm_alpha))
	draw_set_transform(world_to_screen(pose.weapon_origin), angle, Vector2(float(pose.weapon_scale), facing))
	_draw_weapon("arc_blade")
	draw_set_transform(Vector2.ZERO)
	draw_circle(grip, 3.0, Color(INK,float(motion.arm_alpha)))
	draw_circle(grip, 1.8, Color(Color("d6c4a1"),float(motion.arm_alpha)))


func _draw_ranged_actor(player: Dictionary, pose: Dictionary) -> void:
	var facing: float = 1.0 if Vector2(pose.aim).x >= 0.0 else -1.0
	var motion: Dictionary = pose.ranged
	draw_set_transform(Vector2.ZERO)
	_draw_weapon_arm(player, world_to_screen(pose.shoulder), world_to_screen(pose.grip), facing)
	draw_set_transform(world_to_screen(pose.weapon_origin), float(pose.weapon_angle), Vector2(1,facing))
	if float(motion.weapon_alpha) > 0.1:
		_draw_weapon(str(player.weapon), float(motion.mechanism), float(motion.energy))
	draw_set_transform(Vector2.ZERO)


func _draw_weapon_arm(player: Dictionary, shoulder: Vector2, grip: Vector2, facing: float, opacity: float = 1.0) -> void:
	var direction: Vector2 = (grip - shoulder).normalized()
	var elbow: Vector2 = shoulder.lerp(grip, 0.5) + direction.orthogonal() * facing * 5.5 + Vector2(0, 2)
	var armor: Color = Color("b4a798") if str(player.get("character", "ranger")) == "vanguard" else Color("c6c7aa")
	armor.a = opacity
	var outline: Color = Color("424e55",opacity)
	draw_polyline(PackedVector2Array([shoulder, elbow, grip]), outline, 7.0, true)
	draw_line(shoulder, elbow, armor, 4.8, true)
	draw_line(elbow, grip, armor.darkened(0.15), 4.2, true)
	draw_circle(elbow, 2.6, outline)
	draw_circle(elbow, 1.6, armor.lightened(0.15))
	draw_line(shoulder + Vector2(0,-1), elbow + Vector2(0,-1), Color(Color("e5d7b5"),opacity), 1.0, true)


func _draw_enemies() -> void:
	for value: Variant in _frame.get("enemies", []):
		var enemy: Dictionary = value
		if float(enemy.get("hp",1.0))<=0.0: continue
		var p: Vector2 = world_to_screen(_entity_draw_position("e" + str(enemy.get("id", 0)), enemy.get("pos", Vector2.ZERO)))
		if not Entities.Geometric.supports(str(enemy.get("kind", ""))) and Pixels.available(Pixels.enemy_id(enemy)):
			p = Pixels.snap_position(self, p)
		if str(enemy.get("kind", "")) == "sentinel" or (str(enemy.get("kind", ""))=="boss" and str(enemy.get("boss_style",""))=="prism"):
			for hazard: Dictionary in _frame.get("hazards", []):
				if int(hazard.get("owner",-1)) == int(enemy.get("id",0)) and str(hazard.get("shape", "")) == "line":
					p = world_to_screen(hazard.pos)
					break
		var bounds: Rect2 = Entities.enemy_bounds(enemy)
		if not Rect2(p+bounds.position,bounds.size).grow(28.0).intersects(Rect2(Vector2.ZERO,screen_size)): continue
		var kind: String = str(enemy.get("kind", "crawler"))
		var elite: bool = bool(enemy.get("elite", false))
		var vel: Vector2 = enemy.get("vel", Vector2.ZERO)
		var heading: Vector2 = enemy.get("attack_dir",vel) if bool(EnemyAttackArt.attack_sample(enemy).active) else vel
		var facing: float = 1.0 if heading.x >= 0.0 else -1.0
		var accent: Color = Color("ffd08b") if elite else Color("efa67d")
		draw_set_transform(p,0.0,Vector2(facing,1.0))
		Entities.enemy(self,enemy,_clock)
		draw_set_transform(Vector2.ZERO)
		var hp: float = float(enemy.get("hp",100.0))
		var max_hp: float = maxf(1.0,float(enemy.get("max_hp",100.0)))
		var status_index: int = 0
		var top: float = bounds.position.y-10.0
		for status: String in ["slow_timer", "poison_timer", "burn_timer", "stun_timer"]:
			if float(enemy.get(status,0.0))<=0.0: continue
			var color_value: Color = {"slow_timer":Color("b3e6fa"),"poison_timer":Color("a6d884"),"burn_timer":Color("ffa77a"),"stun_timer":Color("c7a8f0")}[status]
			var spot: Vector2 = p+Vector2(-10.0+status_index*7.0,top-8.0)
			draw_colored_polygon(PackedVector2Array([spot+Vector2(0,-3),spot+Vector2(2,0),spot+Vector2(0,3),spot+Vector2(-2,0)]),color_value)
			status_index+=1
		if hp<max_hp or kind=="boss" or elite:
			var width: float = 92.0 if kind=="boss" else 28.0
			var bar_p: Vector2 = p+Vector2(-width*0.5,top)
			draw_rect(Rect2(bar_p-Vector2.ONE,Vector2(width+2,5)),INK)
			draw_rect(Rect2(bar_p,Vector2(width,3)),Color("3a3e43"))
			draw_rect(Rect2(bar_p,Vector2(width*clampf(hp/max_hp,0.0,1.0),3)),accent)
			if kind=="boss":
				var title: String = str(enemy.get("name", {"spore":"孢冠母巢","stone":"裂岩巨像","prism":"寂光执政官"}.get(str(enemy.get("boss_style","spore")),"守望者")))
				_world_label(p+Vector2(0,top-10),Locale.text(title),GOLD,13)


func _draw_projectiles() -> void:
	for value: Variant in _frame.get("projectiles", []):
		var projectile: Dictionary = value
		var rendered: Vector2 = _entity_draw_position("b"+str(projectile.get("id",0)),projectile.get("pos",Vector2.ZERO))
		var p: Vector2 = world_to_screen(rendered)
		# Long precision tails can remain on screen after their core leaves it.
		if not _visible(p,120.0): continue
		var friendly: bool = str(projectile.get("team","player"))=="player"
		var kind: String = str(projectile.get("kind","bullet"))
		var strength: float = effect_strength(projectile) if friendly else 1.0
		if ProcFeedback.draw(self, ProcFeedback.projectile_sample(projectile), p, fx_scale): continue
		var velocity: Vector2 = projectile.get("vel",Vector2.RIGHT)
		var requested: float = minf(velocity.length()*0.032*sqrt(strength),92.0 if kind in ["rail","lance"] else 42.0)
		var tail: float = rendered_projectile_trail_length(projectile,rendered,requested)
		ProjectileArt.draw(self,projectile,p,_clock,strength,tail)


func _draw_threat_overlays() -> void:
	# Draw all dangerous material first, then ALL warning boundaries. An active
	# beam must not erase another enemy's still-harmless warning at a crossing.
	for value: Variant in _frame.get("hazards", []):
		if bool(value.get("active",false)): _draw_hazard(value)
	for value: Variant in _frame.get("hazards", []):
		if not bool(value.get("active",false)): _draw_hazard(value)
	for value: Variant in _frame.get("enemies", []):
		var enemy: Dictionary = value
		if float(enemy.get("hp",0.0))<=0.0: continue
		var attack_position: Vector2=world_to_screen(_entity_draw_position("e"+str(enemy.get("id",0)),enemy.get("pos",Vector2.ZERO)))
		if _visible(attack_position,100.0): EnemyAttackArt.draw_lunge(self,enemy,attack_position)
		var remaining: float = float(enemy.get("telegraph",0.0))
		if remaining<=0.0: continue
		var p: Vector2 = world_to_screen(_entity_draw_position("e"+str(enemy.get("id",0)),enemy.get("pos",Vector2.ZERO)))
		var direction: Vector2 = WeaponPose.normalized_aim(enemy.get("attack_dir",Vector2.RIGHT))
		var progress: float = clampf(1.0-remaining/maxf(0.01,float(enemy.get("telegraph_max",0.8))),0.0,1.0)
		var attack: String = str(enemy.get("attack_kind",""))
		var detail: bool = not reduced_motion and fx_scale>=.6
		if attack not in ["beam","prism_beam","prism_cross"] and _visible(p,100.0):
			EnemyAttackArt.draw_preparation(self,enemy,p,direction,progress,44.0 if str(enemy.get("kind",""))=="boss" else 17.0,detail)
		match attack:
			"blink":
				var destination: Vector2 = world_to_screen(enemy.get("blink_target",enemy.get("pos",Vector2.ZERO)))
				if _visible(destination,45) or _visible(p,45):
					NaturalThreats.draw_blink(self,p,destination,progress)
			"spit", "triple", "salvo", "spore_volley", "mend":
				if not _visible(p,190): continue
				var count: int = 3 if attack in ["triple","salvo"] else (7 if attack=="spore_volley" and float(enemy.hp)<float(enemy.max_hp)*0.45 else (5 if attack=="spore_volley" else 1))
				for index: int in range(count):
					var spacing: float = 0.21 if attack=="spore_volley" else 0.2
					var ray: Vector2 = direction.rotated((index-(count-1)*0.5)*spacing)
					var start: float = float(enemy.get("radius",19.0))+3.0
					if count>1:
						# Charged spores/ports form at the mouth; no future path is drawn.
						var seed: Vector2 = p+ray*start
						var extent: float = 7.0+6.0*progress
						EnemyAttackArt.Geometry.draw_ammunition(self,seed,ray,extent*.35,attack=="spore_volley",true,progress)
				if attack=="mend":
					var linked: int=0
					for ally: Dictionary in _frame.get("enemies",[]):
						if int(ally.get("id",0))==int(enemy.get("id",0)) or str(ally.get("kind",""))=="boss" or float(ally.get("hp",0))<=0 or float(ally.get("hp",0))>=float(ally.get("max_hp",1)): continue
						if Vector2(ally.pos).distance_to(enemy.pos)>260.0: continue
						var end: Vector2 = world_to_screen(ally.pos)
						NaturalThreats.draw_mending(self,p+EnemyAttackArt.Geometry.source_offset(enemy,direction),end,progress,detail)
						linked+=1
						if linked>=3: break


func _draw_hazard(hazard: Dictionary) -> void:
	var p: Vector2 = world_to_screen(hazard.get("pos",Vector2.ZERO))
	var radius: float = clampf(float(hazard.get("radius",30.0)),1.0,400.0)
	if str(hazard.get("shape","circle"))=="line":
		var sampled: Dictionary = EnemyAttackArt.beam_sample(hazard,fx_scale,reduced_motion)
		var end: Vector2 = world_to_screen(sampled.end)
		if not Rect2(p,Vector2.ZERO).expand(end).grow(radius+32).intersects(Rect2(Vector2.ZERO,screen_size)): return
		EnemyAttackArt.draw_beam(self,p,end,sampled)
		return
	if not _visible(p,radius+14): return
	NaturalThreats.draw_area(self,p,NaturalThreats.area_sample(hazard,fx_scale,reduced_motion))


func _draw_effects() -> void:
	_draw_particle_batches()
	for effect: Dictionary in _effects:
		if bool(effect.get("melee", false)): continue
		if str(effect.get("kind","")) in PARTICLE_KINDS: continue
		var pose: Dictionary = muzzle_effect_pose(effect)
		if not bool(pose.visible):
			continue
		var p: Vector2 = world_to_screen(pose.pos)
		if not _visible(p,float(effect.get("radius",0.0))+280.0) and not effect.has("from"): continue
		var effect_angle: float = Vector2(pose.aim).angle()
		var age: float = effect.get("age", 0.0)
		var life: float = effect.get("life", 0.5)
		var t: float = clampf(age / life, 0.0, 1.0)
		var color_value: Color = effect.get("color", TEAL)
		color_value.a *= 1.0 - t
		var strength: float = clampf(float(effect.get("strength", 1.0)), 0.5, 3.3)
		if str(effect.get("kind", "")) == "hostile_contact":
			EnemyAttackArt.Geometry.draw_impact(self,p,str(effect.family),Vector2.from_angle(float(effect.angle)),t)
			continue
		if str(effect.get("kind", "")) == "hostile_natural":
			var tint: Color = effect.get("color",Color.WHITE)
			tint.a *= 1.0 - smoothstep(0.6,1.0,t)
			if str(effect.get("family",""))=="rift":
				EnemyAttackArt.Geometry.draw_rift(self,p,30,t,true)
			elif str(effect.get("family",""))=="repair":
				EnemyAttackArt.Geometry.diamond(self,p,Vector2.UP,5*(1-t),3*(1-t),Color("9ac7ad"))
			else:
				EnemyAttackArt.Geometry.draw_impact(self,p,"spore" if str(effect.get("family","")).begins_with("spore") else "stone",Vector2.UP,t)
			continue
		if str(effect.get("kind", "")) == "proc_activation":
			ProcFeedback.draw(self, ProcFeedback.activation_sample(effect), p, fx_scale)
			continue
		if IllustratedFX.effect(self,effect,p,effect_angle,t,strength,color_value,world_to_screen(effect.get("from",Vector2.ZERO))): continue
		match str(effect.get("kind", "spark")):
			"coin_collect":
				for index: int in range(4):
					var angle: float = index * PI/2.0 + PI/4.0
					var direction: Vector2 = Vector2.from_angle(angle)
					draw_line(p+direction*(5+t*12),p+direction*(14+t*17),Color(GOLD,0.8*(1-t)),2.0,false)
			"slash":
				var angle: float = effect_angle
				if effect.has("weapon"):
					p -= Vector2(pose.aim) * WeaponPose.muzzle_length(str(effect.weapon))
				var radius: float = float(effect.get("radius",85.0)) * (0.6+t*0.35)
				IllustratedFX.ribbon(self,p,radius,angle-1.1+t*.5,angle+.85+t*.5,5*(1-t),color_value)
				IllustratedFX.ribbon(self,p,radius+2,angle-.7+t*.5,angle+.5+t*.5,1.2,Color(CREAM,color_value.a*.8))
	for number: Dictionary in _numbers:
		var age: float = number.get("age", 0.0)
		var p: Vector2 = world_to_screen(number.get("pos", Vector2.ZERO)) + Vector2(0.0, -age * 34.0)
		var crit: bool = number.get("crit", false)
		var color_value: Color = number.get("color", GOLD if crit else CREAM)
		color_value.a = clampf((0.85 - age) * 3.0, 0.0, 1.0)
		_world_label(p, str(number.get("text", "")), color_value, 18 if crit else 13)


func _draw_atmosphere() -> void:
	Biomes.atmosphere(self, _current_biome, camera_position, screen_size, _clock)


func _glow(p: Vector2, radius: float, color_value: Color, layers: int = 3) -> void:
	for layer: int in range(layers, 0, -1):
		var fraction: float = float(layer) / float(layers)
		draw_circle(p, maxf(0.1, radius * fraction), color_value, true, -1.0, true)


func _visible(p: Vector2, margin: float) -> bool:
	return p.x > -margin and p.y > -margin and p.x < screen_size.x + margin and p.y < screen_size.y + margin


func _near_local(world_p: Vector2, distance: float) -> bool:
	if menu_preview:
		return false
	var players: Dictionary = _frame.get("players", {})
	if not players.has(_local_id):
		return false
	var player: Dictionary = players[_local_id]
	var p: Vector2 = player.get("pos", Vector2.ZERO)
	return not bool(player.get("dead", false)) and p.distance_to(world_p) < distance


func _is_focused(kind: String, id_value: int) -> bool:
	return not menu_preview and str(interaction_target.get("kind", "")) == kind and int(interaction_target.get("id", -100)) == id_value


func _focus_marker(p: Vector2, half: Vector2, color_value: Color) -> void:
	var pulse: float = 0.8 + sin(_clock * 3.0) * 0.15
	for x_side: float in [-1.0, 1.0]:
		for y_side: float in [-1.0, 1.0]:
			var corner: Vector2 = p + Vector2(half.x * x_side, half.y * y_side)
			draw_polyline(PackedVector2Array([corner - Vector2(7.0 * x_side, 0.0), corner, corner - Vector2(0.0, 7.0 * y_side)]), Color(color_value, pulse), 1.5, true)


func _key_hint(p: Vector2, color_value: Color) -> void:
	draw_rect(Rect2(p - Vector2(9.0, 13.0), Vector2(18.0, 18.0)), INK)
	draw_rect(Rect2(p - Vector2(9.0, 13.0), Vector2(18.0, 18.0)), Color(color_value, 0.7), false, 1.0)
	_world_label(p + Vector2(0.0, 1.0), "E", color_value, 12)


func _world_label(p: Vector2, message: String, color_value: Color, font_size: int) -> void:
	if _font == null:
		return
	var width: float = _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var baseline: Vector2 = p - Vector2(width * 0.5, 0.0)
	draw_string_outline(_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, Color(INK, color_value.a))
	draw_string(_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color_value)
