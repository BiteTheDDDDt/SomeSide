extends SceneTree

const Icons = preload("res://scripts/item_icons.gd")
const Content = preload("res://scripts/content.gd")
const Locale = preload("res://scripts/localization.gd")

var game: Node
var passed: int = 0
var failed: int = 0
var profile_before: String = ""
var profile_existed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	profile_existed = FileAccess.file_exists("user://profile.cfg")
	profile_before = FileAccess.get_file_as_string("user://profile.cfg") if profile_existed else ""
	var scene: PackedScene = load("res://main.tscn")
	game = scene.instantiate()
	# Set before _ready: this suppresses profile writes, window mode changes,
	# audio and normal human input without triggering host/client automation.
	game.set("_smoke", "ui")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	# Ambient playback may already have started in its child _ready. Drain it
	# before the test exits so the headless audio server releases playback.
	game.get("sound").call("shutdown")
	Locale.set_language("zh")
	game.set("profile", {"name": "UI Traveller", "language": "zh", "character": "ranger", "volume": 0.0, "effects": 1.0, "shake": true, "fullscreen": false, "runs": 0, "best_stage": 0, "wins": 0})
	game.call("_show_menu")
	await _layout()
	_check(str(game.get("screen")) == "menu", "Main scene opens the title menu")
	_check_page_bounds("menu")
	await _press("选择角色")
	_check(str(game.get("screen")) == "characters", "Character button opens character selection")
	_check_page_bounds("characters")
	var portraits: Array = _find_type(game.get("ui"), "TextureRect")
	_check(portraits.size() == 2 and portraits[0].texture != null and portraits[1].texture != null, "Character selection shows both actual packaged character portraits")
	await _press("选择", true)
	_check(str(Dictionary(game.get("profile")).character) == "vanguard", "Selecting the second character changes the local profile")
	await _press("返回", true)
	_check(str(game.get("screen")) == "menu", "Character selection returns to the menu")
	await _press("操作指南")
	_check(str(game.get("screen")) == "guide", "The operation guide opens")
	_check_page_bounds("guide")
	_check(_all_labels_ignore_mouse(game.get("ui")), "Guide text does not intercept pointer input")
	var guide_text: String = ""
	for label in _find_type(game.get("ui"), "Label"):
		guide_text += label.text + "\n"
	_check((guide_text.contains("羽毛") or guide_text.contains("羽翼")) and not guide_text.contains("空中可再次跳跃"), "Guide explains single-jump progression without the obsolete free double jump")
	await _press("返回")
	await _press("设置", true)
	_check(str(game.get("screen")) == "settings", "Settings opens from the menu")
	_check_page_bounds("settings")
	var fields: Array = _find_type(game.get("ui"), "LineEdit")
	_check(fields.size() == 1, "Settings exposes one traveller name field")
	if not fields.is_empty():
		var field: LineEdit = fields[0]
		field.text = "UI Pilot"
		field.text_changed.emit(field.text)
	_check(str(Dictionary(game.get("profile")).name) == "UI Pilot", "Name edits update the active profile")
	var sliders: Array = _find_type(game.get("ui"), "HSlider")
	_check(sliders.size() == 2, "Settings exposes separate volume and visual-intensity sliders")
	if not sliders.is_empty():
		var slider: HSlider = sliders[0]
		slider.value = 0.25
	_check(is_equal_approx(float(Dictionary(game.get("profile")).volume), 0.25), "Volume changes update the profile")
	if sliders.size() > 1:
		var effects: HSlider = sliders[1]
		effects.value = 1.4
	_check(is_equal_approx(float(game.get("profile").effects), 1.4) and is_equal_approx(float(game.get("world").fx_scale), 1.4), "Effect intensity edits update both the profile and live renderer")
	await _press("镜头震动")
	_check(not bool(game.get("profile").shake) and not bool(game.get("world").shake_enabled), "The shake toggle disables camera motion in the actual renderer")
	await _press("返回", true)
	await _press("加入房间")
	_check(str(game.get("screen")) == "join", "Join room opens the address form")
	_check_page_bounds("join")
	await _press("返回", true)
	await _press("单人游戏")
	_check(str(game.get("screen")) == "playing", "Starting solo creates a playable run")
	var simulation = game.get("sim")
	_check(str(simulation.state.players[1].character) == "vanguard" and str(simulation.state.players[1].name) == "UI Pilot", "The run uses the selected character and edited name")
	_check(str(simulation.state.phase) == "playing" and not bool(game.get("paused")), "A new run is active and unpaused")
	_check(game.get("ui").mouse_filter == Control.MOUSE_FILTER_IGNORE, "The root UI surface passes gameplay mouse input through")
	_check_hud_mouse_filters()
	_check_hud_bounds()
	simulation.call("_grant_item", simulation.state.players[1], "overclock")
	simulation.call("_grant_item", simulation.state.players[1], "overclock")
	await _test_compact_hud(simulation)
	await _test_owned_strip(simulation)
	await _test_overlap_selection(simulation)
	_test_network_interaction_aggregation(simulation)
	await _test_map_overlay(simulation)
	await _send_key(KEY_TAB)
	_check(bool(game.get("paused")), "Tab opens the inventory and pauses solo play")
	_check_page_bounds("inventory")
	_check(str(game.get("_inventory_filter")) == "owned" and game.get("_inventory_grid").get_child_count() == simulation.state.players[1].items.size() + 4, "Tab initially lists both innate abilities, the two equipped slots and actually owned relics")
	game.get("_inventory_filters").passive.pressed.emit()
	await _layout()
	_check(str(game.get("_inventory_filter")) == "passive", "The passive filter button opens the complete relic catalogue")
	var catalogue: Array = simulation.call("item_catalog")
	var inventory_labels: Array = _find_type(game.get("overlay"), "Label")
	var descriptions_found: int = 0
	var shows_stack_count: bool = false
	var final_description: Label = null
	for item_value in catalogue:
		var item: Dictionary = item_value
		for label_value in inventory_labels:
			var label: Label = label_value
			if label.text == str(item.description):
				descriptions_found += 1
				final_description = label
			if label.text.replace(" ", "").contains("×2"):
				shows_stack_count = true
	_check(descriptions_found == catalogue.size(), "The inventory contains every current passive description")
	_check(shows_stack_count, "The inventory displays stacked ownership counts")
	var glass_warning = str(simulation.call("loot_definition", "glass").warning)
	var shows_warning = false
	for label in inventory_labels:
		shows_warning = shows_warning or (not glass_warning.is_empty() and label.text.contains(glass_warning))
	_check(shows_warning, "The inventory explicitly displays the harmful relic's downside")
	_check(_find_type(game.get("_inventory_grid"), "TextureRect").size() == catalogue.size(), "The passive catalogue gives every relic its own icon without unrelated equipment cards")
	var scrolls: Array = _find_type(game.get("overlay"), "ScrollContainer")
	_check(scrolls.size() == 1, "The item catalogue uses a scrollable region")
	if not scrolls.is_empty():
		var scroll: ScrollContainer = scrolls[0]
		_check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "The inventory scroll range exposes content beyond the first page")
		scroll.scroll_vertical = 100000
		await _layout()
		_check(final_description != null and scroll.get_global_rect().encloses(final_description.get_global_rect()), "Scrolling to the end makes the final relic description readable")
	for category in ["weapon", "equipment"]:
		game.get("_inventory_filters")[category].pressed.emit()
		await _layout()
		var definitions: Array = simulation.call("weapon_catalog" if category == "weapon" else "equipment_catalog")
		var found: int = 0
		var last_description: Label = null
		for definition in definitions:
			for label in _find_type(game.get("_inventory_grid"), "Label"):
				if label.text == str(definition.description):
					found += 1
					last_description = label
		_check(found == 8 and game.get("_inventory_grid").get_child_count() == 8, "The %s filter exposes all eight actual item descriptions" % category)
		var category_scroll: ScrollContainer = game.get("_inventory_grid").get_parent()
		category_scroll.scroll_vertical = 100000
		await _layout()
		_check(last_description != null and category_scroll.get_global_rect().encloses(last_description.get_global_rect()), "The final %s description remains readable by scrolling" % category)
	await _send_key(KEY_TAB)
	_check(not bool(game.get("paused")) and not is_instance_valid(game.get("overlay")), "Tab closes the inventory and resumes gameplay")
	_check_hud_mouse_filters()
	game.call("_show_pause")
	await _layout()
	_check(bool(game.get("paused")), "Pause opens a modal menu and pauses solo play")
	_check_page_bounds("pause")
	var paused_time: float = simulation.state.time
	game.call("_physics_process", 1.0 / 60.0)
	_check(is_equal_approx(float(simulation.state.time), paused_time), "A paused solo physics tick does not advance the run")
	await _press("继续游戏")
	_check(not bool(game.get("paused")), "Resume clears pause")
	_check(not is_instance_valid(game.get("overlay")), "Resume removes the modal overlay")
	_check_hud_mouse_filters()
	game.call("_physics_process", 1.0 / 60.0)
	_check(float(simulation.state.time) > paused_time, "Simulation advances again after resuming")
	# Exercise the real frame-driven game-over route rather than calling the
	# result-page builder directly.
	simulation.state.players[1].hp = 0.0
	simulation.state.players[1].dead = true
	game.call("_physics_process", 1.0 / 60.0)
	_check(str(simulation.state.phase) == "lost", "A defeated solo player reaches the simulation loss condition")
	game.call("_process", 1.0 / 60.0)
	await _layout()
	_check(str(game.get("screen")) == "results", "A lost run opens results through the main update loop")
	_check(int(Dictionary(game.get("profile")).runs) == 1, "Results records one completed run in memory")
	_check_page_bounds("results")
	game.call("_process", 1.0 / 60.0)
	_check(int(Dictionary(game.get("profile")).runs) == 1, "Repeated result frames do not duplicate the run record")
	await _press("再玩一次")
	_check(str(game.get("screen")) == "playing" and str(simulation.state.phase) == "playing" and int(simulation.state.stage) == 1, "Restart creates a fresh stage-one run")
	_check(simulation.state.players[1].items.is_empty() and int(simulation.state.kills) == 0, "Restart resets run inventory and kill counts")
	game.call("_show_pause")
	await _layout()
	await _press("返回主菜单")
	_check(str(game.get("screen")) == "menu" and not bool(game.get("paused")), "Returning from pause restores the main menu")
	_check(not bool(game.get("online")) and Array(game.get("_pending_inputs")).is_empty(), "Leaving the run clears online state and queued predictions")
	_check_page_bounds("returned menu")
	var profile_after_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var profile_after: String = FileAccess.get_file_as_string("user://profile.cfg") if profile_after_exists else ""
	_check(profile_after_exists == profile_existed and profile_after == profile_before, "UI regression leaves the user's saved profile unchanged")
	game.get("sound").call("shutdown")
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	print("UI_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _test_compact_hud(simulation) -> void:
	var player: Dictionary = simulation.state.players[1]
	game.call("_update_hud")
	await _layout()
	var slots: Dictionary = game.get("_slot_ui")
	_check(slots.size() == 3 and slots.has("weapon") and slots.has("equipment") and slots.has("dash"), "HUD presents separate primary, active equipment and dash slots")
	_check(str(slots.weapon.id) == str(player.weapon) and str(slots.equipment.id) == str(player.equipment), "HUD slot identities follow equipped gear instead of character identity")
	var pictograms = true
	var hidden_names = true
	var slot_area = Rect2()
	for slot in slots.values():
		pictograms = pictograms and slot.icon.texture != null and slot.icon.is_visible_in_tree()
		hidden_names = hidden_names and not slot.name.is_visible_in_tree() and not slot.name.text.is_empty()
		slot_area = slot.panel.get_global_rect() if slot_area.size == Vector2.ZERO else slot_area.merge(slot.panel.get_global_rect())
	_check(pictograms, "Every compact action slot retains a visible pictogram")
	_check(hidden_names, "Action names remain available for inspection without permanent text labels")
	_check(slot_area.size.x <= 180.0 and slot_area.size.y <= 90.0, "The complete three-slot action HUD occupies at most 180 by 90 pixels")
	var tiles: Array = game.get("_relic_tiles")
	_check(tiles.size() == 1 and tiles[0].id == "overclock" and tiles[0].count == 2, "Passive HUD uses one icon with a stack badge for repeated relics")
	game.call("_update_inspection_visibility")
	_check(game.get("_relic_strip").visible and not game.get("_hud_labels").hint.visible, "Owned relic icons remain visible during ordinary play while long hints stay hidden")
	var alt_event := InputEventKey.new()
	alt_event.keycode = KEY_ALT
	alt_event.physical_keycode = KEY_ALT
	alt_event.pressed = true
	Input.parse_input_event(alt_event)
	await process_frame
	game.call("_update_inspection_visibility")
	await _layout()
	_check(game.get("_relic_strip").visible and game.get("_hud_labels").hint.visible, "Holding Alt adds inspection guidance without changing the owned-item strip")
	_check_hud_bounds()
	alt_event.pressed = false
	Input.parse_input_event(alt_event)
	await process_frame
	game.call("_update_inspection_visibility")
	_check(game.get("_relic_strip").visible and not game.get("_hud_labels").hint.visible, "Releasing Alt removes guidance but keeps owned relic icons visible")
	_check(not game.get("_objective_panel").visible, "The large objective display stays hidden outside a gate event or rescue need")
	simulation.state.gate.active = true
	game.call("_update_hud")
	_check(game.get("_objective_panel").visible, "An explicitly activated gate still reveals its necessary objective and charge progress")
	simulation.state.gate.active = false
	game.call("_update_hud")
	player.skill_cd = 3.0
	game.call("_update_hud")
	_check(float(slots.equipment.bar.value) < 100.0 and slots.equipment.cooldown.text == "3", "The compact active slot shows a readable countdown on its icon and progress")
	player.skill_cd = 0.0
	simulation.state.pickups.clear()
	simulation.call("_spawn_pickup", player.pos, "item", "glass", 1)
	game.call("_update_hud")
	game.call("_process", 1.0 / 60.0)
	await _layout()
	var card: Dictionary = game.get("_loot_ui")
	_check(game.get("_loot_panel").visible and card.icon.texture != null and not card.name.text.is_empty(), "Nearby ground loot displays its icon and name before picking up")
	_check(card.warning.visible and card.warning.text.contains(str(simulation.call("loot_definition", "glass").warning)), "Loot inspection visibly warns about maximum-health loss before selection")
	_check(card.action.text.contains("E"), "The ground loot panel explicitly asks for E")
	_check(card.description.max_lines_visible == 2 and card.category.visible and card.category.text.contains(Content.rarity_name("rare")) and card.warning.max_lines_visible == -1 and card.alternatives.text.contains("Alt"), "Compact loot cards show rarity and retain the full harm warning while ordinary detail stays brief")
	var theme_changes: Dictionary = {"count": 0}
	card.name.theme_changed.connect(func(): theme_changes.count += 1)
	for frame in range(30):
		game.call("_process", 1.0 / 120.0)
	await _layout()
	_check(theme_changes.count == 0, "Reading an unchanged loot card does not repeatedly invalidate its font/theme layout")
	var cached_warning: String = card.warning.text
	player.pos.x += 1.0
	game.call("_process", 1.0 / 120.0)
	await _layout()
	_check(theme_changes.count == 0 and card.warning.text == cached_warning, "Small movement preserves the cached card and its full risk warning")
	_check_hud_bounds()
	alt_event.pressed = true
	Input.parse_input_event(alt_event)
	await process_frame
	game.call("_process", 1.0 / 60.0)
	await _layout()
	_check(card.description.max_lines_visible == -1 and card.category.visible and card.warning.visible and card.description.get_visible_line_count() == card.description.get_line_count() and card.description.size.y > card.description.get_theme_font_size("font_size"), "Holding Alt actually lays out every description line with readable height and retains category and harm")
	_check_hud_bounds()
	alt_event.pressed = false
	Input.parse_input_event(alt_event)
	await process_frame
	game.call("_process", 1.0 / 60.0)
	await _layout()
	_check(card.description.max_lines_visible == 2 and card.warning.visible and game.get("_relic_strip").visible, "Releasing Alt collapses item detail while keeping the harm warning and owned relic icons")
	simulation.state.pickups.clear()
	simulation.call("_spawn_pickup", player.pos, "item", "railgun", 1)
	game.call("_update_hud")
	game.call("_process", 1.0 / 60.0)
	await _layout()
	_check(card.replace.visible and card.replace.text.contains(str(simulation.call("loot_definition", str(player.weapon)).name)), "Weapon loot names the currently equipped weapon which will be dropped")
	_check_hud_mouse_filters()
	_check_hud_bounds()
	simulation.state.pickups.clear()
	game.call("_update_hud")
	var hashes: Dictionary = {}
	var icons_unique = true
	var definitions: Array = simulation.call("item_catalog") + simulation.call("weapon_catalog") + simulation.call("equipment_catalog")
	for definition in definitions:
		var texture: Texture2D = Icons.texture(str(definition.id), 64)
		var image: Image = texture.get_image()
		var digest: int = hash(image.get_data())
		icons_unique = icons_unique and not image.is_empty() and not hashes.has(digest)
		hashes[digest] = definition.id
	_check(icons_unique and definitions.size() == 43, "All 43 passive, weapon and active equipment IDs have distinct nonempty pictograms")

func _test_owned_strip(simulation) -> void:
	var player: Dictionary = simulation.state.players[1]
	var original: Dictionary = player.items.duplicate(true)
	player.items = {}
	game.call("_update_hud")
	await _layout()
	_check(not game.get("_relic_strip").visible and game.get("_relic_strip").get_child_count() == 0, "An empty build shows no permanent empty relic slots")
	for definition in simulation.item_catalog():
		player.items[definition.id] = 3
	game.call("_update_hud")
	await _layout()
	var tiles: Array = game.get("_relic_tiles")
	var rect: Rect2 = game.get("_relic_strip").get_global_rect()
	_check(tiles.size() == 27 and rect.size.x <= 520.0 and rect.size.y <= 76.0 and rect.position.y >= 628.0 and rect.end.y <= 704.5, "Twenty-seven owned relics fit within two compact rows confined to the left half of the view")
	var rarity_matches: bool = true
	for tile in tiles:
		rarity_matches = rarity_matches and tile.count == 3 and tile.rarity == simulation.loot_definition(tile.id).rarity and tile.control.is_visible_in_tree()
	_check(rarity_matches, "Every persistent icon keeps its actual stack count and rarity identity")
	_check_hud_bounds()
	simulation.state.pickups.clear()
	simulation._spawn_pickup(player.pos, "item", "glass", 1)
	await _move_pointer(tiles[0].control.get_global_rect().get_center())
	game.call("_process", 1.0 / 60.0)
	await _layout()
	var card: Dictionary = game.get("_loot_ui")
	_check(str(game.call("_hovered_loadout").get("id", "")) == str(tiles[0].id) and card.name.text.contains(str(simulation.loot_definition(tiles[0].id).name)) and card.description.max_lines_visible == -1, "Hovering a persistent icon without Alt displays that owned relic's complete effect")
	game.set("_smoke", "")
	Input.action_press("interact")
	var command: Dictionary = game.call("_get_command")
	Input.action_release("interact")
	game.set("_smoke", "ui")
	_check(not bool(command.get("interact", false)), "Inspecting owned-item text suppresses E so it cannot pick a different ground item")
	await _move_pointer(Vector2(800, 300))
	player.items = original
	simulation.state.pickups.clear()
	game.call("_update_hud")
	game.call("_process", 1.0 / 60.0)
	await _layout()

func _move_pointer(position: Vector2) -> void:
	root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	root.push_input(motion, true)
	await process_frame

func _test_overlap_selection(simulation) -> void:
	var player: Dictionary = simulation.state.players[1]
	simulation.state.pickups.clear()
	simulation.call("_spawn_pickup", player.pos, "item", "glass", 1)
	var glass_id: int = simulation.state.pickups.back().id
	simulation.call("_spawn_pickup", player.pos, "item", "feather", 1)
	var feather_id: int = simulation.state.pickups.back().id
	game.call("_process", 1.0 / 60.0)
	await _layout()
	_check(int(game.get("_focus_target").get("id", -1)) == glass_id, "Initial overlapping-loot focus follows the stable first candidate")
	await _send_key(KEY_F)
	game.call("_process", 1.0 / 60.0)
	await _layout()
	var focus: Dictionary = game.get("_focus_target")
	var card: Dictionary = game.get("_loot_ui")
	_check(int(focus.get("id", -1)) == feather_id and card.name.text.contains(str(simulation.call("loot_definition", "feather").name)), "F cycles to the overlapping feather and updates the displayed item")
	_check(not card.warning.visible and card.alternatives.visible and card.alternatives.text.contains("F"), "The selected harmless item clears the danger warning and advertises target cycling")
	# Read the actual human-input command after the displayed selection is fixed.
	game.set("_smoke", "")
	Input.action_press("interact")
	var command: Dictionary = game.call("_get_command")
	Input.action_release("interact")
	game.set("_smoke", "ui")
	_check(bool(command.get("interact", false)) and command.get("interact_target", {}).get("id", -1) == feather_id, "The real E input sends the exact ID currently shown after F cycling")
	simulation.step(1.0 / 60.0, {1: command})
	_check(player.items.get("feather", 0) == 1 and player.items.get("glass", 0) == 0, "The displayed feather is collected without accepting the overlapping harmful item")
	simulation.state.pickups.clear()
	game.call("_process", 1.0 / 60.0)

func _test_network_interaction_aggregation(simulation) -> void:
	# Local invocation has remote sender ID 0. This temporary simulation player
	# exercises the production batch aggregation without fabricating an RPC peer.
	simulation.call("add_player", 0, "Input Fixture", "ranger")
	var player: Dictionary = simulation.state.players[0]
	player.pos = simulation.state.players[1].pos - Vector2(80, 0)
	simulation.state.pickups.clear()

	simulation.call("_spawn_pickup", player.pos, "item", "lens", 1)
	var first_id: int = simulation.state.pickups.back().id
	simulation.call("_spawn_pickup", player.pos, "item", "capacitor", 1)
	var second_id: int = simulation.state.pickups.back().id
	var target_a = {"kind": "pickup", "id": first_id}
	var target_b = {"kind": "pickup", "id": second_id}
	game.set("hosting", true)
	game.call("_submit_inputs", [
		{"seq": 1, "interact": true, "interact_target": target_a},
		{"seq": 2, "interact": false, "interact_target": target_b},
		{"seq": 3, "interact": true, "interact_target": target_b}
	])
	var commands: Dictionary = game.get("_commands")
	_check(commands.has(0) and commands[0].interact_target == target_a, "One input batch preserves the first pending E target across later movement and E samples")
	game.call("_physics_process", 1.0 / 60.0)
	_check(player.items.get("lens", 0) == 1 and player.items.get("capacitor", 0) == 0 and not commands[0].interact, "The authority consumes that exact target once and clears the E edge")
	# Wait the actual interaction debounce while leaving network aggregation intact.
	for tick in range(15):
		simulation.step(1.0 / 60.0, {})
	game.call("_submit_inputs", [{"seq": 4, "interact": true, "interact_target": target_b}])
	_check(commands[0].interact_target == target_b, "A later E edge can select a new target after the previous edge was consumed")
	game.call("_physics_process", 1.0 / 60.0)
	_check(player.items.get("capacitor", 0) == 1, "The following authoritative tick grants the newly selected item")
	game.set("hosting", false)
	for field in ["_commands", "_command_times", "_received", "_ack"]:
		game.get(field).erase(0)
	simulation.call("remove_player", 0)
	simulation.state.pickups.clear()

func _test_map_overlay(simulation) -> void:
	var before: Dictionary = simulation.get_snapshot()
	for stage in range(1, 4):
		simulation._build_stage(stage)
		await _send_key(KEY_M)
		var map_view = game.get("_map_view")
		_check(bool(game.get("paused")) and is_instance_valid(map_view) and map_view.is_visible_in_tree(), "M opens the stage %d map as an optional paused solo overlay" % stage)
		var frame: Dictionary = map_view.get("_frame")
		_check(frame.world_size == simulation.state.world_size and frame.platforms == simulation.state.platforms and frame.gate == simulation.state.gate and frame.chests.size() == simulation.state.chests.size(), "Stage %d map receives its actual dimensions, full topology, facilities and gate" % stage)
		_check_page_bounds("map stage %d" % stage)
		var paused_time: float = simulation.state.time
		game.call("_physics_process", 1.0 / 60.0)
		_check(is_equal_approx(float(simulation.state.time), paused_time), "Stage %d solo map pauses simulation" % stage)
		await _send_key(KEY_M)
		_check(not bool(game.get("paused")) and not is_instance_valid(game.get("overlay")), "M closes the stage %d map and returns to gameplay" % stage)
	game.set("online", true)
	game.set("hosting", true)
	# Give the local cooperation-pause fixture an engine peer, without opening
	# a socket. Packet delivery is covered by the separate multi-process tests.
	var previous_peer = game.get_multiplayer().multiplayer_peer
	game.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	await _send_key(KEY_M)
	var online_time: float = simulation.state.time
	game.call("_physics_process", 1.0 / 60.0)
	_check(float(simulation.state.time) > online_time, "Viewing the map in cooperation does not pause the shared simulation")
	await _send_key(KEY_ESCAPE)
	_check(not bool(game.get("paused")), "Esc also closes the map overlay")
	game.set("online", false)
	game.set("hosting", false)
	game.get_multiplayer().multiplayer_peer = previous_peer
	simulation.apply_snapshot(before)
	game.call("_process", 1.0 / 60.0)

func _layout() -> void:
	await process_frame
	await process_frame
	await process_frame

func _send_key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	event.echo = false
	game.call("_unhandled_input", event)
	await _layout()

func _press(text: String, exact: bool = false) -> void:
	var buttons: Array = _find_type(game.get("ui"), "Button")
	var found: Button = null
	for candidate_value in buttons:
		var candidate: Button = candidate_value
		if candidate.text == text or (not exact and candidate.text.contains(text)):
			found = candidate
			break
	if found == null:
		_check(false, "Required button exists: " + text)
		return
	_check(not found.disabled, "Button is actionable: " + text)
	found.pressed.emit()
	await _layout()

func _find_type(node: Node, type_name: String) -> Array:
	var result: Array = []
	if node.is_class(type_name) and not node.is_queued_for_deletion():
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_type(child, type_name))
	return result

func _check_page_bounds(label: String) -> void:
	var buttons: Array = _find_type(game.get("ui"), "Button")
	var bad: Array[String] = []
	var focus_visible: bool = true
	for button_value in buttons:
		var button: Button = button_value
		if not button.is_visible_in_tree():
			continue
		var rect: Rect2 = button.get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > 1280.5 or rect.end.y > 720.5:
			bad.append("%s %s" % [button.text, rect])
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		focus_visible = focus_visible and focus != null and focus.border_width_left >= 2 and focus.border_color.a >= 0.9
	_check(bad.is_empty(), "%s buttons stay inside 1280x720%s" % [label, "" if bad.is_empty() else ": " + "; ".join(bad)])
	_check(focus_visible, label + " buttons provide a consistent visible keyboard focus outline")
	var clean_copy: bool = true
	var valid_version: bool = true
	for text_label: Label in _find_type(game.get("ui"), "Label"):
		for phrase: String in ["EXPEDITION PROGRAM", "EARLY EXPEDITION", "PROTOTYPE"]:
			clean_copy = clean_copy and not text_label.text.to_upper().contains(phrase)
		if text_label.name == "VersionLabel": valid_version = valid_version and text_label.text == "v" + str(game.VERSION)
	_check(clean_copy and valid_version, label + " has clean release copy and only the release version in its footer")

func _all_labels_ignore_mouse(node: Node) -> bool:
	for label_value in _find_type(node, "Label"):
		var label: Label = label_value
		if label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return true

func _check_hud_mouse_filters() -> void:
	var bad: Array[String] = []
	for control_value in _find_type(game.get("hud"), "Control"):
		var control: Control = control_value
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			bad.append(str(control.get_path()))
	_check(bad.is_empty(), "Every HUD control passes gameplay pointer input through%s" % ["" if bad.is_empty() else ": " + "; ".join(bad)])

func _check_hud_bounds() -> void:
	var bad: Array[String] = []
	for control_value in _find_type(game.get("hud"), "Control"):
		var control: Control = control_value
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > 1280.5 or rect.end.y > 720.5:
			bad.append("%s %s" % [control.get_class(), rect])
	_check(bad.is_empty(), "HUD controls stay inside 1280x720%s" % ["" if bad.is_empty() else ": " + "; ".join(bad)])

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
