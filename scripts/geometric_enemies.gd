class_name SideGeometricEnemies
extends RefCounted

## Small articulated silhouettes, drawn inside WorldView's facing transform.
## Attack organs use CombatGeometry's fixed authoritative emission anchors.
const Geometry = preload("res://scripts/combat_geometry.gd")
const Attack = preload("res://scripts/enemy_attack_visual.gd")

static func supports(kind: String) -> bool:
	return kind in ["sentinel","crawler","spitter"]

static func bounds(enemy: Dictionary) -> Rect2:
	if str(enemy.get("kind","")) == "sentinel": return Rect2(-38,-35,76,70)
	if str(enemy.get("kind","")) == "spitter": return Rect2(-32,-34,68,69)
	return Rect2(-35,-27,68,47)

static func draw(c: CanvasItem, enemy: Dictionary, clock: float) -> bool:
	if not supports(str(enemy.get("kind", ""))): return false
	var pose: Dictionary = Attack.attack_sample(enemy)
	var colors: Dictionary = Geometry.palette(Geometry.family(enemy))
	if float(enemy.get("flash", 0.0)) > 0.0:
		colors.base = Color(colors.base).lightened(.25)
		colors.light = Color(colors.light).lightened(.15)
	match str(enemy.kind):
		"sentinel": _sentinel(c, enemy, pose, colors, clock)
		"crawler": _crawler(c, enemy, pose, colors, clock)
		"spitter": _spitter(c, enemy, pose, colors, clock)
	return true

static func _poly(c: CanvasItem, points: Array, color: Color, edge: float = Geometry.BODY) -> void:
	Geometry.polygon(c,PackedVector2Array(points),color,edge)

static func _limb(c: CanvasItem, points: Array, color: Color, width: float) -> void:
	c.draw_polyline(PackedVector2Array(points),Geometry.INK,width+2.0,true)
	c.draw_polyline(PackedVector2Array(points),color,width,true)

static func _sentinel(c: CanvasItem, enemy: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var amount: float = float(pose.amount)
	var moving: float = clampf(absf(Vector2(enemy.get("vel",Vector2.ZERO)).x)/55.0,0,1)
	var step: float = sin(clock*8.0+float(enemy.get("id",0)))*2.0*moving
	_limb(c,[Vector2(-20,4),Vector2(-26,10),Vector2(-29+step,17),Vector2(-21+step,17)],colors.shade,4)
	_limb(c,[Vector2(-10,4),Vector2(-9,10),Vector2(-5-step,17),Vector2(1-step,17)],colors.base,4)
	_poly(c,[Vector2(-29,1),Vector2(-23,-9),Vector2(-11,-7),Vector2(-5,4),Vector2(-13,9),Vector2(-24,8)],colors.base)
	_poly(c,[Vector2(-28,0),Vector2(-23,-7),Vector2(-12,-5),Vector2(-17,2)],colors.light,0)
	# The muzzle stays at local zero through recoil; the rear housing telescopes
	# behind it. Rotation therefore cannot detach the shot or re-aim its path.
	var aim: Vector2 = Geometry.local_direction(enemy)
	var side: Vector2 = aim.orthogonal()
	var rear: float = 28.0+amount*3.0
	var shell := PackedVector2Array([Vector2(-rear, -3),Vector2(-rear+7,-13),Vector2(-10,-12),Vector2(-2,-6),Vector2(-2,6),Vector2(-15,8),Vector2(-rear,5)])
	for i: int in range(shell.size()): shell[i] = aim*shell[i].x+side*shell[i].y
	Geometry.polygon(c,shell,colors.base)
	Geometry.polygon(c,PackedVector2Array([-aim*(rear-6)-side*10,-aim*12-side*10,-aim*5-side*5,-aim*(rear-4)-side*3]),colors.light,0)
	Geometry.diamond(c,-aim*21-side*16,aim,6,8,colors.shade,1.5)
	Geometry.diamond(c,-aim*21-side*16,aim,3,5,colors.light)
	Geometry.polygon(c,PackedVector2Array([-aim*7-side*7,-side*5,side*5,-aim*7+side*7]),Geometry.INK,0)
	c.draw_line(-side*4,side*4,colors.attack,2.2,true)
	Geometry.diamond(c,-aim*12,aim,4,2.7,colors.attack)

static func _crawler(c: CanvasItem, enemy: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var charged: bool = float(enemy.get("charge_timer",0.0)) > 0.0
	var amount: float = maxf(0.0,float(pose.amount)) if not charged else 0.0
	var offset := Vector2(-amount*3.0,amount*4.0)
	var moving: float = clampf(absf(Vector2(enemy.get("vel",Vector2.ZERO)).x)/116.0,0,1)
	var gait: float = sin(clock*10.0+float(enemy.get("id",0)))*3.0*moving if not charged else 0.0
	# Two far and two near limbs. Strong folded rear haunch, small front paw.
	_limb(c,[Vector2(-14,1)+offset,Vector2(-5,8),Vector2(-15-gait,16)],colors.shade,4)
	_limb(c,[Vector2(11,1)+offset,Vector2(6,10),Vector2(17+gait,16)],colors.shade,3)
	_poly(c,[Vector2(-25,2)+offset,Vector2(-20,-10)+offset,Vector2(-10,-15)+offset,Vector2(9,-9)+offset,Vector2(18,0)+offset,Vector2(6,7)+offset,Vector2(-14,8)+offset],colors.base)
	_poly(c,[Vector2(-22,-3)+offset,Vector2(-11,-12)+offset,Vector2(7,-7)+offset,Vector2(-1,-1)+offset],colors.light,0)
	for index: int in range(3):
		var point: Vector2 = Vector2(-18+index*10,-9+index)+offset
		_poly(c,[point,point+Vector2(-5,-11+index*2),point+Vector2(8,0)],colors.light)
	# The heavy thigh is a single broad plane, not fur/scale detail.
	_poly(c,[Vector2(-20,-8)+offset,Vector2(-8,-6)+offset,Vector2(-3,4)+offset,Vector2(-15,11),Vector2(-23,5)],colors.base)
	_poly(c,[Vector2(-20,-7)+offset,Vector2(-11,-5)+offset,Vector2(-16,5)],colors.light,0)
	_limb(c,[Vector2(-16,8),Vector2(-26,10+amount),Vector2(-30+gait,17),Vector2(-21+gait,17)],colors.base,3.5)
	var paw := Vector2(24-gait,17)
	if charged: paw = Vector2(25,8)
	_limb(c,[Vector2(8,2)+offset,Vector2(15,9)+offset,paw],colors.base,3.8)
	_poly(c,[Vector2(8,-9)+offset,Vector2(19,-10)+offset,Vector2(28,-2)+offset,Vector2(24,7)+offset,Vector2(14,6)+offset,Vector2(7,0)+offset],colors.shade)
	_poly(c,[Vector2(10,-8)+offset,Vector2(19,-8)+offset,Vector2(25,-3)+offset,Vector2(14,-3)+offset],colors.base,0)
	Geometry.diamond(c,Vector2(20,-3)+offset,Vector2.RIGHT,2,1.2,colors.attack)
	_poly(c,[Vector2(21,4)+offset,Vector2(26,3)+offset,Vector2(25,7)+offset],colors.light,0)
	for index: int in range(2):
		var tip: Vector2 = paw+Vector2(index*2-1,0)
		_poly(c,[tip-Vector2(2,2),tip+Vector2(3,-1),tip+Vector2(1,1)],colors.light,0)
		if charged:
			# A short open claw ribbon hugs the moving paw. It is not an area
			# warning, and never advertises a reach beyond body-contact damage.
			c.draw_arc(paw+Vector2(-3,-3-index*3),5.0,.15,1.35,7,colors.attack,1.7,true)

static func _spitter(c: CanvasItem, enemy: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var amount: float = float(pose.amount)
	var moving: float = clampf(absf(Vector2(enemy.get("vel",Vector2.ZERO)).x)/78.0,0,1)
	var step: float = sin(clock*9.0+float(enemy.get("id",0)))*2.5*moving
	_limb(c,[Vector2(-12,3),Vector2(-8,11),Vector2(-14-step,17)],colors.shade,3)
	_limb(c,[Vector2(4,4),Vector2(10,10),Vector2(9+step,17)],colors.shade,3)
	var center := Vector2(-8,-1)
	var radius: float = 15.0+maxf(0.0,amount)*1.8
	var belly := PackedVector2Array()
	for index: int in range(10): belly.append(center+Vector2.from_angle(index*TAU/10.0)*radius)
	Geometry.polygon(c,belly,colors.base)
	_poly(c,[center+Vector2(-12,-4),center+Vector2(-7,-12),center+Vector2(2,-13),center+Vector2(8,-7),center+Vector2(1,0)],colors.light,0)
	for spot: Vector2 in [Vector2(-13,2),Vector2(-5,6)]: c.draw_circle(spot,3.0,colors.light,true,-1,true)
	for x: float in [-19.0,-9.0]: _poly(c,[Vector2(x,-12),Vector2(x-4,-22),Vector2(x+7,-14)],colors.shade)
	_limb(c,[Vector2(-18,6),Vector2(-24,11),Vector2(-27+step,17),Vector2(-20+step,17)],colors.base,3)
	_limb(c,[Vector2(3,6),Vector2(13,10),Vector2(18-step,17),Vector2(24-step,17)],colors.base,3)
	var aim: Vector2 = Geometry.local_direction(enemy)
	var side: Vector2 = aim.orthogonal()
	var mouth: Vector2 = Geometry.source_offset(enemy,aim)
	# The body contracts behind the anchored mouth, never drags the mouth away
	# from the position actually used by Simulation._enemy_shoot.
	var neck: Vector2 = mouth-aim*(13.0+amount*2.0)
	Geometry.polygon(c,Geometry2D.convex_hull(PackedVector2Array([Vector2(-1,-9),neck-side*7,mouth-aim*7-side*4,mouth-aim*7+side*4,neck+side*6,Vector2(0,6)])),colors.shade)
	Geometry.polygon(c,Geometry2D.convex_hull(PackedVector2Array([Vector2(0,-8),neck-side*6,mouth-aim*8-side*3,neck-side])),colors.base,0)
	_poly(c,[mouth-aim*9-side*5,mouth-side*4,mouth+side*4,mouth-aim*9+side*5],colors.base)
	c.draw_line(mouth-side*3.4,mouth+side*3.4,Geometry.INK,3.0,true)
	c.draw_line(mouth-side*2,mouth+side*2,colors.attack,1.5,true)
	Geometry.diamond(c,neck-side*4,aim,2.2,1.1,colors.light)
