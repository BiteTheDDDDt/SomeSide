extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_view.gd")
const Locale=preload("res://scripts/localization.gd")
const DIRECTORY="res://tools/results/tracking-v0230/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	root.size=Vector2i(1280,720)
	var game: Node=load("res://main.tscn").instantiate()
	game.set("_smoke","ui"); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.sound.shutdown()
	for lang: String in ["en","zh"]:
		Locale.set_language(lang); game._show_characters()
		for i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIRECTORY+lang+"-classes.png")
	game.queue_free(); await process_frame
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Weaver","character":"weaver"},{"id":2,"name":"Seeker","character":"ranger"}],73023)
	sim._build_stage(2); sim._spawn_clock=99999
	var player: Dictionary=sim.state.players[1]
	var floor_y: float=sim.state.floor_y
	player.pos=Vector2(1400,floor_y-21); player.grounded=true; player.aim=Vector2.RIGHT; player.invuln=100
	var friend: Dictionary=sim.state.players[2]
	friend.pos=player.pos+Vector2(-60,0); friend.grounded=true; friend.weapon="star_seeker"; friend.aim=Vector2(200,-40).normalized(); friend.invuln=100
	var target: Dictionary=sim._spawn_enemy("charger",player.pos+Vector2(240,0))
	target.hp=10000; target.max_hp=10000; target.attack_cd=9999; target.move_speed=0
	var moth: Dictionary=sim._spawn_enemy("crystal_moth",player.pos+Vector2(235,-125))
	moth.attack_cd=0; moth.move_speed=12; moth.hp=200
	sim._engrave(player); sim._use_skill(player); sim._fire_weapon(friend)
	var world:=World.new(); world.screen_size=Vector2(1280,720); world.shake_enabled=false; root.add_child(world)
	var captures: Dictionary={20:"charge",54:"release",225:"recovery"}
	var report: Dictionary={"version":"0.23.0","size":[1280,720],"frames":[]}
	for tick: int in range(226):
		sim.step(1.0/60,{1:{"aim":Vector2.RIGHT,"fire":tick==40},2:{"aim":friend.aim,"fire":tick==35}})
		world.set_frame(sim.get_snapshot(),1,1.0/60); world.push_events(sim.events)
		world.camera_position=Vector2(1510,floor_y-245)
		world._process(1.0/60)
		if captures.has(tick):
			for i: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DIRECTORY+str(captures[tick])+".png")
			report.frames.append({"stage":captures[tick],"time":sim.state.time,"projectiles":sim.state.projectiles.size(),"moth_windup":moth.telegraph,"devices":sim.state.deployables.size()})
	FileAccess.open(DIRECTORY+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.queue_free(); await process_frame
	quit(0)
