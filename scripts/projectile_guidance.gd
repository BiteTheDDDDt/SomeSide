class_name SideProjectileGuidance
extends RefCounted

## One launch-time acquisition, then bounded steering towards that ID only.
## The small serializable guidance dictionary travels with authority snapshots.
const STORM: Dictionary = {"range": 520.0, "cone": 20.0, "delay": 0.0, "duration": 0.65, "rate": 80.0, "turn": 22.0}
const CONDUCTOR: Dictionary = {"range": 620.0, "cone": 16.0, "delay": 0.22, "duration": 0.65, "rate": 24.0, "turn": 12.0}
const NEEDLE: Dictionary = {"mode":"weak", "order":"angle", "range":520.0, "cone":12.0, "delay":0.0, "duration":0.20, "rate":60.0, "turn":12.0}
const SEEKER: Dictionary = {"mode":"persistent", "order":"angle", "range":650.0, "cone":35.0, "delay":0.10, "duration":2.8, "rate":150.0, "turn":0.0}
const BLADE: Dictionary = {"mode":"finite", "order":"angle", "range":600.0, "cone":40.0, "delay":0.0, "duration":0.65, "rate":180.0, "turn":85.0}
const BEACON: Dictionary = {"mode":"finite", "order":"distance", "range":500.0, "cone":180.0, "delay":0.06, "duration":0.75, "rate":140.0, "turn":70.0}
const MOTH: Dictionary = {"mode":"persistent", "order":"angle", "range":620.0, "cone":30.0, "delay":0.22, "duration":3.0, "rate":100.0, "turn":0.0}

static func lock(position: Vector2, velocity: Vector2, candidates: Array, preset: Dictionary) -> Dictionary:
	if not position.is_finite() or not velocity.is_finite() or velocity.length_squared() < 0.0001:
		return {}
	var selected: int = -1
	var nearest: float = pow(float(preset.range), 2.0)
	var direction: Vector2 = velocity.normalized()
	var minimum_dot: float = cos(deg_to_rad(float(preset.cone)))
	var ordered: bool = preset.has("mode")
	var best_angle: float = INF
	for candidate: Dictionary in candidates:
		if not _living(candidate):
			continue
		if ordered and not bool(candidate.get("hittable",true)): continue
		var offset: Vector2 = Vector2(candidate.pos) - position
		var distance: float = offset.length_squared()
		var angle: float = absf(direction.angle_to(offset))
		if distance < 0.0001 or distance > pow(float(preset.range), 2.0) or offset.normalized().dot(direction) < minimum_dot:
			continue
		if ordered:
			var angle_first: bool = str(preset.get("order","angle")) == "angle"
			if selected >= 0:
				if angle_first and angle > best_angle + .000001: continue
				if (not angle_first or absf(angle-best_angle)<.000001) and (distance > nearest + .000001 or (absf(distance-nearest)<.000001 and int(candidate.id)>selected)): continue
		else:
			if distance >= nearest: continue
		selected = int(candidate.id)
		nearest = distance
		best_angle = angle
	if selected < 0:
		return {}
	var result: Dictionary = {"target_id": selected, "delay": float(preset.delay), "remaining": float(preset.duration),
		"turn_rate": deg_to_rad(float(preset.rate)), "turn_left": deg_to_rad(float(preset.turn)),
		"range": float(preset.range), "active": true}
	if ordered: result["mode"] = str(preset.mode)
	return result

static func steer(projectile: Dictionary, target: Dictionary, delta: float) -> Vector2:
	var velocity: Vector2 = projectile.get("vel", Vector2.ZERO)
	var guidance: Dictionary = projectile.get("guidance", {})
	if guidance.is_empty() or not bool(guidance.get("active", false)) or delta <= 0.0:
		return velocity
	var position: Vector2 = projectile.get("pos", Vector2.ZERO)
	if not velocity.is_finite() or not position.is_finite() or velocity.length_squared() < 0.0001:
		_stop(guidance)
		return velocity if velocity.is_finite() else Vector2.ZERO
	if not _living(target) or int(target.get("id", -1)) != int(guidance.target_id) or (guidance.has("mode") and not bool(target.get("hittable",true))):
		_stop(guidance)
		return velocity
	var offset: Vector2 = Vector2(target.pos) - position
	var persistent: bool = str(guidance.get("mode","legacy")) == "persistent"
	if guidance.has("mode") and projectile.has("ttl") and float(projectile.ttl)<=0.0:
		_stop(guidance)
		return velocity
	# A dodged projectile never turns around or searches for a second victim.
	if not persistent and (offset.dot(velocity) <= 0.0 or (not guidance.has("mode") and offset.length_squared() > pow(float(guidance.range), 2.0))):
		_stop(guidance)
		return velocity
	var waiting: float = float(guidance.delay)
	guidance.delay = maxf(0.0, waiting - delta)
	var steering_dt: float = maxf(0.0, delta-waiting) if persistent else minf(maxf(0.0, delta - waiting), float(guidance.remaining))
	if steering_dt <= 0.0:
		return velocity
	if not persistent: guidance.remaining = maxf(0.0, float(guidance.remaining) - steering_dt)
	var allowance: float = float(guidance.turn_rate)*steering_dt if persistent else minf(float(guidance.turn_left), float(guidance.turn_rate) * steering_dt)
	var turn: float = clampf(velocity.angle_to(offset), -allowance, allowance)
	velocity = velocity.rotated(turn)
	if not persistent: guidance.turn_left = maxf(0.0, float(guidance.turn_left) - absf(turn))
	if not persistent and (float(guidance.remaining) <= 0.000001 or float(guidance.turn_left) <= 0.000001):
		_stop(guidance)
	return velocity

static func _living(candidate: Dictionary) -> bool:
	return not candidate.is_empty() and candidate.has("pos") and Vector2(candidate.pos).is_finite() and not bool(candidate.get("dead", false)) and float(candidate.get("hp", 1.0)) > 0.0

static func _stop(guidance: Dictionary) -> void:
	guidance.active = false
	guidance.target_id = -1
