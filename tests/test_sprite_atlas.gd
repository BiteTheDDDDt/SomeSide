extends SceneTree

const Atlas = preload("res://scripts/sprite_atlas.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
const Projectiles = preload("res://scripts/projectile_renderer.gd")
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")

class Gallery extends Node2D:
	var mode: String = "enemies"

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("08171d"))
		if mode == "enemies":
			var index: int = 0
			for variant: int in range(4):
				for kind: String in Entities.enemy_kinds():
					var state: Dictionary = {"kind": kind, "id": 0, "elite": (variant & 1) != 0, "flash": 0.1 if (variant & 2) != 0 else 0.0, "telegraph": 0.0}
					draw_set_transform(Vector2(65 + (index % 10) * 124, 110 + (index / 10) * 155), 0.0, Vector2.ONE * 1.25)
					Entities.enemy(self, state, 0.0)
					index += 1
			for variant: int in range(4):
				var state: Dictionary = {"kind": "charger", "id": 0, "elite": (variant & 1) != 0, "flash": 0.1 if (variant & 2) != 0 else 0.0, "telegraph": 0.5}
				draw_set_transform(Vector2(65 + (index % 10) * 124, 110 + (index / 10) * 155), 0.0, Vector2.ONE * 1.25)
				Entities.enemy(self, state, 0.0)
				index += 1
		else:
			var kinds: Array[String] = ["bullet", "pellet", "rail", "lance", "grenade", "boomerang", "storm", "spit", "crystal", "energy", "boss_spore_orb"]
			for row: int in range(4):
				for column: int in range(kinds.size()):
					var kind: String = kinds[column]
					var shot: Dictionary = {"kind": kind, "id": 0, "team": "player" if column < 7 else "enemy", "radius": 9 if kind == "boss_spore_orb" else 6, "vel": Vector2.RIGHT * 500}
					Projectiles.draw(self, shot, Vector2(94 + column * 112, 105 + row * 160), 0.0, 2.3, [0.0, 7.0, 40.0, 92.0][row])
		draw_set_transform(Vector2.ZERO)

var passed: int = 0
var failed: int = 0
var probe: Gallery

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Exercise the retained vector fallback independently of production pixel art.
	Pixels.install_manifest({"version": 1, "actors": {}})
	_test_plans()
	probe = Gallery.new()
	root.size = Vector2i(1280, 720)
	root.add_child(probe)
	if DisplayServer.get_name() == "headless":
		Entities.prepare(probe)
		Projectiles.prepare(probe)
		_check(not probe.has_meta(Entities.CACHE_META) and not probe.has_meta(Projectiles.CACHE_META), "Headless rendering never allocates GPU sprite targets")
	else:
		await _test_native()
	probe.queue_free()
	await process_frame
	Pixels.reload_manifest()
	print("SPRITE_ATLAS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _test_plans() -> void:
	var enemies: Array = Entities.atlas_entries()
	var projectiles: Array = Projectiles.atlas_entries()
	_check(enemies.size() == 580, "The enemy atlas has a fixed finite set of 580 authored animation/state cells")
	_check(projectiles.size() == 243, "The projectile atlas has 243 fixed hostile cores, including a full 24-frame orb cycle")
	var enemy_plan: Dictionary = _check_plan(enemies, Entities.CACHE_MAX_BYTES, 4096, "Enemy")
	var projectile_plan: Dictionary = _check_plan(projectiles, Projectiles.CACHE_MAX_BYTES, 1024, "Projectile")
	_check(int(enemy_plan.bytes) + int(projectile_plan.bytes) <= 32 * 1024 * 1024, "Both complete sprite atlases stay within the 32 MiB combined color-texture budget")
	var counts: Dictionary = {}
	for entry: Dictionary in enemies:
		var state: Dictionary = entry.data.state
		var key: String = str(state.kind)
		counts[key] = int(counts.get(key, 0)) + 1
	var all_states: bool = true
	var all_bounds: bool = true
	for kind: String in Entities.enemy_kinds():
		var frames: int = 1 if kind == "sentinel" else Entities.ANIMATION_FRAMES
		var variants: int = 8 if kind == "charger" else 4
		all_states = all_states and counts.get(kind, 0) == frames * variants
		for variant: int in range(variants):
			for frame: int in range(frames):
				all_states = all_states and enemy_plan.regions.has("%s/%d/%d" % [kind, variant, frame])
	for entry: Dictionary in enemies:
		var state: Dictionary = entry.data.state
		all_bounds = all_bounds and entry.bounds.encloses(Entities._vector_enemy_bounds(state))
		if state.elite:
			var crown: Vector2 = Entities._vector_enemy_bounds(state).position + Vector2(28, -7)
			all_bounds = all_bounds and entry.bounds.has_point(Vector2(0, crown.y))
	_check(all_states, "Every kind includes normal, elite, flash and combined variants plus all charger crouches")
	_check(all_bounds, "Legacy cached vector silhouettes and elite crowns remain inside every padded sprite cell")
	_check(not counts.has("boss"), "Bosses retain their original unrestricted vector animation")
	var all_projectile_variants: bool = true
	for radius: int in range(4, 13):
		for kind: String in ["spit", "crystal", "energy"]:
			all_projectile_variants = all_projectile_variants and projectile_plan.regions.has("enemy/%s/%d/0" % [kind, radius])
		for frame: int in range(Projectiles.ORB_FRAMES):
			all_projectile_variants = all_projectile_variants and projectile_plan.regions.has("enemy/boss_spore_orb/%d/%d" % [radius, frame])
	_check(all_projectile_variants, "All hostile families, exact supported radii and orb animation phases are prewarmed")
	print("SPRITE_ATLAS_PLAN ", JSON.stringify({"enemy_bytes": enemy_plan.bytes, "enemy_size": enemy_plan.size, "projectile_bytes": projectile_plan.bytes, "projectile_size": projectile_plan.size}))

func _check_plan(entries: Array, budget: int, width: int, title: String) -> Dictionary:
	var before: PackedByteArray = var_to_bytes(entries)
	var plan: Dictionary = Atlas.layout(entries, 2.0, width)
	if int(plan.bytes) > budget:
		plan = Atlas.layout(entries, 1.5, width)
	_check(int(plan.bytes) <= budget and plan.size.y <= 4096, title + " layout fits the hard memory and texture-dimension limit")
	_check(plan.regions.size() == entries.size(), title + " regions have unique stable keys")
	_check(var_to_bytes(entries) == before, title + " layout leaves source descriptors and state unchanged")
	_check(var_to_bytes(Atlas.layout(entries, float(plan.scale), width)) == var_to_bytes(plan), title + " packing is deterministic")
	var contained: bool = true
	var disjoint: bool = true
	var total: Rect2 = Rect2(Vector2.ZERO, Vector2(plan.size))
	var row_end: Dictionary = {}
	for entry: Dictionary in plan.entries:
		var region: Rect2 = entry.region
		contained = contained and total.encloses(region)
		var row: int = int(region.position.y)
		disjoint = disjoint and float(region.position.x) >= float(row_end.get(row, 0.0)) + 2.0
		row_end[row] = region.end.x
	_check(contained, title + " regions stay entirely inside the allocated texture")
	_check(disjoint, title + " cells retain transparent gutters instead of overlapping neighboring art")
	return plan

func _test_native() -> void:
	await process_frame
	var texture_before: int = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var start: int = Time.get_ticks_usec()
	Entities.prepare(probe)
	Projectiles.prepare(probe)
	var setup_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	for frame: int in range(4):
		await process_frame
		probe.queue_redraw()
		await RenderingServer.frame_post_draw
	var ready_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
	var enemies: Dictionary = Entities.cache_info(probe)
	var projectiles: Dictionary = Projectiles.cache_info(probe)
	_check(enemies.ready and projectiles.ready, "Both native atlases become ready during controlled prewarm")
	_check(int(enemies.bytes) <= Entities.CACHE_MAX_BYTES and int(projectiles.bytes) <= Projectiles.CACHE_MAX_BYTES, "Native atlas color targets respect their declared RGBA budgets")
	_check(int(enemies.builds) == 1 and int(projectiles.builds) == 1, "Prewarm creates exactly one texture for each renderer")
	Entities.prepare(probe)
	Projectiles.prepare(probe)
	_check(Entities.cache_info(probe).builds == 1 and Projectiles.cache_info(probe).builds == 1, "Repeated prepare does not rebuild or allocate another atlas")
	var gpu_texture_delta: int = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) - texture_before
	_check(gpu_texture_delta <= 64 * 1024 * 1024, "Measured native GPU texture growth remains within 64 MiB including render-target overhead")
	var metrics: Dictionary = {"setup_cpu_ms": setup_ms, "first_ready_ms": ready_ms, "gpu_texture_delta_bytes": gpu_texture_delta, "enemy": enemies, "projectile": projectiles, "comparisons": {}}
	for mode: String in ["enemies", "projectiles"]:
		var source: Image = await _capture(mode, false)
		var cached: Image = await _capture(mode, true)
		var comparison: Dictionary = _compare(source, cached)
		metrics.comparisons[mode] = comparison
		_check(float(comparison.mean_foreground_error) < 0.075, mode + " cached silhouettes/materials match the authored vector render")
		_check(int(comparison.missing_pixels) < maxi(80, int(comparison.foreground_pixels) / 30), mode + " cached rendering does not omit silhouettes or clip their edges")
	var report := FileAccess.open("res://tools/results/v09-sprite-atlas.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t"))
	print("SPRITE_ATLAS_NATIVE ", JSON.stringify(metrics))

func _capture(mode: String, cached: bool) -> Image:
	probe.mode = mode
	probe.set_meta(Atlas.ENABLED_META, cached)
	probe.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.save_png("res://tools/results/v09-atlas-" + mode + ("-cached.png" if cached else "-vector.png"))
	return picture

func _compare(source: Image, cached: Image) -> Dictionary:
	var error: float = 0.0
	var active: int = 0
	var missing: int = 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var a: Color = source.get_pixel(x, y)
			var b: Color = cached.get_pixel(x, y)
			var background: Color = Color("08171d")
			var a_present: bool = absf(a.r - background.r) + absf(a.g - background.g) + absf(a.b - background.b) > 0.09
			var b_present: bool = absf(b.r - background.r) + absf(b.g - background.g) + absf(b.b - background.b) > 0.09
			if a_present or b_present:
				active += 1
				error += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
				if a_present and not b_present: missing += 1
	return {"mean_foreground_error": error / maxi(active, 1), "foreground_pixels": active, "missing_pixels": missing}
