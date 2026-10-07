class_name SideGeometricEnemies
extends RefCounted

## Small articulated silhouettes, drawn inside WorldView's facing transform.
## Attack organs use CombatGeometry's fixed authoritative emission anchors.
const Geometry = preload("res://scripts/combat_geometry.gd")
const Illustrated=preload("res://scripts/illustrated_enemy_renderer.gd")
const Attack = preload("res://scripts/enemy_attack_visual.gd")

static func supports(kind: String) -> bool:
	return kind in ["sentinel","crawler","spitter","spore_moth","drone","charger","burrower","skirmisher","conductor","boss"]

static func bounds(enemy: Dictionary) -> Rect2:
	var art_bounds: Rect2=Illustrated.bounds(enemy)
	if art_bounds.size!=Vector2.ZERO: return art_bounds
	match str(enemy.get("kind","")):
		"boss": return Rect2(-84,-90,168,152)
		"spore_moth","drone","conductor": return Rect2(-48,-48,96,90)
		"charger","burrower": return Rect2(-46,-38,92,62)
		"skirmisher": return Rect2(-36,-40,76,66)
		"sentinel": return Rect2(-38,-35,76,70)
		"spitter": return Rect2(-32,-34,68,69)
	return Rect2(-35,-27,68,47)

static func draw(c: CanvasItem, enemy: Dictionary, clock: float) -> bool:
	if Illustrated.draw(c,enemy,clock): return true
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
		"spore_moth": _moth(c,enemy,pose,colors,clock)
		"drone": _drone(c,enemy,pose,colors,clock)
		"charger","burrower": _stone(c,enemy,pose,colors,clock)
		"skirmisher": _hunter(c,enemy,pose,colors,clock)
		"conductor": _conductor(c,enemy,pose,colors,clock)
		"boss": _boss(c,enemy,pose,colors,clock)
	_details(c,enemy,pose,colors,clock)
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

# Shared construction primitives; each species retains its own proportions,
# locomotion and organ layout instead of rescaling one generic silhouette.
static func _pod(c: CanvasItem, center: Vector2, size: Vector2, colors: Dictionary) -> void:
	var points := PackedVector2Array()
	for i: int in range(10): points.append(center+Vector2.from_angle(i*TAU/10.0)*size)
	Geometry.polygon(c,points,colors.base)
	_poly(c,[center+Vector2(-size.x*.8,-size.y*.2),center+Vector2(-size.x*.3,-size.y*.85),center+Vector2(size.x*.5,-size.y*.6),center+Vector2(size.x*.15,0)],colors.light,0)

static func _ports(c: CanvasItem, enemy: Dictionary, colors: Dictionary, spread: bool = false) -> void:
	var aim: Vector2 = Geometry.local_direction(enemy)
	var count: int = 3 if spread else 1
	if str(enemy.get("attack_kind",""))=="spore_volley": count=7 if float(enemy.get("hp",100))<float(enemy.get("max_hp",100))*.45 else 5
	for i: int in range(count):
		var ray: Vector2=aim.rotated((i-(count-1)*.5)*(.21 if count>3 else .2))
		var tip: Vector2=Geometry.source_offset(enemy,ray)
		var side: Vector2=ray.orthogonal()
		if Geometry.family(enemy)!="spore": _limb(c,[Vector2(-4,0),tip-ray*8],colors.shade,4)
		_poly(c,[tip-ray*12-side*4,tip-side*3,tip+side*3,tip-ray*12+side*4],colors.shade)
		c.draw_line(tip-side*2.5,tip+side*2.5,colors.attack,2,true)

static func _moth(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var fold: float = float(pose.amount)*6
	var flap: float = sin(clock*7+float(e.get("id",0)))*5
	for side: float in [-1.0,1.0]:
		var root_point:=Vector2(side*3,-5)
		_poly(c,[root_point,Vector2(side*(33-fold),-32-flap),Vector2(side*41,-12),Vector2(side*22,9),Vector2(side*7,5)],colors.shade)
		_poly(c,[root_point,Vector2(side*(31-fold),-28-flap),Vector2(side*33,-13),Vector2(side*17,0)],colors.base,0)
	_pod(c,Vector2(0,4),Vector2(10,17+float(pose.amount)*2),colors)
	_pod(c,Vector2(5,-15),Vector2(8,6),colors)
	_limb(c,[Vector2(3,-18),Vector2(10,-27),Vector2(14,-28)],colors.light,1.5)
	# Downward ovipositor belongs to the destination-based mortar animation.
	_poly(c,[Vector2(-4,16),Vector2(0,24),Vector2(5,16)],colors.shade)
	c.draw_line(Vector2(-2,20),Vector2(2,20),colors.attack,2,true)
	if bool(pose.winding): Geometry.draw_ammunition(c,Vector2(0,23),Vector2.DOWN,3+float(pose.progress)*2,true,true,float(pose.progress))

static func _drone(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var fold: float = float(pose.amount)*4
	var wing: float=sin(clock*4+float(e.get("id",0)))*2
	for side: float in [-1.0,1.0]:
		_poly(c,[Vector2(-8,side*4),Vector2(-31,side*(25-fold)+wing),Vector2(-8,side*19),Vector2(10,side*5)],colors.base)
		_poly(c,[Vector2(-25,side*(21-fold)+wing),Vector2(-8,side*16),Vector2(4,side*6)],colors.light,0)
	Geometry.diamond(c,Vector2(-3,0),Vector2.RIGHT,19,10,colors.base,1.5)
	Geometry.diamond(c,Vector2(-5,-2),Vector2.RIGHT,8,4,colors.light)
	_ports(c,e,colors,true)

static func _stone(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var burrow: bool=str(e.kind)=="burrower"
	var charge: bool=float(e.get("charge_timer",0))>0
	var squat: float=maxf(0,float(pose.amount))*4+(7.0 if burrow else 0.0)
	var gait: float=sin(clock*9+float(e.get("id",0)))*3*clampf(absf(Vector2(e.get("vel",Vector2.ZERO)).x)/90,0,1)
	for side: float in [-1.0,1.0]:
		_limb(c,[Vector2(-19,3),Vector2(-26,10),Vector2(-29+side*gait,17)],colors.shade,5)
		_limb(c,[Vector2(12,1),Vector2(18,11),Vector2(23-side*gait,17)],colors.base,5)
	_poly(c,[Vector2(-33,4),Vector2(-26,-15+squat),Vector2(-11,-23+squat),Vector2(14,-19+squat),Vector2(25,-6+squat),Vector2(19,10),Vector2(-21,11)],colors.base)
	_poly(c,[Vector2(-26,-11+squat),Vector2(-11,-20+squat),Vector2(12,-17+squat),Vector2(3,-6+squat)],colors.light,0)
	for i: int in range(3):
		var x: float=-23+i*12
		if burrow:
			_poly(c,[Vector2(x-3,-13+squat),Vector2(x+2,-21+squat),Vector2(x+13,-17+squat),Vector2(x+10,-10+squat)],colors.shade)
		else:
			_poly(c,[Vector2(x,-13+squat),Vector2(x+3,-29+squat),Vector2(x+12,-12+squat)],colors.shade)
	if burrow:
		# A low shovel-jaw and broad foreclaws distinguish digging from ramming.
		_poly(c,[Vector2(13,-3),Vector2(37,5),Vector2(30,13),Vector2(14,9)],colors.light)
		for x: float in [17.0,24.0,31.0]: _poly(c,[Vector2(x,12),Vector2(x+5,18),Vector2(x-3,17)],colors.shade)
	else:
		_poly(c,[Vector2(14,-17+squat),Vector2(29,-12+squat),Vector2(32,5),Vector2(15,9)],colors.shade)
		_poly(c,[Vector2(22,-10+squat),Vector2(42,-13 if charge else -20),Vector2(30,0)],colors.light)
	Geometry.diamond(c,Vector2(24,-4+squat),Vector2.RIGHT,2.4,1.4,colors.attack)

static func _hunter(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var crouch: float=float(pose.amount)*3
	var step: float=sin(clock*10+float(e.get("id",0)))*4*clampf(absf(Vector2(e.get("vel",Vector2.ZERO)).x)/100,0,1)
	_limb(c,[Vector2(-7,2),Vector2(-13,10),Vector2(-19+step,17),Vector2(-11+step,17)],colors.shade,4)
	_limb(c,[Vector2(4,3),Vector2(12,10),Vector2(14-step,17),Vector2(21-step,17)],colors.base,4)
	_poly(c,[Vector2(-17,-22+crouch),Vector2(-5,-30+crouch),Vector2(9,-18+crouch),Vector2(10,4),Vector2(-12,7),Vector2(-25,1)],colors.base)
	_poly(c,[Vector2(-16,-21+crouch),Vector2(-6,-27+crouch),Vector2(5,-18+crouch),Vector2(-8,-9)],colors.light,0)
	_poly(c,[Vector2(-17,-16),Vector2(-31,5),Vector2(-17,0)],colors.shade)
	Geometry.diamond(c,Vector2(5,-18+crouch),Vector2.RIGHT,6,4,colors.shade,1.5)
	c.draw_line(Vector2(5,-20+crouch),Vector2(10,-19+crouch),colors.attack,2,true)
	_ports(c,e,colors,true)

static func _conductor(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var spread: float=3+float(pose.amount)*4
	var sway: float=sin(clock*3+float(e.get("id",0)))*2
	for side: float in [-1.0,1.0]:
		_limb(c,[Vector2(-8,side*5),Vector2(-20-spread,side*18+sway),Vector2(-6,side*28+sway)],colors.shade,4)
		Geometry.diamond(c,Vector2(-6,side*28+sway),Vector2.UP,7,4,colors.light,1.5)
	Geometry.diamond(c,Vector2(-7,0),Vector2.UP,24,14,colors.base,1.5)
	Geometry.diamond(c,Vector2(-9,-4),Vector2.UP,12,7,colors.light)
	Geometry.diamond(c,Vector2(-5,0),Vector2.UP,7,4,Color("9ac7ad"),1.5)
	_ports(c,e,colors)

static func _boss(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var style: String=str(e.get("boss_style","spore"))
	var amount: float=float(pose.amount)
	if style=="prism":
		# A floating armored custodian: head, mantle, articulated arms and
		# suspended lower plates surround a chest-mounted aperture at zero.
		for side: float in [-1.0,1.0]:
			var elbow:=Vector2(side*(37+amount*3),-4)
			_limb(c,[Vector2(side*22,-28),elbow,Vector2(side*27,17)],colors.shade,7)
			_poly(c,[Vector2(side*18,-40),Vector2(side*39,-53),Vector2(side*51,-23),Vector2(side*32,-14)],colors.base)
			_poly(c,[Vector2(side*23,-38),Vector2(side*38,-47),Vector2(side*43,-27),Vector2(side*33,-25)],colors.light,0)
			Geometry.diamond(c,elbow,Vector2.UP,7,6,colors.light,1)
			_poly(c,[Vector2(side*6,13),Vector2(side*25,17),Vector2(side*21,41),Vector2(side*10,53),Vector2(side*8,27)],colors.base)
			_poly(c,[Vector2(side*11,22),Vector2(side*21,20),Vector2(side*17,39),Vector2(side*12,43)],colors.light,0)
		_poly(c,[Vector2(-23,-34),Vector2(-10,-41),Vector2(13,-39),Vector2(25,-22),Vector2(17,14),Vector2(0,25),Vector2(-19,13)],colors.base)
		_poly(c,[Vector2(-20,-31),Vector2(-8,-36),Vector2(4,-29),Vector2(-1,-12),Vector2(-19,-5)],colors.light,0)
		_poly(c,[Vector2(5,-28),Vector2(20,-23),Vector2(14,12),Vector2(0,20),Vector2(-1,9)],colors.shade,0)
		_poly(c,[Vector2(-12,-41),Vector2(-10,-60),Vector2(0,-71),Vector2(13,-59),Vector2(16,-42),Vector2(2,-32)],colors.base)
		_poly(c,[Vector2(-8,-57),Vector2(0,-65),Vector2(8,-58),Vector2(4,-49),Vector2(-6,-48)],colors.light,0)
		_poly(c,[Vector2(-8,-46),Vector2(11,-49),Vector2(8,-39),Vector2(0,-36)],colors.shade)
		c.draw_line(Vector2(-4,-44),Vector2(8,-46),colors.attack,2,true)
		# Aperture nested in solid chest armor; no detached reticle or star.
		Geometry.diamond(c,Vector2.ZERO,Vector2.UP,13,15,Geometry.INK,1.5)
		Geometry.diamond(c,Vector2.ZERO,Vector2.UP,9,11,colors.light)
		Geometry.diamond(c,Vector2.ZERO,Vector2.RIGHT,6,5,colors.attack)
	elif style=="stone":
		# Interlocking rock masses, recessed head and grounded slab feet.
		for side: float in [-1.0,1.0]:
			var fist:=Vector2(side*(47+amount*3),3+amount*7)
			_limb(c,[Vector2(side*19,-2),Vector2(side*25,24),Vector2(side*30,40)],colors.shade,12)
			_poly(c,[Vector2(side*15,8),Vector2(side*29,8),Vector2(side*32,29),Vector2(side*22,35),Vector2(side*18,22)],colors.base)
			_poly(c,[Vector2(side*20,10),Vector2(side*27,11),Vector2(side*28,25),Vector2(side*23,28)],colors.light,0)
			_poly(c,[Vector2(side*22,35),Vector2(side*34,34),Vector2(side*42,44),Vector2(side*20,44)],colors.base)
			_limb(c,[Vector2(side*28,-36),Vector2(side*45,-20),fist],colors.shade,12)
			_poly(c,[Vector2(side*24,-42),Vector2(side*38,-49),Vector2(side*54,-31),Vector2(side*47,-17),Vector2(side*30,-22)],colors.base)
			_poly(c,[Vector2(side*28,-40),Vector2(side*38,-45),Vector2(side*48,-32),Vector2(side*39,-29)],colors.light,0)
			_poly(c,[fist+Vector2(-14,-11),fist+Vector2(5,-14),fist+Vector2(17,-3),fist+Vector2(13,11),fist+Vector2(2,15),fist+Vector2(-14,9)],colors.base)
			_poly(c,[fist+Vector2(-10,-9),fist+Vector2(4,-11),fist+Vector2(12,-3),fist+Vector2(-4,1)],colors.light,0)
			for finger: int in range(2): c.draw_line(fist+Vector2(-5+finger*7,5),fist+Vector2(-4+finger*7,11),colors.shade,1.5,true)
		_poly(c,[Vector2(-29,-44),Vector2(-16,-57),Vector2(11,-58),Vector2(30,-40),Vector2(24,-5),Vector2(12,7),Vector2(-20,4),Vector2(-30,-17)],colors.shade)
		_poly(c,[Vector2(-26,-40),Vector2(-14,-47),Vector2(-1,-35),Vector2(-4,-17),Vector2(-26,-22)],colors.base)
		_poly(c,[Vector2(3,-34),Vector2(16,-47),Vector2(27,-37),Vector2(22,-15),Vector2(6,-19)],colors.base)
		_poly(c,[Vector2(-23,-38),Vector2(-14,-44),Vector2(-5,-35),Vector2(-9,-29)],colors.light,0)
		_poly(c,[Vector2(6,-34),Vector2(16,-43),Vector2(23,-35),Vector2(17,-29)],colors.light,0)
		_poly(c,[Vector2(-20,-15),Vector2(-3,-11),Vector2(19,-14),Vector2(15,1),Vector2(-17,0)],colors.base)
		_poly(c,[Vector2(-10,-47),Vector2(-8,-65),Vector2(6,-71),Vector2(19,-60),Vector2(15,-44),Vector2(3,-36)],colors.base)
		_poly(c,[Vector2(-6,-62),Vector2(5,-67),Vector2(14,-59),Vector2(8,-54),Vector2(-7,-53)],colors.light,0)
		_poly(c,[Vector2(-7,-51),Vector2(14,-55),Vector2(10,-43),Vector2(0,-41)],colors.shade)
		c.draw_line(Vector2(-3,-49),Vector2(10,-51),colors.attack,2.4,true)
		c.draw_line(Vector2(-2,-20),Vector2(1,-14),colors.attack,1.4,true)
	else:
		# Armored brood body with hanging abdomen, asymmetric head and a
		# crown of attached sacs; jointed mandibles frame the volley organs.
		for side: float in [-1.0,1.0]:
			_limb(c,[Vector2(side*20,7),Vector2(side*36,24),Vector2(side*25,42)],colors.shade,5)
			_poly(c,[Vector2(side*31,18),Vector2(side*40,23),Vector2(side*30,40),Vector2(side*25,43)],colors.base)
		_pod(c,Vector2(-12,3),Vector2(34+amount*3,38+amount*2),colors)
		for i: int in range(4):
			var center:=Vector2(-29+i*17,-29-8*sin(i*PI/3.0))
			_pod(c,center,Vector2(8,12+(i%2)*3),colors)
			_poly(c,[center+Vector2(-7,-1),center+Vector2(1,2),center+Vector2(6,8),center+Vector2(-3,10)],colors.shade,0)
		_poly(c,[Vector2(-42,-8),Vector2(-27,-24),Vector2(-9,-18),Vector2(-15,-2),Vector2(-36,4)],colors.shade)
		_poly(c,[Vector2(-38,-9),Vector2(-27,-19),Vector2(-15,-15),Vector2(-24,-6)],colors.base,0)
		for i: int in range(3):
			var y: float=10+i*8
			_poly(c,[Vector2(-33+i*4,y-4),Vector2(-15,y),Vector2(4-i*2,y-3),Vector2(0,y+4),Vector2(-15,y+6)],colors.shade,0)
		_poly(c,[Vector2(-4,-23),Vector2(13,-29),Vector2(27,-17),Vector2(21,2),Vector2(6,9),Vector2(-6,-5)],colors.base)
		_poly(c,[Vector2(0,-21),Vector2(12,-25),Vector2(21,-16),Vector2(12,-12)],colors.light,0)
		Geometry.diamond(c,Vector2(17,-14),Vector2.RIGHT,4,2,Geometry.INK,1)
		Geometry.diamond(c,Vector2(18,-14),Vector2.RIGHT,2,1,colors.attack)
		_ports(c,e,colors,true)
		for side: float in [-1.0,1.0]:
			_poly(c,[Vector2(12,side*14),Vector2(29,side*22),Vector2(37,side*13),Vector2(24,side*15)],colors.shade)

static func _details(c: CanvasItem, e: Dictionary, pose: Dictionary, colors: Dictionary, clock: float) -> void:
	var aim: Vector2=Geometry.local_direction(e)
	var side: Vector2=aim.orthogonal()
	var amount: float=float(pose.amount)
	match str(e.kind):
		"sentinel":
			var rear: float=28+amount*3
			_poly(c,[-aim*(rear-4)-side*3,-aim*13-side*3,-aim*10+side*3,-aim*(rear-4)+side*3],colors.shade,0)
			c.draw_line(-aim*(rear-5)-side*4,-aim*12-side*4,colors.light,1.2,true)
			for i: int in range(2): c.draw_line(-aim*(15+i*4)+side*4,-aim*(17+i*4)+side*7,Geometry.INK,1.1,true)
			Geometry.diamond(c,-aim*8-side*7,aim,2,1.4,colors.attack)
			_poly(c,[Vector2(-24,3),Vector2(-16,2),Vector2(-12,7),Vector2(-23,8)],colors.shade,0)
		"crawler":
			var offset:=Vector2(-maxf(0,amount)*3,maxf(0,amount)*4) if float(e.get("charge_timer",0))<=0 else Vector2.ZERO
			_poly(c,[Vector2(13,-1)+offset,Vector2(25,0)+offset,Vector2(24,4)+offset,Vector2(15,3)+offset],Geometry.INK,0)
			for x: float in [18.0,23.0]: _poly(c,[Vector2(x,0)+offset,Vector2(x+2,0)+offset,Vector2(x+1,3)+offset],colors.light,0)
			c.draw_line(Vector2(-15,-3)+offset,Vector2(-8,2)+offset,colors.shade,1.2,true)
		"spitter":
			var mouth: Vector2=Geometry.source_offset(e,aim)
			var neck: Vector2=mouth-aim*(13+amount*2)
			Geometry.diamond(c,neck-side*5,aim,3.2,2.2,Geometry.INK)
			Geometry.diamond(c,neck-side*5+aim,aim,1.5,1.1,colors.attack)
			c.draw_line(mouth-aim*5-side*5,mouth-aim*5+side*5,colors.light,1.2,true)
			_poly(c,[Vector2(-19,2),Vector2(-10,8),Vector2(0,5),Vector2(-6,12),Vector2(-17,9)],colors.shade,0)
		"spore_moth":
			var flap: float=sin(clock*7+float(e.get("id",0)))*5
			for direction: float in [-1.0,1.0]:
				_poly(c,[Vector2(direction*8,-4),Vector2(direction*23,-10),Vector2(direction*30,-22-flap*.3),Vector2(direction*17,-12)],colors.light,0)
				c.draw_line(Vector2(direction*6,-5),Vector2(direction*29,-17-flap*.4),colors.shade,1.2,true)
				_poly(c,[Vector2(direction*5,6),Vector2(direction*21,4),Vector2(direction*15,16),Vector2(direction*6,12)],colors.shade)
			Geometry.diamond(c,Vector2(9,-16),Vector2.RIGHT,2.7,1.7,Geometry.INK)
			c.draw_circle(Vector2(10,-16),1,colors.attack)
			for y: float in [7.0,13.0]: c.draw_line(Vector2(-4,y),Vector2(4,y+1),colors.shade,1,true)
		"drone":
			_poly(c,[Vector2(-16,-5),Vector2(-6,-9),Vector2(5,-5),Vector2(7,3),Vector2(-4,8),Vector2(-15,4)],colors.shade)
			_poly(c,[Vector2(-13,-4),Vector2(-6,-6),Vector2(3,-3),Vector2(-3,1)],colors.light,0)
			Geometry.diamond(c,Vector2(1,0),Vector2.RIGHT,4,2.5,colors.attack)
			for direction: float in [-1.0,1.0]: c.draw_line(Vector2(-23,direction*18),Vector2(-12,direction*14),colors.shade,1.2,true)
		"charger","burrower":
			var low: bool=str(e.kind)=="burrower"
			var squat: float=maxf(0,amount)*4+(7.0 if low else 0.0)
			_poly(c,[Vector2(-23,-8+squat),Vector2(-8,-12+squat),Vector2(4,-8+squat),Vector2(1,5),Vector2(-17,8)],colors.shade,0)
			Geometry.polygon(c,Geometry2D.convex_hull(PackedVector2Array([Vector2(-24,-7+squat),Vector2(-14,-10+squat),Vector2(-6,-4+squat),Vector2(-11,4),Vector2(-22,5)])),colors.base)
			_poly(c,[Vector2(-21,-6+squat),Vector2(-14,-7+squat),Vector2(-10,-3+squat),Vector2(-17,0+squat)],colors.light,0)
			c.draw_line(Vector2(25,6),Vector2(32,8),Geometry.INK,1.4,true)
			Geometry.diamond(c,Vector2(23,-3+(4 if low else 0)),Vector2.RIGHT,3,1.7,Geometry.INK)
			Geometry.diamond(c,Vector2(24,-3+(4 if low else 0)),Vector2.RIGHT,1.6,1,colors.attack)
		"skirmisher":
			var y: float=amount*3
			_poly(c,[Vector2(-12,-18+y),Vector2(-3,-22+y),Vector2(8,-17+y),Vector2(6,-9+y),Vector2(-4,-8+y)],colors.shade)
			c.draw_line(Vector2(0,-17+y),Vector2(7,-16+y),colors.attack,1.5,true)
			_poly(c,[Vector2(-13,-4),Vector2(-4,-7),Vector2(5,-2),Vector2(4,6),Vector2(-11,6)],colors.shade,0)
			c.draw_line(Vector2(-17,-10),Vector2(-23,0),colors.light,1.2,true)
			_limb(c,[Vector2(-1,-7),aim*9-side*2,aim*15],colors.base,3)
		"conductor":
			_poly(c,[Vector2(-16,-16),Vector2(-5,-23),Vector2(4,-14),Vector2(1,-4),Vector2(-11,-2)],colors.shade)
			_poly(c,[Vector2(-13,-15),Vector2(-5,-19),Vector2(1,-13),Vector2(-5,-10)],colors.light,0)
			c.draw_line(Vector2(-6,-8),Vector2(1,-10),colors.attack,1.6,true)
			_poly(c,[Vector2(-14,7),Vector2(-4,12),Vector2(0,24),Vector2(-7,19),Vector2(-15,14)],colors.shade)
