class_name SideWeaponActionMotion
extends RefCounted

## Presentation only. Ranged fire still happens immediately in Simulation;
## these profiles describe follow-through and recovery in local weapon space.
const Clips=preload("res://scripts/motion_clips_24.gd")
const WEAPONS: Array[String] = ["pulse_rifle", "scattergun", "railgun", "flamethrower", "boomerang", "storm_staff", "sun_lance", "arc_needle", "star_seeker"]
const CAPS: Dictionary = {"pulse_rifle":0.17, "scattergun":0.52, "railgun":0.64,
	"flamethrower":0.14, "boomerang":0.55, "storm_staff":0.42, "sun_lance":0.56, "arc_needle":.16, "star_seeker":.55}

static func duration(weapon: String, interval: float) -> float:
	if not CAPS.has(weapon):
		return 0.0
	var safe_interval: float = maxf(0.025, interval) if is_finite(interval) else 0.19
	return maxf(0.02, minf(safe_interval * 0.9, float(CAPS[weapon])))

static func rest() -> Dictionary:
	return {"active":false, "phase":"ready", "offset":Vector2.ZERO, "angle_offset":0.0,
		"body_angle":0.0, "grip_distance":7.0, "mechanism":0.0, "energy":0.0, "weapon_alpha":1.0,"body_shift":Vector2.ZERO,"elbow_follow":0.0}

static func _pulse(t: float, peak: float, end: float) -> float:
	if t < 0.0 or t >= end:
		return 0.0
	if t < peak:
		return sin(t / peak * PI * 0.5)
	return 1.0 - smoothstep(peak, end, t)

static func sample(weapon: String, elapsed: float, length: float) -> Dictionary:
	if not CAPS.has(weapon) or not is_finite(elapsed) or not is_finite(length) or length<=0 or elapsed<0 or elapsed>=length: return rest()
	var result: Dictionary=Clips.sample("weapon/"+weapon,elapsed/length,func(t: float): return _pose(weapon,t))
	result.phase=_pose(weapon,elapsed/length).phase
	result.active=true
	return result

static func _pose(weapon: String,progress: float) -> Dictionary:
	var elapsed: float=progress
	var length: float=1.0
	var pose: Dictionary = rest()
	if not CAPS.has(weapon) or not is_finite(elapsed) or not is_finite(length) or length <= 0.0 or elapsed < 0.0 or elapsed >= length:
		return pose
	var t: float = elapsed / length
	pose.active = true
	pose.phase = "recover"
	match weapon:
		"arc_needle", "star_seeker":
			var heavy: bool=weapon=="star_seeker"
			var kick: float=_pulse(t,.08,.82 if heavy else .70)
			pose.offset=Vector2((-8.0 if heavy else -3.5)*kick,0)
			pose.angle_offset=(-.12 if heavy else -.035)*kick
			pose.body_angle=(-.065 if heavy else -.025)*kick
			pose.energy=_pulse(t,.15,1.0)
			pose.phase="recoil" if t<.25 else "recover"
		"pulse_rifle":
			var kick: float = _pulse(t, 0.07, 1.0)
			pose.offset = Vector2(-5.5 * kick, 0.4 * kick)
			pose.angle_offset = -0.095 * kick
			pose.body_angle = -0.045 * kick
			pose.mechanism = _pulse(t, 0.13, 0.60)
			pose.phase = "recoil" if t < 0.22 else "recover"
		"scattergun":
			var kick: float = _pulse(t, 0.07, 0.47)
			var pump: float = sin(PI * clampf((t - 0.26) / 0.67, 0.0, 1.0))
			pose.offset = Vector2(-10.5 * kick - 2.0 * pump, 2.0 * pump)
			pose.angle_offset = -0.20 * kick + 0.12 * pump
			pose.body_angle = -0.085 * kick
			pose.grip_distance = 7.0 - 2.0 * pump
			pose.mechanism = pump
			pose.phase = "recoil" if t < 0.26 else ("cycle" if t < 0.90 else "recover")
		"railgun":
			var kick: float = _pulse(t, 0.045, 0.76)
			var vent: float = _pulse(t, 0.18, 1.0)
			pose.offset = Vector2(-13.0 * kick, -0.8 * vent)
			pose.angle_offset = -0.12 * kick
			pose.body_angle = -0.11 * kick
			pose.mechanism = vent
			pose.energy = vent
			pose.phase = "recoil" if t < 0.18 else "vent"
		"flamethrower":
			var envelope: float = sin(PI * t)
			pose.offset = Vector2(-2.4 * envelope, sin(TAU * 2.0 * t) * 0.6 * envelope)
			pose.angle_offset = (0.025 + sin(TAU * 2.0 * t) * 0.016) * envelope
			pose.body_angle = 0.035 * envelope
			pose.mechanism = envelope
			pose.energy = envelope
			pose.phase = "brace"
		"boomerang":
			var flick: float = _pulse(t, 0.15, 0.68)
			pose.offset = Vector2(13.0 * flick, -3.5 * flick)
			pose.angle_offset = -0.80 * flick + sin(PI * t) * 0.16
			pose.body_angle = 0.095 * flick
			pose.grip_distance = 7.0 + 3.0 * flick
			pose.weapon_alpha = 1.0 - smoothstep(0.02, 0.14, t) + smoothstep(0.50, 0.83, t)
			pose.phase = "release" if t < 0.50 else "catch"
		"storm_staff":
			var cast: float = _pulse(t, 0.20, 1.0)
			pose.offset = Vector2(-3.0 * cast, -6.0 * cast)
			pose.angle_offset = -0.55 * cast
			pose.body_angle = -0.055 * cast
			pose.grip_distance = 7.0 + cast
			pose.mechanism = cast
			pose.energy = cast
			pose.phase = "channel" if t < 0.60 else "recover"
		"sun_lance":
			var thrust: float = _pulse(t, 0.13, 0.82)
			var recoil: float = _pulse(maxf(0.0, t - 0.44), 0.16, 0.56)
			pose.offset = Vector2(14.0 * thrust - 2.0 * recoil, -1.5 * thrust)
			pose.angle_offset = -0.07 * thrust + 0.055 * recoil
			pose.body_angle = 0.115 * thrust
			pose.grip_distance = 7.0 + 2.0 * thrust
			pose.energy = thrust
			pose.phase = "thrust" if t < 0.44 else "recover"
	# Shoulder reaction and elbow lag derive from the existing kick/cycle;
	# repeated firing replaces the pose instead of adding another impulse.
	var reaction: float = clampf(float(pose.offset.x),-13,14)
	pose["body_shift"] = Vector2(reaction*.12,absf(float(pose.body_angle))*2)
	pose["elbow_follow"] = clampf(-reaction*.11+float(pose.mechanism)*.7,-1.4,1.8)
	return pose
