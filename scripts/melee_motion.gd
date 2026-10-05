class_name SideMeleeMotion
extends RefCounted

## Shared deterministic timeline. The drawing pose never owns damage or input.
const WINDUP_END: float = 0.22
const IMPACT: float = 0.40
const SWING_END: float = 0.58

static func duration(interval: float) -> float:
	return clampf(interval * 0.8 if is_finite(interval) else 0.36, 0.04, 0.36)

static func impact_time(length: float) -> float:
	return length * IMPACT

static func sample(elapsed: float, length: float, aim: Vector2) -> Dictionary:
	if not is_finite(elapsed) or not is_finite(length) or length <= 0.0 or elapsed < 0.0 or elapsed >= length:
		return {"active": false}
	var direction: Vector2 = aim.normalized() if aim.is_finite() and aim.length_squared() > 0.0001 else Vector2.RIGHT
	var facing: float = 1.0 if direction.x >= 0.0 else -1.0
	var t: float = clampf(elapsed / length, 0.0, 1.0)
	var angle: float
	var lean: float
	var extension: float
	var phase: String
	if t < WINDUP_END:
		var p: float = smoothstep(0.0, WINDUP_END, t)
		angle = lerpf(0.0, -1.70, p)
		lean = lerpf(0.0, -0.12, p)
		extension = lerpf(0.0, 2.0, p)
		phase = "windup"
	elif t < SWING_END:
		var p: float = (t - WINDUP_END) / (SWING_END - WINDUP_END)
		angle = lerpf(-1.70, 1.70, p)
		lean = lerpf(-0.12, 0.16, smoothstep(0.0, 1.0, p))
		extension = 2.0 + sin(p * PI) * 11.0
		phase = "swing"
	else:
		var p: float = smoothstep(SWING_END, 1.0, t)
		angle = lerpf(1.70, 0.0, p)
		lean = lerpf(0.16, 0.0, p)
		extension = lerpf(2.0, 0.0, p)
		phase = "recover"
	var blade_angle: float = direction.angle() + angle * facing
	return {"active": true, "phase": phase, "progress": t, "elapsed": elapsed, "duration": length,
		"aim": direction, "facing": facing, "angle": blade_angle, "body_angle": lean,
		"extension": extension, "weapon_scale":1.0+0.25*sin(PI*t),
		"arm_alpha":smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.86,1.0,t)),
		"trail": phase == "swing", "impact": t + 0.000001 >= IMPACT}
