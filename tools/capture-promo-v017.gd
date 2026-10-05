extends SceneTree

## Directed starting positions/loadouts; every combat effect comes from the
## actual authority tick and the production WorldView. No synthetic FX.
const Locale = preload("res://scripts/localization.gd")
const DT: float = 1.0/60.0
const DIRECTORY: String = "res://tools/results/promo-v017/"
var viewport: SubViewport
var game: Node
var report: Array = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var profile_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var profile_before: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if profile_exists else PackedByteArray()
	viewport=SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.size_2d_override=Vector2i(1280,720)
	viewport.size_2d_override_stretch=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=load("res://main.tscn").instantiate()
	game.set("_smoke","promo-capture")
	viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.world.set_process(false)
	game.sound.shutdown()
	Locale.set_language("en")
	game.profile.language="en"; game.profile.show_fps=false; game.profile.shake=false
	game._fps_label.visible=false
	game.world.shake_enabled=false
	game.world.scenery_cache_enabled=false
	game.world.fx_scale=1.0
	var scenes: Array = [
		{"name":"forest-coop","stage":1,"pos":Vector2(2320,1079),"weapon":"pulse_rifle","equipment":"grenade","coop":true,"items":["overclock","capacitor","arc","feather","harvest"],"enemies":[["crawler",230,2],["crawler",310,2],["spitter",420,2],["spore_moth",365,-120],["spitter",560,2]]},
		{"name":"forest-gold","stage":1,"pos":Vector2(2430,1079),"weapon":"flamethrower","equipment":"grenade","items":["capacitor","harvest","ember","magnet","plating"],"enemies":[["crawler",100,2],["crawler",155,2],["crawler",205,2],["spitter",390,2],["spore_moth",315,-130]]},
		{"name":"canyon-blade","stage":2,"pos":Vector2(4460,1619),"character":"vanguard","weapon":"arc_blade","equipment":"shockwave","items":["capacitor","plating","vitality","momentum","frost"],"enemies":[["charger",105,2],["burrower",210,2],["drone",305,-95],["charger",375,2]]},
		{"name":"canyon-counter","stage":2,"pos":Vector2(4460,1619),"character":"vanguard","weapon":"arc_blade","equipment":"shockwave","items":["plating","vitality","momentum","battery","siphon"],"enemies":[["charger",85,2],["charger",130,2],["drone",190,-70],["burrower",250,2]]},
		{"name":"ruins-storm","stage":3,"pos":Vector2(4350,579),"weapon":"storm_staff","equipment":"graviton","boss":true,"items":["overclock","arc","frost","battery","feather","piercer"],"enemies":[["sentinel",-180,2],["conductor",-275,-100],["skirmisher",-320,2]]},
		{"name":"ruins-sun","stage":3,"pos":Vector2(4350,579),"weapon":"sun_lance","equipment":"meteor","boss":true,"items":["capacitor","lens","lens","resonator","plating","phoenix"],"enemies":[["sentinel",-160,2],["conductor",-285,-100],["sentinel",-400,2]]},
		{"name":"canyon-air","stage":2,"pos":Vector2(1700,1169),"weapon":"railgun","equipment":"aegis","air":true,"items":["feather","overclock","plating","capacitor","piercer"],"enemies":[["drone",330,-210],["drone",470,-270],["charger",250,-88],["burrower",480,-178]]}
	]
	for scene: Dictionary in scenes:
		if "--forest-only" in OS.get_cmdline_user_args() and scene.name!="forest-coop": continue
		if "--air-only" in OS.get_cmdline_user_args() and not scene.get("air",false): continue
		await _scene(scene)
	var current: PackedByteArray=FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	assert(profile_exists==FileAccess.file_exists("user://profile.cfg") and current==profile_before,"Capture must preserve the user's profile")
	FileAccess.open(DIRECTORY+("report-air.json" if "--air-only" in OS.get_cmdline_user_args() else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free(); await process_frame
	print("PROMO_CAPTURE_RESULT scenes=",report.size()," native=true profile_unchanged=true")
	quit(0)

func _scene(config: Dictionary) -> void:
	var members: Array=[{"id":1,"name":"Ranger" if config.get("character","ranger")=="ranger" else "Vanguard","character":config.get("character","ranger")}]
	if config.get("coop",false): members.append({"id":2,"name":"Vanguard","character":"vanguard"})
	game._begin_local(members,17017)
	game.sim._build_stage(int(config.stage))
	game.sim.state.time=[154.0,367.0,628.0][int(config.stage)-1]
	game.sim.state.threat_time=game.sim.state.time
	game.sim._spawn_clock=9999.0
	game.sim.state.enemies.clear()
	game._notice.text=""; game._notice_time=0.0
	game._fps_label.visible=false
	game.world._effects.clear(); game.world._numbers.clear()
	var player: Dictionary=game.sim.state.players[1]
	for index: int in range(members.size()):
		var actor: Dictionary=game.sim.state.players[index+1]
		actor.pos=Vector2(config.pos)+Vector2(index*85,0)
		actor.vel=Vector2.ZERO; actor.grounded=true; actor.invuln=0.0
		actor.weapon=config.weapon if index==0 else "arc_blade"
		actor.equipment=config.equipment
		actor.coins=137+int(config.stage)*74
		actor.aim=Vector2.LEFT if config.get("boss",false) else Vector2.RIGHT
		actor.explore_anchor=actor.pos; actor.explore_sites=[actor.pos]
		for item: String in config.items: game.sim._grant_item(actor,item)
	for setup: Array in config.enemies:
		var enemy: Dictionary=game.sim._spawn_enemy(str(setup[0]),Vector2(config.pos)+Vector2(setup[1],setup[2]))
		enemy.attack_cd=0.05 if config.name=="canyon-counter" else 0.3
	var events_seen: Dictionary={}
	var captures: Array=[]
	for tick: int in range(156):
		var commands: Dictionary={}
		for id: int in game.sim.state.players:
			var actor: Dictionary=game.sim.state.players[id]
			var aim: Vector2=Vector2(-1,-.35).normalized() if config.get("boss",false) else Vector2.RIGHT
			if config.get("air",false): aim=Vector2(1,-.38).normalized()
			if config.get("boss",false):
				for enemy: Dictionary in game.sim.state.enemies:
					if enemy.kind=="boss": aim=(Vector2(enemy.pos)-Vector2(actor.pos)-Vector2(0,-5)).normalized()
			commands[id]={"aim":aim,"move":1.0 if config.get("air",false) and tick<105 else 0.0,"fire":tick>=(37 if config.get("air",false) else 8) and (config.name!="canyon-counter" or tick>=98),
				"jump":config.get("air",false) and tick==32,"jump_held":tick<50,
				"dash":tick==42 and config.name=="canyon-counter",
				"skill":tick==36 and config.name in ["forest-gold","ruins-storm","ruins-sun"],
				"interact":tick==0 and config.get("boss",false),"interact_target":{"kind":"gate","id":-1}}
		game.sim.step(DT,commands)
		for event: Dictionary in game.sim.events: events_seen[event.type]=int(events_seen.get(event.type,0))+1
		game.world._process(DT)
		game.world.set_frame(game.sim.get_snapshot(),1,DT)
		game.world.push_events(game.sim.events)
		game._update_hud()
		var mouse := InputEventMouseMotion.new()
		mouse.position=game.world.world_to_screen(Vector2(player.pos)+Vector2(player.aim)*230.0+Vector2(0,-5))
		mouse.global_position=mouse.position
		viewport.push_input(mouse,true)
		game.ui.queue_redraw()
		game.world.queue_redraw()
		await process_frame
		if tick in [18,22,27,38,40,43,47,54,68,84,90,93,96,102,120,144,155]:
			await RenderingServer.frame_post_draw
			var label: String=str(config.name)+"-%03d"%tick
			viewport.get_texture().get_image().save_png(DIRECTORY+label+"-hud.png")
			captures.append({"file":label+"-hud.png","tick":tick,"enemies":game.sim.state.enemies.size(),"coin_pickups":game.sim.state.coin_pickups.size(),
				"player":{"grounded":player.grounded,"position":[player.pos.x,player.pos.y],"velocity":[player.vel.x,player.vel.y],"aim":[player.aim.x,player.aim.y],"hp":player.hp,"weapon":player.weapon},
				"command":commands[1],"events":game.sim.events.map(func(e:Dictionary):return str(e.type))})
			if config.name=="forest-coop" and tick in [40,68,93]: await _cover(label)
			if config.name in ["canyon-counter","ruins-storm","ruins-sun"] and tick==93:
				game.ui.visible=false
				await process_frame; await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(DIRECTORY+label+"-clean.png")
				game.ui.visible=true
		var record: Dictionary=config.duplicate(true)
		record["captures"]=captures
		record["events_seen"]=events_seen
		if tick==155: report.append(record)
	print("PROMO_SCENE_READY ",config.name)

func _cover(label: String) -> void:
	var camera: Vector2=game.world.camera_position
	var player: Dictionary=game.sim.state.players[1]
	game.ui.visible=false
	viewport.size=Vector2i(1260,1000)
	viewport.size_2d_override=Vector2i(900,714)
	game.world.screen_size=Vector2(900,714)
	game.world.camera_position=Vector2(player.pos)+Vector2(130,-140)
	game.world.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(DIRECTORY+label+"-cover-clean.png")
	viewport.size=Vector2i(1920,1080)
	viewport.size_2d_override=Vector2i(1280,720)
	game.world.screen_size=Vector2(1280,720)
	game.world.camera_position=camera
	game.ui.visible=true
	game.world.queue_redraw()
	await process_frame
