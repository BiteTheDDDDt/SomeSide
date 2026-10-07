class_name SideProcFeedback
extends RefCounted

## Presentation samples use replicated lifetimes, never wall-clock time or RNG.
## Live damaging bodies remain visible at the lowest cosmetic FX setting.
const Sprites = preload("res://scripts/attack_fx_sprites.gd")
const IllustratedFX = preload("res://scripts/illustrated_fx.gd")
const SOURCES: Array[String] = ["missile_pod", "landing_coil", "frost_halo", "pursuit_protocol", "reactive_plating"]

static func projectile_sample(shot: Dictionary) -> Dictionary:
	if str(shot.get("team", "player")) != "player" or float(shot.get("ttl", 0.0)) <= 0.0: return {}
	var kind: String = str(shot.get("kind", ""))
	if kind not in ["seeker_missile", "shock_wave"]: return {}
	var age: float = maxf(0.0, float(shot.get("age", 0.0)))
	var velocity: Vector2 = shot.get("vel", Vector2.RIGHT)
	return {"family": "missile" if kind == "seeker_missile" else "wave",
		"size": Vector2(52, 28) if kind == "seeker_missile" else Vector2(54, 58),
		"phase": fposmod(age / 0.6, 1.0) if kind == "seeker_missile" else clampf(age / 0.45, 0.0, 0.99),
		"angle": velocity.angle() if velocity.length_squared() > 0.001 else 0.0,
		"alpha": 1.0}

static func field_sample(field: Dictionary) -> Dictionary:
	var ttl: float = maxf(0.0, float(field.get("ttl", 0.0)))
	if str(field.get("kind", "")) != "frost_halo" or ttl <= 0.0: return {}
	var elapsed: float = maxf(0.0, float(field.get("duration", 1.5)) - ttl)
	var radius: float = clampf(float(field.get("radius", 105.0)), 105.0, 130.0)
	# A full eight-frame cycle per damage pulse: crystal arcs gather, then crack.
	return {"family": "aura", "size": Vector2.ONE * radius * 2.0,
		"phase": fposmod(elapsed / 0.5, 1.0), "angle": 0.0, "alpha": 0.76}

static func shield_sample(player: Dictionary) -> Dictionary:
	var ttl: float = float(player.get("reactive_shield_timer", 0.0))
	if bool(player.get("dead", false)) or ttl <= 0.0 or float(player.get("reactive_shield", 0.0)) <= 0.0: return {}
	return {"family": "aura", "size": Vector2(68, 68),
		"phase": fposmod(maxf(0.0, 3.0 - ttl) / 0.8, 1.0), "angle": 0.0,
		"alpha": 0.6 if ttl > 0.5 else 0.35 + ttl * 0.5}

static func activation(event: Dictionary) -> Dictionary:
	var source: String = str(event.get("kind", ""))
	if str(event.get("type", "")) != "proc" or source not in SOURCES: return {}
	var size: float = 48.0 if source in ["missile_pod", "pursuit_protocol"] else 76.0
	return {"kind": "proc_activation", "family": "charge", "source": source,
		"pos": event.get("pos", Vector2.ZERO), "size": Vector2.ONE * size,
		"age": 0.0, "life": 0.3, "color": Color.WHITE}

static func activation_sample(effect: Dictionary) -> Dictionary:
	var phase: float = float(effect.get("age", 0.0)) / maxf(0.01, float(effect.get("life", 0.3)))
	if phase >= 1.0: return {}
	return {"family": "charge", "size": effect.get("size", Vector2(48, 48)),
		"phase": clampf(phase, 0.0, 1.0), "angle": 0.0, "alpha": 0.85 * (1.0 - phase)}

static func draw(canvas: CanvasItem, sample: Dictionary, origin: Vector2, fx_scale: float = 1.0) -> bool:
	if sample.is_empty(): return false
	var opacity: float = float(sample.alpha) * clampf(fx_scale, 0.75, 1.0)
	return IllustratedFX.proc(canvas,str(sample.family),origin,sample.size,float(sample.angle),float(sample.phase),opacity)
