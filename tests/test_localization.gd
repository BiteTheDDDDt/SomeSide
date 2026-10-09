extends SceneTree

const Locale = preload("res://scripts/localization.gd")
const Content = preload("res://scripts/content.gd")
const Layouts = preload("res://scripts/stage_layouts.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Simulation = preload("res://scripts/simulation.gd")

var game: Node
var passed: int = 0
var failed: int = 0
var profile_before: PackedByteArray
var profile_existed: bool = false
var chinese: RegEx = RegEx.new()
var numbers: RegEx = RegEx.new()

func _initialize() -> void:
	chinese.compile("[\\x{3400}-\\x{9fff}]")
	numbers.compile("[0-9]+(?:\\.[0-9]+)?")
	_run.call_deferred()

func _run() -> void:
	_test_resolution()
	_test_catalogue()
	_test_interactions()
	if OS.get_cmdline_user_args().has("--core-only"):
		_finish()
		return
	root.size = Vector2i(1280,720)
	profile_existed = FileAccess.file_exists("user://profile.cfg")
	profile_before = FileAccess.get_file_as_bytes("user://profile.cfg") if profile_existed else PackedByteArray()
	game = load("res://main.tscn").instantiate()
	game.set("_smoke","localization")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.get("world").set_process(false)
	game.get("sound").call("shutdown")
	game.profile.name = "Pilot 雨"
	game.profile.volume = 0.0
	game.profile.language = "en"
	Locale.set_language("en")
	await _test_pages()
	await _test_run()
	var after_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if after_exists else PackedByteArray()
	_check(after_exists == profile_existed and after == profile_before,"Localization regression leaves the user's profile byte-for-byte unchanged")
	game.get("sound").call("shutdown")
	game.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("LOCALIZATION_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _test_resolution() -> void:
	_check(Locale.current_language=="en","Localization defaults to English before profile resolution")
	for entry: Array in [["zh-CN","zh"],["zh_TW","zh"],["zh-HK","zh"],["ZH_hans_CN","zh"],["zh","zh"],["en_US","en"],["fr","en"],["","en"],["zheng","en"]]:
		_check(Locale.choose_language("",entry[0])==entry[1],"System locale %s resolves to %s"%entry)
	_check(Locale.choose_language("en","zh-CN")=="en" and Locale.choose_language("zh","fr")=="zh","A valid saved language overrides the operating system")
	_check(Locale.choose_language("broken","zh_TW")=="zh" and Locale.choose_language("broken","fr_FR")=="en","An invalid saved language falls back to the operating system")
	Locale.set_language("broken")
	_check(Locale.current_language=="en","An unsupported language cannot enter active locale state")
	_check(Locale.text("Pilot 雨")=="Pilot 雨" and Locale.text("custom_asset_99")=="custom_asset_99","Exact translation leaves user names and unknown identifiers intact")
	_check(Locale.format("120%",[])=="120%","Empty formatting arguments preserve literal percent signs")
	_check(Locale.format("%s   ·   %d 件遗物   ·   %d 击破",["Pilot 雨",14,27]).contains("Pilot 雨") and not _has_chinese(Locale.format("%s   ·   %d 件遗物   ·   %d 击破",["Pilot",14,27])),"Formatting translates the template before interpolating names and numbers")
	Locale.set_language("zh")
	_check(Locale.text("开始独行     →")=="开始独行     →","Chinese preserves the source text")
	Locale.set_language("en")

func _test_catalogue() -> void:
	var records: Array = Content.passives()+Content.weapons()+Content.equipment()
	var original: PackedByteArray = var_to_bytes(records)
	_check(records.size()==46,"Localization covers the complete forty-six-item catalogue")
	for record: Dictionary in records:
		var missing: Array[String] = []
		for key: String in ["name","description","warning"]:
			var source: String = str(record.get(key,""))
			if source.is_empty(): continue
			var translated: String = Locale.text(source)
			if not Locale.has_translation(source) or _has_chinese(translated): missing.append(key+": "+source)
		_check(missing.is_empty(),"%s name, effect and risk have complete English translations%s"%[record.id,"" if missing.is_empty() else " / "+str(missing)])
		_check(_digits(str(record.description))==_digits(Locale.text(str(record.description))),"%s translated effect preserves every numeric value"%record.id)
	var missing_world: Array[String] = []
	for character: String in ["ranger", "vanguard", "weaver"]:
		for ability: Dictionary in [Content.movement_ability(character), Content.character_passive(character)]:
			_check(Locale.has_translation(str(ability.name)) and Locale.has_translation(str(ability.description)) and not _has_chinese(Locale.text(str(ability.description))), character+" active and passive ability have complete English descriptions")
			_check(_digits(str(ability.description))==_digits(Locale.text(str(ability.description))), str(ability.id)+" translated rules preserve all numerical values")
	for stage: int in range(1,4):
		var layout: Dictionary = Layouts.build(stage)
		var terms: Array = [layout.stage_name,Enemies.boss_definition(layout.biome).name]
		for mark: Dictionary in layout.landmarks: terms.append(mark.name)
		for term: String in terms:
			if not Locale.has_translation(term) or _has_chinese(Locale.text(term)): missing_world.append(term)
	for enemy: Dictionary in Enemies.catalog():
		if not Locale.has_translation(enemy.name) or _has_chinese(Locale.text(enemy.name)): missing_world.append(enemy.name)
	_check(missing_world.is_empty(),"Three maps, every landmark and all twelve enemies have English names%s"%("" if missing_world.is_empty() else " / "+str(missing_world)))
	var rarity_ok: bool = true
	for rarity: String in ["common","uncommon","rare","legendary"]:
		var source: String = Content.rarity_name(rarity)
		rarity_ok = rarity_ok and Locale.has_translation(source) and not _has_chinese(Locale.text(source))
	_check(rarity_ok,"All four rarity names have English translations")
	Locale.set_language("zh")
	_check(var_to_bytes(Content.passives()+Content.weapons()+Content.equipment())==original,"Changing language does not rewrite authoritative item definitions")
	Locale.set_language("en")

func _test_interactions() -> void:
	var sim: Variant = Simulation.new()
	sim.start_run([{"id":1,"name":"Pilot 雨","character":"ranger"}],808)
	var player: Dictionary = sim.state.players[1]
	player.coins = 123456
	var count: int = 0
	for chest: Dictionary in sim.state.chests:
		player.pos = chest.pos
		var before: PackedByteArray = var_to_bytes(sim.state)
		Locale.set_language("zh")
		var cn: Dictionary = sim._interaction_record("chest",chest,player)
		Locale.set_language("en")
		var en: Dictionary = sim._interaction_record("chest",chest,player)
		var english_ok: bool = true
		for key: String in ["title","description","warning","prompt","replace"]:
			english_ok = english_ok and not _has_chinese(str(en.get(key,"")))
		_check(english_ok,"%s facility display has no untranslated English text"%chest.type)
		_check(_numeric_fields(cn)==_numeric_fields(en) and _digits(str(cn.get("prompt","")))==_digits(str(en.get("prompt",""))),"%s facility language preserves price, IDs, availability and prompt amounts"%chest.type)
		_check(var_to_bytes(sim.state)==before,"%s facility display translation is read-only"%chest.type)
		count += 1
	_check(count>=18,"Language comparison exercises all authored facilities")
	var pickup: Dictionary = sim._spawn_pickup(player.pos,"item","glass",1)
	var shown: Dictionary = sim._interaction_record("pickup",pickup,player)
	_check(not _has_chinese(str(shown)) and not str(shown.get("warning","")).is_empty(),"Harmful ground loot retains its complete English risk before pickup")

func _test_pages() -> void:
	for method: String in ["_show_menu","_show_characters","_show_guide","_show_settings","_show_join"]:
		game.call(method)
		await _layout()
		_check_english_page(method)
	game.roster = [{"id":1,"name":"游侠","character":"ranger","ready":true},{"id":2,"name":"Guest","character":"vanguard","ready":true}]
	game.hosting = true
	game.call("_show_lobby")
	await _layout()
	_check_english_page("lobby")
	_check(_labels_contain("游侠"),"A lobby nickname equal to a translation key remains the player's original name")
	game.roster = []
	for id: int in range(1,5): game.roster.append({"id":id,"name":"WWWWWWWWWWWWWWWWWW","character":"vanguard","ready":id%2==0})
	game.call("_show_lobby")
	await _layout()
	_check_english_page("full lobby with eighteen-character names")
	game.hosting = false
	game.online = false

func _test_run() -> void:
	game.call("_begin_local",[{"id":1,"name":"游侠","character":"ranger"}],809)
	var sim: Variant = game.get("sim")
	var player: Dictionary = sim.state.players[1]
	for id: String in ["overclock","glass","feather","battery"]: sim._grant_item(player,id)
	game.call("_update_hud")
	await _layout()
	_check_english_page("game HUD")
	sim.state.gate.active=true
	sim.state.boss_alive=true
	game.call("_update_hud")
	await _layout()
	_check_english_page("active boss objective HUD")
	sim.state.boss_alive=false
	game.call("_update_hud")
	await _layout()
	_check_english_page("charging objective HUD")
	sim.state.gate.active=false
	await _test_coins(sim,player)
	var seen_types: Dictionary = {}
	for chest: Dictionary in sim.state.chests:
		if seen_types.has(chest.type): continue
		seen_types[chest.type]=true
		player.pos=chest.pos
		game.call("_process",0.0)
		await _layout()
		_check_english_page("%s facility card"%chest.type)
	for id: String in ["glass","railgun","aegis"]:
		sim.state.pickups.clear()
		sim._spawn_pickup(player.pos,"item",id,1)
		game.call("_process",0.0)
		await _layout()
		_check_english_page(id+" ground loot card")
		if id=="glass":
			_check(game._loot_ui.warning.visible and game._loot_ui.warning.text==Locale.text(Simulation.loot_definition(id).warning),"English ground-loot UI shows the complete harmful-item warning")
	sim.events.clear()
	sim._interact(player,{"kind":"pickup","id":-1234})
	game.call("_consume_events",sim.events)
	await _layout()
	_check(not str(game._notice.text).is_empty() and not _has_chinese(str(game._notice.text)),"An actual rejected interaction produces a translated notice")
	sim.events.clear()
	sim._notice(player,"金币不足：需要%d金币。",[413])
	var notice_event: Dictionary = sim.events.back().duplicate(true)
	var event_bytes: PackedByteArray = var_to_bytes(notice_event)
	for language: String in ["en","zh"]:
		Locale.set_language(language)
		game.call("_consume_events",[notice_event])
		var rendered: String = str(game._notice.text)
		_check(rendered.contains("413") and _has_chinese(rendered)==(language=="zh"),"The same authority notice renders in %s with its exact amount"%language)
	_check(var_to_bytes(notice_event)==event_bytes,"Per-client notice localization does not mutate the shared event")
	Locale.set_language("en")
	game.call("_consume_events",[notice_event])
	game.call("_show_inventory")
	await _layout()
	_check_english_page("owned inventory")
	for filter: String in ["passive","weapon","equipment"]:
		game.call("_populate_inventory",filter)
		await _layout()
		_check_english_page(filter+" catalogue")
		var scroll: ScrollContainer = game._inventory_grid.get_parent()
		scroll.scroll_vertical = 100000
		await _layout()
		_check_english_page(filter+" catalogue bottom")
	game.call("_resume")
	for stage: int in range(1,4):
		sim._build_stage(stage)
		game.call("_show_map")
		await _layout()
		_check_english_page("stage %d map"%stage)
		game.call("_resume")
	game.call("_show_pause")
	await _layout()
	_check_english_page("pause")
	var unchanged: PackedByteArray = var_to_bytes(sim.state)
	game.call("_show_settings",true)
	await _layout()
	game.call("_set_language","zh")
	await _layout()
	_check(Locale.current_language=="zh" and game.profile.language=="zh","The live settings callback selects and remembers Chinese in memory")
	_check(var_to_bytes(sim.state)==unchanged,"Switching to Chinese during a run preserves every simulation field")
	game.call("_set_language","en")
	await _layout()
	_check(Locale.current_language=="en" and game.profile.language=="en","The live settings callback selects and remembers English in memory")
	_check(var_to_bytes(sim.state)==unchanged,"Switching back to English preserves the same live run")
	_check_english_page("in-run settings")
	game.call("_resume")
	for phase: String in ["lost","won"]:
		sim.state.phase = phase
		game.call("_show_results")
		await _layout()
		_check_english_page(phase+" results")
		_check(_labels_contain("游侠"),"%s results preserve a nickname equal to a translation key"%phase)

func _test_coins(sim: Variant, player: Dictionary) -> void:
	var labels: Dictionary = game.get("_hud_labels")
	_check(labels.has("coins"),"Gold has its own permanent HUD label")
	if not labels.has("coins"): return
	var label: Label = labels.coins
	_check(label.get_parent()!=labels.expedition.get_parent() and not labels.expedition.text.contains("◈"),"Gold has a separate HUD panel rather than sharing the expedition status line")
	for amount: int in [0,35,9876543210]:
		player.coins = amount
		game.call("_update_hud")
		await _layout()
		_check(label.is_visible_in_tree() and label.text.contains(str(amount)),"Gold HUD renders the full balance %d"%amount)
		_check_text_bounds(label,"gold %d"%amount)
	_check(label.get_theme_font_size("font_size")>=24,"Gold uses a prominent readable font")
	var tint: Color = label.get_theme_color("font_color")
	_check(tint.r>0.7 and tint.g>0.45 and tint.b<tint.g,"Gold is visibly distinguished by a warm gold color")
	player.items = {}
	player.coins = 500
	sim._spawn_pickup(player.pos,"coin","",27)
	sim._step_pickups(0.001)
	game.call("_update_hud")
	_check(player.coins==527 and label.text.contains("527"),"Collecting real coins immediately increases the displayed balance")
	var chest: Dictionary = {}
	for entry: Dictionary in sim.state.chests:
		if str(entry.type)=="cache": chest=entry; break
	player.pos = chest.pos
	var cost: int = int(chest.cost)
	sim._interact(player,{"kind":"chest","id":chest.id})
	game.call("_update_hud")
	_check(player.coins==527-cost and label.text.contains(str(527-cost)),"Purchasing a real cache immediately reduces the displayed balance")

func _numeric_fields(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in record:
		if record[key] is int or record[key] is float or record[key] is bool: result[key]=record[key]
	return result

func _digits(value: String) -> Array[String]:
	var result: Array[String] = []
	for match_value: RegExMatch in numbers.search_all(value): result.append(match_value.get_string())
	result.sort()
	return result

func _has_chinese(value: String) -> bool:
	return chinese.search(value)!=null

func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node.is_queued_for_deletion(): return result
	result.append(node)
	for child: Node in node.get_children(): result.append_array(_nodes(child))
	return result

func _check_english_page(context: String) -> void:
	var untranslated: Array[String] = []
	var version: Label
	var buttons: Array[Button] = []
	for node: Node in _nodes(game.get("ui")):
		var message: String = ""
		if node is Label or node is Button: message = node.text
		elif node is LineEdit: message = node.placeholder_text
		if node is Control: message += node.tooltip_text
		# User-defined names and the language selector's native language label
		# deliberately remain in their original script.
		message = message.replace("Pilot 雨","").replace("游侠","").replace("简体中文","").replace("中文","")
		if _has_chinese(message): untranslated.append(message)
		if (node is Label or node is Button) and node.is_visible_in_tree(): _check_text_bounds(node,context,false)
		if node is Label and node.is_visible_in_tree() and node.name == "VersionLabel": version=node
		if node is Button and node.is_visible_in_tree(): buttons.append(node)
	_check(untranslated.is_empty(),context+" has no untranslated text"+("" if untranslated.is_empty() else ": "+str(untranslated)))
	if version!=null:
		var collision: bool = false
		for button: Button in buttons: collision = collision or version.get_global_rect().intersects(button.get_global_rect())
		_check(not collision,context+" buttons do not overlap the version footer")

func _check_text_bounds(control: Control, context: String, report_success: bool = true) -> void:
	var in_scroll: bool = false
	var parent: Node = control.get_parent()
	while parent!=null:
		if parent is ScrollContainer: in_scroll=true; break
		parent=parent.get_parent()
	var rect: Rect2 = control.get_global_rect()
	var okay: bool = in_scroll or Rect2(-1,-1,1282,722).encloses(rect)
	if control is Label and control.autowrap_mode==TextServer.AUTOWRAP_OFF:
		var measured: Vector2 = control.get_theme_font("font").get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size"))
		okay = okay and measured.x<=rect.size.x+2.0
	elif control is Label and control.max_lines_visible<0:
		okay = okay and control.get_visible_line_count()==control.get_line_count()
	elif control is Button:
		var needed: float = control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x+control.get_theme_stylebox("normal").get_minimum_size().x
		okay = okay and needed<=rect.size.x+2.0
	if report_success or not okay: _check(okay,"%s text fits: %s %s"%[context,str(control.get("text")),str(rect)])

func _layout() -> void:
	for frame: int in range(3): await process_frame

func _labels_contain(value: String) -> bool:
	for node: Node in _nodes(game.get("ui")):
		if node is Label and node.text.contains(value): return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		passed+=1
		print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)
