class_name SideNaturalThreats
extends RefCounted

## Ready and damaging states have different silhouettes, not just different
## opacity. All placement and phase come from the authoritative snapshot.
const Sprites = preload("res://scripts/attack_fx_sprites.gd")
const Geometry = preload("res://scripts/combat_geometry.gd")
const SelectedFX = preload("res://scripts/selected_enemy_fx.gd")

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
		"warning_radius": radius, "warning_alpha": Geometry.warning_alpha(progress*float(hazard.get("telegraph_max",1.5))),
		"warning_fill_alpha": 0.0, "warning_progress": progress,
		"release": release}

static func area_family(kind: String, active: bool) -> String:
	var material: String = "spore" if kind in ["spore_mortar", "boss_spore", "spore_bloom", "spore_pool"] else ("stone" if kind == "stone_spike" else "earth")
	return material + ("_hit" if active else "_ready")

static func warning_points(position: Vector2, radius: float, progress: float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var amount: float=clampf(progress,0.0,1.0)
	if amount<=0.0: return points
	var steps: int=maxi(2,ceili(amount*64))
	for index: int in range(steps+1): points.append(position+Vector2.from_angle(-PI*.5+amount*TAU*index/steps)*radius)
	return points

static func draw_area(canvas: CanvasItem, position: Vector2, sample: Dictionary) -> void:
	var tint: Color = sample.color
	tint.a = float(sample.material_alpha)
	var center: Vector2 = position + Vector2(sample.draw_offset)
	if bool(sample.warning_visible):
		# A dark-backed red dashed boundary gives the player useful
		# space/time information even when the terrain sprite blends in.
		var radius: float = float(sample.warning_radius)
		var progress: float=clampf(float(sample.warning_progress),0.0,1.0)
		if progress>0.0:
			var boundary: PackedVector2Array=warning_points(position,radius,progress)
			Geometry.draw_warning(canvas,boundary,float(sample.warning_alpha),false)
	SelectedFX.draw_area(canvas,position,sample)

static func draw_blink(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float) -> void:
	SelectedFX.draw_blink(canvas,source,progress)
	SelectedFX.draw_blink(canvas,destination,progress*.85)

static func draw_mending(canvas: CanvasItem, source: Vector2, destination: Vector2, progress: float, detail: bool) -> void:
	var motion: Dictionary=Geometry.FX.motion("mending",progress)
	progress=float(motion.progress)
	var direction: Vector2 = (destination - source).normalized()
	# Sparse, curved motes travel to the actual recipient. They have no tether,
	# evenly-spaced dots, endpoint reticle, or extra target selection on clients.
	var seeds: Array = [0.12, 0.69] if detail else [0.31]
	for index: int in range(seeds.size()):
		var t: float = fposmod(progress * 1.55 + seeds[index], 1.0)
		var bend: float = (18.0 if index % 2 == 0 else -14.0) * sin(t * PI)
		var point: Vector2 = source.lerp(destination, t) + direction.orthogonal() * bend
		var size_value: float = 6.0 + sin(t * PI) * 3.0
		Geometry.diamond(canvas,point,direction,size_value*.5,size_value*.25,Color("9ac7ad"),1.0)
	Geometry.diamond(canvas,destination,Vector2.UP,5,3,Color("9ac7ad"),1.0)
