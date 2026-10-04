class_name SideBiomeRenderer
extends RefCounted

## Non-interactive scenery. All drawing is issued inside the view's _draw call.
## Geometry is deterministic, consumes no simulation RNG and accepts any bounds.
static func background(view: Node2D, biome: String, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	if biome == "canyon":
		_canyon(view, camera, size, world, time)
	elif biome == "ruins":
		_ruins(view, camera, size, world, time)
	else:
		_forest(view, camera, size, world, time)


static func _gradient(view: Node2D, size: Vector2, upper: Color, lower: Color) -> void:
	for index: int in range(32):
		var fraction: float = float(index) / 31.0
		view.draw_rect(Rect2(0.0, float(index) / 32.0 * size.y, size.x, size.y / 32.0 + 1.0), upper.lerp(lower, fraction))


static func _forest(view: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	# Branching tree trunks, umbrella canopies and glowing seed pods are unique
	# to this biome, supplementing the original distant ring-moon landscape.
	for layer: int in range(2):
		var spacing: float = 460.0 if layer == 0 else 680.0
		var drift: float = camera.x * (0.15 if layer == 0 else 0.3)
		var base: float = size.y + 90.0 + (world.y - camera.y - 650.0) * 0.06
		var trunk_color: Color = Color("153f3e") if layer == 0 else Color("102f30")
		for index: int in range(-1, 5):
			var world_index: int = index + int(drift / spacing)
			var x: float = float(index) * spacing - fposmod(drift, spacing)
			var height: float = 430.0 + sin(float(world_index) * 4.31) * 125.0
			var crown: Vector2 = Vector2(x + 40.0, base - height)
			var trunk: PackedVector2Array = PackedVector2Array([Vector2(x - 55.0, base), Vector2(x - 19.0, base - 155.0), crown + Vector2(-17.0, 10.0), crown + Vector2(16.0, 0.0), Vector2(x + 25.0, base - 165.0), Vector2(x + 69.0, base)])
			view.draw_colored_polygon(trunk, trunk_color)
			for side: float in [-1.0, 1.0]:
				var joint: Vector2 = crown + Vector2(-10.0, 180.0)
				var branch_tip: Vector2 = crown + Vector2(side * 170.0, 70.0)
				view.draw_polyline(PackedVector2Array([joint, joint + Vector2(side * 60.0, -35.0), branch_tip]), trunk_color, 17.0, true)
				for leaf: int in range(5):
					var angle: float = float(leaf) * 0.45 - 2.5
					var tip: Vector2 = branch_tip + Vector2.from_angle(angle) * 94.0
					view.draw_colored_polygon(PackedVector2Array([branch_tip, tip, branch_tip + Vector2(-28.0 + float(leaf) * 15.0, -22.0)]), trunk_color)
			for lobe: int in range(5):
				var px: float = float(lobe - 2) * 62.0
				view.draw_circle(crown + Vector2(px, -22.0 + absf(px) * 0.22), 65.0 - absf(px) * 0.16, trunk_color, true, -1.0, true)
			view.draw_line(Vector2(x - 4.0, base - 30.0), crown + Vector2(1.0, 61.0), Color("205148") if layer == 0 else Color("1b4039"), 2.0, true)
			for pod: int in range(3):
				var anchor: Vector2 = crown + Vector2(float(pod - 1) * 74.0, 12.0)
				var drop: Vector2 = anchor + Vector2(sin(time * 0.4 + float(pod)) * 5.0, 50.0 + float(pod % 2) * 20.0)
				view.draw_line(anchor, drop, Color("2b6553"), 1.0, true)
				view.draw_circle(drop, 3.0, Color(0.43, 0.77, 0.55, 0.4), true, -1.0, true)


static func _canyon(view: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	_gradient(view, size, Color("251b2c"), Color("72503c"))
	var elevation: float = clampf(1.0 - camera.y / maxf(world.y, 1.0), 0.0, 1.0)
	var sun: Vector2 = Vector2(size.x * 0.57 - camera.x * 0.035, 135.0 + elevation * 55.0)
	for glow: int in range(4, 0, -1):
		view.draw_circle(sun, 45.0 + float(glow) * 25.0, Color(0.91, 0.59, 0.3, 0.025), true, -1.0, true)
	view.draw_circle(sun, 46.0, Color("c18b5f"), true, -1.0, true)
	view.draw_circle(sun + Vector2(-13.0, -7.0), 43.0, Color("73574b"), true, -1.0, true)
	# Tall opposing rock stacks span the screen and convey a shaft, not hills.
	for layer: int in range(3):
		var spacing: float = 290.0 + float(layer) * 130.0
		var drift: float = camera.x * (0.12 + float(layer) * 0.13)
		var color_value: Color = [Color("57443f"), Color("43363a"), Color("302a32")][layer]
		for index: int in range(-1, 7):
			var cell: int = int(drift / spacing) + index
			var x: float = float(index) * spacing - fposmod(drift, spacing)
			var top: float = -100.0 + sin(float(cell) * 8.713) * 155.0 - camera.y * 0.025
			var width: float = 95.0 + absf(sin(float(cell) * 3.13)) * 110.0
			var silhouette: PackedVector2Array = PackedVector2Array([Vector2(x, size.y + 90.0), Vector2(x + 12.0, top + 290.0), Vector2(x + 27.0, top + 265.0), Vector2(x + 20.0, top + 120.0), Vector2(x + 50.0, top), Vector2(x + width - 20.0, top + 20.0), Vector2(x + width, top + 205.0), Vector2(x + width - 12.0, top + 238.0), Vector2(x + width + 35.0, size.y + 90.0)])
			view.draw_colored_polygon(silhouette, color_value)
			for seam: int in range(13):
				var y: float = fposmod(float(seam) * 91.0 - camera.y * (0.07 + float(layer) * 0.045), size.y + 140.0) - 70.0
				view.draw_line(Vector2(x + 20.0, y), Vector2(x + width - 3.0, y - 7.0), Color(0.72, 0.52, 0.36, 0.11), 2.0, true)
			view.draw_line(Vector2(x + 51.0, top + 20.0), Vector2(x + 36.0, size.y), Color(0.81, 0.6, 0.38, 0.1), 2.0, true)
	# Suspended mining cables and water streaming down the full vertical valley.
	for cable: int in range(4):
		var x: float = float(cable) * 440.0 - fposmod(camera.x * 0.32, 440.0) + 120.0
		view.draw_line(Vector2(x, -20.0), Vector2(x + 9.0, size.y + 20.0), Color("594843"), 2.0, true)
		for link: int in range(17):
			var y: float = fposmod(float(link) * 61.0 - camera.y * 0.22, size.y + 60.0) - 30.0
			view.draw_rect(Rect2(x - 3.0, y, 8.0, 9.0), Color("6f5747"), false, 1.0)
		var waterfall_x: float = x + 93.0
		view.draw_line(Vector2(waterfall_x, -10.0), Vector2(waterfall_x + 18.0, size.y + 20.0), Color(0.81, 0.68, 0.47, 0.045), 14.0)
		for stripe: int in range(2):
			var y: float = fposmod(time * 70.0 + float(stripe) * 370.0, size.y + 300.0) - 150.0
			view.draw_line(Vector2(waterfall_x, y), Vector2(waterfall_x + 3.0, y + 170.0), Color(0.91, 0.72, 0.51, 0.08), 1.0, true)


static func _ruins(view: Node2D, camera: Vector2, size: Vector2, world: Vector2, time: float) -> void:
	_gradient(view, size, Color("100f26"), Color("342b52"))
	# Broken celestial iris. Ruins have a void aperture instead of a moon.
	var center: Vector2 = Vector2(size.x * 0.57 - camera.x * 0.035, 210.0 - camera.y * 0.025)
	view.draw_circle(center, 99.0, Color("111525"), true, -1.0, true)
	for ring: int in range(3):
		var radius: float = 106.0 + float(ring) * 26.0
		for segment: int in range(8):
			var start: float = float(segment) * TAU / 8.0 + float(ring) * 0.16 + sin(time * 0.04) * 0.03
			view.draw_arc(center, radius, start, start + 0.55, 18, Color(0.58, 0.48, 0.8, 0.24 - float(ring) * 0.035), 7.0 - float(ring) * 2.0, true)
			var glyph_p: Vector2 = center + Vector2.from_angle(start + 0.26) * radius
			view.draw_line(glyph_p, glyph_p + Vector2.from_angle(start + 0.26) * 10.0, Color(0.56, 0.85, 0.87, 0.23), 1.0, true)
	var ray: PackedVector2Array = PackedVector2Array([center + Vector2(-2.0, -94.0), center + Vector2(3.0, -20.0), center + Vector2(-13.0, 14.0), center + Vector2(4.0, 52.0), center + Vector2(-1.0, 95.0)])
	view.draw_polyline(ray, Color(0.45, 0.85, 0.87, 0.3), 3.0, true)
	for star: int in range(58):
		var p: Vector2 = Vector2(fposmod(float(star) * 173.731 - camera.x * 0.025, size.x), fposmod(float(star) * 117.313 - camera.y * 0.04, size.y))
		view.draw_circle(p, 0.6 + float(star % 3) * 0.3, Color(0.7, 0.7, 0.88, 0.28), true, -1.0, true)
	# Orthogonal galleries, gates and hovering lintels are unmistakably built.
	for layer: int in range(2):
		var spacing: float = 440.0 + float(layer) * 170.0
		var drift: float = camera.x * (0.13 + float(layer) * 0.19)
		var color_value: Color = Color("29273f") if layer == 0 else Color("202137")
		for index: int in range(-1, 5):
			var x: float = float(index) * spacing - fposmod(drift, spacing)
			var y: float = 300.0 + sin(float(index + int(drift / spacing)) * 3.41) * 95.0 - fposmod(camera.y * 0.06, 90.0)
			view.draw_colored_polygon(PackedVector2Array([Vector2(x, size.y + 80.0), Vector2(x, y - 130.0), Vector2(x + 25.0, y - 158.0), Vector2(x + 63.0, y - 158.0), Vector2(x + 88.0, y - 129.0), Vector2(x + 88.0, size.y + 80.0)]), color_value)
			view.draw_rect(Rect2(x + 10.0, y - 101.0, 65.0, 14.0), color_value.lightened(0.05))
			view.draw_line(Vector2(x + 21.0, y - 87.0), Vector2(x + 21.0, size.y), Color(0.52, 0.45, 0.7, 0.13), 2.0, true)
			var lintel: PackedVector2Array = PackedVector2Array([Vector2(x + 63.0, y - 95.0), Vector2(x + spacing - 58.0, y - 95.0), Vector2(x + spacing - 81.0, y - 68.0), Vector2(x + 84.0, y - 68.0)])
			view.draw_colored_polygon(lintel, color_value)
			for glyph: int in range(3):
				var gp: Vector2 = Vector2(x + 43.0, y + float(glyph) * 56.0)
				view.draw_polyline(PackedVector2Array([gp + Vector2(-6.0, -7.0), gp + Vector2(6.0, -7.0), gp + Vector2(0.0, 7.0), gp + Vector2(-6.0, -7.0)]), Color(0.48, 0.81, 0.81, 0.14), 1.0, true)
	# Central hub energy lines extend with the physical width of the map.
	var hub_x: float = size.x * 0.5 + (world.x * 0.5 - camera.x) * 0.13
	view.draw_line(Vector2(hub_x, 0.0), Vector2(hub_x, size.y), Color(0.4, 0.88, 0.9, 0.025), 31.0)
	view.draw_line(Vector2(hub_x, 0.0), Vector2(hub_x, size.y), Color(0.48, 0.88, 0.9, 0.06), 2.0)


static func platform(view: Node2D, rectangle: Rect2, index: int, biome: String, time: float, size: Vector2, world: Vector2) -> void:
	var p: Vector2 = view.world_to_screen(rectangle.position)
	var width: float = rectangle.size.x
	var floor_piece: bool = rectangle.size.y > 60.0 or rectangle.position.y >= world.y - 160.0
	if p.x + width < -70.0 or p.x > size.x + 70.0 or p.y > size.y + 140.0 or (not floor_piece and p.y < -150.0):
		return
	var depth: float = maxf(rectangle.size.y, 31.0) if not floor_piece else maxf(size.y - p.y + 80.0, rectangle.size.y)
	var left: float = maxf(p.x, -100.0)
	var right: float = minf(p.x + width, size.x + 100.0)
	if biome == "canyon":
		view.draw_colored_polygon(PackedVector2Array([Vector2(left, p.y + 3.0), Vector2(right, p.y + 3.0), Vector2(right - 6.0, p.y + depth * 0.6), Vector2(right - 21.0, p.y + depth), Vector2(left + 17.0, p.y + depth - 6.0), Vector2(left + 5.0, p.y + depth * 0.5)]), Color("362b2c"))
		view.draw_colored_polygon(PackedVector2Array([Vector2(left + 1.0, p.y + 4.0), Vector2(right - 1.0, p.y + 4.0), Vector2(right - 12.0, p.y + 17.0), Vector2(left + 9.0, p.y + 21.0)]), Color("775443"))
		view.draw_line(Vector2(left, p.y + 1.0), Vector2(right, p.y + 1.0), Color("d3a275"), 3.0, true)
		for seam: int in range(maxi(1, int(depth / 17.0))):
			var y: float = p.y + 19.0 + float(seam) * 17.0
			view.draw_line(Vector2(left + 13.0, y), Vector2(right - 17.0, y - 3.0), Color(0.6, 0.4, 0.3, 0.24), 1.5, true)
		for stone: int in range(maxi(1, int((right - left) / 82.0))):
			var x: float = left + 28.0 + float(stone) * 82.0
			view.draw_polyline(PackedVector2Array([Vector2(x, p.y + 6.0), Vector2(x - 4.0, p.y + 17.0), Vector2(x + 10.0, p.y + 27.0)]), Color("433b35"), 2.0, true)
			if (stone + index) % 4 == 0:
				view.draw_colored_polygon(PackedVector2Array([Vector2(x, p.y), Vector2(x - 7.0, p.y - 8.0), Vector2(x - 4.0, p.y - 17.0), Vector2(x + 5.0, p.y - 4.0), Vector2(x + 10.0, p.y - 11.0), Vector2(x + 13.0, p.y)]), Color("a37359"))
		if not floor_piece and index % 3 == 0:
			view.draw_line(Vector2(left + 35.0, p.y + 22.0), Vector2(left + 33.0, p.y + 69.0), Color("796151"), 1.5, true)
			view.draw_circle(Vector2(left + 33.0, p.y + 72.0), 4.0, Color("987157"), false, 1.0, true)
	else:
		view.draw_colored_polygon(PackedVector2Array([Vector2(left, p.y + 3.0), Vector2(right, p.y + 3.0), Vector2(right - 11.0, p.y + depth), Vector2(left + 11.0, p.y + depth)]), Color("181c30"))
		view.draw_rect(Rect2(left + 4.0, p.y + 5.0, right - left - 8.0, 10.0), Color("404058"))
		view.draw_line(Vector2(left + 1.0, p.y + 1.0), Vector2(right - 1.0, p.y + 1.0), Color("b5b3e4"), 3.0, true)
		view.draw_line(Vector2(left + 9.0, p.y + 16.0), Vector2(right - 9.0, p.y + 16.0), Color("746999"), 1.0, true)
		for tile: int in range(maxi(1, int((right - left) / 58.0))):
			var x: float = left + 20.0 + float(tile) * 58.0
			view.draw_line(Vector2(x, p.y + 5.0), Vector2(x, p.y + 13.0), Color("21263b"), 2.0)
			if tile % 2 == 0:
				var gp: Vector2 = Vector2(x + 16.0, p.y + 24.0)
				view.draw_polyline(PackedVector2Array([gp + Vector2(-4.0, -4.0), gp + Vector2(4.0, -4.0), gp + Vector2(0.0, 4.0), gp + Vector2(-4.0, -4.0)]), Color(0.42, 0.85, 0.9, 0.52), 1.0, true)
		if not floor_piece:
			for node_index: int in range(2):
				var x: float = lerpf(left, right, 0.25 + float(node_index) * 0.5)
				var bob: float = sin(time * 0.8 + float(index)) * 2.0
				view.draw_colored_polygon(PackedVector2Array([Vector2(x - 10.0, p.y + depth + 2.0 + bob), Vector2(x + 10.0, p.y + depth + 2.0 + bob), Vector2(x, p.y + depth + 19.0 + bob)]), Color("37344f"))
				view.draw_line(Vector2(x - 5.0, p.y + depth + 5.0 + bob), Vector2(x, p.y + depth + 13.0 + bob), Color(0.47, 0.78, 0.88, 0.45), 1.0, true)


static func landmarks(view: Node2D, entries: Array, biome: String, time: float) -> void:
	for value: Variant in entries:
		var landmark: Dictionary = value
		var p: Vector2 = view.world_to_screen(landmark.get("pos", Vector2.ZERO))
		var scale_value: float = clampf(float(landmark.get("scale", 1.0)), 0.5, 3.0)
		if p.x < -500.0 * scale_value or p.x > view.screen_size.x + 500.0 * scale_value or p.y < -600.0 * scale_value or p.y > view.screen_size.y + 600.0 * scale_value:
			continue
		view.draw_set_transform(p, 0.0, Vector2.ONE * scale_value)
		var kind: String = str(landmark.get("kind", ""))
		if _special_landmark(view, kind, time):
			view.draw_set_transform(Vector2.ZERO)
			continue
		if biome == "rainforest":
			# Monumental split seed-tree; its dim silhouette is deliberately not
			# a traversable-looking platform.
			view.draw_colored_polygon(PackedVector2Array([Vector2(-65,-10),Vector2(-28,-130),Vector2(-45,-315),Vector2(-22,-430),Vector2(-3,-425),Vector2(-9,-255),Vector2(21,-116),Vector2(75,-10)]), Color("123b35"))
			view.draw_colored_polygon(PackedVector2Array([Vector2(5,-14),Vector2(18,-185),Vector2(61,-315),Vector2(80,-343),Vector2(76,-265),Vector2(46,-129),Vector2(66,-10)]), Color("123b35"))
			for root_index: int in range(6):
				var end: Vector2 = Vector2(-180.0 + float(root_index) * 70.0, 20.0 + float(root_index % 2) * 27.0)
				view.draw_polyline(PackedVector2Array([Vector2(0,-100),end * 0.55 + Vector2(0,-40),end]), Color("184c40"), 7.0, true)
			var core: Vector2 = Vector2(9.0, -215.0)
			view.draw_colored_polygon(PackedVector2Array([core+Vector2(0,-34),core+Vector2(13,0),core+Vector2(0,30),core+Vector2(-9,0)]), Color(0.42, 0.74, 0.48, 0.37))
		elif biome == "canyon":
			# An abandoned lift wheel and diagonal stays emphasize traversal.
			view.draw_line(Vector2(-80,70),Vector2(-80,-235),Color("51413a"),8.0,true)
			view.draw_line(Vector2(80,70),Vector2(80,-235),Color("51413a"),8.0,true)
			view.draw_line(Vector2(-80,-210),Vector2(80,-210),Color("69503d"),7.0,true)
			view.draw_line(Vector2(-70,50),Vector2(70,-205),Color("4b3d38"),4.0,true)
			view.draw_arc(Vector2(0,-208),59.0,0.0,TAU,50,Color("70543c"),7.0,true)
			for spoke: int in range(8):
				var end: Vector2 = Vector2(0,-208) + Vector2.from_angle(float(spoke)*TAU/8.0)*55.0
				view.draw_line(Vector2(0,-208),end,Color("70543c"),2.0,true)
			view.draw_line(Vector2(-56,-208),Vector2(-56,400),Color("6a5242"),2.0,true)
			view.draw_line(Vector2(56,-208),Vector2(56,400),Color("6a5242"),2.0,true)
		else:
			# Large broken phase engine centered on the hub/branch junction.
			var center: Vector2 = Vector2(0,-100)
			for radius: float in [90.0,118.0,151.0]:
				for segment: int in range(4):
					var start: float = float(segment) * PI * 0.5 + time * 0.015
					view.draw_arc(center,radius,start,start+1.18,24,Color("413d61"),10.0 if radius>120.0 else 4.0,true)
			view.draw_line(center+Vector2(0,-125),center+Vector2(0,125),Color(0.45,0.86,0.9,0.17),2.0,true)
			view.draw_line(center+Vector2(-125,0),center+Vector2(125,0),Color(0.45,0.86,0.9,0.17),2.0,true)
			view.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-49),center+Vector2(32,0),center+Vector2(0,49),center+Vector2(-32,0)]),Color("345360"))
			view.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-32),center+Vector2(12,0),center+Vector2(0,32),center+Vector2(-12,0)]),Color(0.63,0.92,0.9,0.45))
		view.draw_set_transform(Vector2.ZERO)


static func _special_landmark(view: Node2D, kind: String, time: float) -> bool:
	match kind:
		"waterfall":
			view.draw_colored_polygon(PackedVector2Array([Vector2(-94,70),Vector2(-79,-290),Vector2(-51,-335),Vector2(18,-350),Vector2(79,-310),Vector2(97,70)]),Color("163c3c"))
			for stream: int in range(6):
				var x: float = -42.0+float(stream)*16.0
				view.draw_line(Vector2(x,-315),Vector2(x+sin(float(stream))*9.0,83),Color(0.39,0.8,0.72,0.09),9.0,true)
				var y: float = fposmod(time*70.0+float(stream)*61.0,390.0)-315.0
				view.draw_line(Vector2(x,y),Vector2(x+2,y+65),Color(0.6,0.93,0.83,0.19),1.5,true)
			for ripple: int in range(3):
				view.draw_arc(Vector2(0,83),60.0+float(ripple)*18.0,PI,TAU,24,Color(0.47,0.84,0.74,0.16),2.0,true)
		"observatory":
			for side: float in [-1.0,1.0]:
				view.draw_line(Vector2(side*70,85),Vector2(side*39,-96),Color("234c42"),7.0,true)
				view.draw_line(Vector2(side*39,-96),Vector2(-side*40,20),Color("234c42"),3.0,true)
			view.draw_arc(Vector2(0,-123),65.0,0.3,PI-0.3,28,Color("315b4c"),8.0,true)
			view.draw_line(Vector2(0,-101),Vector2(14,-166),Color("4d7860"),3.0,true)
			view.draw_circle(Vector2(14,-166),4.0,Color("8aad7d"),true,-1.0,true)
		"crown":
			view.draw_line(Vector2(0,80),Vector2(0,-175),Color("245244"),11.0,true)
			for petal: int in range(9):
				var angle: float = float(petal)*TAU/9.0-PI*0.5
				var axis: Vector2 = Vector2.from_angle(angle)
				var normal: Vector2 = axis.orthogonal()
				var c: Vector2 = Vector2(0,-170)
				view.draw_colored_polygon(PackedVector2Array([c+axis*20,c+axis*76+normal*24,c+axis*117,c+axis*76-normal*24]),Color("356a50"))
				view.draw_line(c+axis*25,c+axis*105,Color(0.63,0.83,0.47,0.29),1.5,true)
			view.draw_circle(Vector2(0,-170),23.0,Color("668861"),true,-1.0,true)
		"crystal_cave":
			for shard: int in range(6):
				var x: float = -115.0+float(shard)*47.0
				var height: float = 85.0+absf(sin(float(shard)*7.4))*155.0
				view.draw_colored_polygon(PackedVector2Array([Vector2(x-20,30),Vector2(x-25,-height*0.8),Vector2(x,-height),Vector2(x+25,-height*0.8),Vector2(x+16,30)]),Color("31565b"))
				view.draw_line(Vector2(x,-height+7),Vector2(x-2,15),Color(0.43,0.75,0.78,0.38),2.0,true)
				view.draw_line(Vector2(x,-height),Vector2(x+25,-height*0.8),Color(0.56,0.8,0.79,0.5),1.0,true)
		"obelisk", "beacon":
			view.draw_colored_polygon(PackedVector2Array([Vector2(-50,50),Vector2(-38,-250),Vector2(0,-310),Vector2(38,-250),Vector2(50,50)]),Color("493e3c"))
			view.draw_line(Vector2(0,-290),Vector2(0,20),Color("8c7154"),2.0,true)
			for glyph: int in range(5):
				var y: float = -217.0+float(glyph)*41.0
				view.draw_polyline(PackedVector2Array([Vector2(-9,y-6),Vector2(9,y-6),Vector2(0,y+8)]),Color(0.69,0.66,0.44,0.42),2.0,true)
			if kind=="beacon":
				view.draw_colored_polygon(PackedVector2Array([Vector2(-9,-293),Vector2(9,-293),Vector2(77,-650),Vector2(-77,-650)]),Color(0.53,0.78,0.83,0.045))
				view.draw_circle(Vector2(0,-303),9.0,Color("a4c7b6"),true,-1.0,true)
		"chasm":
			for side: float in [-1.0,1.0]:
				view.draw_colored_polygon(PackedVector2Array([Vector2(side*40,240),Vector2(side*65,-260),Vector2(side*102,-299),Vector2(side*152,-230),Vector2(side*195,240)]),Color("3b3136"))
				view.draw_line(Vector2(side*65,-230),Vector2(side*46,220),Color("6d5041"),2.0,true)
		"archive", "crypt":
			for pillar: int in range(5):
				var x: float = -144.0+float(pillar)*72.0
				view.draw_rect(Rect2(x-16,-215,32,280),Color("302e48"))
				view.draw_line(Vector2(x-7,-204),Vector2(x-7,55),Color("504660"),2.0,true)
			view.draw_colored_polygon(PackedVector2Array([Vector2(-180,-215),Vector2(0,-295),Vector2(180,-215),Vector2(166,-195),Vector2(0,-267),Vector2(-166,-195)]),Color("444058"))
			if kind=="archive":
				for glyph: int in range(11):
					var x: float = -130.0+float(glyph)*26.0
					view.draw_line(Vector2(x,-133),Vector2(x+8,-116),Color(0.59,0.83,0.85,0.26),2.0,true)
			else:
				view.draw_colored_polygon(PackedVector2Array([Vector2(-22,30),Vector2(-27,-95),Vector2(0,-118),Vector2(27,-95),Vector2(22,30)]),Color("4c465e"))
		"reactor":
			view.draw_rect(Rect2(-52,-260,104,290),Color("26263e"))
			for band: int in range(5):
				var y: float = -240.0+float(band)*60.0
				view.draw_line(Vector2(-67,y),Vector2(67,y),Color("555174"),9.0,true)
			view.draw_rect(Rect2(-17,-237,34,260),Color(0.37,0.71,0.82,0.14))
			view.draw_line(Vector2(0,-237),Vector2(0,17),Color(0.57,0.86,0.9,0.52),3.0,true)
		_:
			return false
	return true


static func atmosphere(view: Node2D, biome: String, camera: Vector2, size: Vector2, time: float) -> void:
	if biome == "rainforest":
		return
	for index: int in range(40):
		var x: float = fposmod(float(index) * 197.32 - camera.x * 0.16 + time * (9.0 if biome == "canyon" else 1.8), size.x)
		var y: float = fposmod(float(index) * 83.61 - camera.y * 0.14 - time * (3.0 if biome == "canyon" else 10.0), size.y)
		if biome == "canyon":
			view.draw_line(Vector2(x,y),Vector2(x+4.0,y-1.0),Color(0.94,0.68,0.39,0.16),1.0,true)
		else:
			var alpha: float = 0.15 + sin(time + float(index)) * 0.08
			view.draw_colored_polygon(PackedVector2Array([Vector2(x,y-2),Vector2(x+1.5,y),Vector2(x,y+2),Vector2(x-1.5,y)]),Color(0.64,0.66,0.94,alpha))
