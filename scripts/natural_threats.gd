class_name SideNaturalThreats
extends RefCounted

## Ready and damaging states have different silhouettes, not just different
## opacity. All placement and phase come from the authoritative snapshot.
const Sprites = preload("res://scripts/attack_fx_sprites.gd")

static func area_sample(hazard: Dictionary, _fx_scale: float = 1.0, _reduced_motion: bool = false) -> Dictionary:
	var active: bool = bool(hazard.get("active", false))
	var radius: float = clampf(float(hazard.get("radius", 30.0)), 1.0, 400.0)
	var progress: float = clampf(1.0 - float(hazard.get("delay", 0.0)) / maxf(0.01, float(hazard.get("telegraph_max", 0.8))), 0.0, 1.0)
	var release: float = clampf(1.0 - float(hazard.get("ttl", 0.22)) / 0.22, 0.0, 1.0)
	var kind: String = str(hazard.get("kind", ""))
	var organic: bool = kind in ["spore_mortar", "boss_spore", "spore_bloom", "spore_pool"]
	var material_color: Color = Color(1.0, 0.84, 0.55) if kind == "stone_spike" else Color.WHITE
	var size_value: Vector2 = Vector2(radius * 2.0, radius * 2.0 if active else 24.0)
	var offset: Vector2 = Vector2.ZERO
	if organic and not active:
		# A compact sealed pod promises a later burst. Stretching it across the
		# future radius would turn the seed into an unrelated flat cloud.
		size_value = Vector2.ONE * (36.0 + progress * 8.0)
	elif not organic:
		# Burrow/spikes are authored 17px above their support surface. Their
		# warning is a shallow disturbance there, and the eruption reaches the
		# top of the actual danger area. Airborne spores retain their true Y.
		size_value.y = radius + 17.0 if active else 22.0
		offset.y = 17.0 - size_value.y * 0.5
	return {"origin": hazard.get("pos", Vector2.ZERO), "radius": radius,
		"active": active, "progress": progress, "phase": release if active else progress,
		"material_alpha": 1.0,
		"size": size_value, "draw_offset": offset, "family": area_family(kind, active),
		"color": material_color,
		"warning_visible": not active, "warning_origin": hazard.get("pos", Vector2.ZERO),
		"warning_radius": radius, "warning_alpha": 0.9 + progress * 0.1,
		"warning_fill_alpha": 0.065, "warning_progress": progress,
		"release": release}

static func area_family(kind: String, active: bool) -> String:
	var material: String = "spore" if kind in ["spore_mortar", "boss_spore", "spore_bloom", "spore_pool"] else ("stone" if kind == "stone_spike" else "earth")
	return material + ("_hit" if active else "_ready")

static func draw_area(canvas: CanvasItem, position: Vector2, sample: Dictionary) -> void:
	var tint: Color = sample.color
	tint.a = float(sample.material_alpha)
	var center: Vector2 = position + Vector2(sample.draw_offset)
	if bool(sample.warning_visible):
		# A continuous dark-backed amber boundary gives the player useful
		# space/time information even when the terrain sprite blends in.
		var radius: float = float(sample.warning_radius)
		var warning: Color = Color("ffcb70")
		warning.a = float(sample.warning_alpha)
		canvas.draw_circle(position, radius, Color(warning, float(sample.warning_fill_alpha)), true, -1, true)
		canvas.draw_arc(position, radius, 0, TAU, 48, Color("071219"), 5.0, true)
		canvas.draw_arc(position, radius, 0, TAU, 48, warning, 2.0, true)
		var progress: float = float(sample.warning_progress)
		if progress > 0.001:
			canvas.draw_arc(position, radius - 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color("fff0b1"), 1.6, true)
		if str(sample.family) == "spore_ready":
			# The seed can coincide with the player's torso. A compact dark
			# backing and full-opacity seed keep its first frame recognizable.
			canvas.draw_circle(center, Vector2(sample.size).x * 0.47, Color(0.025, 0.055, 0.065, 0.8), true, -1, true)
	# Every active frame remains solid. There is no generic blast or lingering
	# damaging-looking cloud after the authority removes this hazard.
	Sprites.draw_family(canvas, str(sample.family), Rect2(center - Vector2(sample.size) * 0.5, sample.size), float(sample.phase), tint)

static func draw_blink(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float) -> void:
	# Paired vertical tears imply a transition without drawing the path between.
	var size_value: Vector2 = Vector2(12.0 + progress * 8.0, 42.0)
	Sprites.draw_family(canvas, "rift", Rect2(destination - size_value * 0.5, size_value), progress, Color(1, 1, 1, 0.5 + progress * 0.3))
	Sprites.draw_family(canvas, "rift", Rect2(source - Vector2(7, 18), Vector2(14, 36)), progress, Color(1, 1, 1, 0.3 + progress * 0.35))

static func draw_mending(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float, detail: bool) -> void:
	var direction: Vector2 = (destination - source).normalized()
	# Sparse, curved motes travel to the actual recipient. They have no tether,
	# evenly-spaced dots, endpoint reticle, or extra target selection on clients.
	var seeds: Array = [0.12, 0.69] if detail else [0.31]
	for index: int in range(seeds.size()):
		var t: float = fposmod(progress * 1.55 + seeds[index], 1.0)
		var bend: float = (18.0 if index % 2 == 0 else -14.0) * sin(t * PI)
		var point: Vector2 = source.lerp(destination, t) + direction.orthogonal() * bend
		var size_value: float = 6.0 + sin(t * PI) * 3.0
		Sprites.draw_family(canvas, "repair", Rect2(point - Vector2.ONE * size_value * 0.5, Vector2.ONE * size_value), t, Color(1, 1, 1, 0.68))
	Sprites.draw_family(canvas, "repair", Rect2(destination - Vector2(6, 9), Vector2(12, 18)), progress, Color(1, 1, 1, 0.5))
