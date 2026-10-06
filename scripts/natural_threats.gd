class_name SideNaturalThreats
extends RefCounted

## Diegetic warnings: sprites occupy the locked attack area, without a diagram
## of its collision shape. Replicated timers keep remote/paused frames stable.
const Sprites = preload("res://scripts/attack_fx_sprites.gd")

static func area_sample(hazard: Dictionary, _fx_scale: float = 1.0, _reduced_motion: bool = false) -> Dictionary:
	var active: bool = bool(hazard.get("active", false))
	var radius: float = clampf(float(hazard.get("radius", 30.0)), 1.0, 400.0)
	var progress: float = clampf(1.0 - float(hazard.get("delay", 0.0)) / maxf(0.01, float(hazard.get("telegraph_max", 0.8))), 0.0, 1.0)
	var release: float = clampf(1.0 - float(hazard.get("ttl", 0.22)) / 0.22, 0.0, 1.0)
	var organic: bool = str(hazard.get("kind", "")) in ["spore_mortar", "boss_spore", "spore_bloom", "spore_pool"]
	return {"origin": hazard.get("pos", Vector2.ZERO), "radius": radius,
		"active": active, "progress": progress, "phase": 0.25 + (release if active else progress) * 0.7,
		"material_alpha": 0.88 if active else 0.58 + progress * 0.28,
		"size": Vector2.ONE * radius * 2.2, "family": "dust_cloud",
		"color": Color(0.86, 1.0, 0.58) if organic else Color(1.0, 0.82, 0.64),
		"release": release}

static func draw_area(canvas: CanvasItem, position: Vector2, sample: Dictionary) -> void:
	var tint: Color = sample.color
	tint.a = float(sample.material_alpha)
	Sprites.draw_family(canvas, str(sample.family), Rect2(position - Vector2(sample.size) * 0.5, sample.size), float(sample.phase), tint)
	# The whole disturbed patch is present from the first warning frame; its
	# texture grows denser rather than painting a growing circle around it.
	if bool(sample.active):
		Sprites.draw_family(canvas, "burst", Rect2(position - Vector2(sample.size) * 0.45, Vector2(sample.size) * 0.9), float(sample.release), Color(1, 0.93, 0.8, 0.9))

static func draw_blink(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float) -> void:
	# Paired vertical tears imply a transition without drawing the path between.
	var size_value: Vector2 = Vector2(38.0 + progress * 14.0, 64.0)
	Sprites.draw_family(canvas, "charge", Rect2(destination - size_value * 0.5, size_value), progress, Color(1, 0.82, 0.75, 0.65 + progress * 0.3))
	Sprites.draw_family(canvas, "charge", Rect2(source - Vector2(17, 27), Vector2(34, 54)), progress, Color(1, 0.82, 0.75, 0.3 + progress * 0.35))

static func draw_mending(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float, detail: bool) -> void:
	var direction: Vector2 = (destination - source).normalized()
	# Sparse, curved motes travel to the actual recipient. They have no tether,
	# evenly-spaced dots, endpoint reticle, or extra target selection on clients.
	var seeds: Array = [0.04, 0.31, 0.77] if detail else [0.31]
	for index: int in range(seeds.size()):
		var t: float = fposmod(progress * 1.55 + seeds[index], 1.0)
		var bend: float = (18.0 if index % 2 == 0 else -14.0) * sin(t * PI)
		var point: Vector2 = source.lerp(destination, t) + direction.orthogonal() * bend
		var size_value: float = 10.0 + sin(t * PI) * 5.0
		Sprites.draw_family(canvas, "charge", Rect2(point - Vector2.ONE * size_value * 0.5, Vector2.ONE * size_value), 0.6 + t * 0.35, Color(0.95, 1, 0.72, 0.85))
	Sprites.draw_family(canvas, "charge", Rect2(destination - Vector2(19, 25), Vector2(38, 50)), progress, Color(0.95, 1, 0.72, 0.75))
