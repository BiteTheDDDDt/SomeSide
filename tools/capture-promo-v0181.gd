extends SceneTree

## Three production-game close-ups, photographed at 1920x1080. Only initial
## positions, legal loadouts and input timing are directed. Attacks, damage,
## effects, stage geometry and HUD all come from the shipped game.
const Locale = preload("res://scripts/localization.gd")
const DT: float = 1.0/60.0
const DIRECTORY: String = "res://tools/results/promo-v0181/"
var viewport: SubViewport
var game: Node
var report: Array = []
var audit_only: bool = false
var targets: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	audit_only = "--audit-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" and not audit_only:
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY+"candidates/")
	var profile_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var profile_before: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if profile_exists else PackedByteArray()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.size_2d_override = Vector2i(1280,720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke","promo-photography")
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	Locale.set_language("en")
	game.profile.language = "en"
	game.profile.show_fps = false
	game.profile.shake = false
	game.world.shake_enabled = false
	game.world.scenery_cache_enabled = false
	game.world.fx_scale = 1.0
	var scenes: Array = [
		{"name":"forest-coop","final":"01-forest-cooperation.png","stage":1,"time":154.0,"zoom":1.25,"camera":Vector2(1535,990),"ticks":[27,28,29,30],"selected":29,
			"actors":[["ranger",Vector2(1230,1079),"pulse_rifle","grenade",["overclock","capacitor","feather","magnet"]],["vanguard",Vector2(1400,1079),"arc_blade","shockwave",["plating","vitality","momentum"]]],
			"enemies":[["crawler",Vector2(1512,1081),false],["spitter",Vector2(1690,1079),false],["spore_moth",Vector2(1750,930),false],["spitter",Vector2(1880,1079),false]]},
		{"name":"canyon-ascent","final":"02-canyon-ascent.png","stage":2,"time":367.0,"zoom":1.20,"camera":Vector2(1890,1020),"ticks":[42,43,44,46],"selected":43,
			"actors":[["ranger",Vector2(1580,1169),"railgun","aegis",["feather","overclock","plating","piercer"]],["vanguard",Vector2(1950,1079),"arc_blade","shockwave",["plating","battery","momentum"]]],
			"enemies":[["drone",Vector2(2100,915),true],["drone",Vector2(2310,850),false],["charger",Vector2(2055,1076),false],["burrower",Vector2(2300,989),false]]},
		{"name":"ruins-archon","final":"03-ruins-archon.png","stage":3,"time":628.0,"zoom":1.15,"camera":Vector2(4310,475),"ticks":[67],"selected":67,
			"actors":[["ranger",Vector2(4350,579),"storm_staff","meteor",["overclock","capacitor","feather","plating"]]],
			"enemies":[["sentinel",Vector2(4700,577),false],["conductor",Vector2(4740,460),false]]}
	]
	for config: Dictionary in scenes:
		var requested: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--scene="): requested=argument.trim_prefix("--scene=")
		if not requested.is_empty() and requested!=str(config.name): continue
		await _scene(config)
	var profile_after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	assert(profile_exists==FileAccess.file_exists("user://profile.cfg") and profile_before==profile_after,"Photography must not change the user's profile")
	var metadata: Dictionary = {"version":"0.18.1","dimensions":[1920,1080],"hud_language":"en","close_up_camera_only":true,"profile_unchanged":true,"generated_fx":false,"scenes":report}
	FileAccess.open(DIRECTORY+("audit.json" if audit_only else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	game.sound.shutdown()
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	print("PROMO_PHOTOGRAPHY_RESULT scenes=",report.size()," native=",not audit_only," profile_unchanged=true")
	quit(0)

func _scene(config: Dictionary) -> void:
	var members: Array = []
	for index: int in range(config.actors.size()):
		members.append({"id":index+1,"name":"Ranger" if str(config.actors[index][0])=="ranger" else "Vanguard","character":config.actors[index][0]})
	game._begin_local(members,18181+int(config.stage))
	game.sim._build_stage(int(config.stage))
	game.sim.state.time = float(config.time)
	game.sim.state.threat_time = float(config.time)
	game.sim._spawn_clock = 9999.0
	game.sim.state.enemies.clear()
	# Advance the real difficulty calculation before staging this point in a run.
	game.sim.step(DT,{})
	game.sim.state.enemies.clear()
	targets.clear()
	for index: int in range(config.actors.size()):
		var actor: Dictionary = game.sim.state.players[index+1]
		var setup: Array = config.actors[index]
		actor.pos = setup[1]
		actor.vel = Vector2.ZERO
		actor.grounded = true
		actor.invuln = 0.0
		actor.weapon = str(setup[2])
		actor.equipment = str(setup[3])
		actor.coins = 137+int(config.stage)*74
		actor.aim = Vector2.LEFT if int(config.stage)==3 else Vector2.RIGHT
		actor.explore_anchor = actor.pos
		actor.explore_sites = [actor.pos]
		for item: String in setup[4]: game.sim._grant_item(actor,item)
	for setup: Array in config.enemies:
		var enemy: Dictionary = game.sim._spawn_enemy(str(setup[0]),setup[1],bool(setup[2]))
		enemy.attack_cd = 0.7
		if not targets.has(str(enemy.kind)): targets[str(enemy.kind)]=enemy
	game._notice.text = ""
	game._notice_time = 0.0
	game._fps_label.visible = false
	game.world._effects.clear()
	game.world._numbers.clear()
	game.world.scale = Vector2.ONE*float(config.zoom)
	game.world.screen_size = Vector2(1280,720)/float(config.zoom)
	game.world.combat_paused = false
	var events_seen: Dictionary = {}
	var event_samples: Array = []
	var captures: Array = []
	for tick: int in range(int(config.ticks.back())+1):
		var commands: Dictionary = {}
		for id: int in game.sim.state.players:
			commands[id] = _command(str(config.name),tick,id)
		game.sim.step(DT,commands)
		for event: Dictionary in game.sim.events:
			var key: String = str(event.type)+":"+str(event.get("kind",event.get("weapon","")))
			events_seen[key] = int(events_seen.get(key,0))+1
			if str(event.type) in ["shoot","slash","hit","equipment","explosion","gate","jump"]:
				event_samples.append({"tick":tick,"type":event.type,"kind":event.get("kind",""),"weapon":event.get("weapon",""),"equipment":event.get("equipment",""),"player":event.get("player",event.get("owner",0)),"amount":event.get("amount",0)})
		if int(config.stage)==3 and tick==0:
			for enemy: Dictionary in game.sim.state.enemies:
				if str(enemy.kind)=="boss":
					targets.boss = enemy
					enemy.attack_cd = 0.5
		game.world._process(DT)
		var snapshot: Dictionary = game.sim.get_snapshot()
		var unchanged: PackedByteArray = var_to_bytes(snapshot)
		game.world.set_frame(snapshot,1,DT)
		game.world.camera_position = config.camera
		game.world.push_events(game.sim.events)
		game._update_hud()
		var local: Dictionary = game.sim.state.players[1]
		var mouse := InputEventMouseMotion.new()
		mouse.position = game.world.world_to_screen(Vector2(local.pos)+Vector2(local.aim)*250.0+Vector2(0,-5))*float(config.zoom)
		mouse.global_position = mouse.position
		viewport.push_input(mouse,true)
		game.ui.queue_redraw()
		game.world.queue_redraw()
		await process_frame
		assert(var_to_bytes(snapshot)==unchanged,"The production renderer must be read-only")
		if tick in config.ticks:
			var label: String = str(config.name)+"-%03d"%tick
			if not audit_only:
				await RenderingServer.frame_post_draw
				var frame: Image = viewport.get_texture().get_image()
				assert(frame.save_png(DIRECTORY+"candidates/"+label+".png")==OK)
				if tick==int(config.selected): assert(frame.save_png(DIRECTORY+str(config.final))==OK)
			var actors: Array = []
			for actor: Dictionary in game.sim.state.players.values():
				var pose: Dictionary = game.world.weapon_draw_pose(actor)
				actors.append({"id":actor.id,"character":actor.character,"weapon":actor.weapon,"equipment":actor.equipment,"pos":[actor.pos.x,actor.pos.y],"vel":[actor.vel.x,actor.vel.y],"grounded":actor.grounded,"hp":actor.hp,"melee":pose.melee,"items":actor.items.duplicate()})
			captures.append({"file":"candidates/"+label+".png","tick":tick,"actors":actors,"enemies":game.sim.state.enemies.map(func(e:Dictionary):return {"id":e.id,"kind":e.kind,"hp":e.hp,"pos":[e.pos.x,e.pos.y]}),"projectiles":game.sim.state.projectiles.size(),"pending_effects":game.sim.state.effects.size(),"active_fx":game.world._effects.size(),"commands":commands})
	report.append({"theme":config.name,"stage":config.stage,"time":config.time,"zoom":config.zoom,"camera":[config.camera.x,config.camera.y],"final_file":config.final,"selected_tick":config.selected,"captures":captures,"events_seen":events_seen,"event_samples":event_samples})
	print("PROMO_SCENE_READY ",config.name," candidates=",captures.size()," events=",events_seen)

func _command(scene: String, tick: int, id: int) -> Dictionary:
	var actor: Dictionary = game.sim.state.players[id]
	var aim := Vector2.RIGHT
	var command: Dictionary = {"move":0.0,"jump":false,"jump_held":true,"fire":false,"skill":false,"interact":false}
	match scene:
		"forest-coop":
			if id==1:
				aim = (Vector2(targets.spore_moth.pos)-Vector2(actor.pos)-Vector2(0,-5)).normalized()
				command.fire = tick>=8
			else: command.fire = tick==20
		"canyon-ascent":
			if id==1:
				aim = (Vector2(targets.drone.pos)-Vector2(actor.pos)-Vector2(0,-5)).normalized()
				command.move = 1.0
				command.jump = tick==18
				command.jump_held = tick<48
				command.fire = tick==39
			else: command.fire = tick==34
		"ruins-archon":
			if targets.has("boss"):
				aim = (Vector2(targets.boss.pos)-Vector2(actor.pos)-Vector2(0,-5)).normalized()
			else: aim=Vector2(-1,-0.5).normalized()
			command.fire = tick>=12
			command.skill = tick==30
			command.move = 1.0 if tick>=40 and tick<64 else 0.0
			command.jump = tick==48
			command.interact = tick==0
			command.interact_target = {"kind":"gate","id":-1}
	command.aim = aim
	return command
