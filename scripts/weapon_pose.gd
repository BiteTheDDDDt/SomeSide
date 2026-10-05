class_name SideWeaponPose
extends RefCounted

## Shared by authority, local prediction and rendering. Cosmetic body motion
## must never shift the aim pivot or the ballistic muzzle.
const AIM_DEADZONE: float = 4.0
const MeleeMotion = preload("res://scripts/melee_motion.gd")

static func melee_duration(interval: float) -> float:
	return MeleeMotion.duration(interval)

static func melee_impact_time(duration: float) -> float:
	return MeleeMotion.impact_time(duration)

static func melee_swing_time(duration: float) -> float:
	return duration * MeleeMotion.WINDUP_END

static func normalized_aim(aim: Vector2) -> Vector2:
	if not aim.is_finite():
		return Vector2.RIGHT
	var extent: float = maxf(absf(aim.x), absf(aim.y))
	if extent < 0.00001:
		return Vector2.RIGHT
	return (aim / extent).normalized()

static func shoulder_position(position: Vector2) -> Vector2:
	return position + Vector2(0.0, -5.0)

static func muzzle_length(weapon: String) -> float:
	match weapon:
		"scattergun": return 38.0
		"railgun": return 52.0
		"flamethrower": return 46.0
		"boomerang": return 36.0
		"storm_staff": return 48.0
		"sun_lance": return 58.0
		"arc_blade": return 47.0
		_: return 36.0

static func muzzle_position(player: Dictionary, aim_override: Vector2 = Vector2.ZERO) -> Vector2:
	var direction: Vector2 = aim_override if aim_override != Vector2.ZERO else Vector2(player.get("aim", Vector2.RIGHT))
	return shoulder_position(Vector2(player.get("pos", Vector2.ZERO))) + normalized_aim(direction) * muzzle_length(str(player.get("weapon", "pulse_rifle")))

static func aim_at(player: Dictionary, target: Vector2) -> Vector2:
	var offset: Vector2 = target - shoulder_position(Vector2(player.get("pos", Vector2.ZERO)))
	if not offset.is_finite() or offset.length_squared() <= AIM_DEADZONE * AIM_DEADZONE:
		return normalized_aim(Vector2(player.get("aim", Vector2.RIGHT)))
	return normalized_aim(offset)
