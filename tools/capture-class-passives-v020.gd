extends SceneTree

const Locale = preload("res://scripts/localization.gd")
const Content = preload("res://scripts/content.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Appearance = preload("res://scripts/player_appearance.gd")
const DIRECTORY: String = "res://tools/results/class-passives-v020/"
var view: SubViewport
var game: Node
var count: int = 0

class NewItems extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720), Color("08161d"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(36,52), "SOMESIDE / AUTOMATIC ABILITIES + TRIGGERED RELICS", HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e4e6ce"))
		var ids: Array[String] = ["pursuit_protocol", "reactive_plating", "missile_pod", "landing_coil", "frost_halo"]
		for index: int in range(ids.size()):
			var id: String = ids[index]
			var p := Vector2(40 + index * 244, 106)
			draw_rect(Rect2(p, Vector2(226,508)), Color("10232b"))
			draw_texture(Icons.texture(id,128), p + Vector2(48,32))
			draw_texture(Icons.texture(id,64), p + Vector2(20,196))
			draw_texture(Icons.texture(id,34), p + Vector2(105,214))
			draw_texture(Icons.pickup_texture(id,24), p + Vector2(171,219))
			draw_string(font,p+Vector2(14,303),id,HORIZONTAL_ALIGNMENT_LEFT,204,17,Color("e2e0cf"))
			draw_string(font,p+Vector2(14,330),"128 / 64 / HUD 34 / ground 24",HORIZONTAL_ALIGNMENT_LEFT,205,12,Color("829e9f"))
			if index >= 2:
				var descriptor: Array = Appearance.build({id: 1})
				var piece: Dictionary = Appearance._piece(descriptor[0])
				var extent: Vector2 = piece.texture.get_size() * 4.0
				draw_texture_rect(piece.texture,Rect2(p+Vector2(113,419)-extent*0.5,extent),false)
				draw_string(font,p+Vector2(14,484),"Wearable part / 4x",HORIZONTAL_ALIGNMENT_LEFT,200,13,Color("829e9f"))

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This is a native visual capture")
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	view = SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://main.tscn").instantiate()
	game._smoke = "class-passive-capture"
	view.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	game.profile.name = "Pilot"
	for language: String in ["zh", "en"]:
		Locale.set_language(language)
		game._show_menu()
		game.world.set_frame(game.sim.get_snapshot(),1,1)
		game.world.queue_redraw()
		game._show_characters()
		await _save(language + "-characters")
		game._show_guide()
		await _save(language + "-guide")
		for character: String in ["ranger", "vanguard"]:
			game._begin_local([{"id":1,"name":"Pilot","character":character}],2001)
			var player: Dictionary = game.sim.state.players[1]
			for id: String in ["missile_pod", "landing_coil", "frost_halo"]: game.sim._grant_item(player,id)
			player.shield = 12.5
			player.reactive_shield = 10.0 if character == "vanguard" else 0.0
			game._update_hud()
			game.world.set_frame(game.sim.get_snapshot(),1,1)
			game.world.queue_redraw()
			game._show_inventory()
			await _save(language + "-" + character + "-build")
			game._populate_inventory("passive")
			var scroll: ScrollContainer = game._inventory_grid.get_parent()
			for frame: int in range(3): await process_frame
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await _save(language + "-" + character + "-new-relics")
			game._resume()
			for frame: int in range(3): await process_frame
			var mouse := InputEventMouseMotion.new()
			mouse.position = game._slot_ui.dash.icon.get_global_rect().get_center()
			mouse.global_position = mouse.position
			view.push_input(mouse,true)
			game._update_interaction_panel(player)
			await _save(language + "-" + character + "-hover")
			for definition: Dictionary in Content.passives(): player.items[definition.id] = 3
			game._update_hud()
			game._loot_panel.hide()
			await _save(language + "-" + character + "-all-items")
	game.queue_free()
	await process_frame
	var icons := NewItems.new()
	view.add_child(icons)
	await _save("new-icons")
	var unchanged: bool = FileAccess.file_exists("user://profile.cfg") == existed and (not existed or FileAccess.get_file_as_bytes("user://profile.cfg") == saved)
	assert(unchanged, "Capture must preserve the real profile")
	print("CLASS_PASSIVE_CAPTURE_RESULT images=", count, " profile_unchanged=", unchanged)
	quit(0)

func _save(label: String) -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(DIRECTORY+label+".png") == OK)
	count += 1
