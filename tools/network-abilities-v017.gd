extends SceneTree

## Four actual ENet processes exercise production input batching, reconciliation,
## authoritative collision damage, snapshots and stage-tagged event delivery.
class AbilityProbe:
	extends "res://scripts/main.gd"
	var expected_ids: Array = []
	var records: Dictionary = {}
	var seen_kinds: Dictionary = {}
	var snapshot_active: Dictionary = {}
	var impact_keys: Dictionary = {}
	var duplicate_impacts: int = 0
	var predicted_starts: int = 0
	var prediction_changed_enemies: int = 0
	var hp_updates: int = 0
	var last_hp: Dictionary = {}
	var target_owners: Dictionary = {}
	var max_charge: float = 0.0

	func _begin_local(members: Array, seed_value: int) -> void:
		super._begin_local(members, seed_value)
		sim.state.world_size = Vector2(4200, 1100)
		sim.state.floor_y = 1000.0
		sim.state.platforms = [Rect2(0, 1000, 4200, 60)]
		sim.state.chests = []
		sim.state.enemies = []
		sim._spawn_clock = 9999.0
		var slot: int = 0
		for player: Dictionary in sim.state.players.values():
			var id: int = int(player.id)
			expected_ids.append(id)
			player.character = "vanguard" if slot % 2 == 0 else "ranger"
			player.pos = Vector2(600 + slot * 850, 979)
			player.vel = Vector2.ZERO
			player.grounded = true
			player.invuln = 0.0 if player.character == "vanguard" else 9999.0
			player.explore_anchor = player.pos
			player.explore_sites = [player.pos]
			records[str(id)] = {"character": player.character, "starts": 0, "blocks": 0, "releases": 0, "hits": 0, "ids": [], "release_ids": [], "distance": 0.0, "last_pos": player.pos.x}
			if hosting:
				var target: Dictionary = sim._spawn_enemy("crawler", Vector2(player.pos) + Vector2(65, 0))
				target.hp = 10000.0
				target.max_hp = 10000.0
				target.stun_timer = 9999.0
				target_owners[str(target.id)] = id
			slot += 1

	func _get_command() -> Dictionary:
		var cycle: int = int(_tick / 360)
		var aim: Vector2 = Vector2.RIGHT if cycle % 2 == 1 else Vector2.LEFT
		return {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "aim": aim,
			"dash": _tick > 90 and _tick % 360 < 6, "fire": false, "skill": false, "interact": false}

	func _physics_process(delta: float) -> void:
		var own_id: int = int(sim.state.get("players", {}).get(local_id, {}).get("dash_id", 0))
		var enemies: PackedByteArray = var_to_bytes(sim.state.get("enemies", [])) if online and not hosting else PackedByteArray()
		super._physics_process(delta)
		if screen != "playing": return
		if online and not hosting:
			if enemies != var_to_bytes(sim.state.get("enemies", [])): prediction_changed_enemies += 1
			if int(sim.state.get("players", {}).get(local_id, {}).get("dash_id", 0)) > own_id: predicted_starts += 1
		else:
			for player: Dictionary in sim.state.players.values():
				var record: Dictionary = records[str(player.id)]
				record.distance += absf(float(player.pos.x) - float(record.last_pos))
				record.last_pos = player.pos.x

	func _consume_events(events: Array) -> void:
		for event: Dictionary in events:
			if int(event.get("stage", sim.state.stage)) != int(sim.state.stage): continue
			var owner: String = str(event.get("player", event.get("owner", -1)))
			if not records.has(owner): continue
			if (event.get("type") == "dash" and event.has("ability")) or (event.get("type") == "ability" and event.get("phase") == "start"):
				seen_kinds[str(event.ability)] = true
				records[owner].starts += 1
				records[owner].ids.append(int(event.ability_id))
				if hosting and event.ability == "guard_burst":
					var target: Dictionary = sim.state.players[int(owner)]
					sim._spawn_projectile(target.pos + Vector2(110, 0), Vector2(-600, 0), "enemy", "spit", 50.0, -1, 1.0, 6.0)
			elif event.get("type") == "ability" and event.get("phase") == "block":
				records[owner].blocks += 1
				max_charge = maxf(max_charge, float(event.absorbed))
			elif event.get("type") == "ability" and event.get("phase") == "release":
				records[owner].releases += 1
				if records[owner].release_ids.has(int(event.ability_id)): duplicate_impacts += 1
				records[owner].release_ids.append(int(event.ability_id))
			elif event.get("type") == "hit" and event.has("owner") and not event.get("friendly", false):
				var key: String = "%s:%s:%s" % [owner, str(records[owner].ids.back()), str(event.pos)]
				if impact_keys.has(key): duplicate_impacts += 1
				impact_keys[key] = true
				records[owner].hits += 1
		super._consume_events(events)

	func _receive_snapshot(snapshot: Dictionary) -> void:
		var count: int = _snapshots_received
		super._receive_snapshot(snapshot)
		if count == _snapshots_received: return
		for player: Dictionary in Dictionary(snapshot.get("players", {})).values():
			if float(player.get("dash_timer", 0.0)) > 0.0 or float(player.get("guard_timer", 0.0)) > 0.0:
				var id: String = str(player.id)
				snapshot_active[id] = int(snapshot_active.get(id, 0)) + 1
				seen_kinds["guard_burst" if float(player.get("guard_timer", 0.0)) > 0.0 else str(player.dash_kind)] = true
				max_charge = maxf(max_charge, float(player.get("guard_absorbed", 0.0)))
		for enemy: Dictionary in Array(snapshot.get("enemies", [])):
			var id: String = str(enemy.id)
			if float(enemy.hp) < float(last_hp.get(id, enemy.hp)): hp_updates += 1
			last_hp[id] = float(enemy.hp)

	func _finish_automation() -> void:
		_smoke_finished = true
		var accepted: bool = _started and expected_ids.size() == 4 and seen_kinds.has("phase_dash") and seen_kinds.has("guard_burst") and duplicate_impacts == 0 and max_charge == 40.0
		for id: int in expected_ids:
			var record: Dictionary = records[str(id)]
			accepted = accepted and int(record.starts) >= 3
			if record.character == "vanguard": accepted = accepted and int(record.hits) >= 3 and int(record.hits) == int(record.releases) and int(record.blocks) >= int(record.releases) and int(record.starts) - int(record.releases) in [0, 1]
			else: accepted = accepted and int(record.hits) == 0
			if hosting: accepted = accepted and (float(record.distance) < 0.001 if record.character == "vanguard" else float(record.distance) >= 250.0)
			else: accepted = accepted and int(snapshot_active.get(str(id), 0)) >= 3
		if hosting:
			accepted = accepted and _inputs_received > 150
			for enemy: Dictionary in sim.state.enemies:
				var owner: String = str(target_owners.get(str(enemy.id), -1))
				if records.has(owner) and records[owner].character == "ranger": accepted = accepted and enemy.hp == 10000.0
		else:
			accepted = accepted and _snapshots_received > 80 and predicted_starts >= 3 and prediction_changed_enemies == 0 and hp_updates >= 4
		var report: Dictionary = {"passed": accepted, "mode": _smoke, "local_id": local_id, "players": expected_ids,
			"records": records, "seen_abilities": seen_kinds.keys(), "snapshot_active": snapshot_active,
			"duplicate_impacts": duplicate_impacts, "predicted_starts": predicted_starts, "prediction_changed_enemies": prediction_changed_enemies,
			"max_guard_charge": max_charge,
			"snapshots": _snapshots_received, "inputs": _inputs_received, "hp_updates": hp_updates, "elapsed": _elapsed,
			"simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
		if _options.has("report"):
			var file: FileAccess = FileAccess.open(str(_options.report), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "\t"))
		print("NETWORK_ABILITIES_V017_RESULT ", JSON.stringify(report))
		_quit_game(0 if accepted else 1)

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.has("--smoke-host") and not arguments.has("--smoke-client"):
		push_error("Use the bounded four-peer network ability runner.")
		quit(2)
		return
	var game := AbilityProbe.new()
	game.name = "NetworkAbilityProbe"
	root.add_child(game)
