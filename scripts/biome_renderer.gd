class_name SideBiomeRenderer
extends RefCounted

## Deterministic scenery only. Collision tops always come from the stage layout.
## Screen-local loops are capped; no simulation RNG, state writes or textures.
static func _n(seed: float) -> float:
	return fposmod(sin(seed * 12.9898 + 78.233) * 43758.5453, 1.0)

static func _poly(v: Node2D, points: Array, tint: Color) -> void:
	v.draw_colored_polygon(PackedVector2Array(points), tint)

static func _line(v: Node2D, points: Array, tint: Color, width: float = 1.0) -> void:
	v.draw_polyline(PackedVector2Array(points), tint, width, true)

static func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2, steps: int = 16) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var s: float = 1.0 - t
		points.append(a*s*s*s + b*3.0*s*s*t + c*3.0*s*t*t + d*t*t*t)
	return points

static func _branch(v: Node2D, a: Vector2, b: Vector2, c: Vector2, d: Vector2, width: float, tint: Color) -> void:
	var path: PackedVector2Array = _curve(a,b,c,d,12)
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(path.size()):
		var before: Vector2 = path[maxi(0,i-1)]
		var after: Vector2 = path[mini(path.size()-1,i+1)]
		var normal: Vector2 = (after-before).normalized().orthogonal()
		var radius: float = width * (1.0-float(i)/float(path.size())*0.94) * 0.5
		left.append(path[i]+normal*radius)
		right.append(path[i]-normal*radius)
	right.reverse()
	left.append_array(right)
	v.draw_colored_polygon(left,tint)

static func _gradient(v: Node2D, size: Vector2, top: Color, bottom: Color) -> void:
	for i: int in range(48):
		v.draw_rect(Rect2(0,float(i)*size.y/48.0,size.x,size.y/48.0+1),top.lerp(bottom,float(i)/47.0))

static func _haze(v: Node2D, size: Vector2, center_y: float, tint: Color, breadth: float) -> void:
	for band: int in range(12):
		var d: float = float(band)/11.0
		v.draw_rect(Rect2(0,center_y-breadth+float(band)*breadth/6.0,size.x,breadth/6.0+1),Color(tint,sin(d*PI)*tint.a))

static func background(v: Node2D, biome: String, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	match biome:
		"canyon": _canyon(v,camera,size,world,time)
		"ruins": _ruins(v,camera,size,world,time)
		_: _forest(v,camera,size,world,time)

static func _forest(v: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	_gradient(v,size,Color("091c28"),Color("294b4b"))
	var moon: Vector2 = Vector2(size.x*0.78-camera.x*0.018,110.0-camera.y*0.027)
	for halo: int in range(3,0,-1):
		v.draw_circle(moon,63.0+halo*21.0,Color(0.39,0.73,0.73,0.019),true,-1,true)
	v.draw_circle(moon,61.0,Color("638f91"),true,-1,true)
	v.draw_circle(moon+Vector2(-14,-5),56.0,Color("567e83"),true,-1,true)
	for crater: int in range(8):
		var p: Vector2 = moon+Vector2((_n(crater+12)-0.5)*79,(_n(crater+43)-0.5)*80)
		v.draw_circle(p,3+_n(crater+74)*8,Color("4d777c"),true,-1,true)
	v.draw_arc(moon,61,-1.4,1.15,42,Color("abc1b4"),1.0,true)
	for segment: int in range(2):
		var ring: PackedVector2Array = PackedVector2Array()
		for i: int in range(43):
			var a: float = float(i)*0.06+float(segment)*PI+0.3
			ring.append(moon+Vector2(cos(a)*126,sin(a)*26).rotated(-0.32))
		v.draw_polyline(ring,Color(0.66,0.77,0.7,0.25),2.4,true)
	for star: int in range(36):
		var p: Vector2 = Vector2(fposmod(_n(star+10)*size.x-camera.x*0.012,size.x),_n(star+91)*size.y*0.42)
		v.draw_circle(p,0.6,Color(0.73,0.82,0.77,0.24),true,-1,true)
	# Broad, quiet distant ridges preserve sky and space around small actors.
	for layer: int in range(3):
		var spacing: float = 90.0
		var drift: float = camera.x*(0.06+layer*0.065)
		var ridge: Array = []
		var cell: int = int(floor(drift/spacing))
		var horizon: float = size.y*0.54+layer*75+(world.y-camera.y-850)*0.045
		for step: int in range(-2,18):
			var x: float = step*spacing-fposmod(drift,spacing)
			var y: float = horizon+sin(float(cell+step)*0.64+layer)*42+sin(float(cell+step)*1.37)*18
			ridge.append(Vector2(x,y))
		ridge.append(Vector2(1550,size.y+180))
		ridge.append(Vector2(-220,size.y+180))
		_poly(v,ridge,[Color("234b50"),Color("1b4044"),Color("153438")][layer])
	_haze(v,size,size.y*0.64,Color(0.48,0.65,0.57,0.013),75)
	# Irregular buttress roots and lean branches, not repeated round canopies.
	var spacing: float = 720.0
	var drift: float = camera.x*0.28
	for i: int in range(-1,4):
		var cell: int = i+int(floor(drift/spacing))
		var x: float = i*spacing-fposmod(drift,spacing)+_n(cell+22)*100
		var base: Vector2 = Vector2(x,size.y+140+(world.y-camera.y-800)*0.08)
		var crown: Vector2 = base+Vector2(70-_n(cell+1)*140,-480-_n(cell+21)*190)
		var dark: Color = Color("112e31")
		_branch(v,base+Vector2(-50,0),base+Vector2(-3,-180),crown+Vector2(-30,130),crown,85,dark)
		_branch(v,base+Vector2(78,0),base+Vector2(25,-80),crown+Vector2(50,180),crown+Vector2(18,15),58,dark)
		for side: float in [-1.0,1.0]:
			var tip: Vector2 = crown+Vector2(side*240,-35+_n(cell+side)*55)
			_branch(v,crown+Vector2(0,130),crown+Vector2(side*40,40),tip+Vector2(-side*80,-25),tip,25,dark)
			for leaf: int in range(7):
				var p: Vector2 = crown.lerp(tip,float(leaf+1)/7.0)+Vector2(0,-12-_n(leaf+cell)*25)
				_leaf(v,p,Vector2(side*(36+_n(cell+leaf)*22),-20),12,Color("16383a"))
		_branch(v,base+Vector2(-36,0),base+Vector2(-140,-30),base+Vector2(-140,-10),base+Vector2(-215,10),18,dark)
		v.draw_polyline(_curve(base+Vector2(-12,-25),base+Vector2(8,-180),crown+Vector2(-8,90),crown+Vector2(5,20)),Color("21443e"),2.2,true)
		for vine: int in range(3):
			var p: Vector2 = crown+Vector2(-100+vine*86,55)
			var end: Vector2 = p+Vector2(12*sin(time*0.15+vine),90+_n(vine+cell)*100)
			v.draw_polyline(_curve(p,p+Vector2(-15,45),end+Vector2(8,-30),end,10),Color("234c42"),1.1,true)
	_haze(v,size,size.y*0.84,Color(0.42,0.63,0.56,0.012),90)

static func _canyon(v: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	_gradient(v,size,Color("252232"),Color("815c46"))
	var sun: Vector2 = Vector2(size.x*0.72-camera.x*0.019,125+(world.y-camera.y)*0.014)
	v.draw_circle(sun,57,Color("b88862"),true,-1,true)
	v.draw_circle(sun+Vector2(-19,-9),51,Color("624c49"),true,-1,true)
	# Mesas leave a broad winding valley between them. Layering is in masses.
	for layer: int in range(3):
		var spacing: float = 500.0+layer*185.0
		var drift: float = camera.x*(0.065+layer*0.10)
		for i: int in range(-1,5):
			var cell: int = int(floor(drift/spacing))+i
			var x: float = i*spacing-fposmod(drift,spacing)
			var top: float = 250-layer*53+_n(cell+layer*47)*125-camera.y*0.018
			var width: float = spacing*(0.46+_n(cell+8)*0.12)
			var tint: Color = [Color("69504a"),Color("4c3d3f"),Color("342e35")][layer]
			var poly: Array = [Vector2(x-60,size.y+100),Vector2(x+10,top+160),Vector2(x+28,top+35),Vector2(x+67,top+17),Vector2(x+81,top),Vector2(x+width-40,top+8),Vector2(x+width-26,top+63),Vector2(x+width+3,top+89),Vector2(x+width+19,top+235),Vector2(x+width+72,size.y+100)]
			_poly(v,poly,tint)
			_poly(v,[Vector2(x+30,top+37),Vector2(x+78,top+10),Vector2(x+85,top+190),Vector2(x+15,size.y+60),Vector2(x-31,size.y+60)],tint.lightened(0.048))
			for band: int in range(7):
				var y: float = top+80+band*52
				var start: float = x+18-band*2
				var end: float = x+width+10+band*2
				_poly(v,[Vector2(start,y),Vector2(end,y-6),Vector2(end+2,y+4),Vector2(start-3,y+12)],Color(tint.lightened(0.095),0.48))
	_haze(v,size,size.y*0.66,Color(0.84,0.62,0.44,0.018),110)
	# Sagging haulage cables and a distant skeletal refinery imply scale.
	var anchor: float = size.x*0.5+(world.x*0.53-camera.x)*0.12
	for cable: int in range(2):
		v.draw_polyline(_curve(Vector2(-40,150+cable*13),Vector2(380,260+cable*13),Vector2(750,245+cable*13),Vector2(size.x+40,100+cable*13),32),Color("493b39"),1.4,true)
	for tower: int in range(3):
		var x: float = anchor-190+tower*135
		var y: float = size.y*0.75-40*_n(tower+2)
		v.draw_rect(Rect2(x-15,y-164,30,265),Color("392f35"))
		_poly(v,[Vector2(x-39,y-160),Vector2(x+39,y-160),Vector2(x+25,y-185),Vector2(x-24,y-185)],Color("463737"))
		for brace: int in range(4):
			_line(v,[Vector2(x-27,y-brace*39),Vector2(x+25,y-brace*39-32)],Color("54413c"),3)
			v.draw_rect(Rect2(x-26,y-brace*39-5,54,8),Color("443737"))
		v.draw_line(Vector2(x+5,y-148),Vector2(x+5,y+84),Color("685044"),2,true)

static func _ruins(v: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	_gradient(v,size,Color("111526"),Color("39334d"))
	var center: Vector2 = Vector2(size.x*0.62-camera.x*0.018,170-camera.y*0.024)
	v.draw_circle(center,98,Color("111724"),true,-1,true)
	# A massive physical broken iris, with thick wedge sections and dark void.
	for sector: int in range(10):
		var a: float = float(sector)*TAU/10.0+0.07
		var p: Array = []
		for sample: int in range(8): p.append(center+Vector2.from_angle(a+sample*0.052)*142)
		for sample: int in range(7,-1,-1): p.append(center+Vector2.from_angle(a+sample*0.052)*116)
		_poly(v,p,Color("514760") if sector%3==0 else Color("3b394f"))
		v.draw_arc(center,119,a,a+0.34,14,Color("767089"),1.7,true)
		v.draw_line(center+Vector2.from_angle(a+0.18)*126,center+Vector2.from_angle(a+0.18)*137,Color("35374b"),5,true)
	v.draw_arc(center,105,0.12,TAU-0.3,80,Color(0.5,0.7,0.71,0.24),1.4,true)
	for star: int in range(35):
		var p: Vector2 = Vector2(fposmod(_n(star+7)*size.x-camera.x*0.02,size.x),_n(star+77)*size.y*0.75)
		v.draw_circle(p,0.6,Color(0.76,0.74,0.87,0.21),true,-1,true)
	# Broken halls have recesses, incomplete vaults and sheer cliff footings.
	for layer: int in range(2):
		var spacing: float = 640.0+layer*240
		var drift: float = camera.x*(0.10+layer*0.12)
		for index: int in range(-1,4):
			var cell: int = index+int(floor(drift/spacing))
			var x: float = index*spacing-fposmod(drift,spacing)
			var top: float = 305+_n(cell+41)*110-layer*60-camera.y*0.018
			var tint: Color = Color("303046") if layer==0 else Color("252638")
			for pillar: int in range(3):
				var px: float = x+pillar*134
				var height: float = 170+_n(pillar+cell)*110
				_poly(v,[Vector2(px-31,size.y+60),Vector2(px-28,top+22),Vector2(px-18,top-height*0.28),Vector2(px+19,top-height*0.28-9),Vector2(px+33,top+17),Vector2(px+35,size.y+60)],tint)
				v.draw_rect(Rect2(px-17,top+6,13,220),tint.lightened(0.07))
				v.draw_rect(Rect2(px+4,top+36,12,155),Color("181e30"))
				v.draw_arc(Vector2(px+65,top+43),67,PI+0.2,TAU-0.4,28,tint,18,true)
				v.draw_arc(Vector2(px+65,top+43),58,PI+0.22,PI+0.95,12,tint.lightened(0.08),2,true)
			_poly(v,[Vector2(x-49,top-47),Vector2(x+180,top-58),Vector2(x+190,top-40),Vector2(x+112,top-29),Vector2(x-40,top-28)],tint.lightened(0.04))
	_haze(v,size,size.y*0.78,Color(0.54,0.55,0.72,0.013),105)

static func _leaf(v: Node2D, base: Vector2, axis: Vector2, width: float, tint: Color) -> void:
	var side: Vector2 = axis.normalized().orthogonal()*width
	var upper: PackedVector2Array = _curve(base,base+axis*0.15+side,base+axis*0.7+side*0.55,base+axis,8)
	var lower: PackedVector2Array = _curve(base+axis,base+axis*0.64-side*0.3,base+axis*0.2-side*0.65,base,8)
	for i: int in range(1,8): upper.append(lower[i])
	v.draw_colored_polygon(upper,tint)
	if width>7:
		v.draw_line(base+axis*0.15,base+axis*0.84,tint.lightened(0.035),0.7,true)

static func platform(v: Node2D, rectangle: Rect2, index: int, biome: String, time: float, size: Vector2, world: Vector2, static_only: bool = false) -> void:
	var p: Vector2 = v.world_to_screen(rectangle.position)
	var width: float = rectangle.size.x
	var floor_piece: bool = rectangle.size.y>60 or rectangle.position.y>=world.y-160
	if p.x+width < -100 or p.x>size.x+100 or p.y>size.y+110 or (not floor_piece and p.y < -140): return
	var left: float = maxf(p.x,-80)
	var right: float = minf(p.x+width,size.x+80)
	if right-left<4: return
	var depth: float = maxf(38,rectangle.size.y+16) if not floor_piece else maxf(65,size.y-p.y+80)
	var ground: Color = Color("102b2b") if biome=="rainforest" else (Color("3b3030") if biome=="canyon" else Color("1d2333"))
	var body: Array = [Vector2(left,p.y+3),Vector2(right,p.y+3)]
	var cells: int = clampi(int(ceil((right-left)/48.0)),1,32)
	for cell: int in range(cells,-1,-1):
		var x: float = lerpf(left,right,float(cell)/cells)
		var global_x: float = rectangle.position.x+x-p.x
		body.append(Vector2(x,p.y+depth+(_n(floor(global_x/43)+index*39)-0.5)*13))
	_poly(v,body,ground)
	# Textures are anchored in world coordinates, so camera movement never
	# rearranges rocks, moss or masonry. Only visible cells are issued.
	var pitch: float = 74.0 if biome!="ruins" else 88.0
	var first: int = maxi(0,int(floor((-90-p.x)/pitch)))
	var last: int = mini(int(ceil(width/pitch)),first+22)
	for cell: int in range(first,last):
		var x: float = p.x+cell*pitch
		var end: float = minf(p.x+width,x+pitch)
		var span: float = end-x
		# Tiny remainder cells are covered by the solid substrate; inset quads
		# would cross themselves when the remaining surface is narrower than 30.
		if span<30: continue
		var seed: float = index*89+cell
		if biome=="rainforest":
			_poly(v,[Vector2(x+2,p.y+7),Vector2(end-1,p.y+6),Vector2(end-9,p.y+24+_n(seed)*7),Vector2(x+11,p.y+28+_n(seed+4)*7)],Color("28463b").lightened(_n(seed)*0.026))
			_poly(v,[Vector2(x+8,p.y+18),Vector2(x+span*(0.43+_n(seed+3)*0.2),p.y+13),Vector2(end-6,p.y+depth-8),Vector2(x+18,p.y+depth+4)],Color("183735").lightened(_n(seed)*0.055))
			_line(v,[Vector2(x+7,p.y+14),Vector2(x+span*0.51,p.y+18),Vector2(x+span*0.72,p.y+31)],Color("335346"),1.1)
			for moss: int in range(4):
				var mx: float = x+4+moss*(span-8)/4
				v.draw_circle(Vector2(mx,p.y+4),2+_n(seed+moss)*3.0,Color("3a644c"),true,-1,true)
			if cell%3==index%3:
				_branch(v,Vector2(x+24,p.y+11),Vector2(x+41,p.y+26),Vector2(x+8,p.y+45),Vector2(x+26,p.y+72),6,Color("456148"))
				_branch(v,Vector2(x+26,p.y+31),Vector2(x+33,p.y+43),Vector2(x+50,p.y+49),Vector2(x+53,p.y+59),3,Color("36563e"))
			if not static_only and cell%3!=1: _fern(v,Vector2(x+span*(0.25+_n(seed+29)*0.5),p.y),0.55+_n(seed)*0.55,time,Color("43795d"),false)
			if int(seed)%7==0: _mushroom(v,Vector2(x+14,p.y),0.65+_n(seed+5)*0.45)
		elif biome=="canyon":
			_poly(v,[Vector2(x,p.y+6),Vector2(end,p.y+4),Vector2(end-6,p.y+16+_n(seed)*7),Vector2(x+3,p.y+23+_n(seed+1)*4)],Color("856049").lightened(_n(seed+6)*0.065))
			for band: int in range(3):
				var y: float = p.y+19+band*9+_n(seed+band)*3
				_poly(v,[Vector2(x+4,y),Vector2(end-4,y-2),Vector2(end-8,y+3),Vector2(x+8,y+5)],Color("69503f") if band%2==0 else Color("514038"))
			_line(v,[Vector2(x+span*0.4,p.y+6),Vector2(x+span*0.31,p.y+18),Vector2(x+span*0.5,p.y+29)],Color("493c35"),1.4)
			if cell%4==0 and index%3==1:
				v.draw_rect(Rect2(x+14,p.y+8,maxf(8,span-25),15),Color("44433c"))
				v.draw_rect(Rect2(x+17,p.y+10,maxf(5,span-31),4),Color("726247"))
				for bolt: int in range(2): v.draw_circle(Vector2(x+21+bolt*(span-39),p.y+17),1.4,Color("b19869"),true,-1,true)
			if cell%5==2:
				_poly(v,[Vector2(x+18,p.y),Vector2(x+21,p.y-6),Vector2(x+31,p.y-9),Vector2(x+39,p.y-3),Vector2(x+41,p.y)],Color("8d6e50"))
				_line(v,[Vector2(x+24,p.y-5),Vector2(x+31,p.y-7),Vector2(x+35,p.y-3)],Color("ac8a5d"),1)
		else:
			v.draw_rect(Rect2(x+1,p.y+5,span-3,22),Color("454752"))
			_poly(v,[Vector2(x+4,p.y+6),Vector2(end-5,p.y+6),Vector2(end-10,p.y+12),Vector2(x+8,p.y+12)],Color("6a6770"))
			_poly(v,[Vector2(x+6,p.y+28),Vector2(end-7,p.y+28),Vector2(end-12,p.y+depth-1),Vector2(x+10,p.y+depth+4)],Color("303445"))
			v.draw_rect(Rect2(x+14,p.y+17,maxf(5,span-31),7),Color("272e3e"))
			if cell%3==1:
				v.draw_line(Vector2(x+22,p.y+21),Vector2(x+minf(span-18,41),p.y+21),Color("82aaa7"),1.5,true)
			for bolt: int in range(2): v.draw_circle(Vector2(x+8+bolt*(span-17),p.y+18),1.1,Color("989588"),true,-1,true)
			if index%4==2 and cell%3==0:
				_poly(v,[Vector2(x+span*0.25,p.y+32),Vector2(x+span*0.75,p.y+32),Vector2(x+span*0.63,p.y+55),Vector2(x+span*0.45,p.y+61)],Color("292d40"))
				v.draw_line(Vector2(x+span*0.48,p.y+35),Vector2(x+span*0.48,p.y+51),Color("53586b"),2,true)
		# Sparse embedded mineral flecks and edge wear give material scale.
		for fleck: int in range(7):
			var fx: float = x+7+_n(seed*11+fleck)*(span-14)
			var fy: float = p.y+8+_n(seed*19+fleck)*22
			var tint: Color = Color("708069") if biome=="rainforest" else (Color("b79870") if biome=="canyon" else Color("9a959a"))
			v.draw_line(Vector2(fx,fy),Vector2(fx+1.0+_n(seed+fleck)*2.2,fy),Color(tint,0.16+_n(seed+fleck)*0.17),0.8,true)
	# Continuous thin landing cue follows the exact collision top.
	var lip: Color = Color("759779") if biome=="rainforest" else (Color("c5a37b") if biome=="canyon" else Color("b0afb4"))
	v.draw_line(Vector2(left,p.y+0.5),Vector2(right,p.y+0.5),lip,2.0,true)
	v.draw_line(Vector2(left,p.y+4),Vector2(right,p.y+4),ground.lightened(0.12),1.4,true)
	if floor_piece:
		_haze_floor(v,left,right,p.y+66,minf(depth,260),ground)

## The foliage stays live above cached material. Its phase follows exactly the
## same screen-space placement as the uncached renderer.
static func platform_animated(v: Node2D, rectangle: Rect2, index: int, biome: String, time: float, size: Vector2) -> void:
	if biome!="rainforest": return
	var p: Vector2=v.world_to_screen(rectangle.position)
	if p.y < -40 or p.y>size.y+40 or p.x+rectangle.size.x<0 or p.x>size.x: return
	var first: int=maxi(0,int(floor((-90-p.x)/74.0)))
	var last: int=mini(int(ceil(rectangle.size.x/74.0)),first+22)
	for cell: int in range(first,last):
		var x: float=p.x+cell*74.0
		var span: float=minf(p.x+rectangle.size.x,x+74.0)-x
		if span<30 or cell%3==1: continue
		var seed: float=index*89+cell
		_fern(v,Vector2(x+span*(0.25+_n(seed+29)*0.5),p.y),0.55+_n(seed)*0.55,time,Color("43795d"),false)

static func _haze_floor(v: Node2D, left: float, right: float, y: float, depth: float, tint: Color) -> void:
	for i: int in range(4):
		v.draw_rect(Rect2(left,y+i*depth/4.0,right-left,depth/4.0+1),Color(tint.darkened(0.2),float(i+1)*0.13))

static func _fern(v: Node2D, p: Vector2, scale_value: float, time: float, tint: Color, large: bool) -> void:
	var height: float = (54.0 if large else 21.0)*scale_value
	var sway: float = sin(time*1.1+p.x*0.007)*2.0*scale_value
	var tip: Vector2 = p+Vector2(sway,-height)
	v.draw_line(p,tip,tint.darkened(0.15),1.3,true)
	for leaf: int in range(4):
		var f: float = float(leaf+1)/5.0
		var center: Vector2 = p.lerp(tip,f)
		var breadth: float = height*(1.0-f)*0.47
		for side: float in [-1.0,1.0]:
			_leaf(v,center,Vector2(side*breadth,-height*0.12),breadth*0.22,tint)

static func _mushroom(v: Node2D, p: Vector2, scale_value: float) -> void:
	var cap: Vector2 = p+Vector2(0,-20*scale_value)
	v.draw_line(p,cap,Color("5a795f"),2*scale_value,true)
	_poly(v,[cap+Vector2(-13,1)*scale_value,cap+Vector2(-8,-6)*scale_value,cap+Vector2(0,-9)*scale_value,cap+Vector2(9,-5)*scale_value,cap+Vector2(13,1)*scale_value],Color("548c78"))
	v.draw_line(cap+Vector2(-11,2)*scale_value,cap+Vector2(11,2)*scale_value,Color("a2cba0"),1.6,true)
	v.draw_line(cap+Vector2(-7,4)*scale_value,cap+Vector2(7,4)*scale_value,Color(0.66,0.89,0.7,0.26),1,true)

static func landmarks(v: Node2D, entries: Array, biome: String, time: float) -> void:
	for landmark: Dictionary in entries:
		var p: Vector2 = v.world_to_screen(landmark.get("pos",Vector2.ZERO))
		var s: float = clampf(float(landmark.get("scale",1.0)),0.5,3.0)
		if p.x < -460*s or p.x > v.screen_size.x+460*s or p.y < -420*s or p.y > v.screen_size.y+680*s: continue
		v.draw_set_transform(p,0,Vector2.ONE*s)
		match biome:
			"canyon": _industrial_landmark(v,str(landmark.get("kind","")),time)
			"ruins": _ruin_landmark(v,str(landmark.get("kind","")),time)
			_: _forest_landmark(v,str(landmark.get("kind","")),time)
		v.draw_set_transform(Vector2.ZERO)

static func _forest_landmark(v: Node2D, kind: String, time: float) -> void:
	if kind=="waterfall":
		_poly(v,[Vector2(-104,100),Vector2(-91,-250),Vector2(-53,-319),Vector2(54,-309),Vector2(89,-240),Vector2(113,100)],Color("203e3c"))
		_poly(v,[Vector2(-86,-270),Vector2(-37,-319),Vector2(-23,105),Vector2(-80,105)],Color("2a4d45"))
		for stream: int in range(7):
			var x: float = -42+stream*13
			v.draw_line(Vector2(x,-298),Vector2(x+sin(stream)*10,87),Color(0.45,0.7,0.63,0.07),8,true)
			var y: float = fposmod(time*64+stream*61,375)-290
			v.draw_line(Vector2(x,y),Vector2(x+2,y+57),Color(0.68,0.84,0.7,0.19),1.2,true)
		for rock: int in range(5): _poly(v,[Vector2(-110+rock*47,80),Vector2(-83+rock*47,60-_n(rock)*15),Vector2(-55+rock*47,90)],Color("264840"))
		return
	if kind=="observatory":
		for side: float in [-1.0,1.0]:
			_line(v,[Vector2(side*82,80),Vector2(side*59,-56),Vector2(side*33,-151)],Color("28483e"),12)
			_line(v,[Vector2(side*72,29),Vector2(-side*48,-83)],Color("365346"),5)
		v.draw_arc(Vector2(0,-181),69,0.22,PI-0.22,36,Color("3d5b4b"),15,true)
		v.draw_arc(Vector2(0,-181),60,0.24,PI-0.24,36,Color("60806a"),2,true)
		_line(v,[Vector2(0,-120),Vector2(12,-188),Vector2(17,-211)],Color("657963"),3)
		v.draw_circle(Vector2(17,-211),3,Color("abc09a"),true,-1,true)
		for vine: int in range(3): _branch(v,Vector2(-44+vine*31,-128),Vector2(-40+vine*31,-50),Vector2(-65+vine*31,-20),Vector2(-37+vine*31,24),2,Color("416d4c"))
		return
	# Hollow trunk has two lit buttresses, deep recess and branching roots.
	_branch(v,Vector2(-17,38),Vector2(-59,-111),Vector2(-18,-267),Vector2(-27,-439),127,Color("254237"))
	_branch(v,Vector2(61,30),Vector2(27,-100),Vector2(92,-245),Vector2(78,-354),75,Color("294b38"))
	_branch(v,Vector2(-49,25),Vector2(-57,-128),Vector2(-43,-255),Vector2(-26,-414),29,Color("38583e"))
	_branch(v,Vector2(-12,-89),Vector2(-34,-171),Vector2(6,-233),Vector2(-20,-311),40,Color("102b28"))
	_branch(v,Vector2(42,14),Vector2(37,-92),Vector2(71,-236),Vector2(78,-323),18,Color("456345"))
	for root: int in range(7):
		var end: Vector2 = Vector2(-195+root*66,38+_n(root+9)*23)
		_branch(v,Vector2(-8,-91),Vector2(end.x*0.31,-45),Vector2(end.x*0.65,5),end,22,Color("284c36"))
		v.draw_polyline(_curve(Vector2(-11,-86),Vector2(end.x*0.31,-43),Vector2(end.x*0.65,7),end,14),Color("486445"),1.2,true)
	for branch: int in range(5):
		var start: Vector2 = Vector2(-25,-275-branch*22)
		var side: float = -1.0 if branch%2==0 else 1.0
		var end: Vector2 = start+Vector2(side*(110+branch*21),-24-branch*6)
		_branch(v,start,start+Vector2(side*40,7),end+Vector2(-side*35,-17),end,16,Color("244534"))
		for leaf: int in range(7):
			var leaf_start: Vector2 = start.lerp(end,float(leaf+1)/7.0)
			var direction: Vector2 = Vector2(side*(24+_n(leaf+branch)*16),-13-_n(leaf+33)*22)
			_leaf(v,leaf_start,direction,8+_n(leaf+8)*5,Color("2c533b").lightened(_n(leaf+12)*0.018))
	for bark: int in range(9):
		var x: float = -39+bark*10
		v.draw_polyline(_curve(Vector2(x,-41),Vector2(x-25,-132),Vector2(x-7,-210),Vector2(x-19,-255),13),Color("3c5b3f"),1.1,true)
	for knot: int in range(3):
		var point: Vector2 = Vector2(-39+knot*41,-88-knot*73)
		v.draw_arc(point,9+2*knot,0.5,TAU-0.6,20,Color("203c30"),3,true)
		v.draw_arc(point,12+2*knot,PI,TAU-0.2,17,Color("4a6343"),1.2,true)
	for growth: int in range(5): _mushroom(v,Vector2(-46+growth*16,-145+sin(growth*3.1)*70),0.44)
	if kind=="crown":
		for petal: int in range(7):
			var axis: Vector2 = Vector2.from_angle(-PI+petal*PI/6)*94
			_leaf(v,Vector2(4,-236),axis,18,Color("47734d"))
		v.draw_circle(Vector2(4,-236),15,Color("849168"),true,-1,true)

static func _industrial_landmark(v: Node2D, kind: String, time: float) -> void:
	if kind=="crystal_cave":
		for shard: int in range(7):
			var x: float = -119+shard*38
			var height: float = 55+_n(shard+61)*140
			_poly(v,[Vector2(x-17,25),Vector2(x-14,-height+16),Vector2(x,-height),Vector2(x+15,-height+17),Vector2(x+19,25)],Color("335156"))
			_poly(v,[Vector2(x,-height+4),Vector2(x+13,-height+18),Vector2(x+16,20),Vector2(x+2,20)],Color("486b69"))
			v.draw_line(Vector2(x,-height+5),Vector2(x-1,13),Color("699186"),1.2,true)
		return
	if kind in ["obelisk","beacon","chasm"]:
		_poly(v,[Vector2(-74,91),Vector2(-55,-181),Vector2(-25,-260),Vector2(34,-258),Vector2(61,-149),Vector2(82,91)],Color("4a3c35"))
		_poly(v,[Vector2(-55,-167),Vector2(-25,-255),Vector2(-18,71),Vector2(-57,88)],Color("68503d"))
		v.draw_rect(Rect2(-19,-209,47,97),Color("302e30"))
		for bar: int in range(5): v.draw_rect(Rect2(-14,-200+bar*16,37,6),Color("846b48"))
		v.draw_rect(Rect2(-9,-103,22,151),Color("333638"))
		v.draw_line(Vector2(1,-91),Vector2(1,33),Color("977b50"),2,true)
		if kind=="beacon": v.draw_circle(Vector2(3,-238),6,Color("b7b784"),true,-1,true)
		return
	# Lift head: broad cast housing, exposed gear, riveted stanchions and cables.
	for side: float in [-1.0,1.0]:
		v.draw_rect(Rect2(side*87-8,-244,16,355),Color("423b35"))
		v.draw_rect(Rect2(side*87-5,-240,4,344),Color("796149"))
		for joint: int in range(5):
			v.draw_rect(Rect2(side*87-11,-212+joint*61,22,10),Color("66513e"))
			v.draw_circle(Vector2(side*87,-207+joint*61),2,Color("9b8057"),true,-1,true)
	_line(v,[Vector2(-84,30),Vector2(81,-212)],Color("51453b"),7)
	_poly(v,[Vector2(-110,-225),Vector2(-83,-268),Vector2(77,-268),Vector2(112,-226),Vector2(101,-204),Vector2(-99,-204)],Color("59493b"))
	v.draw_circle(Vector2(0,-228),55,Color("2b2e2e"),true,-1,true)
	v.draw_circle(Vector2(0,-228),49,Color("4c4238"),false,8,true)
	v.draw_circle(Vector2(0,-228),35,Color("8b6e4b"),false,3,true)
	for tooth: int in range(14):
		var direction: Vector2 = Vector2.from_angle(tooth*TAU/14)
		v.draw_line(Vector2(0,-228)+direction*42,Vector2(0,-228)+direction*54,Color("826749"),6,true)
	for spoke: int in range(6):
		var direction: Vector2 = Vector2.from_angle(spoke*TAU/6+0.13)
		v.draw_line(Vector2(0,-228)+direction*11,Vector2(0,-228)+direction*32,Color("665742"),5,true)
	v.draw_circle(Vector2(0,-228),10,Color("8f7955"),true,-1,true)
	for side: float in [-1.0,1.0]: v.draw_line(Vector2(side*48,-229),Vector2(side*48,350),Color("756046"),1.5,true)
	for vent: int in range(6): v.draw_rect(Rect2(-61+vent*22,-261,13,8),Color("282e2c"))
	v.draw_rect(Rect2(-34,-89,68,57),Color("413c34"))
	for slat: int in range(4): v.draw_rect(Rect2(-29,-82+slat*12,58,5),Color("766044"))

static func _ruin_landmark(v: Node2D, kind: String, time: float) -> void:
	if kind in ["archive","crypt"]:
		for pillar: int in range(5):
			var x: float = -144+pillar*72
			v.draw_rect(Rect2(x-18,-215,36,278),Color("333344"))
			v.draw_rect(Rect2(x-15,-213,7,273),Color("55505c"))
			v.draw_rect(Rect2(x-5,-182,13,177),Color("1e2738"))
			v.draw_rect(Rect2(x-22,-207,44,12),Color("68606a"))
			for bolt: int in range(3): v.draw_rect(Rect2(x-1,-173+bolt*48,4,16),Color("516f75"))
		_poly(v,[Vector2(-183,-216),Vector2(-163,-241),Vector2(13,-293),Vector2(91,-265),Vector2(155,-224),Vector2(181,-220),Vector2(170,-201),Vector2(96,-227),Vector2(12,-267),Vector2(-144,-216)],Color("4e475b"))
		if kind=="crypt":
			_poly(v,[Vector2(-25,37),Vector2(-31,-104),Vector2(0,-124),Vector2(31,-104),Vector2(25,37)],Color("595366"))
			v.draw_rect(Rect2(-12,-83,24,94),Color("283646"))
		return
	if kind=="reactor":
		v.draw_rect(Rect2(-61,-277,122,324),Color("252b3c"))
		for side: float in [-1.0,1.0]:
			v.draw_rect(Rect2(side*48-9,-253,18,292),Color("555367"))
			for collar: int in range(4): v.draw_rect(Rect2(side*48-13,-232+collar*70,26,12),Color("787082"))
		v.draw_rect(Rect2(-24,-245,48,270),Color("162c39"))
		v.draw_rect(Rect2(-12,-238,24,257),Color("3c6870"))
		for fin: int in range(6):
			v.draw_rect(Rect2(-33,-220+fin*44,66,8),Color("333447"))
			v.draw_line(Vector2(-28,-216+fin*44),Vector2(28,-216+fin*44),Color("819697"),1,true)
		return
	var center: Vector2 = Vector2(0,-108)
	for ring: int in range(2):
		var radius: float = 102+ring*47
		for sector: int in range(7):
			var a: float = sector*TAU/7+ring*0.25+time*0.008
			var shape: Array = []
			for step: int in range(7): shape.append(center+Vector2.from_angle(a+step*0.1)*radius)
			for step: int in range(6,-1,-1): shape.append(center+Vector2.from_angle(a+step*0.1)*(radius-18))
			_poly(v,shape,Color("4a445d") if ring==0 else Color("343447"))
			v.draw_arc(center,radius-3,a,a+0.58,18,Color("696275"),1.5,true)
			var axis: Vector2 = Vector2.from_angle(a+0.3)
			v.draw_line(center+axis*(radius-15),center+axis*(radius-6),Color("7b8286"),2,true)
	for support: int in range(3):
		var angle: float = support*TAU/3+PI*0.5
		var axis: Vector2 = Vector2.from_angle(angle)
		v.draw_line(center+axis*52,center+axis*94,Color("525363"),8,true)
	v.draw_circle(center,45,Color("1b2b39"),true,-1,true)
	v.draw_circle(center,37,Color("435867"),false,5,true)
	_poly(v,[center+Vector2(0,-31),center+Vector2(17,0),center+Vector2(0,32),center+Vector2(-17,0)],Color("6a9998"))
	_poly(v,[center+Vector2(0,-24),center+Vector2(7,0),center+Vector2(0,24),center+Vector2(-6,0)],Color("a6bcb0"))

static func atmosphere(v: Node2D, biome: String, camera: Vector2, size: Vector2, time: float) -> void:
	var tint: Color = Color(0.65,0.8,0.71,0.10) if biome=="rainforest" else (Color(0.91,0.7,0.49,0.10) if biome=="canyon" else Color(0.7,0.73,0.86,0.13))
	for mote: int in range(30):
		var p: Vector2 = Vector2(fposmod(mote*173.71-camera.x*0.15+time*(5 if biome=="canyon" else -2),size.x),fposmod(mote*81.33-camera.y*0.12+time*(65 if biome=="rainforest" else -5),size.y))
		if biome=="rainforest": v.draw_line(p,p+Vector2(-2,10),tint,1,true)
		else: v.draw_circle(p,0.8 if biome=="canyon" else 1.1,tint,true,-1,true)
	# Only edge-attached foreground silhouettes, never opaque cover on actors.
	if biome=="rainforest":
		for side: int in range(2):
			var x: float = 10.0 if side==0 else size.x-9
			_fern(v,Vector2(x,size.y+18),2.5,time,Color(0.02,0.09,0.10,0.65),true)
	elif biome=="canyon":
		for side: int in range(2):
			var x: float = 0 if side==0 else size.x
			var sign_value: float = 1 if side==0 else -1
			_poly(v,[Vector2(x,size.y),Vector2(x,size.y-99),Vector2(x+sign_value*11,size.y-80),Vector2(x+sign_value*29,size.y-8),Vector2(x+sign_value*48,size.y)],Color(0.09,0.10,0.12,0.5))
