extends SceneTree

## Reproducible renderer-only visual verification; does not depend on the UI.
func _initialize() -> void:
	call_deferred("_preview")


func _preview() -> void:
	if OS.get_cmdline_user_args().has("--v05-live"):
		await _v05_live_events()
		return
	if OS.get_cmdline_user_args().has("--v05"):
		await _v05_gallery()
		return
	if OS.get_cmdline_user_args().has("--v04"):
		await _v04_gallery()
		return
	if OS.get_cmdline_user_args().has("--icons"):
		await _icon_gallery()
		return
	var simulation: Variant = load("res://scripts/simulation.gd").new()
	simulation.start_run([{"id": 1, "name": "RANGER", "character": "ranger"}, {"id": 2, "name": "VANGUARD", "character": "vanguard"}], 73519)
	simulation.state["players"][1]["pos"] = Vector2(2420.0, 999.0)
	simulation.state["players"][2]["pos"] = Vector2(2510.0, 999.0)
	simulation.state["players"][1]["aim"] = Vector2(1.0, -0.25).normalized()
	simulation.state["players"][2]["aim"] = Vector2(1.0, -0.05).normalized()
	simulation.state["players"][1]["weapon"] = "railgun"
	simulation.state["players"][2]["weapon"] = "scattergun"
	simulation.state["gate"]["active"] = true
	simulation.state["gate"]["charge"] = 0.56
	simulation.state["enemies"] = [
		{"id": 301, "pos": Vector2(2760.0, 976.0), "vel": Vector2(-30.0, 0.0), "kind": "boss", "hp": 900.0, "max_hp": 1200.0, "elite": false, "telegraph": 0.35},
		{"id": 302, "pos": Vector2(2650.0, 1003.0), "vel": Vector2(-30.0, 0.0), "kind": "crawler", "hp": 28.0, "max_hp": 40.0, "elite": false},
		{"id": 303, "pos": Vector2(2590.0, 880.0), "vel": Vector2(-30.0, 0.0), "kind": "drone", "hp": 40.0, "max_hp": 40.0, "elite": true},
		{"id": 304, "pos": Vector2(2300.0, 1002.0), "vel": Vector2(30.0, 0.0), "kind": "spitter", "hp": 40.0, "max_hp": 40.0, "elite": false},
	]
	simulation.state["projectiles"] = [
		{"id": 501, "pos": Vector2(2480.0, 980.0), "vel": Vector2(950.0, -190.0), "team": "player", "kind": "bullet", "radius": 3.0},
		{"id": 502, "pos": Vector2(2700.0, 950.0), "vel": Vector2(-350.0, -110.0), "team": "enemy", "kind": "boss_orb", "radius": 6.0},
	]
	simulation.state["chests"] = [
		{"id": 601, "pos": Vector2(2030.0, 1003.0), "type": "cache", "opened": false, "item": "moss"},
		{"id": 602, "pos": Vector2(2160.0, 1003.0), "type": "blood", "opened": false, "item": "glass"},
		{"id": 603, "pos": Vector2(2350.0, 1003.0), "type": "choice", "opened": false, "item": "feather"},
		{"id": 604, "pos": Vector2(3020.0, 1003.0), "type": "equipment", "opened": false, "item": "aegis"},
		{"id": 605, "pos": Vector2(3150.0, 1003.0), "type": "combat", "opened": false, "status": "active", "remaining": 4},
	]
	simulation.state["pickups"] = [
		{"id": 701, "pos": Vector2(2240.0, 1002.0), "kind": "item", "item": "glass", "rarity": "rare"},
		{"id": 702, "pos": Vector2(2520.0, 1002.0), "kind": "item", "item": "repair_field", "rarity": "uncommon"},
		{"id": 703, "pos": Vector2(2660.0, 1002.0), "kind": "item", "item": "pulse_rifle", "rarity": "common"},
	]
	var view: SideWorldView = SideWorldView.new()
	root.add_child(view)
	print("ART_FONT axes=" + str(view._font.get_supported_variation_list()))
	root.size = Vector2i(1280, 720)
	view.interaction_target = {"kind": "pickup", "id": 702}
	view.interpolate_remote_entities = true
	view.set_frame(simulation.get_snapshot(), 1, 1.0)
	assert(not view._render_positions.has("p1"), "Local prediction must remain owned by the root")
	var original_remote: Vector2 = simulation.state["players"][2]["pos"]
	simulation.state["players"][2]["pos"] = original_remote + Vector2(20.0, 0.0)
	simulation.state["time"] = 0.05
	view.set_frame(simulation.get_snapshot(), 1, 1.0 / 60.0)
	var smoothed: Vector2 = view._render_positions["p2"]
	assert(smoothed.x > original_remote.x and smoothed.x < original_remote.x + 20.0, "Remote movement must interpolate")
	assert(simulation.state["players"][2]["pos"] == original_remote + Vector2(20.0, 0.0), "Rendering must not mutate simulation")
	simulation.state["stage"] = 2
	view.set_frame(simulation.get_snapshot(), 1, 1.0 / 60.0)
	assert(view._render_positions["p2"] == original_remote + Vector2(20.0, 0.0), "Stage transitions must clear interpolation")
	simulation.state["stage"] = 1
	simulation.state["players"][2]["pos"] = original_remote
	view.interpolate_remote_entities = false
	view.set_frame(simulation.get_snapshot(), 1, 1.0 / 60.0)
	for index: int in range(4):
		await process_frame
	view.push_events([{"type": "slash", "pos": Vector2(2510.0, 999.0), "aim": Vector2.RIGHT}, {"type": "hit", "pos": Vector2(2650.0, 1003.0), "amount": 24, "crit": true, "arc_from": Vector2(2590.0, 880.0)}])
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://tools/world-preview.png")
	var result: int = root.get_texture().get_image().save_png(output)
	print("ART_PREVIEW image=" + output + " result=" + str(result))
	quit(result)


func _v04_gallery() -> void:
	var simulation: Variant = load("res://scripts/simulation.gd").new()
	simulation.start_run([{"id":1,"name":"RANGER","character":"ranger"}],41723)
	var view: SideWorldView = SideWorldView.new()
	root.add_child(view)
	view.set_process(false)
	root.size = Vector2i(1280,720)
	var folder: String = ProjectSettings.globalize_path("res://tools/results")
	DirAccess.make_dir_recursive_absolute(folder)
	var focus: Array[Vector2] = [Vector2(1800,1079),Vector2(1920,2249),Vector2(4150,1659)]
	for stage: int in range(1,4):
		simulation._build_stage(stage)
		var player: Dictionary = simulation.state["players"][1]
		var position_value: Vector2 = focus[stage-1]
		player["pos"] = position_value
		player["aim"] = Vector2(1,-0.08).normalized()
		player["grounded"] = true
		player["weapon"] = "pulse_rifle"
		player["items"] = {"overclock":2,"arc":1}
		simulation.state["enemies"] = [
			{"id":301,"pos":position_value+Vector2(280,-23),"vel":Vector2(-30,0),"kind":"boss","hp":700.0,"max_hp":1200.0,"elite":false,"telegraph":0.35},
			{"id":302,"pos":position_value+Vector2(190,4),"vel":Vector2(-30,0),"kind":"crawler","hp":28.0,"max_hp":40.0,"elite":false},
			{"id":303,"pos":position_value+Vector2(170,-110),"vel":Vector2(-30,0),"kind":"drone","hp":40.0,"max_hp":40.0,"elite":true},
		]
		simulation.state["projectiles"] = [{"id":501,"pos":position_value+Vector2(105,-14),"vel":Vector2(1100,-88),"team":"player","kind":"bullet","radius":3.0,"owner":1,"visual_stacks":3}]
		var snapshot: Dictionary = simulation.get_snapshot()
		var immutable: PackedByteArray = var_to_bytes(snapshot)
		view.set_frame(snapshot,1,1.0)
		view._clock = 1.3
		view.push_events(_showcase_events(position_value,3))
		view._process(0.06)
		assert(var_to_bytes(snapshot)==immutable,"Renderer must never mutate supplied state")
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = folder+"/v04-biome-"+str(stage)+".png"
		assert(root.get_texture().get_image().save_png(output)==OK,"Biome screenshot must save")
		print("ART_BIOME stage="+str(stage)+" biome="+str(snapshot.get("biome"))+" bounds="+str(snapshot.get("world_size"))+" image="+output)
	# Compare equal attacks with only visual stack metadata changed.
	simulation._build_stage(1)
	var player: Dictionary = simulation.state["players"][1]
	var position_value: Vector2 = Vector2(1800,1079)
	player["pos"] = position_value
	player["aim"] = Vector2(1,-0.08).normalized()
	player["grounded"] = true
	player["weapon"] = "pulse_rifle"
	for stacks: int in [0,8]:
		player["items"] = {"overclock":stacks}
		simulation.state["projectiles"] = [
			{"id":501,"pos":position_value+Vector2(130,-16),"vel":Vector2(1100,-88),"team":"player","kind":"bullet","radius":3.0,"owner":1,"visual_stacks":stacks},
			{"id":502,"pos":position_value+Vector2(260,-100),"vel":Vector2(2500,-100),"team":"player","kind":"rail","radius":4.0,"owner":1,"visual_stacks":stacks},
		]
		simulation.state["enemies"] = [{"id":301,"pos":position_value+Vector2(190,4),"vel":Vector2.ZERO,"kind":"crawler","hp":28.0,"max_hp":40.0,"elite":false}]
		view._effects.clear()
		view._numbers.clear()
		view.set_frame(simulation.get_snapshot(),1,1.0)
		view.push_events(_showcase_events(position_value,stacks))
		view._process(0.06)
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = folder+"/v04-fx-"+str(stacks)+".png"
		assert(root.get_texture().get_image().save_png(output)==OK,"Effects comparison screenshot must save")
		print("ART_FX stacks="+str(stacks)+" strength="+str(view.effect_strength({"visual_stacks":stacks}))+" budget="+JSON.stringify(view.visual_budget_stats())+" image="+output)
	var stress: Array = []
	for index: int in range(700):
		stress.append({"type":"hit","pos":position_value,"amount":12,"crit":true,"visual_stacks":1000000,"arc_from":position_value+Vector2(100,0)})
	var snapshot: Dictionary = simulation.get_snapshot()
	var before: PackedByteArray = var_to_bytes(snapshot)
	view.set_frame(snapshot,1,0.01)
	view.fx_scale = 1000.0
	view.push_events(stress)
	var stats: Dictionary = view.visual_budget_stats()
	assert(int(stats.effects)<=384 and int(stats.damage_numbers)<=32,"Four-player effects must be bounded")
	assert(view.effect_strength({"visual_stacks":1000000})<=3.3001,"Extreme stacks/settings must be capped")
	assert(var_to_bytes(snapshot)==before,"Stress effects must preserve snapshot")
	view.shake_enabled = false
	view._shake = 5.0
	view._process(0.001)
	assert(view._shake_offset==Vector2.ZERO,"Shake toggle must disable all visual camera shake")
	print("ART_V04_VERIFIED bounded="+JSON.stringify(stats)+" snapshot_immutable=true shake_toggle=true")
	quit(0)


func _showcase_events(p: Vector2, stacks: int) -> Array:
	return [
		{"type":"shoot","kind":"bullet","pos":p+Vector2(35,-6),"aim":Vector2(1,-0.08).normalized(),"player":1,"visual_stacks":stacks},
		{"type":"hit","pos":p+Vector2(190,4),"amount":24,"crit":true,"arc_from":p+Vector2(170,-110),"owner":1,"visual_stacks":stacks},
		{"type":"slash","pos":p+Vector2(72,2),"aim":Vector2.RIGHT,"radius":100.0,"player":1,"visual_stacks":stacks},
		{"type":"explosion","pos":p+Vector2(400,-10),"radius":105.0,"owner":1,"visual_stacks":stacks},
	]


func _v05_label(parent: Node, text_value: String, p: Vector2, font: Font, size_value: int = 16, tint: Color = Color("dbe9d6")) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.position = p
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",tint)
	parent.add_child(label)


func _v05_save(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path_value: String = ProjectSettings.globalize_path("res://tools/results/"+name_value+".png")
	assert(root.get_texture().get_image().save_png(path_value)==OK,"Preview screenshot must save")
	print("ART_V05 screenshot="+path_value)


func _v05_gallery() -> void:
	var icons = preload("res://scripts/item_icons.gd")
	var content = preload("res://scripts/content.gd")
	var font: FontVariation = FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {2003265652:500.0}
	root.size = Vector2i(1280,720)
	var catalog: Array = content.passives()+content.weapons()+content.equipment()
	assert(catalog.size()==40,"Catalog should have all 40 entries")
	var gallery: Control = Control.new()
	root.add_child(gallery)
	var background: ColorRect = ColorRect.new()
	background.color = Color("081e28")
	background.size = Vector2(1280,720)
	gallery.add_child(background)
	_v05_label(gallery,"SOMESIDE / 40 FIELD ARTIFACTS",Vector2(40,24),font,28)
	_v05_label(gallery,"24 遗物 · 8 主武器 · 8 主动装备     /     每格显示 64 px 与 24 px 实际图标",Vector2(40,68),font,16,Color("95b5b7"))
	var signatures: Dictionary = {}
	for index: int in range(catalog.size()):
		var record: Dictionary = catalog[index]
		var id_value: String = str(record.id)
		var texture_value: Texture2D = icons.texture(id_value,64)
		assert(texture_value == icons.texture(id_value,64),"Icon cache must reuse texture")
		assert(texture_value.get_width()==64,"Exact raster size is required")
		var signature: int = hash(texture_value.get_image().get_data())
		assert(not signatures.has(signature),"Each catalog pictogram must be distinct: "+id_value)
		signatures[signature] = id_value
		var p: Vector2 = Vector2(42.0+float(index%8)*151.0,110.0+float(index/8)*118.0)
		var border: ColorRect = ColorRect.new()
		border.color = content.rarity_color(str(record.rarity))
		border.position = p-Vector2.ONE*1.0
		border.size = Vector2(66,66)
		gallery.add_child(border)
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture_value
		icon.position = p
		icon.size = Vector2(64,64)
		gallery.add_child(icon)
		var small: TextureRect = TextureRect.new()
		small.texture = icons.texture(id_value,24)
		small.position = p+Vector2(84,39)
		small.size = Vector2(24,24)
		gallery.add_child(small)
		_v05_label(gallery,str(record.name),p+Vector2(0,70),font,14)
		_v05_label(gallery,id_value,p+Vector2(0,91),font,11,icons.color(id_value))
		_v05_label(gallery,content.rarity_name(str(record.rarity)),p+Vector2(84,3),font,13,content.rarity_color(str(record.rarity)))
	await _v05_save("v05-icons")
	gallery.queue_free()
	await process_frame
	root.size = Vector2i(1280,720)
	var view: SideWorldView = SideWorldView.new()
	root.add_child(view)
	view.set_process(false)
	view.shake_enabled = false
	var snapshot: Dictionary = {"stage":1,"biome":"rainforest","world_size":Vector2(4000,2000),"spawn":Vector2(2000,1100),"players":{},"platforms":[Rect2(1300,1200,1400,30)],"chests":[],"pickups":[],"projectiles":[],"enemies":[],"gate":{},"landmarks":[],"deployables":[],"effects":[]}
	var overlay: Control = Control.new()
	root.add_child(overlay)
	_v05_label(overlay,"SOMESIDE / 四阶地面信号",Vector2(40,24),font,25)
	_v05_label(overlay,"稀有度由外框、光束和 1–4 个光点表达；图标内部保留物品主题色",Vector2(40,66),font,17,Color("95b5b7"))
	var rarity_ids: Array[String] = ["plating","flamethrower","glass","phoenix"]
	var rarity_keys: Array[String] = ["common","uncommon","rare","legendary"]
	for index: int in range(4):
		var p: Vector2 = Vector2(1550.0+float(index)*290.0,1177.0)
		snapshot.pickups.append({"id":701+index,"pos":p,"kind":"item","item":rarity_ids[index],"rarity":rarity_keys[index],"warning":str(content.definition(rarity_ids[index]).warning)})
		_v05_label(overlay,content.rarity_name(rarity_keys[index]),Vector2(163.0+float(index)*290.0,546),font,19,content.rarity_color(rarity_keys[index]))
	view.set_frame(snapshot,1,1.0)
	view.camera_position = Vector2(2000,1050)
	view.interaction_target = {"kind":"pickup","id":703}
	view.queue_redraw()
	var snapshot_before: PackedByteArray = var_to_bytes(snapshot)
	await _v05_save("v05-rarity")
	assert(var_to_bytes(snapshot)==snapshot_before,"Ground loot renderer must not mutate input")
	overlay.queue_free()
	await process_frame
	overlay = Control.new()
	root.add_child(overlay)
	_v05_label(overlay,"SOMESIDE / 八种武器 · 实际角色与弹道",Vector2(40,24),font,25)
	snapshot.pickups = []
	snapshot.players = {}
	snapshot.platforms = [Rect2(1320,1030,1360,24),Rect2(1320,1300,1360,24)]
	var weapon_ids: Array[String] = ["pulse_rifle","arc_blade","scattergun","railgun","flamethrower","boomerang","storm_staff","sun_lance"]
	var events: Array = []
	for index: int in range(8):
		var p: Vector2 = Vector2(1460+float(index%4)*295,1009+float(index/4)*270)
		var weapon: String = weapon_ids[index]
		snapshot.players[index+1] = {"id":index+1,"pos":p,"vel":Vector2.ZERO,"aim":Vector2.RIGHT,"character":"ranger","weapon":weapon,"grounded":true,"dead":false,"items":{}}
		_v05_label(overlay,str(content.definition(weapon).name),Vector2(84+float(index%4)*295,380+float(index/4)*270),font,17,icons.color(weapon))
		if weapon in ["arc_blade","flamethrower"]:
			events.append({"type":"slash","pos":p,"aim":Vector2.RIGHT,"kind":"flame" if weapon=="flamethrower" else "blade","radius":150.0 if weapon=="flamethrower" else 82.0})
		else:
			var kind: String = {"pulse_rifle":"bullet","scattergun":"pellet","railgun":"rail","boomerang":"boomerang","storm_staff":"storm","sun_lance":"lance"}.get(weapon,"bullet")
			snapshot.projectiles.append({"id":801+index,"pos":p+Vector2(160,-7),"vel":Vector2(2100 if kind=="rail" else 1100,0),"team":"player","kind":kind,"radius":6.0 if kind=="storm" else 3.0})
			events.append({"type":"shoot","pos":p+Vector2(45,-5),"aim":Vector2.RIGHT,"kind":weapon})
			if weapon == "scattergun":
				for side: int in [-1,1]:
					snapshot.projectiles.append({"id":830+side,"pos":p+Vector2(150,float(side)*15-7),"vel":Vector2(1000,side*100),"team":"player","kind":"pellet","radius":2.0})
	view.interaction_target = {}
	view.set_frame(snapshot,1,1.0)
	view.camera_position = Vector2(2000,1050)
	view.push_events(events)
	view._process(0.065)
	snapshot_before = var_to_bytes(snapshot)
	await _v05_save("v05-weapons")
	assert(var_to_bytes(snapshot)==snapshot_before,"Weapon render must remain read-only")
	overlay.queue_free()
	await process_frame
	overlay = Control.new()
	root.add_child(overlay)
	_v05_label(overlay,"SOMESIDE / 新主动装备 · 局部战场反馈",Vector2(40,24),font,25)
	snapshot.players = {1:{"id":1,"pos":Vector2(2460,1179),"vel":Vector2.ZERO,"aim":Vector2.RIGHT,"character":"ranger","weapon":"storm_staff","chrono_timer":5.0,"items":{}}}
	snapshot.platforms = [Rect2(1300,1200,1400,30)]
	snapshot.projectiles = []
	snapshot.deployables = [{"id":901,"pos":Vector2(1850,1186),"ttl":5.0,"kind":"turret"}]
	snapshot.effects = [{"id":902,"pos":Vector2(2190,1090),"delay":0.45,"radius":120.0,"kind":"meteor"}]
	snapshot.enemies = [{"id":903,"pos":Vector2(1550,1179),"kind":"crawler","hp":40.0,"max_hp":40.0,"stun_timer":0.5,"poison_timer":2.0,"burn_timer":1.0,"slow_timer":1.0}]
	view._effects.clear()
	view._numbers.clear()
	view.set_frame(snapshot,1,1.0)
	view.camera_position = Vector2(2000,1050)
	view.push_events([{"type":"explosion","kind":"graviton","pos":Vector2(1550,1100),"radius":140.0},{"type":"explosion","kind":"meteor","pos":Vector2(2190,1175),"radius":90.0}])
	view._process(0.12)
	for index: int in range(4):
		_v05_label(overlay,["引力囚笼","哨戒构装","天穹陨击","时序王冠"][index],Vector2(160+float(index)*300,574),font,19)
	await _v05_save("v05-equipment")
	print("ART_V05_VERIFIED catalog=40 unique_icons=40 shared_rarity_palette=true snapshot_immutable=true budget="+JSON.stringify(view.visual_budget_stats()))
	quit(0)


func _v05_live_events() -> void:
	# Exercise authoritative events and replicated state, rather than rebuilding
	# their shapes in the preview. This only writes into its isolated simulation.
	var simulation: Variant = load("res://scripts/simulation.gd").new()
	simulation.start_run([{"id":1,"name":"RENDER CHECK","character":"ranger"}],71532)
	var player: Dictionary = simulation.state.players[1]
	player.pos = Vector2(900,1799)
	player.aim = Vector2.RIGHT
	player.items = {"overclock":2,"capacitor":2,"arc":2,"ember":2}
	var view: SideWorldView = SideWorldView.new()
	root.add_child(view)
	view.set_process(false)
	view.shake_enabled = false
	var seen: Dictionary = {}
	var actions: int = 0
	for category: String in ["weapon","equipment"]:
		var catalog: Array = simulation.weapon_catalog() if category=="weapon" else simulation.equipment_catalog()
		for entry: Dictionary in catalog:
			simulation.events.clear()
			simulation.state.projectiles = []
			simulation.state.enemies = []
			simulation.state.deployables = []
			simulation.state.effects = []
			player[category] = str(entry.id)
			if category=="weapon": simulation._fire_weapon(player)
			else: simulation._use_skill(player)
			var snapshot: Dictionary = simulation.get_snapshot()
			var events: Array = simulation.events.duplicate(true)
			var original_snapshot: PackedByteArray = var_to_bytes(snapshot)
			var original_events: PackedByteArray = var_to_bytes(events)
			view._effects.clear()
			view._numbers.clear()
			view.set_frame(snapshot,1,1.0)
			view.push_events(events)
			view._process(0.03)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(var_to_bytes(snapshot)==original_snapshot,"Render must preserve authoritative snapshot: "+str(entry.id))
			assert(var_to_bytes(events)==original_events,"Render must preserve input events: "+str(entry.id))
			assert(view._effects.size()<=view.MAX_EFFECTS,"All new visual branches must share the budget")
			for event: Dictionary in events:
				seen[str(event.get("type",""))+":"+str(event.get("kind",""))] = true
			if str(entry.id)=="meteor":
				simulation.events.clear()
				simulation._step_effects(1.3)
				view.push_events(simulation.events)
				view._process(0.06)
				await process_frame
				await RenderingServer.frame_post_draw
			actions += 1
	print("ART_V05_LIVE_VERIFIED actions="+str(actions)+" input_immutable=true shared_budget=true events="+JSON.stringify(seen.keys()))
	quit(0)


func _icon_gallery() -> void:
	var icons = preload("res://scripts/item_icons.gd")
	var ids: Array[String] = ["overclock", "capacitor", "lens", "vitality", "thruster", "arc", "ember", "moss", "siphon", "coolant", "feather", "glass", "pulse_rifle", "arc_blade", "scattergun", "railgun", "grenade", "shockwave", "repair_field", "aegis", "dash", "cache", "choice", "blood", "combat", "equipment_cache", "gate", "revive"]
	root.size = Vector2i(1280, 720)
	var background: ColorRect = ColorRect.new()
	background.color = Color("081e28")
	background.size = Vector2(1280.0, 720.0)
	root.add_child(background)
	var title: Label = Label.new()
	title.text = "SOMESIDE / FIELD EQUIPMENT"
	title.position = Vector2(44.0, 26.0)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("dbe9d6"))
	root.add_child(title)
	var signatures: Dictionary = {}
	for index: int in range(ids.size()):
		var id_value: String = ids[index]
		var texture_value: Texture2D = icons.texture(id_value, 96)
		assert(texture_value == icons.texture(id_value, 96), "Icon textures must be cached")
		assert(texture_value.get_width() == 96 and texture_value.get_height() == 96, "Requested icon resolution must be exact")
		var checksum: int = hash(texture_value.get_image().get_data())
		assert(not signatures.has(checksum), "Every icon must have a unique silhouette: " + id_value)
		signatures[checksum] = id_value
		var grid_p: Vector2 = Vector2(70.0 + float(index % 7) * 173.0, 99.0 + float(index / 7) * 146.0)
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture_value
		icon.position = grid_p
		icon.size = Vector2(96.0, 96.0)
		root.add_child(icon)
		var small: TextureRect = TextureRect.new()
		small.texture = icons.texture(id_value, 24)
		small.position = grid_p + Vector2(109.0, 69.0)
		small.size = Vector2(24.0, 24.0)
		root.add_child(small)
		var label: Label = Label.new()
		label.text = id_value
		label.position = grid_p + Vector2(-6.0, 109.0)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", icons.color(id_value))
		root.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://tools/icon-preview.png")
	var result: int = root.get_texture().get_image().save_png(output)
	print("ART_ICONS verified=" + str(ids.size()) + " image=" + output + " result=" + str(result))
	quit(result)
