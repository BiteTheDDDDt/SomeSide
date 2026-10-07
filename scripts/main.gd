extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Icons = preload("res://scripts/item_icons.gd")
const MapView = preload("res://scripts/map_view.gd")
const Content = preload("res://scripts/content.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const WeaponActionMotion = preload("res://scripts/weapon_action_motion.gd")
const EnemyCatalog = preload("res://scripts/enemy_catalog.gd")
const Locale = preload("res://scripts/localization.gd")
const PlayerInput = preload("res://scripts/player_input.gd")
const PixelActorRenderer = preload("res://scripts/pixel_actor_renderer.gd")
const IllustratedPlayers = preload("res://scripts/illustrated_player_renderer.gd")
const AttackFxSprites = preload("res://scripts/attack_fx_sprites.gd")
const UIArt = preload("res://scripts/ui_art.gd")
const UITheme = preload("res://scripts/ui_theme.gd")
const VERSION: String = "0.20.7"
const DEFAULT_PORT: int = 27841
const MAX_PENDING_STAGE_EVENTS: int = 192
const TRANSIENT_EVENT_TYPES: Array[String] = ["shoot", "slash", "hit", "explosion", "death", "jump", "land", "dash", "ability_hit", "ability", "proc", "coin_drop", "equipment", "drop"]
const WINDOWS_DOWNLOAD_URL: String = "https://bitetheddddt.itch.io/someside"
const WEB_COOP_MESSAGE: String = "浏览器版支持单人游玩。2–4 人合作请下载 Windows 版。"
const INK := Color("0b1e27")
const PAPER := Color("e8ede5")
const MUTED := Color("91aaa9")
const TEAL := Color("70dfbd")
const AMBER := Color("f2b368")
const SURFACE := Color("10272e")
const EDGE := Color("30474b")

var sim = Simulation.new()
var world = WorldView.new()
var sound = Soundscape.new()
var ui: Control
var overlay: Control
var hud: Control
var font: Font
var heading_font: Font
var screen: String = "menu"
var online: bool = false
var hosting: bool = false
var local_id: int = 1
var roster: Array = []
var profile: Dictionary = {"name": "Traveller", "character": "ranger", "volume": 0.65, "effects": 1.0, "shake": true, "fullscreen": false, "runs": 0, "best_stage": 0, "wins": 0, "language": "", "show_fps": true}
var paused: bool = false
var _hud_labels: Dictionary = {}
var _hp_bar: ProgressBar
var _gate_bar: ProgressBar
var _notice: Label
var _notice_time: float = 0.0
var _network_wait: float = 0.0
var _port: int = DEFAULT_PORT
var _tick: int = 0
var _sequence: int = 0
var _ack: Dictionary = {}
var _received: Dictionary = {}
var _commands: Dictionary = {}
var _command_times: Dictionary = {}
var _snapshot_chunks: Dictionary = {}
var _pending_inputs: Array = []
var _event_buffer: Array = []
var _pending_stage_events: Array = []
var _visual_error: Vector2 = Vector2.ZERO
var _last_snapshot_tick: int = -1
var _last_event_tick: int = -1
var _ping_ms: float = 0.0
var _ping_timer: float = 0.0
var _run_saved: bool = false
var _hud_clock: float = 0.0
var _connect_address: String = "127.0.0.1"
var _options: Dictionary = {}
var _smoke: String = ""
var _elapsed: float = 0.0
var _started: bool = false
var _snapshots_received: int = 0
var _inputs_received: int = 0
var _max_players: int = 0
var _events_seen: int = 0
var _captured: bool = false
var _smoke_finished: bool = false
var _quitting: bool = false
var _local_fire_timer: float = 0.0
var _predicted_attack_count: int = 0
var _slot_ui: Dictionary = {}
var _relic_strip: GridContainer
var _relic_signature: String = ""
var _relic_tiles: Array = []
var _loot_panel: PanelContainer
var _loot_ui: Dictionary = {}
var _focus_target: Dictionary = {}
var _interaction_options: Array = []
var _interaction_selection: Dictionary = {}
var _objective_panel: PanelContainer
var _map_view: Control
var _map_title: Label
var _inventory_filter: String = "owned"
var _inventory_grid: GridContainer
var _inventory_filters: Dictionary = {}
var _advanced_observed: Dictionary = {"deployables": false, "effects": false, "chrono": false, "guided_projectiles": false, "proc_effects": false, "projectile_kinds": []}
var _biome_observed: Dictionary = {"biomes": [], "enemy_kinds": [], "boss_styles": [], "hazard_shapes": [], "attack_kinds": []}
var _biome_smoke_stage: int = 0
var _settings_in_game: bool = false
var _coin_panel: PanelContainer
var _last_coin_balance: int = -1
var _coin_feedback: float = 0.0
var _player_input = PlayerInput.new()
var _controls_focused: bool = true
# Tests can inject the platform flag before _ready without altering OS state.
var _web_runtime: bool = OS.has_feature("web") or OS.has_feature("someside_web")
var _fullscreen_button: Button
var _profile_save_error: Error = OK
var _loot_signature: Array = []
var _fps_label: Label
var _fps_settings_button: Button
var _fps_refresh_clock: float = 0.0
var _fps_value: int = 0
const FPS_REFRESH_INTERVAL: float = 0.25

func _ready() -> void:
	Engine.max_fps = 120
	get_tree().auto_accept_quit = false
	_parse_options()
	_load_profile()
	_setup_inputs()
	# Clients communicate only with the authority; the explicit roster replaces
	# engine peer-to-peer relay announcements, including during disconnection.
	if multiplayer is SceneMultiplayer:
		multiplayer.server_relay = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var base_font: Font = load("res://assets/fonts/NotoSansSC.ttf")
		var regular := FontVariation.new()
		regular.base_font = base_font
		regular.variation_opentype = {2003265652: 450.0}
		font = regular
		var semibold := FontVariation.new()
		semibold.base_font = base_font
		semibold.variation_opentype = {2003265652: 650.0}
		heading_font = semibold
	else:
		heading_font = font
	add_child(world)
	sound.enabled = _smoke.is_empty()
	sound.wait_for_gesture = _is_web()
	add_child(sound)
	_apply_settings()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	ui.draw.connect(_draw_reticle)
	_build_fps_overlay()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	sim.start_run([{"id": 1, "name": "SomeSide", "character": "ranger"}], 73021)
	world.menu_preview = true
	_show_menu()
	if _smoke == "host":
		_host_lobby()
	elif _smoke == "client":
		_join_lobby(str(_options.get("address", "127.0.0.1")))
	elif _options.has("demo"):
		_start_solo()
	print("SOMESIDE_READY version=", VERSION, " mode=", _smoke if not _smoke.is_empty() else "interactive")

func _process(delta: float) -> void:
	_elapsed += delta
	_update_fps(delta)
	var was_coin_feedback: bool = _coin_feedback > 0.0
	_coin_feedback = maxf(0.0, _coin_feedback - delta)
	if was_coin_feedback and _hud_labels.has("coins") and is_instance_valid(_hud_labels.coins):
		_hud_labels.coins.add_theme_color_override("font_color", AMBER.lerp(Color("fff2bc"), _coin_feedback / 0.55))
	_visual_error = _visual_error.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * delta))
	var render_state: Dictionary = sim.state
	if online and not hosting and screen in ["playing", "results"] and sim.state.get("players", {}).has(local_id):
		render_state = sim.state.duplicate(false)
		render_state["players"] = sim.state.players.duplicate(false)
		render_state.players[local_id] = sim.state.players[local_id].duplicate(false)
		render_state.players[local_id]["pos"] += _visual_error
	world.interpolate_remote_entities = online and not hosting
	if screen == "playing":
		_refresh_interaction_focus()
		world.interaction_target = _focus_target
	else:
		world.interaction_target = {}
	world.combat_paused = paused and not online
	world.set_frame(render_state, local_id, delta)
	_flush_stage_events()
	sound.update_game_audio(delta, sim.state, paused and not online, screen == "playing")
	if is_instance_valid(_map_view):
		_map_view.set_frame(sim.state, local_id)
		_map_title.text = "%02d  /  %s" % [int(sim.state.get("stage", 1)), Locale.text(str(sim.state.get("stage_name", "远征地图")))]
	ui.queue_redraw()
	if screen == "playing":
		if sim.state.get("players", {}).has(local_id) and is_instance_valid(_loot_panel):
			_update_interaction_panel(sim.state.players[local_id])
		_update_inspection_visibility()
		_hud_clock += delta
		if _hud_clock > 0.08:
			_hud_clock = 0.0
			_update_hud()
		if str(sim.state.get("phase", "playing")) != "playing":
			_show_results()
	if _notice_time > 0.0:
		_notice_time -= delta
		if is_instance_valid(_notice):
			_notice.modulate.a = minf(_notice_time, 1.0)
	if _network_wait > 0.0:
		_network_wait -= delta
		if _network_wait <= 0.0 and screen == "connecting":
			_disconnect()
			_show_menu("连接超时。请检查地址、端口与防火墙。")
	if online and not hosting and screen == "playing":
		_ping_timer += delta
		if _ping_timer > 2.0:
			_ping_timer = 0.0
			_ping.rpc_id(1, Time.get_ticks_msec())
	if not _smoke.is_empty() or _options.has("duration") or _options.has("capture"):
		_process_automation()

func _physics_process(delta: float) -> void:
	if screen != "playing":
		return
	if paused and not online:
		return
	_tick += 1
	_step_biome_smoke()
	var command: Dictionary = _get_command()
	if online and not hosting:
		_predict_attack_feedback(command, delta)
		_sequence += 1
		command["seq"] = _sequence
		_pending_inputs.append(command.duplicate(true))
		if _pending_inputs.size() > 180:
			_pending_inputs.pop_front()
		var batch: Array = _pending_inputs.slice(maxi(0, _pending_inputs.size() - 6))
		_submit_inputs.rpc_id(1, batch)
		if sim.state.players.has(local_id):
			sim.predict_player(sim.state.players[local_id], command, delta)
		return
	var frame: Dictionary = {local_id: command}
	for peer_id in _commands:
		frame[peer_id] = _commands[peer_id].duplicate(true)
		if Time.get_ticks_msec() - int(_command_times.get(peer_id, 0)) > 350:
			frame[peer_id]["move"] = 0.0
			frame[peer_id]["fire"] = false
			frame[peer_id]["jump_held"] = false
		_ack[peer_id] = _received.get(peer_id, 0)
		for edge in ["jump", "drop", "skill", "dash", "interact"]:
			_commands[peer_id][edge] = false
	sim.step(delta, frame)
	if _smoke == "host" and _options.has("finish-after") and _elapsed > float(_options["finish-after"]):
		sim.state["phase"] = "lost"
		sim.events.append({"type": "lose", "pos": Vector2.ZERO})
	_consume_events(sim.events)
	_event_buffer.append_array(sim.events)
	if online and (_tick % 3 == 0 or sim.state.get("phase", "playing") != "playing"):
		var snapshot: Dictionary = sim.get_snapshot()
		snapshot["_ack"] = _ack.duplicate()
		snapshot["_tick"] = _tick
		_send_snapshot(snapshot)
		if sim.state.get("phase", "playing") != "playing":
			_broadcast("_end_run", [snapshot])
		if not _event_buffer.is_empty():
			_broadcast("_receive_events", [_event_buffer.slice(maxi(0, _event_buffer.size() - 72)), _tick, int(sim.state.seed)])
		_event_buffer.clear()
	elif not online:
		_event_buffer.clear()

func _get_command() -> Dictionary:
	var command: Dictionary = {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "aim": Vector2.RIGHT, "fire": false, "skill": false, "dash": false, "interact": false}
	var player: Dictionary = sim.state.get("players", {}).get(local_id, {})
	if player.is_empty():
		return command
	if not _smoke.is_empty() or _options.has("demo"):
		command.jump_held = true
		var position: Vector2 = player.get("pos", Vector2.ZERO)
		var aim: Vector2 = Vector2.RIGHT
		var best: float = INF
		for enemy in sim.state.get("enemies", []):
			var d: float = position.distance_squared_to(enemy.pos)
			if d < best:
				best = d
				aim = (enemy.pos - position).normalized()
		command.merge({"move": 1.0 if fmod(_elapsed, 9.0) < 5.0 else -1.0, "jump": _tick % 73 == 0, "aim": aim, "fire": true, "skill": _tick % 200 == 0, "dash": _tick % 170 == 0, "interact": _tick % 30 == 0}, true)
		if _options.has("smoke-advanced"):
			command.interact = false
			command.skill = _tick >= 240 and _tick % 120 == 0
		if _options.has("smoke-biomes"):
			command.merge({"move": 0.0, "jump": false, "fire": false, "skill": false, "dash": false, "interact": false}, true)
		if _options.has("demo"):
			var gate_position: Vector2 = sim.state.get("gate", {}).get("pos", Vector2(2800, 999))
			command.move = signf(gate_position.x - position.x) if absf(gate_position.x - position.x) > 90.0 else sin(_elapsed * 1.6) * 0.45
		return command
	if paused or not _controls_focused:
		command.aim = player.get("aim", Vector2.RIGHT)
		return command
	var aiming_player: Dictionary = player.duplicate(false)
	if online and not hosting:
		aiming_player.pos = Vector2(player.pos) + _visual_error
	command.aim = WeaponPose.aim_at(aiming_player, world.screen_to_world(get_viewport().get_mouse_position()))
	command.move = _player_input.movement_axis()
	command.jump = _player_input.consume_jump_pressed()
	command.jump_held = _player_input.jump_held()
	command.drop = Input.is_action_pressed("down") and command.jump
	command.fire = Input.is_action_pressed("fire")
	command.skill = Input.is_action_just_pressed("skill")
	command.dash = Input.is_action_just_pressed("dash")
	command.interact = Input.is_action_just_pressed("interact") and _hovered_loadout().is_empty()
	if command.interact:
		var target: Dictionary = _focus_target
		command["interact_target"] = {"kind": str(target.get("kind", "")), "id": int(target.get("id", -999))}
	return command

func _setup_inputs() -> void:
	var keys: Dictionary = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "dash": [KEY_SHIFT], "interact": [KEY_E], "skill": [KEY_Q]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	for binding in [["fire", MOUSE_BUTTON_LEFT], ["skill", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
		var event := InputEventMouseButton.new()
		event.button_index = binding[1]
		if not InputMap.action_has_event(binding[0], event):
			InputMap.action_add_event(binding[0], event)

func _predict_attack_feedback(command: Dictionary, delta: float) -> void:
	_local_fire_timer = maxf(0.0, _local_fire_timer - delta)
	var player: Dictionary = sim.state.get("players", {}).get(local_id, {})
	if player.is_empty() or player.get("dead", false) or not command.get("fire", false) or _local_fire_timer > 0.0:
		return
	var weapon: String = str(player.get("weapon", "pulse_rifle"))
	_local_fire_timer = Simulation.attack_interval(player)
	_predicted_attack_count = maxi(_predicted_attack_count, int(player.get("attack_count", 0))) + 1
	var aim: Vector2 = WeaponPose.normalized_aim(command.get("aim", player.get("aim", Vector2.RIGHT)))
	var event: Dictionary = {"type": "slash" if weapon == "arc_blade" else "shoot", "kind": "bullet" if weapon == "pulse_rifle" else weapon, "weapon": weapon, "pos": WeaponPose.muzzle_position(player, aim), "aim": aim, "player": local_id}
	event.merge({"attack_id": _predicted_attack_count, "predicted": true, "interval": _local_fire_timer,
		"duration": WeaponActionMotion.duration(weapon, _local_fire_timer)})
	match weapon:
		"arc_blade":
			event.radius = 105.0
			event.merge({"phase": "start", "duration": WeaponPose.melee_duration(_local_fire_timer), "attack_id": _predicted_attack_count, "predicted": true}, true)
		"flamethrower":
			event.type = "slash"
			event.kind = "flame"
			event.radius = 170.0
		"storm_staff":
			event.kind = "storm"
		"sun_lance":
			event.kind = "lance"
	event.merge(sim._visual_data(local_id), false)
	world.push_events([event])
	sound.sync_game_audio(sim.state)
	sound.play_game_event(event)

func _is_web() -> bool:
	return _web_runtime

func _input(event: InputEvent) -> void:
	if _is_web() and event.is_pressed() and not event.is_echo():
		sound.activate_from_gesture()
		# Fullscreen must stay inside the active browser input callback. The
		# settings button is also usable when the browser reserves F11 itself.
		if is_instance_valid(_fullscreen_button) and _fullscreen_button.is_visible_in_tree():
			var mouse_press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _fullscreen_button.get_global_rect().has_point(event.position)
			var key_press: bool = event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _fullscreen_button.has_focus()
			var touch_press: bool = event is InputEventScreenTouch and _fullscreen_button.get_global_rect().has_point(event.position)
			if mouse_press or key_press or touch_press:
				_toggle_fullscreen()
				get_viewport().set_input_as_handled()
				return
	# This shortcut also works when a settings text field owns GUI focus.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and _controls_focused:
		_toggle_fps()
		get_viewport().set_input_as_handled()
		return
	# Observe releases before GUI controls can consume them.
	if screen == "playing" and not paused and _controls_focused:
		_player_input.handle_event(event)

func _reset_controls() -> void:
	_player_input.reset()
	for action in ["move_left", "move_right", "jump", "down", "fire", "skill", "dash", "interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and screen == "playing" and not paused:
			_cycle_interaction()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			if screen == "playing":
				sound.play_event("ui_back" if paused else "ui")
				if paused:
					_resume()
				else:
					_show_pause()
			elif screen in ["join", "settings", "guide", "characters"]:
				sound.play_event("ui_back")
				_show_menu()
		if event.keycode == KEY_TAB and screen == "playing":
			sound.play_event("ui_back" if paused else "ui")
			if paused:
				_resume()
			else:
				_show_inventory()
		if event.keycode == KEY_M and screen == "playing":
			sound.play_event("ui_back" if paused else "ui")
			if paused:
				_resume()
			else:
				_show_map()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_controls_focused = false
		_reset_controls()
		if _is_web() and screen == "playing" and not online and not paused and is_instance_valid(ui):
			_show_pause()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_controls_focused = true
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func _quit_game(exit_code: int = 0) -> void:
	if _is_web():
		_disconnect()
		_show_menu()
		return
	if _quitting:
		return
	_quitting = true
	sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(exit_code)

func _host_lobby() -> void:
	if _is_web():
		_show_menu(WEB_COOP_MESSAGE)
		return
	_disconnect()
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(_port, 3)
	if error != OK:
		_show_menu(Locale.format("无法创建房间：端口 %d 可能已被占用（%s）。", [_port, error_string(error)]))
		return
	multiplayer.multiplayer_peer = peer
	online = true
	hosting = true
	local_id = 1
	roster = [{"id": 1, "name": str(profile.name), "character": str(profile.character), "ready": true}]
	_show_lobby()

func _join_lobby(address: String) -> void:
	if _is_web():
		_show_menu(WEB_COOP_MESSAGE)
		return
	_disconnect()
	_connect_address = address.strip_edges()
	if _connect_address.is_empty():
		_show_menu("请输入房主的 IP 地址。")
		return
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(_connect_address, _port)
	if error != OK:
		_show_menu(Locale.format("无法连接：%s", [error_string(error)]))
		return
	multiplayer.multiplayer_peer = peer
	online = true
	hosting = false
	_network_wait = 12.0
	screen = "connecting"
	var column: VBoxContainer = _page("建立连接", Locale.format("正在寻找 %s:%d …", [_connect_address, _port]))
	_button(column, "取消", func(): _disconnect(); _show_menu(), false)

func _on_connected() -> void:
	local_id = multiplayer.get_unique_id()
	_register.rpc_id(1, str(profile.name), str(profile.character))

func _on_connection_failed() -> void:
	_disconnect()
	_show_menu("连接失败。请确认房主已创建房间，地址和 UDP 端口正确。")

func _on_server_disconnected() -> void:
	_disconnect()
	_show_menu("房主已断开连接，本次对局结束。")

func _on_peer_connected(id: int) -> void:
	if hosting and screen != "lobby":
		_reject.rpc_id(id, "当前对局已经开始，请等待房主返回大厅后再加入。")

func _on_peer_disconnected(id: int) -> void:
	if not hosting:
		return
	for index in range(roster.size() - 1, -1, -1):
		if int(roster[index].id) == id:
			roster.remove_at(index)
	_commands.erase(id)
	_ack.erase(id)
	_received.erase(id)
	if screen == "playing":
		sim.remove_player(id)
		_notify("一位队友离开了远征。")
	elif screen == "lobby":
		_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(player_name: String, character: String) -> void:
	if not hosting:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if screen != "lobby" or roster.size() >= 4:
		_reject.rpc_id(id, "房间已满或对局已经开始。")
		return
	for member in roster:
		if member.id == id:
			return
	player_name = player_name.strip_edges().substr(0, 18)
	if player_name.is_empty():
		player_name = "Traveller"
	character = character if character in ["ranger", "vanguard"] else "ranger"
	roster.append({"id": id, "name": player_name, "character": character, "ready": not _smoke.is_empty()})
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable", 0)
func _reject(reason: String) -> void:
	_disconnect()
	_show_menu(reason)

func _broadcast_lobby() -> void:
	_broadcast("_receive_lobby", [roster])
	_show_lobby()

func _peer_is_connected(id: int) -> bool:
	if not online or not multiplayer.get_peers().has(id):
		return false
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var peer: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(id)
		return peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED
	return false

func _broadcast(method: String, arguments: Array) -> void:
	for id in multiplayer.get_peers():
		if _peer_is_connected(id):
			callv("rpc_id", [id, method] + arguments)

func _send_snapshot(snapshot: Dictionary) -> void:
	# Each UDP payload stays below the MTU. Incomplete snapshots are discarded;
	# a newer complete one supersedes them without blocking movement updates.
	var packed: PackedByteArray = var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
	var count: int = ceili(float(packed.size()) / 950.0)
	for index in range(count):
		_broadcast("_receive_chunk", [_tick, index, count, packed.slice(index * 950, mini((index + 1) * 950, packed.size()))])

@rpc("authority", "call_remote", "unreliable", 2)
func _receive_chunk(tick: int, index: int, total: int, data: PackedByteArray) -> void:
	if screen != "playing" or tick <= _last_snapshot_tick or total < 1 or total > 128 or index < 0 or index >= total or data.size() > 950:
		return
	if not _snapshot_chunks.has(tick):
		if _snapshot_chunks.size() >= 4:
			_snapshot_chunks.erase(_snapshot_chunks.keys().min())
		_snapshot_chunks[tick] = {"count": total, "parts": {}}
	var buffer: Dictionary = _snapshot_chunks[tick]
	if int(buffer.count) != total:
		return
	buffer.parts[index] = data
	if buffer.parts.size() != total:
		return
	var packed := PackedByteArray()
	for part in range(total):
		packed.append_array(buffer.parts[part])
	var decoded: Variant = bytes_to_var(packed.decompress_dynamic(2 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	_snapshot_chunks.erase(tick)
	if decoded is Dictionary:
		_receive_snapshot(decoded)

@rpc("authority", "call_remote", "reliable", 0)
func _receive_lobby(members: Array) -> void:
	_network_wait = 0.0
	roster = members
	_max_players = maxi(_max_players, roster.size())
	_show_lobby()

@rpc("any_peer", "call_remote", "reliable", 0)
func _set_member(character: String, ready: bool) -> void:
	if not hosting or screen != "lobby":
		return
	var id: int = multiplayer.get_remote_sender_id()
	for member in roster:
		if int(member.id) == id:
			member.character = character if character in ["ranger", "vanguard"] else "ranger"
			member.ready = ready
	_broadcast_lobby()

func _start_solo() -> void:
	_disconnect()
	roster = [{"id": 1, "name": str(profile.name), "character": str(profile.character)}]
	_begin_local(roster, randi() & 0x7fffffff)

func _start_match() -> void:
	if not hosting:
		return
	for member in roster:
		if not member.get("ready", false):
			_notify("等待所有队员准备完毕。")
			return
	var seed_value: int = randi() & 0x7fffffff
	_broadcast("_begin_run", [roster, seed_value])
	_begin_local(roster, seed_value)

@rpc("authority", "call_remote", "reliable", 0)
func _begin_run(members: Array, seed_value: int) -> void:
	roster = members
	_begin_local(members, seed_value)

func _begin_local(members: Array, seed_value: int) -> void:
	sim.start_run(members, seed_value)
	sound.reset_game_audio()
	_advanced_observed = {"deployables": false, "effects": false, "chrono": false, "guided_projectiles": false, "proc_effects": false, "projectile_kinds": []}
	_biome_observed = {"biomes": [], "enemy_kinds": [], "boss_styles": [], "hazard_shapes": [], "attack_kinds": []}
	_biome_smoke_stage = 0
	if _smoke in ["host", "client"] and _options.has("smoke-advanced"):
		# Integration-only fixture: every peer starts with the same ordered
		# roster so snapshots exercise the new attacks and timed world state.
		var weapons: Array[String] = ["flamethrower", "boomerang", "storm_staff", "sun_lance"]
		var equipment: Array[String] = ["graviton", "turret", "meteor", "time_warp"]
		for index in range(members.size()):
			var player: Dictionary = sim.state.players[int(members[index].id)]
			player.weapon = weapons[index]
			player.equipment = equipment[index]
			for item in ["plating", "magnet", "harvest", "battery", "frost", "momentum", "toxin", "echo", "piercer", "resonator", "phoenix", "nova", "missile_pod", "landing_coil", "frost_halo"]:
				sim._grant_item(player, item)
	_commands.clear()
	_command_times.clear()
	_snapshot_chunks.clear()
	_ack.clear()
	_received.clear()
	_pending_inputs.clear()
	_event_buffer.clear()
	_pending_stage_events.clear()
	_tick = 0
	_sequence = 0
	_local_fire_timer = 0.0
	_predicted_attack_count = 0
	_last_snapshot_tick = -1
	_last_event_tick = -1
	_visual_error = Vector2.ZERO
	_run_saved = false
	_started = true
	_max_players = maxi(_max_players, members.size())
	paused = false
	screen = "playing"
	world.menu_preview = false
	_build_hud()
	_notify(Locale.format("%s · M 地图 · Alt 详情 · 时间会提高威胁", [Locale.text(str(sim.state.get("stage_name", "远征开始")))]), 4.0)
	print("SOMESIDE_RUN_STARTED peers=", members.size(), " local=", local_id)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_inputs(batch: Array) -> void:
	if not hosting or screen != "playing" or batch.size() > 8:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if not sim.state.players.has(id):
		return
	for record in batch:
		if not record is Dictionary:
			continue
		var sequence: int = int(record.get("seq", 0))
		if sequence <= int(_received.get(id, 0)) or sequence > int(_received.get(id, 0)) + 600:
			continue
		var aim: Vector2 = record.get("aim", Vector2.RIGHT) if record.get("aim") is Vector2 else Vector2.RIGHT
		if not aim.is_finite():
			aim = Vector2.RIGHT
		var movement: float = float(record.get("move", 0.0))
		if not is_finite(movement):
			movement = 0.0
		# Held state is the latest sample, not an accumulated button edge.
		var command: Dictionary = {"move": clampf(movement, -1.0, 1.0), "aim": aim.normalized(), "fire": bool(record.get("fire", false)), "jump_held": bool(record.get("jump_held", true))}
		# Preserve the exact displayed target for the first pending E press.
		# Later movement samples must not retarget a deliberate loot choice.
		if bool(_commands.get(id, {}).get("interact", false)):
			command["interact_target"] = _commands[id].get("interact_target", {}).duplicate()
		elif bool(record.get("interact", false)) and record.get("interact_target", {}) is Dictionary:
			var requested: Dictionary = record.get("interact_target", {})
			var target_kind: String = str(requested.get("kind", ""))
			if target_kind in ["pickup", "chest", "gate", "revive"]:
				command["interact_target"] = {"kind": target_kind, "id": int(requested.get("id", -999))}
			elif not requested.is_empty():
				command["interact_target"] = {"kind": "invalid", "id": -999}
		for edge in ["jump", "drop", "skill", "dash", "interact"]:
			command[edge] = bool(record.get(edge, false)) or bool(_commands.get(id, {}).get(edge, false))
		_commands[id] = command
		_command_times[id] = Time.get_ticks_msec()
		_received[id] = sequence
		_inputs_received += 1

func _receive_snapshot(snapshot: Dictionary) -> void:
	if screen not in ["playing", "results"]:
		return
	if int(snapshot.get("seed", -1)) != int(sim.state.get("seed", -2)):
		return
	var tick: int = int(snapshot.get("_tick", -1))
	if tick <= _last_snapshot_tick:
		return
	_last_snapshot_tick = tick
	_snapshots_received += 1
	_observe_advanced_state(snapshot)
	_observe_biome_state(snapshot)
	var previous: Vector2 = sim.state.get("players", {}).get(local_id, {}).get("pos", Vector2.ZERO)
	var old_stage: int = int(sim.state.get("stage", 1))
	sim.apply_snapshot(snapshot)
	var acknowledgement: int = int(snapshot.get("_ack", {}).get(local_id, 0))
	while not _pending_inputs.is_empty() and int(_pending_inputs[0].seq) <= acknowledgement:
		_pending_inputs.pop_front()
	if sim.state.players.has(local_id):
		for command in _pending_inputs:
			sim.predict_player(sim.state.players[local_id], command, 1.0 / 60.0)
		var correction: Vector2 = previous - Vector2(sim.state.players[local_id].pos)
		if old_stage == int(sim.state.stage) and correction.length() < 120.0:
			_visual_error = (_visual_error + correction).limit_length(80.0)
		else:
			_visual_error = Vector2.ZERO

@rpc("authority", "call_remote", "reliable", 3)
func _receive_events(events: Array, tick: int, run_seed: int) -> void:
	if screen not in ["playing", "results"] or tick <= _last_event_tick or run_seed != int(sim.state.get("seed", -1)):
		return
	_last_event_tick = tick
	var current_stage: int = int(sim.state.get("stage", 1))
	for value: Variant in events:
		if not value is Dictionary:
			continue
		var event: Dictionary = value
		var event_stage: int = int(event.get("stage", current_stage))
		if event_stage < current_stage or event_stage > 3:
			continue
		if _pending_stage_events.size() >= MAX_PENDING_STAGE_EVENTS:
			# Under a long snapshot gap, keep progress/interaction notices ahead
			# of expendable shot and hit effects. Currency already lives in state.
			var disposable: int = -1
			for index in range(_pending_stage_events.size()):
				if str(_pending_stage_events[index].get("type", "")) in TRANSIENT_EVENT_TYPES:
					disposable = index
					break
			if disposable < 0 and str(event.get("type", "")) in TRANSIENT_EVENT_TYPES:
				continue
			_pending_stage_events.remove_at(maxi(0, disposable))
		var queued: Dictionary = event.duplicate(true)
		# Legacy fixtures without a stage belong to the stage at reception,
		# never to whichever stage happens to be current when later presented.
		queued["stage"] = event_stage
		_pending_stage_events.append(queued)

func _flush_stage_events() -> void:
	if _pending_stage_events.is_empty():
		return
	if screen not in ["playing", "results"]:
		_pending_stage_events.clear()
		return
	var current_stage: int = int(sim.state.get("stage", 1))
	var ready: Array = []
	var future: Array = []
	for event: Dictionary in _pending_stage_events:
		var event_stage: int = int(event.stage)
		if event_stage == current_stage:
			ready.append(event)
		elif event_stage > current_stage:
			future.append(event)
	_pending_stage_events = future
	# Called after world.set_frame: a newly arrived stage's effects must not
	# be built against the old map and then erased by its visual reset.
	if not ready.is_empty():
		_consume_events(ready)

@rpc("authority", "call_remote", "reliable", 0)
func _end_run(snapshot: Dictionary) -> void:
	if screen != "playing" or int(snapshot.get("seed", -1)) != int(sim.state.get("seed", -2)):
		return
	sim.apply_snapshot(snapshot)
	_last_snapshot_tick = int(snapshot.get("_tick", _last_snapshot_tick))
	_pending_inputs.clear()
	_show_results()

@rpc("any_peer", "call_remote", "unreliable", 4)
func _ping(stamp: int) -> void:
	if hosting and _peer_is_connected(multiplayer.get_remote_sender_id()):
		_pong.rpc_id(multiplayer.get_remote_sender_id(), stamp)

@rpc("authority", "call_remote", "unreliable", 4)
func _pong(stamp: int) -> void:
	_ping_ms = float(Time.get_ticks_msec() - stamp)

func _consume_events(events: Array) -> void:
	sound.sync_game_audio(sim.state)
	var presented: Array = []
	var accepted_count: int = 0
	var current_stage: int = int(sim.state.get("stage", 1))
	for event in events:
		# Also protect solo/host delivery when a transition and an accumulated
		# action share the same local consume boundary.
		if int(event.get("stage", current_stage)) != current_stage:
			continue
		accepted_count += 1
		# The owning client already presents primary attacks immediately.
		# Keep authoritative damage/skill events and every other player's shots.
		if online and not hosting and int(event.get("player", -1)) == local_id and event.has("weapon") and str(event.get("type", "")) in ["shoot", "slash"]:
			continue
		presented.append(event)
	world.push_events(presented)
	_events_seen += accepted_count
	var local_position: Vector2 = sim.state.get("players", {}).get(local_id, {}).get("pos", Vector2.ZERO)
	for event in presented:
		var kind: String = str(event.get("type", ""))
		var distance: float = local_position.distance_to(event.get("pos", local_position))
		var audio_event: Dictionary = event
		if kind == "pickup":
			if bool(event.get("automatic", false)) and str(event.get("kind", "")) == "coin":
				# Kill gold is shared immediately, even when a teammate fights far away.
				distance = 0.0
			elif not str(event.get("item", "")).is_empty():
				audio_event = event.duplicate(false)
				audio_event["rarity"] = Simulation.loot_definition(str(event.item)).get("rarity", "common")
		sound.play_game_event(audio_event, distance)
		if kind == "pickup" and int(event.get("player", -1)) == local_id and not str(event.get("item", "")).is_empty():
			var definition: Dictionary = Simulation.loot_definition(str(event.item))
			var category: String = str(definition.get("category", "passive"))
			_notify(Locale.format("获得遗物 · %s · %s" if category == "passive" else "已装备 · %s · %s", [Locale.text(Content.rarity_name(str(definition.get("rarity", "common")))), Locale.text(str(definition.get("name", event.item)))]))
		elif kind == "notice" and int(event.get("player", -1)) == local_id:
			sound.play_event("ui_error")
			var message_key: String = str(event.get("message_key", event.get("message", "")))
			var message_args: Array = event.get("message_args", [])
			_notify(Locale.text(message_key) if message_args.is_empty() else Locale.format(message_key, message_args), 3.0)
		elif kind == "stage":
			_notify(Locale.format("第 %d 区 · %s", [int(sim.state.get("stage", 1)), Locale.text(str(sim.state.get("stage_name", "新的远征")))]), 4.0)
		elif kind == "gate":
			_notify("裂隙已稳定！靠近裂隙门按 E 进入下一关。" if event.get("ready", false) else "裂隙门已激活。留在附近充能，击败守卫。", 5.0)
		elif kind == "revive":
			if event.get("phoenix", false):
				var saved_name: String = Locale.text("你") if int(event.get("player", -1)) == local_id else str(sim.state.get("players", {}).get(int(event.get("player", -1)), {}).get("name", Locale.text("队友")))
				_notify(Locale.format("不灭余火触发 · %s抵挡了一次致命伤。", [saved_name]))
			else:
				_notify("正在重建队友的共鸣 …" if event.get("started", false) else "队友已重返战场。")

func _disconnect() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	online = false
	hosting = false
	local_id = 1
	_network_wait = 0.0
	paused = false
	roster.clear()
	_commands.clear()
	_command_times.clear()
	_snapshot_chunks.clear()
	_pending_inputs.clear()
	_pending_stage_events.clear()

func _load_profile() -> void:
	var file := ConfigFile.new()
	if file.load("user://profile.cfg") == OK:
		for key in profile:
			profile[key] = file.get_value("profile", key, profile[key])
	profile.volume = clampf(float(profile.volume), 0.0, 1.0)
	profile.effects = clampf(float(profile.effects), 0.5, 1.5)
	profile.shake = bool(profile.shake)
	profile.show_fps = bool(profile.get("show_fps", true))
	if _is_web():
		profile.fullscreen = false
	profile.character = profile.character if profile.character in ["ranger", "vanguard"] else "ranger"
	profile.name = str(profile.name).substr(0, 18)
	profile.language = Locale.choose_language(str(profile.get("language", "")), OS.get_locale())
	var requested_language: String = str(_options.get("language", ""))
	Locale.set_language(requested_language if requested_language in ["zh", "en"] else str(profile.language))

func _save_profile() -> void:
	# Explicit test locales never overwrite the player's real preferences.
	if not _smoke.is_empty() or _options.has("language"):
		return
	var file := ConfigFile.new()
	for key in profile:
		file.set_value("profile", key, profile[key])
	_profile_save_error = file.save("user://profile.cfg")

func _apply_settings() -> void:
	world.fx_scale = float(profile.effects)
	world.shake_enabled = bool(profile.shake)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(profile.volume), 0.001)))
	AudioServer.set_bus_mute(0, float(profile.volume) <= 0.001)
	if not _is_web() and _smoke.is_empty() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _toggle_fullscreen() -> void:
	if _is_web() and DisplayServer.get_name() != "headless":
		# Browser Esc may have exited fullscreen without changing the profile.
		profile.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	else:
		profile.fullscreen = not bool(profile.fullscreen)
	if _smoke.is_empty() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_profile()

func _open_windows_download() -> void:
	if _smoke.is_empty():
		OS.shell_open(WINDOWS_DOWNLOAD_URL)

func _parse_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var pair: PackedStringArray = arg.substr(2).split("=", true, 1)
			_options[pair[0]] = pair[1] if pair.size() > 1 else true
	_port = clampi(int(_options.get("port", DEFAULT_PORT)), 1024, 65535)
	if _options.has("smoke-host"):
		_smoke = "host"
	elif _options.has("smoke-client"):
		_smoke = "client"

func _step_biome_smoke() -> void:
	if _smoke != "host" or not _options.has("smoke-biomes"):
		return
	# A bounded integration fixture: real AI, three real stage transitions,
	# invulnerable spectators, and no incidental exploration spawns.
	var stage: int = clampi(1 + int(float(sim.state.time) / 12.0), 1, 3)
	if stage == _biome_smoke_stage:
		return
	if int(sim.state.stage) != stage:
		sim._build_stage(stage)
	_biome_smoke_stage = stage
	var anchor: Vector2 = Vector2(float(sim.state.world_size.x) * 0.42, float(sim.state.world_size.y) - 101.0)
	var member_index: int = 0
	for player: Dictionary in sim.state.players.values():
		player.pos = anchor + Vector2(member_index * 24.0, 0.0)
		player.vel = Vector2.ZERO
		player.invuln = 1000.0
		sim._reset_exploration(player, true)
		member_index += 1
	sim.state.enemies.clear()
	sim.state.projectiles.clear()
	sim.state.hazards.clear()
	sim._spawn_clock = 9999.0
	var biome: String = str(sim.state.biome)
	var index: int = 0
	for kind: String in EnemyCatalog.pool(biome):
		var horizontal: float = [-250.0, 300.0, 460.0][index]
		sim._spawn_enemy(kind, anchor + Vector2(horizontal, -160.0 if bool(EnemyCatalog.definition(kind).get("flying", false)) else -80.0))
		index += 1
	sim._spawn_enemy("boss", anchor + Vector2(570.0, -90.0))

func _observe_biome_state(snapshot: Dictionary) -> void:
	if not _options.has("smoke-biomes") or snapshot.is_empty():
		return
	var biome: String = str(snapshot.get("biome", ""))
	if not biome.is_empty() and biome not in _biome_observed.biomes:
		_biome_observed.biomes.append(biome)
	for enemy: Dictionary in snapshot.get("enemies", []):
		var kind: String = str(enemy.get("kind", ""))
		if kind not in _biome_observed.enemy_kinds:
			_biome_observed.enemy_kinds.append(kind)
		var style: String = str(enemy.get("boss_style", ""))
		if not style.is_empty() and style not in _biome_observed.boss_styles:
			_biome_observed.boss_styles.append(style)
		var attack: String = str(enemy.get("attack_kind", ""))
		if float(enemy.get("telegraph", 0.0)) > 0.0 and not attack.is_empty() and attack not in _biome_observed.attack_kinds:
			_biome_observed.attack_kinds.append(attack)
	for hazard: Dictionary in snapshot.get("hazards", []):
		var shape: String = str(hazard.get("shape", ""))
		if shape not in _biome_observed.hazard_shapes:
			_biome_observed.hazard_shapes.append(shape)

func _observe_advanced_state(snapshot: Dictionary) -> void:
	if not _options.has("smoke-advanced") or snapshot.is_empty():
		return
	# Observe each accepted network snapshot too: several can be dispatched
	# before one render frame, especially during initial texture/font setup.
	_advanced_observed.deployables = _advanced_observed.deployables or not snapshot.get("deployables", []).is_empty()
	_advanced_observed.effects = _advanced_observed.effects or not snapshot.get("effects", []).is_empty()
	_advanced_observed.proc_effects = _advanced_observed.proc_effects or not snapshot.get("proc_effects", []).is_empty()
	for player in snapshot.get("players", {}).values():
		_advanced_observed.chrono = _advanced_observed.chrono or float(player.get("chrono_timer", 0)) > 0.0
	for projectile in snapshot.get("projectiles", []):
		var kind: String = str(projectile.get("kind", ""))
		var guidance: Dictionary = projectile.get("guidance", {})
		_advanced_observed.guided_projectiles = _advanced_observed.guided_projectiles or int(guidance.get("target_id", -1)) >= 0
		if kind not in _advanced_observed.projectile_kinds:
			_advanced_observed.projectile_kinds.append(kind)

func _process_automation() -> void:
	if _smoke_finished:
		return
	_observe_advanced_state(sim.state)
	_observe_biome_state(sim.state)
	if _smoke == "host" and screen == "lobby" and roster.size() >= int(_options.get("expected-players", 2)) and _elapsed > 2.0:
		_start_match()
	if _options.has("capture") and not _captured and _elapsed > float(_options.get("capture-after", 4.0)):
		_captured = true
		_capture_frame.call_deferred(str(_options.capture))
	var duration: float = float(_options.get("duration", 0.0))
	if duration > 0.0 and _elapsed > duration:
		_finish_automation()

func _capture_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var error: Error = picture.save_png(path)
	print("SOMESIDE_CAPTURE ", path, " error=", error)

func _finish_automation() -> void:
	_smoke_finished = true
	var passed: bool = true
	if _smoke == "host":
		passed = _started and _max_players >= int(_options.get("expected-players", 2)) and _inputs_received > 10
	elif _smoke == "client":
		passed = _started and _snapshots_received > 10
	var report: Dictionary = {"passed": passed, "mode": _smoke, "started": _started, "max_players": _max_players, "snapshots": _snapshots_received, "inputs": _inputs_received, "events": _events_seen, "tick": _tick, "stage": sim.state.get("stage", 0), "kills": sim.state.get("kills", 0), "phase": sim.state.get("phase", ""), "screen": screen, "elapsed": _elapsed}
	report["language"] = Locale.current_language
	report["profile_language"] = str(profile.get("language", ""))
	report["pixel_actors"] = PixelActorRenderer.stats()
	report["attack_fx"] = AttackFxSprites.cache_stats()
	report["fps"] = {"visible": is_instance_valid(_fps_label) and _fps_label.is_visible_in_tree(), "value": _fps_value}
	report["performance"] = {"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "scenery": world.scenery_cache_stats()}
	report["advanced"] = _options.has("smoke-advanced")
	report["observed"] = _advanced_observed.duplicate(true)
	report["biomes"] = _options.has("smoke-biomes")
	report["biome_observed"] = _biome_observed.duplicate(true)
	if _options.has("report"):
		var file := FileAccess.open(str(_options.report), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print("SOMESIDE_AUTOMATION ", JSON.stringify(report))
	_quit_game(0 if passed else 1)

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBoxFlat:
	return UITheme.panel(color, border, radius)

func _label(parent: Node, text: String, size: int = 18, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = Locale.text(text)
	label.add_theme_font_override("font", heading_font if size >= 24 else font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = Locale.text(text)
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	_skin_button(button, primary)
	button.pressed.connect(func(): sound.play_event("ui"); action.call())
	parent.add_child(button)
	var machining := UIArt.new()
	machining.name = "ButtonMachining"
	machining.mode = "button"
	machining.button = button
	machining.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(machining)
	return button

func _skin_button(button: Button, primary: bool = false) -> void:
	button.set_meta("art_primary", primary)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("667879"))
	button.add_theme_stylebox_override("normal", UITheme.button(AMBER if primary else Color("153039"), Color("ffd394") if primary else Color("3c6268"), primary))
	button.add_theme_stylebox_override("hover", UITheme.button(AMBER.lightened(0.12) if primary else Color("20494e"), PAPER if primary else TEAL, primary))
	button.add_theme_stylebox_override("pressed", UITheme.button(AMBER.darkened(0.12), AMBER, primary))
	button.add_theme_stylebox_override("disabled", UITheme.button(Color("11252d"), Color("29444b"), primary))
	var focus: StyleBoxFlat = UITheme.button(Color.TRANSPARENT, PAPER, primary)
	focus.set_border_width_all(2)
	focus.shadow_size = 0
	button.add_theme_stylebox_override("focus", focus)
	if button.has_node("ButtonMachining"): button.get_node("ButtonMachining").queue_redraw()

func _divider(parent: Node) -> void:
	var line := UIArt.new()
	line.mode = "divider"
	line.custom_minimum_size.y = 9
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _overlay_surface(bounds: Rect2, shade_alpha: float = 0.88) -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.037, 0.046, shade_alpha)
	overlay.add_child(shade)
	var surface := Panel.new()
	surface.position = bounds.position
	surface.size = bounds.size
	surface.add_theme_stylebox_override("panel", _style(Color("0b2028"), Color("365960"), 18))
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(surface)
	var frame := UIArt.new()
	frame.mode = "frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(frame)

func _gap(parent: Node, height: float = 12.0) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

func _clear_ui() -> void:
	_reset_controls()
	_loot_signature.clear()
	for child in ui.get_children():
		if child == _fps_label:
			continue
		ui.remove_child(child)
		child.queue_free()
	_hud_labels.clear()
	_fps_settings_button = null
	_refresh_fps_view()
	_coin_panel = null
	_last_coin_balance = -1
	_coin_feedback = 0.0
	overlay = null
	hud = null
	_slot_ui.clear()
	_loot_ui.clear()
	_relic_tiles.clear()
	_relic_signature = ""
	_focus_target = {}
	_interaction_options.clear()
	_interaction_selection.clear()
	_map_view = null
	_map_title = null
	_inventory_grid = null
	_inventory_filters.clear()
	_notice = null
	_hud_clock = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _page(title: String, subtitle: String, width: float = 480.0, preserve_game: bool = false) -> VBoxContainer:
	if preserve_game:
		if is_instance_valid(overlay):
			ui.remove_child(overlay)
			overlay.queue_free()
	else:
		_clear_ui()
	_overlay_surface(Rect2(40, 28, width + 48, 644), 0.5 if not preserve_game else 0.85)
	if not preserve_game and width <= 640:
		var display := UIArt.new()
		display.name = "CharacterDisplay"
		display.mode = "scene"
		display.character = str(profile.character)
		display.stage = int(sim.state.get("stage", 1))
		display.position = Vector2(width + 120, 42)
		display.size = Vector2(1130 - width, 610)
		overlay.add_child(display)
	var margin := MarginContainer.new()
	margin.position = Vector2(64, 46)
	margin.size = Vector2(width, 600)
	overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	if title != "SomeSide":
		_label(column, "SomeSide", 13, TEAL)
	if title == "SomeSide":
		var wordmark := UIArt.new()
		wordmark.name = "SomeSideWordmark"
		wordmark.mode = "wordmark"
		wordmark.custom_minimum_size = Vector2(width, 82)
		column.add_child(wordmark)
	else:
		_label(column, title, 32)
	var description: Label = _label(column, subtitle, 14, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = width
	_divider(column)
	var version: Label = _label(overlay, "v%s" % VERSION, 12, MUTED)
	version.name = "VersionLabel"
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(64, 684)
	_refresh_fps_view()
	return column

func _show_menu(message: String = "") -> void:
	_settings_in_game = false
	screen = "menu"
	paused = false
	world.menu_preview = true
	if sim.state.is_empty() or sim.state.get("phase", "playing") != "playing":
		sim.start_run([{"id": 1, "name": "SomeSide", "character": "ranger"}], 73021)
	var column: VBoxContainer = _page("SomeSide", "探索、战斗，抵达另一边。" if _is_web() else "探索、战斗，与朋友一起抵达另一边。")
	var character: String = "游侠 · RANGER" if profile.character == "ranger" else "先锋 · VANGUARD"
	_label(column, Locale.format("当前角色：%s", [Locale.text(character)]), 14, MUTED)
	_button(column, "单人游戏", _start_solo, true)
	if _is_web():
		var web_note: Label = _label(column, WEB_COOP_MESSAGE, 14, MUTED)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_note.custom_minimum_size.x = 480
		_button(column, "下载 Windows 版（含联机）", _open_windows_download)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		_button(row, "创建合作房间", _host_lobby)
		_button(row, "加入房间", _show_join)
	_button(column, "选择角色", _show_characters)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	column.add_child(row2)
	_button(row2, "操作指南", _show_guide)
	_button(row2, "设置", _show_settings)
	if not _is_web():
		_button(row2, "退出", _quit_game)
	_gap(column, 3)
	var details: String = "浏览器单人版  /  自由瞄准  /  遗物构筑" if _is_web() else "2–4 人合作  /  自由瞄准  /  遗物构筑"
	if int(profile.runs) > 0:
		details = Locale.format("已远征 %d 次  ·  最远第 %d 区  ·  生还 %d 次", [int(profile.runs), int(profile.best_stage), int(profile.wins)])
	_label(column, details, 13, MUTED)
	if not message.is_empty():
		var error_label: Label = _label(column, message, 14, AMBER)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var regions := UIArt.new()
		regions.name = "RegionRoute"
		regions.mode = "regions"
		regions.position = Vector2(64, 548)
		regions.size = Vector2(480, 65)
		overlay.add_child(regions)
		var names: Array = ["巨木雨林", "折光断崖", "双环遗迹"]
		for index in range(3):
			var region: Label = _label(overlay, str(names[index]), 12, MUTED)
			region.position = Vector2(64 + index * 166, 619)
			region.size = Vector2(148, 22)
			region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge: Label = _label(overlay, "%02d  /  %s" % [int(sim.state.get("stage", 1)), Locale.text(str(sim.state.get("stage_name", "巨木雨林")))], 14, MUTED)
	badge.position = Vector2(950, 650)

func _show_characters() -> void:
	screen = "characters"
	var page_width: float = 670
	var column: VBoxContainer = _page("选择角色", "选择初始武器与技能；遗物会改变你的战斗方式。", page_width)
	column.add_theme_constant_override("separation", 8)
	for definition in Simulation.character_catalog():
		var selected: bool = str(profile.character) == str(definition.id)
		var panel := PanelContainer.new()
		var character_style: StyleBoxFlat = _style(SURFACE, AMBER if selected else EDGE, 7)
		character_style.border_width_left = 3 if selected else 1
		panel.add_theme_stylebox_override("panel", character_style)
		column.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		panel.add_child(row)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(76, 88)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var appearance: Dictionary = IllustratedPlayers.frame(str(definition.id))
		if not appearance.is_empty(): portrait.texture = appearance.texture
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var portrait_frame := UIArt.new()
		portrait_frame.mode = "portrait"
		portrait_frame.tint = TEAL if str(definition.id) == "ranger" else AMBER
		portrait_frame.show_behind_parent = true
		portrait_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(portrait_frame)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 6)
		row.add_child(content)
		_label(content, str(definition.name), 22, PAPER)
		var description: Label = _label(content, "脉冲步枪 + 震荡手雷 · 100 生命" if str(definition.id) == "ranger" else "共鸣弧刃 + 裂地冲击 · 145 生命", 14, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = page_width - 130
		var character_id: String = str(definition.id)
		var active: Dictionary = Content.movement_ability(character_id)
		var passive: Dictionary = Content.character_passive(character_id)
		_label(content, Locale.format("Shift 主动 · %s", [Locale.text(str(active.name))]), 14, TEAL)
		var passive_label: Label = _label(content, Locale.format("自动被动 · %s", [Locale.text(str(passive.name))]) + "\n" + Locale.text("持续命中后追加追击弹。" if character_id == "ranger" else "累计失血后获得临时护盾。"), 14, AMBER)
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passive_label.custom_minimum_size.x = page_width - 130
		var select: Button = _button(content, "已选中" if selected else "选择", func(): profile.character = character_id; _save_profile(); _show_characters(), selected)
		select.custom_minimum_size.y = 38
		select.disabled = selected
	_gap(column, 2)
	_button(column, "返回", _show_menu)

func _text_field(parent: Node, value: String, placeholder: String = "") -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = Locale.text(placeholder)
	field.custom_minimum_size.y = 44
	field.add_theme_font_override("font", font)
	field.add_theme_font_size_override("font_size", 16)
	field.add_theme_color_override("font_color", PAPER)
	field.add_theme_color_override("font_placeholder_color", MUTED)
	field.add_theme_color_override("caret_color", AMBER)
	field.add_theme_color_override("selection_color", Color("375751"))
	var normal: StyleBoxFlat = _style(Color("071a22"), Color("355760"), 5)
	normal.border_width_bottom = 2
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("focus", _style(Color("102d35"), TEAL, 5))
	parent.add_child(field)
	return field

func _show_join() -> void:
	if _is_web():
		_show_menu(WEB_COOP_MESSAGE)
		return
	screen = "join"
	var column: VBoxContainer = _page("加入房间", "输入朋友的房间地址。房主需要先创建房间。", 520)
	_label(column, "房主 IP 地址", 15, TEAL)
	var address: LineEdit = _text_field(column, _connect_address, "例如 192.168.1.20")
	_label(column, "UDP 端口", 15, TEAL)
	var port_field: LineEdit = _text_field(column, str(_port))
	port_field.max_length = 5
	_gap(column, 6)
	_button(column, "连接", func(): _port = clampi(int(port_field.text), 1024, 65535); _join_lobby(address.text), true)
	_button(column, "返回", _show_menu)
	_gap(column, 4)
	var note: Label = _label(column, "同一局域网可直接连接。互联网直连需要可达的公网地址与 UDP 端口转发，也可使用虚拟局域网。当前版本通过 IP 加入。", 14, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 520

func _show_lobby() -> void:
	screen = "lobby"
	world.menu_preview = true
	var column: VBoxContainer = _page("合作房间", "所有玩家准备后，房主即可开始游戏。", 620)
	var address_text: String = Locale.format("房主 %s  ·  UDP %d", [_connect_address, _port])
	if hosting:
		var addresses: Array[String] = []
		for address in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254"):
				addresses.append(address)
		address_text = Locale.format("你的局域网地址  %s  :  %d", [", ".join(addresses.slice(0, 2)) if not addresses.is_empty() else "127.0.0.1", _port])
	var address_label: Label = _label(column, address_text, 14, TEAL)
	address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	address_label.custom_minimum_size.x = 620
	var me: Dictionary = {}
	for index in range(4):
		var row := PanelContainer.new()
		var row_style: StyleBoxFlat = _style(SURFACE, EDGE, 5)
		if index < roster.size() and bool(roster[index].get("ready", false)):
			row_style.border_color = Color("3a6c65")
			row_style.border_width_left = 3
		row.add_theme_stylebox_override("panel", row_style)
		column.add_child(row)
		var cells := HBoxContainer.new()
		cells.add_theme_constant_override("separation", 14)
		row.add_child(cells)
		var number: Label = _label(cells, "%02d" % [index + 1], 14, MUTED)
		number.custom_minimum_size.x = 26
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if index < roster.size():
			var member: Dictionary = roster[index]
			if int(member.id) == local_id:
				me = member
			var role: String = "游侠" if member.character == "ranger" else "先锋"
			var state_text: String = "准备就绪" if member.get("ready", false) else "等待准备"
			var identity := VBoxContainer.new()
			identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			identity.add_theme_constant_override("separation", 2)
			cells.add_child(identity)
			var name_label: Label = _label(identity, "", 16, PAPER)
			name_label.text = str(member.name)
			_label(identity, Locale.text(role) + (Locale.text(" (你)") if member.id == local_id else ""), 12, MUTED)
			var status: Label = _label(cells, state_text, 13, TEAL if member.get("ready", false) else MUTED)
			status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			var empty: Label = _label(cells, "等待玩家加入", 14, MUTED)
			empty.custom_minimum_size.y = 42
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var change_row := HBoxContainer.new()
	change_row.add_theme_constant_override("separation", 10)
	column.add_child(change_row)
	_button(change_row, "切换角色", _lobby_change_character)
	if hosting:
		var all_ready: bool = true
		for member in roster:
			all_ready = all_ready and bool(member.get("ready", false))
		var start: Button = _button(change_row, "开始游戏", _start_match, true)
		start.disabled = not all_ready
	else:
		var ready_now: bool = bool(me.get("ready", false))
		_button(change_row, "取消准备" if ready_now else "准备就绪", func(): _set_member.rpc_id(1, str(profile.character), not ready_now), not ready_now)
	_button(column, "离开房间", func(): _disconnect(); _show_menu())
	_label(column, "每人独立镜头 · 合作救援 · 三段远征", 13, MUTED)

func _lobby_change_character() -> void:
	profile.character = "vanguard" if profile.character == "ranger" else "ranger"
	_save_profile()
	if hosting:
		roster[0].character = profile.character
		_broadcast_lobby()
	else:
		_set_member.rpc_id(1, str(profile.character), false)

func _show_settings(in_game: bool = false) -> void:
	_settings_in_game = in_game
	if in_game:
		paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		screen = "settings"
	var settings_description: String = "语言、声音与显示。更改自动保存。"
	if _is_web() and (not OS.is_userfs_persistent() or _profile_save_error != OK):
		settings_description = "此浏览器无法保存设置；关闭页面后更改可能丢失。"
	var column: VBoxContainer = _page("设置", settings_description, 550, in_game)
	column.add_theme_constant_override("separation", 7)
	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	column.add_child(language_row)
	var language_label: Label = _label(language_row, "语言 / Language", 15, TEAL)
	language_label.custom_minimum_size.x = 140
	language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for language in [["zh", "简体中文"], ["en", "English"]]:
		var code: String = language[0]
		var option: Button = _button(language_row, language[1], func(): _set_language(code), Locale.current_language == code)
		option.custom_minimum_size.y = 40
	_label(column, "旅者名称", 15, TEAL)
	var field: LineEdit = _text_field(column, str(profile.name))
	field.max_length = 18
	field.text_changed.connect(func(value: String): profile.name = value.strip_edges() if not value.strip_edges().is_empty() else "Traveller"; _save_profile())
	_settings_slider(column, "主音量", float(profile.volume), 0.0, 1.0, func(value: float): profile.volume = value; _apply_settings(); _save_profile())
	_settings_slider(column, "特效强度", float(profile.effects), 0.5, 1.5, func(value: float): profile.effects = value; _apply_settings(); _save_profile())
	var effect_hint: Label = _label(column, "叠层会增强局部光效；可降低强度或关闭镜头震动。", 13, MUTED)
	effect_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_hint.custom_minimum_size.x = 550
	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 12)
	column.add_child(display_row)
	_button(display_row, Locale.format("镜头震动  ·  %s", [Locale.text("开启" if profile.shake else "关闭")]), func(): profile.shake = not profile.shake; _apply_settings(); _save_profile(); _show_settings(_settings_in_game))
	_fps_settings_button = _button(display_row, _fps_setting_text(), _toggle_fps)
	_fullscreen_button = _button(column, "切换全屏" if _is_web() else "切换窗口 / 全屏  ·  F11", _toggle_fullscreen)
	_button(column, "返回战场" if in_game else "返回", _resume if in_game else _show_menu, true)

func _set_language(language: String) -> void:
	if language not in ["zh", "en"]:
		return
	profile.language = language
	Locale.set_language(language)
	_save_profile()
	# Rebuild only presentation. A live expedition and its network identity stay intact.
	if screen == "playing":
		var was_paused: bool = paused
		var had_settings: bool = _settings_in_game
		var had_map: bool = is_instance_valid(_map_view)
		var had_inventory: bool = is_instance_valid(_inventory_grid)
		var inventory_filter: String = _inventory_filter
		_build_hud()
		paused = was_paused
		if had_settings:
			_show_settings(true)
		elif had_map:
			_show_map()
		elif had_inventory:
			_show_inventory()
			_populate_inventory(inventory_filter)
		elif was_paused:
			_show_pause()
		return
	match screen:
		"settings": _show_settings()
		"characters": _show_characters()
		"guide": _show_guide()
		"join": _show_join()
		"lobby": _show_lobby()
		"results": _show_results()
		_: _show_menu()

func _settings_slider(parent: Node, title: String, value: float, minimum: float, maximum: float, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label: Label = _label(row, title, 15, TEAL)
	label.custom_minimum_size.x = 140
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.y = 32
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track: StyleBoxFlat = _style(Color("253c41"), Color.TRANSPARENT, 2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = TEAL.darkened(0.25)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", UITheme.slider_grip(PAPER))
	slider.add_theme_icon_override("grabber_highlight", UITheme.slider_grip(AMBER))
	slider.add_theme_icon_override("grabber_disabled", UITheme.slider_grip(MUTED))
	row.add_child(slider)
	var amount: Label = _label(row, "%d%%" % roundi(value * 100), 14, MUTED)
	amount.custom_minimum_size.x = 50
	slider.value_changed.connect(func(next: float): amount.text = "%d%%" % roundi(next * 100); action.call(next))

func _show_guide() -> void:
	screen = "guide"
	var guide_width: float = 800 if Locale.current_language == "en" else 590
	var column: VBoxContainer = _page("操作指南", "基础操作与通关目标。", guide_width)
	column.add_theme_constant_override("separation", 7)
	var guide: Array = [
		["A / D   或   ← / →", "移动；相反方向同时按住时，后按优先"],
		["Space / W / ↑", "短按低跳，长按高跳；羽翼增加空跳"],
		["S + Space", "穿过脚下的平台"],
		["鼠标左键", "使用当前主武器，跟随鼠标瞄准"],
		["鼠标右键 / Q", "使用当前主动装备；下方显示冷却"],
		["Shift", "职业主动：游侠闪身，先锋架盾反击"],
		["自动触发", "职业被动与遗物无需按键；Tab 查看触发条件"],
		["E", "拾取 / 使用设施 / 激活裂隙门 / 救援"],
		["F   /   按住 Alt", "切换附近目标 / 展开道具与装备详情"],
		["Tab / M / Esc / F3", "构筑 / 地图 / 菜单 / 帧率"] if _is_web() else ["Tab / M / Esc / F11 / F3", "构筑 / 地图 / 菜单 / 全屏 / 帧率"]
	]
	for entry in guide:
		var row := HBoxContainer.new()
		column.add_child(row)
		row.add_theme_constant_override("separation", 16)
		var key_box := PanelContainer.new()
		var key_style: StyleBoxFlat = _style(SURFACE, EDGE, 3)
		key_style.content_margin_left = 10
		key_style.content_margin_right = 10
		key_style.content_margin_top = 3
		key_style.content_margin_bottom = 3
		key_box.add_theme_stylebox_override("panel", key_style)
		key_box.custom_minimum_size.x = 220
		row.add_child(key_box)
		var key: Label = _label(key_box, entry[0], 13, AMBER)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var instruction: Label = _label(row, entry[1], 15, PAPER)
		instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gap(column, 6)
	var tip: Label = _label(column, "三处区域路线不同，按 M 找路，基础单跳即可通行。停留不持续补怪，强度仍随时间增长。遗物图标常驻左下角，悬停查看效果；Tab 查看构筑与图鉴。白 / 绿 / 紫 / 金代表四级稀有度，红字另示代价。裂隙充能并击败守卫后可前进。", 15, MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = guide_width
	_button(column, "返回", _show_menu, true)

func _icon(parent: Node, id: String, size: int = 48) -> TextureRect:
	var image := TextureRect.new()
	image.texture = Icons.texture(id, size)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size = Vector2(size, size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _meter(parent: Node, tint: Color, dimensions: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = dimensions
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("213a43")
	background.set_corner_radius_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(1)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _hud_panel(position: Vector2, dimensions: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop: StyleBoxFlat = _style(Color(0.025, 0.065, 0.085, 0.78), Color(0.28, 0.43, 0.44, 0.48), 5)
	backdrop.content_margin_left = 10
	backdrop.content_margin_right = 10
	backdrop.content_margin_top = 7
	backdrop.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", backdrop)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	return column

func _loadout_slot(parent: Node, key: String, binding: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(50, 65)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _style(Color(0.035, 0.09, 0.115, 0.74), Color("30444c"), 6)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(38, 34)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_box)
	var image: TextureRect = _icon(icon_box, "dash", 34)
	image.position.x = 2
	image.size = Vector2(34, 34)
	var remaining: Label = _label(icon_box, "", 16, PAPER)
	remaining.size = Vector2(38, 34)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	remaining.add_theme_color_override("font_shadow_color", INK)
	remaining.add_theme_constant_override("shadow_offset_x", 1)
	remaining.add_theme_constant_override("shadow_offset_y", 1)
	var progress: ProgressBar = _meter(content, TEAL, Vector2(38, 2))
	var key_label: Label = _label(content, binding, 10, MUTED)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label: Label = _label(content, "", 11, PAPER)
	name_label.visible = false
	_slot_ui[key] = {"icon": image, "name": name_label, "bar": progress, "cooldown": remaining, "panel": panel, "id": ""}

func _build_hud() -> void:
	_clear_ui()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hud)
	var health: VBoxContainer = _hud_panel(Vector2(18, 18), Vector2(190, 42))
	_hud_labels["health"] = _label(health, "", 12, PAPER)
	_hp_bar = _meter(health, TEAL, Vector2(170, 5))
	var expedition: VBoxContainer = _hud_panel(Vector2(1012, 18), Vector2(250, 32))
	_hud_labels["expedition"] = _label(expedition, "", 12, MUTED)
	_hud_labels.expedition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_coin_hud()
	var objective: VBoxContainer = _hud_panel(Vector2(480, 18), Vector2(320, 34))
	_objective_panel = objective.get_parent()
	_hud_labels["objective"] = _label(objective, "", 12, PAPER)
	_hud_labels.objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_bar = _meter(objective, AMBER, Vector2(300, 3))
	_objective_panel.visible = false
	_hud_labels["team"] = _label(hud, "", 11, MUTED)
	_hud_labels.team.position = Vector2(22, 69)
	_hud_labels.team.add_theme_constant_override("line_spacing", 3)
	var actions := HBoxContainer.new()
	actions.position = Vector2(1096, 639)
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(actions)
	_loadout_slot(actions, "weapon", "左键")
	_loadout_slot(actions, "equipment", "Q / 右键")
	_loadout_slot(actions, "dash", "SHIFT")
	_hud_labels["relics"] = _label(hud, "", 11, MUTED)
	_hud_labels.relics.position = Vector2(20, 644)
	_relic_strip = GridContainer.new()
	_relic_strip.position = Vector2(18, 666)
	_relic_strip.columns = 14
	_relic_strip.add_theme_constant_override("h_separation", 3)
	_relic_strip.add_theme_constant_override("v_separation", 3)
	_relic_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_relic_strip)
	_hud_labels["hint"] = _label(hud, "", 11, MUTED)
	_hud_labels.hint.position = Vector2(18, 620)
	_notice = _label(hud, "", 13, AMBER)
	_notice.position = Vector2(370, 65)
	_notice.size = Vector2(540, 54)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_loot_panel()
	_update_hud()
	_update_inspection_visibility()

func _build_coin_hud() -> void:
	_coin_panel = PanelContainer.new()
	_coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _style(Color(0.055, 0.075, 0.075, 0.88), Color(0.76, 0.56, 0.28, 0.5), 7)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_coin_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(_coin_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_panel.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(26, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	icon.draw.connect(func():
		icon.draw_circle(Vector2(13, 16), 11, Color("9f622d"))
		icon.draw_circle(Vector2(13, 14), 10, Color("f5c76c"))
		icon.draw_circle(Vector2(13, 14), 7, Color("b77c38"), false, 1.4, true)
		icon.draw_line(Vector2(13, 9), Vector2(13, 19), Color("fff0aa"), 2.3, true)
		icon.draw_line(Vector2(10, 11), Vector2(15, 11), Color("fff0aa"), 1.4, true)
	)
	_hud_labels["coins"] = _label(row, "0", 24, AMBER)
	_hud_labels.coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_labels.coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_labels.coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_panel.position = Vector2(1130, 55)
	_coin_panel.custom_minimum_size = Vector2(132, 40)

func _update_coins(balance: int) -> void:
	if not is_instance_valid(_coin_panel):
		return
	if balance == _last_coin_balance:
		return
	if _last_coin_balance >= 0 and balance != _last_coin_balance:
		_coin_feedback = 0.55
	_last_coin_balance = balance
	_hud_labels.coins.text = str(balance)
	# Keep every digit, including unusually large saved/test balances.
	var width: float = maxf(132.0, heading_font.get_string_size(str(balance), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 58.0)
	_coin_panel.custom_minimum_size.x = width
	_coin_panel.size = Vector2(width, 40)
	_coin_panel.position.x = 1262.0 - width

func _build_fps_overlay() -> void:
	_fps_label = _label(ui, "— FPS", 12, MUTED)
	_fps_label.name = "FpsReadout"
	_fps_label.position = Vector2(1158, 101)
	_fps_label.size = Vector2(104, 20)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.z_index = 100
	_fps_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.05, 0.9))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_refresh_fps_view()

func _fps_setting_text() -> String:
	return Locale.format("显示帧率  ·  %s  /  F3", [Locale.text("开启" if profile.get("show_fps", true) else "关闭")])

func _refresh_fps_view() -> void:
	if is_instance_valid(_fps_label):
		_fps_label.visible = bool(profile.get("show_fps", true))
		var wide_modal: bool = (is_instance_valid(_inventory_grid) and _inventory_grid.is_inside_tree()) or (is_instance_valid(_map_view) and _map_view.is_inside_tree())
		_fps_label.position = Vector2(1158, 0 if wide_modal else 101)
	if is_instance_valid(_fps_settings_button):
		_fps_settings_button.text = _fps_setting_text()

func _toggle_fps() -> void:
	profile.show_fps = not bool(profile.get("show_fps", true))
	_refresh_fps_view()
	_update_fps(0.0, true)
	_save_profile()

func _update_fps(delta: float, force: bool = false) -> void:
	_fps_refresh_clock += maxf(0.0, delta)
	if not force and _fps_refresh_clock < FPS_REFRESH_INTERVAL:
		return
	_fps_refresh_clock = fmod(_fps_refresh_clock, FPS_REFRESH_INTERVAL)
	if not is_instance_valid(_fps_label) or not bool(profile.get("show_fps", true)):
		return
	# Engine FPS measures rendered frames, independently of the 60 Hz simulation.
	_fps_value = maxi(0, roundi(Engine.get_frames_per_second()))
	var next_text: String = "%d FPS" % _fps_value if _fps_value > 0 else "— FPS"
	if _fps_label.text != next_text:
		_fps_label.text = next_text
	var tint: Color = MUTED
	if _fps_value > 0 and _fps_value < 30:
		tint = Color("d69587")
	elif _fps_value > 0 and _fps_value < 45:
		tint = AMBER
	_set_label_color(_fps_label, tint)

func _update_inspection_visibility() -> void:
	if not is_instance_valid(_relic_strip):
		return
	var expanded: bool = Input.is_key_pressed(KEY_ALT) and not paused
	_relic_strip.visible = not _relic_tiles.is_empty()
	_hud_labels.relics.visible = expanded and _relic_strip.visible
	_hud_labels.hint.visible = expanded
	var hint: String = Locale.text("[Tab] 构筑 / 图鉴  ·  [F] 切换目标  ·  悬停图标查看效果") + Locale.text("  ·  [M] 地图")
	var mode: String = str(sim.state.get("director", {}).get("mode", "rest"))
	_hud_labels.hint.text = hint + "   /   " + Locale.text({"rest": "停留 · 环境怪不再补充", "exploring": "探索中", "event": "事件战斗中"}.get(mode, ""))


func _build_loot_panel() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.position = Vector2(892, 342)
	_loot_panel.custom_minimum_size = Vector2(306, 0)
	_loot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style: StyleBoxFlat = _style(Color(0.025, 0.065, 0.09, 0.94), Color("3a5359"), 7)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	_loot_panel.add_theme_stylebox_override("panel", card_style)
	hud.add_child(_loot_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_panel.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 9)
	column.add_child(header)
	_loot_ui["icon"] = _icon(header, "unknown", 30)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	header.add_child(names)
	_loot_ui["category"] = _label(names, "", 11, MUTED)
	_loot_ui["name"] = _label(names, "", 16, PAPER)
	_loot_ui.name.custom_minimum_size.x = 241
	_loot_ui.name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in ["description", "warning", "replace", "action", "alternatives"]:
		var label: Label = _label(column, "", 12 if key != "action" else 14, PAPER)
		label.custom_minimum_size.x = 280
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_loot_ui[key] = label
	_loot_ui.warning.add_theme_color_override("font_color", Color("ff9b9b"))
	_loot_ui.replace.add_theme_color_override("font_color", MUTED)
	_loot_ui.alternatives.add_theme_font_size_override("font_size", 12)
	_loot_ui.alternatives.add_theme_color_override("font_color", MUTED)
	_loot_panel.visible = false

func _refresh_relics(inventory: Dictionary) -> void:
	var signature: String = JSON.stringify(inventory)
	if signature == _relic_signature:
		return
	_relic_signature = signature
	for child in _relic_strip.get_children():
		_relic_strip.remove_child(child)
		child.queue_free()
	_relic_tiles.clear()
	for definition in Simulation.item_catalog():
		var count: int = int(inventory.get(definition.id, 0))
		if count <= 0:
			continue
		var tile := Control.new()
		tile.custom_minimum_size = Vector2(34, 34)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_relic_strip.add_child(tile)
		var rarity_tint: Color = Content.rarity_color(str(definition.get("rarity", "common")))
		var frame := Panel.new()
		frame.size = Vector2(34, 34)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame_style: StyleBoxFlat = _style(Color(0.025, 0.065, 0.085, 0.78), Color(rarity_tint, 0.55), 4)
		frame_style.content_margin_left = 0
		frame_style.content_margin_right = 0
		frame_style.content_margin_top = 0
		frame_style.content_margin_bottom = 0
		frame.add_theme_stylebox_override("panel", frame_style)
		tile.add_child(frame)
		var image: TextureRect = _icon(tile, str(definition.id), 30)
		image.position = Vector2(2, 1)
		image.size = Vector2(30, 30)
		var edge := ColorRect.new()
		edge.position = Vector2(5, 31)
		edge.size = Vector2(24, 2)
		edge.color = rarity_tint
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(edge)
		var amount: Label = _label(tile, str(count) if count < 1000 else "999+", 10, PAPER)
		amount.add_theme_color_override("font_shadow_color", INK)
		amount.add_theme_color_override("font_outline_color", INK)
		amount.add_theme_constant_override("outline_size", 3)
		amount.position = Vector2(1, 16)
		amount.size = Vector2(31, 16)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_relic_tiles.append({"control": tile, "id": str(definition.id), "count": count, "rarity": definition.get("rarity", "common")})
	var rows: int = maxi(1, ceili(_relic_tiles.size() / float(_relic_strip.columns)))
	_relic_strip.position = Vector2(18, 704 - rows * 34 - (rows - 1) * 3)
	_hud_labels.relics.position.y = _relic_strip.position.y - 20
	_hud_labels.hint.position.y = _relic_strip.position.y - 42
	_update_inspection_visibility()

func _update_slot(key: String, id: String, cooldown: float, maximum: float, definition_override: Dictionary = {}) -> void:
	var slot: Dictionary = _slot_ui[key]
	var definition: Dictionary = definition_override if not definition_override.is_empty() else Simulation.loot_definition(id)
	if str(slot.id) != id:
		slot.icon.texture = Icons.texture(id, 34)
		slot.id = id
		var frame: StyleBoxFlat = slot.panel.get_theme_stylebox("panel").duplicate()
		frame.border_color = Content.rarity_color(str(definition.get("rarity", "common"))) if key != "dash" else Icons.color(id).darkened(0.45)
		slot.panel.add_theme_stylebox_override("panel", frame)
		if key == "dash":
			var fill: StyleBoxFlat = slot.bar.get_theme_stylebox("fill").duplicate()
			fill.bg_color = Icons.color(id)
			slot.bar.add_theme_stylebox_override("fill", fill)
	slot.name.text = Locale.text(str(definition.get("name", id)))
	var unavailable: bool = cooldown > 0.1 and key != "weapon"
	slot.cooldown.text = str(ceili(cooldown)) if unavailable else ""
	slot.icon.modulate = Color(0.4, 0.5, 0.52, 0.8) if unavailable else Color.WHITE
	slot.bar.value = 100.0 * (1.0 - clampf(cooldown / maxf(maximum, 0.1), 0.0, 1.0))

func _update_hud() -> void:
	if _hud_labels.is_empty() or not sim.state.get("players", {}).has(local_id):
		return
	var player: Dictionary = sim.state.players[local_id]
	_hp_bar.max_value = maxf(1.0, float(player.max_hp))
	_hp_bar.value = float(player.hp)
	_hud_labels.health.text = "%d / %d" % [ceili(float(player.hp)), ceili(float(player.max_hp))]
	var total_shield: float = float(player.get("shield", 0.0)) + float(player.get("reactive_shield", 0.0))
	if total_shield > 0.0:
		_hud_labels.health.text += Locale.format("   +%d 护盾", [ceili(total_shield)])
	var elapsed: int = int(sim.state.get("time", 0.0))
	var difficulty: float = float(sim.state.get("difficulty", 1.0))
	_hud_labels.expedition.text = Locale.format("%02d/03  %02d:%02d  威胁%.1f", [int(sim.state.get("stage", 1)), elapsed / 60, elapsed % 60, difficulty])
	_update_coins(int(player.coins))
	_set_label_color(_hud_labels.expedition, Color("ee9488") if difficulty >= 4 else (AMBER if difficulty >= 2 else MUTED))
	var gate: Dictionary = sim.state.get("gate", {})
	_objective_panel.visible = bool(gate.get("active", false)) or bool(player.dead)
	_hud_labels.objective.text = Locale.format("裂隙 %d%%  ·  %s", [int(float(gate.get("charge", 0.0)) * 100.0), Locale.text("击败守卫" if sim.state.get("boss_alive", false) else "留在附近充能")])
	if gate.get("ready", false):
		_hud_labels.objective.text = Locale.text("裂隙就绪  ·  靠近按 E 前进")
	_gate_bar.visible = bool(gate.get("active", false)) and not bool(player.dead)
	_gate_bar.value = clampf(float(gate.get("charge", 0.0)), 0.0, 1.0) * 100.0
	var teammates: Array[String] = []
	for id in sim.state.players:
		if id == local_id:
			continue
		var member: Dictionary = sim.state.players[id]
		teammates.append(str(member.name).substr(0, 10) + "  " + (Locale.text("✚ 待救援") if member.dead else "%d HP" % ceili(float(member.hp))))
	_hud_labels.team.text = "\n".join(teammates)
	var weapon: String = str(player.get("weapon", "pulse_rifle"))
	var equipment: String = str(player.get("equipment", "grenade"))
	_update_slot("weapon", weapon, float(player.fire_cd), float(Simulation.loot_definition(weapon).get("fire_interval", 0.19)))
	_update_slot("equipment", equipment, float(player.skill_cd), float(Simulation.loot_definition(equipment).get("cooldown", 8.0)))
	var movement_ability: Dictionary = Simulation.movement_ability(player)
	_update_slot("dash", str(movement_ability.id), float(player.dash_cd), float(movement_ability.cooldown), movement_ability)
	_hud_labels.relics.text = Locale.format("遗物 %d 件  ·  %d 种", [_item_total(player.items), player.items.size()])
	_refresh_relics(player.items)
	if player.dead:
		_hud_labels.objective.text = Locale.text("等待队友靠近按 E 救援")


func _refresh_interaction_focus() -> void:
	_interaction_options = sim.interaction_candidates(local_id)
	for candidate in _interaction_options:
		if _same_interaction(candidate, _interaction_selection):
			_focus_target = candidate
			return
	_interaction_selection.clear()
	_focus_target = _interaction_options[0] if not _interaction_options.is_empty() else {}

func _same_interaction(first: Dictionary, second: Dictionary) -> bool:
	return not first.is_empty() and not second.is_empty() and first.get("kind") == second.get("kind") and first.get("id") == second.get("id")

func _cycle_interaction() -> void:
	_refresh_interaction_focus()
	if _interaction_options.size() < 2:
		return
	var current: int = 0
	for index in range(_interaction_options.size()):
		if _same_interaction(_interaction_options[index], _focus_target):
			current = index
			break
	_focus_target = _interaction_options[(current + 1) % _interaction_options.size()]
	_interaction_selection = {"kind": _focus_target.kind, "id": _focus_target.id}
	world.interaction_target = _focus_target

func _hovered_loadout() -> Dictionary:
	var pointer: Vector2 = get_viewport().get_mouse_position()
	for tile in _relic_tiles:
		if tile.control.is_visible_in_tree() and tile.control.get_global_rect().has_point(pointer):
			return tile
	for key in ["weapon", "equipment", "dash"]:
		if not _slot_ui.has(key):
			continue
		var slot: Dictionary = _slot_ui[key]
		if slot.icon.is_visible_in_tree() and slot.icon.get_global_rect().has_point(pointer):
			return {"id": str(slot.id), "count": 1, "equipped": true, "innate": key == "dash"}
	return {}

func _update_interaction_panel(player: Dictionary) -> void:
	if paused or bool(player.get("dead", false)):
		_loot_panel.visible = false
		return
	var target: Dictionary = _focus_target
	var expanded: bool = Input.is_key_pressed(KEY_ALT)
	var hovered: Dictionary = _hovered_loadout()
	if not hovered.is_empty():
		expanded = true
		if bool(hovered.get("innate", false)):
			var active: Dictionary = Content.movement_ability(str(player.get("character", "ranger")))
			var passive: Dictionary = Content.character_passive(str(player.get("character", "ranger")))
			target = {"kind": "inspect", "item": active.id, "title": Locale.format("Shift 主动 · %s", [Locale.text(str(active.name))]), "description": Locale.text(str(active.description)) + "\n\n" + Locale.format("自动被动 · %s", [Locale.text(str(passive.name))]) + "\n" + Locale.text(str(passive.description)), "category": "character", "prompt": "[Tab] 查看完整构筑", "affordable": true}
		else:
			var definition: Dictionary = Simulation.loot_definition(str(hovered.id))
			var suffix: String = Locale.text(" · 已装备") if hovered.get("equipped", false) else " ×" + str(hovered.count)
			target = {"kind": "inspect", "item": hovered.id, "title": Locale.text(str(definition.name)) + suffix, "description": definition.description, "warning": definition.get("warning", ""), "category": definition.category, "prompt": "[Tab] 查看完整构筑", "affordable": true}
	_loot_panel.visible = not target.is_empty()
	if target.is_empty():
		return
	# Geometry/distance vary every frame; only presentation changes rebuild text,
	# theme resources and container minimum sizes. Price, risks and selection are
	# included so a purchase or F/Alt press is reflected immediately.
	var signature: Array = [expanded, Locale.current_language, player.get("weapon"), player.get("equipment"), not hovered.is_empty(), _interaction_options.size()]
	for key in ["kind", "id", "item", "title", "description", "warning", "category", "prompt", "affordable", "facility_type"]:
		signature.append(target.get(key))
	for option in _interaction_options:
		signature.append([option.get("kind"), option.get("id")])
	if signature == _loot_signature:
		_position_loot_panel(player)
		return
	_loot_signature = signature
	var id: String = str(target.get("item", ""))
	var category: String = str(target.get("category", ""))
	var definition: Dictionary = Simulation.loot_definition(id)
	var category_text: String = {"passive": "被动遗物  ·  可叠加", "weapon": "主武器  ·  单一槽位", "equipment": "主动装备  ·  单一槽位", "character": "职业能力 · 换装后保留"}.get(category, "交互设施")
	if str(target.get("kind", "")) == "chest":
		category_text = "补给设施  ·  操作前确认代价"
	var icon_id: String = id if not id.is_empty() else str(target.get("kind", "unknown"))
	if str(target.get("kind", "")) == "chest":
		icon_id = str(target.get("facility_type", "cache"))
		if icon_id == "equipment":
			icon_id = "equipment_cache"
	_loot_ui.icon.texture = Icons.texture(icon_id, 30)
	var rarity: String = str(definition.get("rarity", "common"))
	var rarity_tint: Color = Content.rarity_color(rarity) if not definition.is_empty() else AMBER
	_loot_ui.category.text = (Locale.text(Content.rarity_name(rarity)) + "  ·  " if not definition.is_empty() else "") + Locale.text(category_text)
	_loot_ui.category.visible = true
	_loot_ui.category.add_theme_color_override("font_color", rarity_tint)
	var card_frame: StyleBoxFlat = _loot_panel.get_theme_stylebox("panel")
	card_frame.border_color = Color(rarity_tint, 0.6)
	_loot_ui.name.text = Locale.text(str(target.get("title", definition.get("name", ""))))
	_loot_ui.name.add_theme_color_override("font_color", rarity_tint)
	_loot_ui.description.text = Locale.text(str(target.get("description", definition.get("description", ""))))
	_loot_ui.description.max_lines_visible = -1 if expanded else 2
	_loot_ui.description.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if expanded else TextServer.OVERRUN_TRIM_ELLIPSIS
	var warning: String = str(target.get("warning", definition.get("warning", "")))
	if category in ["weapon", "equipment"] and str(target.get("kind", "")) == "pickup":
		warning = str(definition.get("warning", ""))
	_loot_ui.warning.visible = not warning.is_empty()
	_loot_ui.warning.text = Locale.text(warning)
	_loot_ui.replace.visible = category in ["weapon", "equipment"] and str(target.get("kind", "")) == "pickup"
	if _loot_ui.replace.visible:
		var old: Dictionary = Simulation.loot_definition(str(player.get(category, "")))
		_loot_ui.replace.text = Locale.format("替换「%s · %s」；旧装备落地，冷却保留。", [Locale.text(Content.rarity_name(str(old.get("rarity", "common")))), Locale.text(str(old.get("name", "当前装备")))])
	_loot_ui.action.text = Locale.text(str(target.get("prompt", "[ E ] 交互")))
	_loot_ui.action.add_theme_color_override("font_color", TEAL if target.get("affordable", true) else Color("ff9b9b"))
	_loot_ui.alternatives.visible = true
	var selection_index: int = 0
	for index in range(_interaction_options.size()):
		if _same_interaction(_interaction_options[index], target):
			selection_index = index
			break
	_loot_ui.alternatives.text = Locale.text("移开鼠标收起  ·  Tab 查看构筑" if not hovered.is_empty() else ("松开 Alt 收起" if expanded else "按住 Alt 查看完整说明"))
	if _interaction_options.size() > 1 and str(target.get("kind", "")) != "inspect":
		_loot_ui.alternatives.text += "  ·  [F] %d/%d" % [selection_index + 1, _interaction_options.size()]
	_loot_panel.custom_minimum_size.x = 346 if expanded else 306
	for key in ["description", "warning", "replace", "action", "alternatives"]:
		_loot_ui[key].custom_minimum_size.x = 322 if expanded else 280
	_loot_panel.reset_size()
	_position_loot_panel(player)

func _position_loot_panel(player: Dictionary) -> void:
	var actor_x: float = world.world_to_screen(player.pos).x
	_loot_panel.position.x = 18.0 if actor_x > 815.0 else 1262.0 - _loot_panel.size.x
	_loot_panel.position.y = maxf(100.0, 622.0 - _loot_panel.size.y)

func _set_label_color(label: Label, color: Color) -> void:
	if label.get_theme_color("font_color") != color:
		label.add_theme_color_override("font_color", color)

func _item_total(items: Dictionary) -> int:
	var count: int = 0
	for value in items.values():
		count += int(value)
	return count

func _interaction_hint(_player: Dictionary) -> String:
	return str(sim.interaction_for(local_id).get("prompt", Locale.text("Space 跳跃 · E 交互 · Tab 背包")))

func _inventory_card(parent: Node, definition: Dictionary, count: int, equipped: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(510, 110)
	var rarity: String = str(definition.get("rarity", "common"))
	var tint: Color = Content.rarity_color(rarity)
	var frame: StyleBoxFlat = _style(SURFACE if count > 0 else Color("0d2027"), Color(tint, 0.5 if count > 0 else 0.22), 4)
	frame.border_width_left = 3
	frame.content_margin_left = 13
	frame.content_margin_right = 13
	panel.add_theme_stylebox_override("panel", frame)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var image: TextureRect = _icon(row, str(definition.id), 42)
	image.modulate.a = 1.0 if count > 0 else 0.78
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	var category: String = {"passive": "被动遗物 · 可叠加", "weapon": "主武器 · 单一槽位", "equipment": "主动装备 · 单一槽位"}.get(str(definition.get("category", "passive")), "遗物")
	_label(words, Locale.text(Content.rarity_name(rarity)) + "  /  " + Locale.text(category), 11, tint)
	var title: Label = _label(words, Locale.text(str(definition.name)) + (Locale.text("  ·  已装备") if equipped else ("  ×" + str(count) if count > 0 else Locale.text("  ·  未持有"))), 16, PAPER if count > 0 else MUTED)
	title.custom_minimum_size.x = 414
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var description: Label = _label(words, str(definition.description), 14, PAPER if count > 0 else MUTED)
	description.custom_minimum_size.x = 414
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not str(definition.get("warning", "")).is_empty():
		var downside: Label = _label(words, str(definition.warning), 13, Color("ff9b9b"))
		downside.custom_minimum_size.x = 414
		downside.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_inventory() -> void:
	_reset_controls()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay_surface(Rect2(48, 20, 1184, 680), 0.94)
	var content := VBoxContainer.new()
	content.position = Vector2(72, 38)
	content.size = Vector2(1136, 638)
	content.add_theme_constant_override("separation", 10)
	overlay.add_child(content)
	_label(content, "背包与图鉴", 30, PAPER)
	var player: Dictionary = sim.state.get("players", {}).get(local_id, {})
	_label(content, Locale.format("%s · %d/%d HP · %d 段跳 · 威胁 %.1f · %d 击破   /   %s", [Locale.text("游侠" if player.get("character", "ranger") == "ranger" else "先锋"), ceili(float(player.get("hp", 0))), ceili(float(player.get("max_hp", 0))), 1 + int(player.get("items", {}).get("feather", 0)), float(sim.state.get("difficulty", 1)), int(sim.state.get("kills", 0)), Locale.text("合作远征仍在继续" if online else "远征已暂停")]), 14, MUTED)
	var innate: Dictionary = Simulation.movement_ability(player)
	var passive: Dictionary = Content.character_passive(str(player.get("character", "ranger")))
	var innate_description: Label = _label(content, Locale.format("Shift 主动 · %s", [Locale.text(str(innate.name))]) + "   /   " + Locale.format("自动被动 · %s", [Locale.text(str(passive.name))]), 13, MUTED)
	innate_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	innate_description.custom_minimum_size.x = 1136
	_inventory_filters.clear()
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	content.add_child(filters)
	var tabs: Array = [["owned", "当前持有"], ["passive", Locale.format("遗物图鉴 · %d", [Simulation.item_catalog().size()])], ["weapon", Locale.format("主武器 · %d", [Simulation.weapon_catalog().size()])], ["equipment", Locale.format("主动装备 · %d", [Simulation.equipment_catalog().size()])]]
	for entry in tabs:
		var filter_key: String = entry[0]
		var button: Button = _button(filters, entry[1], func(): _populate_inventory(filter_key))
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 14)
		_inventory_filters[filter_key] = button
	var rarity_legend := HBoxContainer.new()
	rarity_legend.add_theme_constant_override("separation", 20)
	content.add_child(rarity_legend)
	for rarity in ["common", "uncommon", "rare", "legendary"]:
		_label(rarity_legend, "◆ " + Locale.text(Content.rarity_name(rarity)), 12, Content.rarity_color(rarity))
	_label(rarity_legend, "叠层数量在角标显示；红字表示副作用。", 12, MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1136, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 2
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("h_separation", 14)
	_inventory_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_inventory_grid)
	_button(content, "返回战场  ·  Tab / Esc", _resume, true)
	_populate_inventory("owned")
	_refresh_fps_view()

func _populate_inventory(filter_key: String) -> void:
	if not is_instance_valid(_inventory_grid):
		return
	_inventory_filter = filter_key
	for child in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)
		child.queue_free()
	var player: Dictionary = sim.state.get("players", {}).get(local_id, {})
	var inventory: Dictionary = player.get("items", {})
	var definitions: Array = []
	match filter_key:
		"passive": definitions = Simulation.item_catalog()
		"weapon": definitions = Simulation.weapon_catalog()
		"equipment": definitions = Simulation.equipment_catalog()
		_:
			_character_ability_card(_inventory_grid, Content.movement_ability(str(player.get("character", "ranger"))), true)
			_character_ability_card(_inventory_grid, Content.character_passive(str(player.get("character", "ranger"))), false)
			for key in ["weapon", "equipment"]:
				definitions.append(Simulation.loot_definition(str(player.get(key, "pulse_rifle" if key == "weapon" else "grenade"))))
			for definition in Simulation.item_catalog():
				if int(inventory.get(definition.id, 0)) > 0:
					definitions.append(definition)
	for definition in definitions:
		if definition.is_empty():
			continue
		var category: String = str(definition.category)
		var equipped: bool = category in ["weapon", "equipment"] and str(player.get(category, "")) == str(definition.id)
		var count: int = int(inventory.get(definition.id, 0)) if category == "passive" else (1 if equipped else 0)
		_inventory_card(_inventory_grid, definition, count, equipped)
	for key in _inventory_filters:
		var button: Button = _inventory_filters[key]
		_skin_button(button, key == filter_key)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state)
			style.content_margin_top = 6
			style.content_margin_bottom = 6
	var scroll: ScrollContainer = _inventory_grid.get_parent()
	scroll.scroll_vertical = 0

func _character_ability_card(parent: Node, definition: Dictionary, active: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(510, 110)
	var tint: Color = TEAL if active else AMBER
	var style: StyleBoxFlat = _style(SURFACE, Color(tint, 0.5), 4)
	style.border_width_left = 3
	style.content_margin_left = 13
	style.content_margin_right = 13
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_icon(row, str(definition.id), 42)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	_label(words, "职业主动 · Shift" if active else "职业被动 · 自动触发", 11, tint)
	_label(words, str(definition.name), 16, PAPER)
	var description: Label = _label(words, str(definition.description), 14, PAPER)
	description.custom_minimum_size.x = 414
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_map() -> void:
	_reset_controls()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay_surface(Rect2(48, 20, 1184, 680), 0.94)
	var title: Label = _label(overlay, "%02d  /  %s" % [int(sim.state.get("stage", 1)), Locale.text(str(sim.state.get("stage_name", "远征地图")))], 30, PAPER)
	_map_title = title
	title.position = Vector2(72, 38)
	var subtitle: Label = _label(overlay, Locale.text("寻找通往高处裂隙的路线，探索分支补给。") + " " + Locale.text("合作远征仍在继续。" if online else "远征已暂停。"), 14, MUTED)
	subtitle.position = Vector2(72, 84)
	_map_view = MapView.new()
	_map_view.position = Vector2(72, 123)
	_map_view.size = Vector2(1136, 458)
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.map_font = font
	_map_view.set_frame(sim.state, local_id)
	overlay.add_child(_map_view)
	var legend: Label = _label(overlay, "青色 ● 你    蓝色 ● 队友    橙色 ◎ 裂隙门    图标 = 补给设施（暗色表示已使用）", 13, MUTED)
	legend.position = Vector2(72, 596)
	var back: Button = _button(overlay, "返回战场  ·  M / Esc", _resume, true)
	back.position = Vector2(72, 632)
	back.size = Vector2(1136, 44)
	_refresh_fps_view()


func _notify(message: String, duration: float = 3.5) -> void:
	if is_instance_valid(_notice):
		_notice.text = Locale.text(message)
		_notice.modulate.a = 1.0
		_notice_time = duration

func _show_pause() -> void:
	_reset_controls()
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay_surface(Rect2(411, 158, 458, 404), 0.78)
	var panel := VBoxContainer.new()
	panel.position = Vector2(435, 180)
	panel.size = Vector2(410, 340)
	panel.add_theme_constant_override("separation", 12)
	overlay.add_child(panel)
	_label(panel, "游戏菜单", 32, PAPER)
	_label(panel, "合作远征仍在继续。" if online else "游戏已暂停。", 14, MUTED)
	_divider(panel)
	_button(panel, "继续游戏", _resume, true)
	_button(panel, "设置", func(): _show_settings(true))
	_button(panel, "返回主菜单", func(): _disconnect(); _show_menu())
	_label(panel, "Esc 返回  ·  F3 帧率" if _is_web() else "Esc 返回  ·  F11 全屏  ·  F3 帧率", 13, MUTED)

func _resume() -> void:
	_reset_controls()
	paused = false
	_settings_in_game = false
	_map_view = null
	_map_title = null
	_inventory_grid = null
	_inventory_filters.clear()
	_refresh_fps_view()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null

func _show_results() -> void:
	screen = "results"
	paused = false
	var won: bool = sim.state.get("phase", "lost") == "won"
	if not _run_saved:
		profile.runs = int(profile.runs) + 1
		profile.best_stage = maxi(int(profile.best_stage), int(sim.state.get("stage", 1)))
		if won:
			profile.wins = int(profile.wins) + 1
		_save_profile()
		_run_saved = true
	var column: VBoxContainer = _page("通关成功" if won else "本局结束", "已完成全部三个区域。" if won else "调整构筑，再次挑战。", 560)
	var elapsed: int = int(sim.state.get("time", 0.0))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	column.add_child(stats)
	for metric: Array in [["区域", "%d / 3" % int(sim.state.get("stage", 1))], ["用时", "%02d:%02d" % [elapsed / 60, elapsed % 60]], ["击破", str(int(sim.state.get("kills", 0)))]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(SURFACE, EDGE, 4))
		stats.add_child(card)
		var words := VBoxContainer.new()
		card.add_child(words)
		_label(words, metric[0], 12, MUTED)
		_label(words, metric[1], 24, AMBER)
	var route := UIArt.new()
	route.mode = "route"
	route.stage = int(sim.state.get("stage", 1))
	route.custom_minimum_size.y = 26
	column.add_child(route)
	_divider(column)
	for player in sim.state.get("players", {}).values():
		_label(column, Locale.format("%s   ·   %d 件遗物   ·   %d 击破", [str(player.name), _item_total(player.get("items", {})), int(player.get("kills", 0))]), 16, PAPER)
	_gap(column, 15)
	if online:
		if hosting:
			_button(column, "返回小队大厅", _return_to_lobby, true)
		else:
			_label(column, "等待房主返回大厅，可再次出发。", 15, TEAL)
	else:
		_button(column, "再玩一次", _start_solo, true)
	_button(column, "返回主菜单", func(): _disconnect(); _show_menu())

func _return_to_lobby() -> void:
	if not hosting:
		return
	for member in roster:
		member.ready = int(member.id) == 1
	_broadcast_lobby()

func _draw_reticle() -> void:
	if screen != "playing" or paused:
		return
	var point: Vector2 = get_viewport().get_mouse_position()
	var color: Color = AMBER
	ui.draw_arc(point, 9.0, 0, TAU, 24, Color(0, 0, 0, 0.8), 3, true)
	ui.draw_arc(point, 8.0, 0, TAU, 24, color, 1, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		ui.draw_line(point + direction * 12.0, point + direction * 17.0, color, 1.5, true)
	ui.draw_circle(point, 1.8, PAPER)
