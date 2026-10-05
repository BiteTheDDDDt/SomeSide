extends SceneTree

const Appearance = preload("res://scripts/player_appearance.gd")
const Content = preload("res://scripts/content.gd")
const Simulation = preload("res://scripts/simulation.gd")
const WorldView = preload("res://scripts/world_view.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const SLOTS: Array[String] = ["back", "shoulder", "chest", "head", "belt", "legs"]
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ",message)
	else:
		failed += 1
		push_error("FAIL: "+message)

func _valid_descriptor(value: Dictionary) -> bool:
	for key: String in ["slot","item","stacks","tier","scale","brightness"]:
		if not value.has(key): return false
	return str(value.slot) in SLOTS and int(value.stacks)>0 and int(value.tier)>=0 and int(value.tier)<=3 and is_finite(float(value.scale)) and float(value.scale)>0.0 and float(value.scale)<=1.1201 and is_finite(float(value.brightness)) and float(value.brightness)>0.0 and float(value.brightness)<=1.2001

func _run() -> void:
	var supported: Dictionary = Appearance.supported_items()
	var catalog: Array = Content.passives()
	var all_items: Dictionary = {}
	var groups: Dictionary = {}
	var complete: bool = supported.size()==24 and catalog.size()==24
	for entry: Dictionary in catalog:
		var id_value: String = str(entry.id)
		complete = complete and supported.has(id_value)
		if not supported.has(id_value): continue
		var slot: String = str(supported[id_value])
		complete = complete and slot in SLOTS
		if not groups.has(slot): groups[slot] = []
		groups[slot].append(entry)
		all_items[id_value] = 1
		var descriptor: Array = Appearance.build({id_value:1})
		_check(descriptor.size()==1 and str(descriptor[0].get("item",""))==id_value and str(descriptor[0].get("slot",""))==slot and _valid_descriptor(descriptor[0]),"A single "+id_value+" produces its own valid wearable part")
	_check(complete and groups.size()==6,"All 24 catalog relics are supported across exactly six valid body slots")
	_check(Appearance.build({}).is_empty(),"A character without relics has no extra body parts")
	_check(Appearance.build({"unknown_relic":999,"pulse_rifle":4,"overclock":0,"feather":-2}).is_empty(),"Unknown entries, equipment and nonpositive stacks cannot create body parts")
	var original_items: PackedByteArray = var_to_bytes(all_items)
	var mixed: Array = Appearance.build(all_items)
	var unique_slots: Dictionary = {}
	var descriptors_valid: bool = true
	for value: Dictionary in mixed:
		descriptors_valid = descriptors_valid and _valid_descriptor(value) and not unique_slots.has(str(value.slot))
		unique_slots[str(value.slot)] = true
	_check(mixed.size()==6 and descriptors_valid and unique_slots.size()==6,"Owning every relic uses at most one representative in each of six slots")
	_check(var_to_bytes(all_items)==original_items,"Building every body part leaves the source inventory byte-for-byte unchanged")
	var reversed: Dictionary = {}
	var keys: Array = all_items.keys()
	keys.reverse()
	for key: Variant in keys: reversed[key] = all_items[key]
	_check(Appearance.build(reversed)==mixed,"Equivalent inventories received in a different dictionary order yield identical ordered parts")
	var repeated: bool = true
	for index: int in range(50): repeated = repeated and Appearance.build(all_items)==mixed
	_check(repeated,"Repeated presentation builds have deterministic output without random variation")
	var rarity_checks: int = 0
	var stack_checks: int = 0
	var tie_deterministic: bool = true
	for slot: String in groups:
		var entries: Array = groups[slot]
		var checked_rarity: bool = false
		var checked_stacks: bool = false
		for left: Dictionary in entries:
			for right: Dictionary in entries:
				if str(left.id)==str(right.id): continue
				var left_rank: int = Content.rarity_rank(str(left.rarity))
				var right_rank: int = Content.rarity_rank(str(right.rarity))
				if left_rank>right_rank and not checked_rarity:
					var result: Array = Appearance.build({str(left.id):1,str(right.id):1000000})
					_check(result.size()==1 and str(result[0].item)==str(left.id),"Higher rarity wins a competing "+slot+" slot even against a million lower-rarity stacks")
					rarity_checks += 1
					checked_rarity = true
				elif left_rank==right_rank and not checked_stacks:
					var result: Array = Appearance.build({str(left.id):2,str(right.id):7})
					_check(result.size()==1 and str(result[0].item)==str(right.id),"Higher stacks choose the representative when competing "+slot+" relics share rarity")
					stack_checks += 1
					checked_stacks = true
					var tie_forward: Array = Appearance.build({str(left.id):4,str(right.id):4})
					var tie_reverse: Array = Appearance.build({str(right.id):4,str(left.id):4})
					tie_deterministic = tie_deterministic and tie_forward==tie_reverse and tie_forward.size()==1
	_check(rarity_checks>0 and stack_checks>0,"The actual catalog exercises both rarity and same-rarity stack selection")
	_check(tie_deterministic,"Tied rarity and stack counts use the same representative regardless of dictionary arrival order")
	var extreme_items: Dictionary = {}
	var bounded: bool = true
	var strengthened: bool = true
	for entry: Dictionary in catalog:
		var id_value: String = str(entry.id)
		extreme_items[id_value] = 1000000
		var low: Array = Appearance.build({id_value:1})
		var high: Array = Appearance.build({id_value:8})
		var extreme: Array = Appearance.build({id_value:1000000})
		if low.is_empty() or high.is_empty() or extreme.is_empty():
			bounded = false
			continue
		bounded = bounded and _valid_descriptor(extreme[0]) and float(extreme[0].scale)==float(high[0].scale) and float(extreme[0].brightness)==float(high[0].brightness) and int(extreme[0].tier)==int(high[0].tier)
		strengthened = strengthened and float(high[0].scale)>=float(low[0].scale) and float(high[0].brightness)>=float(low[0].brightness)
	_check(bounded,"Every relic saturates by eight stacks; a million stacks cannot exceed size 1.12, brightness 1.2 or tier three")
	_check(strengthened,"Higher stacks never make the selected wearable smaller or dimmer")
	_check(Appearance.build(extreme_items).size()==6,"Even all 24 extreme-stack relics retain the six-part budget")
	_check(Appearance.build(extreme_items,true).is_empty() and var_to_bytes(all_items)==original_items,"Death hides all wearable parts without removing inventory")
	var independent: Array = Appearance.build(all_items)
	if not independent.is_empty(): independent[0]["item"] = "mutated_preview"
	independent.clear()
	_check(Appearance.build(all_items)==mixed,"A caller mutating its returned descriptors cannot poison future appearance builds")
	await _check_render_isolation(all_items)
	await _check_weapon_visual_feedback()
	print("APPEARANCE_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _check_render_isolation(all_items: Dictionary) -> void:
	var simulation = Simulation.new()
	simulation.start_run([{"id":1,"name":"Local","character":"ranger"},{"id":2,"name":"Remote","character":"vanguard"}],2606)
	for player: Dictionary in simulation.state.players.values(): player.items = all_items.duplicate(true)
	var world = WorldView.new()
	root.add_child(world)
	world.set_process(false)
	world.interpolate_remote_entities = true
	var unchanged: bool = true
	var same_parts: bool = true
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1).normalized()]:
		for player: Dictionary in simulation.state.players.values(): player.aim = direction
		var snapshot: Dictionary = simulation.get_snapshot()
		var original: PackedByteArray = var_to_bytes(snapshot)
		world.set_frame(snapshot,1,1.0/60.0)
		world.call("_process",1.0/60.0)
		await process_frame
		unchanged = unchanged and var_to_bytes(snapshot)==original and simulation.get_snapshot()==snapshot
		same_parts = same_parts and Appearance.build(snapshot.players[1].items)==Appearance.build(snapshot.players[2].items)
	_check(unchanged,"Rendering local and remote fully equipped characters in five aim directions never writes into authoritative or incoming state")
	_check(same_parts,"Local and replicated teammates with identical relics derive identical parts independently of facing")
	world.queue_free()
	await process_frame

func _check_weapon_visual_feedback() -> void:
	var simulation = Simulation.new()
	simulation.start_run([{"id":1,"name":"Local","character":"ranger"},{"id":2,"name":"Remote","character":"vanguard"}],2607)
	simulation.state.enemies = []
	simulation.state.platforms = []
	var world = WorldView.new()
	root.add_child(world)
	world.set_process(false)
	world.interpolate_remote_entities = true
	var remote: Dictionary = simulation.state.players[2]
	var actual_metadata: bool = true
	var follows: bool = true
	var aim_control: bool = true
	var changed_weapon_hides: bool = true
	var dead_hides: bool = true
	var immutable: bool = true
	var zero_at_spawn: bool = true
	var short_first_step: bool = true
	var within_origin: bool = true
	var last_effect: Dictionary = {}
	for entry: Dictionary in Content.weapons():
		remote.weapon = str(entry.id)
		remote.dead = false
		remote.pos = Vector2(900,750)
		remote.aim = Vector2.RIGHT
		simulation.state.time += 0.1
		simulation.state.projectiles = []
		simulation.events.clear()
		world._effects.clear()
		simulation._fire_weapon(remote)
		var snapshot: Dictionary = simulation.get_snapshot()
		var events: Array = simulation.events.duplicate(true)
		var original_snapshot: PackedByteArray = var_to_bytes(snapshot)
		var original_events: PackedByteArray = var_to_bytes(events)
		world.set_frame(snapshot,1,1.0/60.0)
		world.push_events(events)
		var flash: Dictionary = {}
		for effect: Dictionary in world._effects:
			if str(effect.get("weapon",""))==str(entry.id) and int(effect.get("owner",-1))==2:
				flash = effect
				break
		actual_metadata = actual_metadata and not flash.is_empty()
		if flash.is_empty(): continue
		last_effect = flash
		for projectile: Dictionary in simulation.state.projectiles:
			zero_at_spawn = zero_at_spawn and WorldView.projectile_trail_length(projectile,projectile.pos,135.0)==0.0
		simulation._step_projectiles(1.0/240.0)
		for projectile: Dictionary in simulation.state.projectiles:
			var velocity: Vector2 = projectile.vel
			var origin: Vector2 = projectile.origin
			var drawn: Vector2 = origin.lerp(projectile.pos,0.5)
			var tail: float = WorldView.projectile_trail_length(projectile,drawn,135.0)
			short_first_step = short_first_step and tail>0.0 and tail<=float(projectile.travel_distance)+0.0001 and tail<135.0
			within_origin = within_origin and (drawn-velocity.normalized()*tail-origin).dot(velocity.normalized())>=-0.0001
			within_origin = within_origin and WorldView.projectile_trail_length(projectile,origin-velocity.normalized()*3.0,135.0)==0.0
		remote.pos += Vector2(36,20)
		remote.aim = Vector2(-1,-0.4).normalized()
		simulation.state.time += 0.05
		var moved_snapshot: Dictionary = simulation.get_snapshot()
		var original_moved: PackedByteArray = var_to_bytes(moved_snapshot)
		world.set_frame(moved_snapshot,1,1.0/60.0)
		var draw_pose: Dictionary = world.weapon_draw_pose(moved_snapshot.players[2])
		var flash_pose: Dictionary = world.muzzle_effect_pose(flash)
		var displayed_axis: Vector2 = Vector2.from_angle(float(draw_pose.weapon_angle))
		follows = follows and bool(flash_pose.visible) and Vector2(flash_pose.pos).distance_to(draw_pose.muzzle)<0.001 and Vector2(flash_pose.aim).distance_to(displayed_axis)<0.001 and Vector2(draw_pose.position).distance_to(remote.pos)>0.1 and Vector2(flash_pose.pos).distance_to(WeaponPose.muzzle_position(remote))>0.1
		var expected_aim: Vector2 = Vector2.RIGHT if str(entry.id)=="arc_blade" else Vector2(remote.aim)
		aim_control = aim_control and Vector2(draw_pose.aim).distance_to(expected_aim)<0.001
		await process_frame
		immutable = immutable and var_to_bytes(snapshot)==original_snapshot and var_to_bytes(events)==original_events and var_to_bytes(moved_snapshot)==original_moved
		remote.weapon = "arc_blade" if str(entry.id)!="arc_blade" else "pulse_rifle"
		world.set_frame(simulation.get_snapshot(),1,1.0/60.0)
		changed_weapon_hides = changed_weapon_hides and not bool(world.muzzle_effect_pose(flash).visible)
		remote.weapon = str(entry.id)
		remote.dead = true
		world.set_frame(simulation.get_snapshot(),1,1.0/60.0)
		dead_hides = dead_hides and not bool(world.muzzle_effect_pose(flash).visible)
	_check(actual_metadata,"All eight real authoritative attacks retain weapon and owner when transformed into rendered muzzle, flame or slash effects")
	_check(follows,"Actual attack feedback follows the remote character's interpolated muzzle and displayed weapon axis, including recoil and swing rotation")
	_check(aim_control,"Ranged attacks immediately follow current aim while the blade retains its original swing direction")
	_check(changed_weapon_hides,"Changing each weapon suppresses that weapon's still-alive outgoing muzzle effect")
	_check(dead_hides,"Death suppresses stale attached attack feedback for every weapon")
	_check(immutable,"Pushing real attacks and updating their smoothed poses cannot alter event payloads or incoming snapshots")
	_check(zero_at_spawn,"Every real projectile weapon begins with zero rearward trail at its muzzle")
	_check(short_first_step,"The first simulated projectile step limits trails to the actual short distance already travelled")
	_check(within_origin,"Interpolated first-step trails never cross behind their spawn muzzle, including a draw position temporarily behind origin")
	simulation.remove_player(2)
	world.set_frame(simulation.get_snapshot(),1,1.0/60.0)
	_check(not last_effect.is_empty() and not bool(world.muzzle_effect_pose(last_effect).visible),"A disconnected owner cannot leave a floating attached muzzle flash")
	simulation.events.clear()
	var local: Dictionary = simulation.state.players[1]
	local.equipment = "grenade"
	simulation._use_skill(local)
	world.push_events(simulation.events)
	var grenade_found: bool = false
	for effect: Dictionary in world._effects:
		if str(effect.get("kind",""))=="muzzle" and not effect.has("weapon"):
			var pose: Dictionary = world.muzzle_effect_pose(effect)
			grenade_found = bool(pose.visible) and Vector2(pose.pos)==Vector2(effect.pos)
	_check(grenade_found,"A real active grenade's unattached feedback keeps its original position and survives weapon validation")
	world.queue_free()
	await process_frame
