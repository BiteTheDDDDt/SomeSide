class_name SideProjectileGuidance
extends RefCounted

## One launch-time acquisition, then bounded steering towards that ID only.
## The small serializable guidance dictionary travels with authority snapshots.
const STORM: Dictionary = {"range": 520.0, "cone": 20.0, "delay": 0.0, "duration": 0.65, "rate": 80.0, "turn": 22.0}
const CONDUCTOR: Dictionary = {"range": 620.0, "cone": 16.0, "delay": 0.22, "duration": 0.65, "rate": 24.0, "turn": 12.0}

static func lock(position: Vector2, velocity: Vector2, candidates: Array, preset: Dictionary) -> Dictionary:
	if not position.is_finite() or not velocity.is_finite() or velocity.length_squared() < 0.0001:
		return {}
	var selected: int = -1
	var nearest: float = pow(float(preset.range), 2.0)
	var direction: Vector2 = velocity.normalized()
	var minimum_dot: float = cos(deg_to_rad(float(preset.cone)))
	for candidate: Dictionary in candidates:
		if not _living(candidate):
			continue
		var offset: Vector2 = Vector2(candidate.pos) - position
		var distance: float = offset.length_squared()
		if distance < 0.0001 or distance >= nearest or offset.normalized().dot(direction) < minimum_dot:
			continue
		selected = int(candidate.id)
		nearest = distance
	if selected < 0:
		return {}
	return {"target_id": selected, "delay": float(preset.delay), "remaining": float(preset.duration),
		"turn_rate": deg_to_rad(float(preset.rate)), "turn_left": deg_to_rad(float(preset.turn)),
		"range": float(preset.range), "active": true}

static func steer(projectile: Dictionary, target: Dictionary, delta: float) -> Vector2:
	var velocity: Vector2 = projectile.get("vel", Vector2.ZERO)
	var guidance: Dictionary = projectile.get("guidance", {})
	if guidance.is_empty() or not bool(guidance.get("active", false)) or delta <= 0.0:
		return velocity
	var position: Vector2 = projectile.get("pos", Vector2.ZERO)
	if not velocity.is_finite() or not position.is_finite() or velocity.length_squared() < 0.0001:
		_stop(guidance)
		return velocity if velocity.is_finite() else Vector2.ZERO
	if not _living(target) or int(target.get("id", -1)) != int(guidance.target_id):
		_stop(guidance)
		return velocity
	var offset: Vector2 = Vector2(target.pos) - position
	# A dodged projectile never turns around or searches for a second victim.
	if offset.dot(velocity) <= 0.0 or offset.length_squared() > pow(float(guidance.range), 2.0):
		_stop(guidance)
		return velocity
	var waiting: float = float(guidance.delay)
	guidance.delay = maxf(0.0, waiting - delta)
	var steering_dt: float = minf(maxf(0.0, delta - waiting), float(guidance.remaining))
	if steering_dt <= 0.0:
		return velocity
	guidance.remaining = maxf(0.0, float(guidance.remaining) - steering_dt)
	var allowance: float = minf(float(guidance.turn_left), float(guidance.turn_rate) * steering_dt)
	var turn: float = clampf(velocity.angle_to(offset), -allowance, allowance)
	velocity = velocity.rotated(turn)
	guidance.turn_left = maxf(0.0, float(guidance.turn_left) - absf(turn))
	if float(guidance.remaining) <= 0.000001 or float(guidance.turn_left) <= 0.000001:
		_stop(guidance)
	return velocity

static func _living(candidate: Dictionary) -> bool:
	return not candidate.is_empty() and candidate.has("pos") and Vector2(candidate.pos).is_finite() and not bool(candidate.get("dead", false)) and float(candidate.get("hp", 1.0)) > 0.0

static func _stop(guidance: Dictionary) -> void:
	guidance.active = false
	guidance.target_id = -1
