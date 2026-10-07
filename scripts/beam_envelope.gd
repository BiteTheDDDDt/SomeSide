class_name SideBeamEnvelope
extends RefCounted

## Shared by authority and presentation: extension and contraction never hide
## a larger live collision shape. No scene or drawing dependencies.
const LIFETIME: float = .55

static func sample(ttl: float) -> Vector2:
	var age: float = clampf(LIFETIME-ttl,0.0,LIFETIME)
	if ttl<=0.0: return Vector2.ZERO
	var reach: float = smoothstep(0.0,.045,age)
	var width: float = smoothstep(0.0,.035,age)*(1.0-smoothstep(.34,LIFETIME,age))
	return Vector2(reach,width)
