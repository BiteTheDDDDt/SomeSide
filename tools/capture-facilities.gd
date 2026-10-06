extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Locale = preload("res://scripts/localization.gd")
var tag: String = "after"
const DIRECTORY = "res://tools/results/facilities-v019/"

class Gallery extends "res://scripts/world_view.gd":
	var caption: String
	func _ready() -> void:
		var font:=FontVariation.new()
		font.base_font=load("res://assets/fonts/NotoSansSC.ttf")
		font.variation_opentype={2003265652:500.0}
		_font=font
		set_process(false)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("10252d"))
		for y: float in [280.0,560.0]:
			draw_rect(Rect2(0,y,1280,25),Color("253e45"))
			draw_line(Vector2(0,y),Vector2(1280,y),Color("698a84"),2)
		_draw_chests()
		draw_string(_font,Vector2(30,42),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("e9f3da"))
		draw_string(_font,Vector2(30,690),"Production facility renderer / 1x / real generated rewards / no player profile",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("91aaa8"))

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag=arg.trim_prefix("--tag=")
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Facility capture","character":"ranger"}],19006)
	var original: PackedByteArray=var_to_bytes(sim.state)
	var candidates: Dictionary={}
	var choices: Array=[]
	var group: int=-1
	for chest: Dictionary in sim.state.chests:
		if not candidates.has(chest.type): candidates[chest.type]=chest.duplicate(true)
		if chest.type=="choice" and (group<0 or group==int(chest.group)):
			group=int(chest.group); choices.append(chest.duplicate(true))
	var view=Gallery.new()
	view.camera_position=Vector2(640,360)
	view._clock=.73
	var viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport); viewport.add_child(view)
	for language: String in ["zh","en"]:
		Locale.set_language(language)
		for states: bool in [false,true]:
			var chests: Array=[]
			var kinds: Array[String]=["cache","blood","combat","equipment","choice"]
			for index: int in range(kinds.size()):
				var chest: Dictionary=candidates[kinds[index]].duplicate(true)
				chest.pos=Vector2(140+index*245,263)
				if kinds[index]=="choice": chest.group=-1
				if states:
					chest.opened=true
					if chest.type=="choice": chest.locked=true
					if chest.type=="combat": chest.status="cleared"
				chests.append(chest)
			for index: int in range(choices.size()):
				var chest: Dictionary=choices[index].duplicate(true)
				chest.pos=Vector2(190+index*112,543)
				if states:
					chest.opened=true; chest.locked=index!=1
				chests.append(chest)
			var trial: Dictionary=candidates.combat.duplicate(true)
			trial.id=9901; trial.pos=Vector2(800,543); trial.status="active"; trial.remaining=2
			chests.append(trial)
			var extra: Dictionary=candidates.blood.duplicate(true)
			extra.id=9902; extra.pos=Vector2(1080,543)
			chests.append(extra)
			view._frame={"chests":chests,"players":{1:{"coins":30,"hp":18}}}
			view.caption="SOMESIDE / FACILITIES / "+tag.to_upper()+" / "+language.to_upper()+ (" / USED" if states else " / AVAILABLE")
			view.queue_redraw()
			for tick: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var name: String=tag+"-"+language+("-states" if states else "-available")
			assert(viewport.get_texture().get_image().save_png(DIRECTORY+name+".png")==OK)
	assert(original==var_to_bytes(sim.state))
	viewport.queue_free(); await process_frame
	if tag!="before": await _capture_game()
	print("FACILITY_CAPTURE_RESULT tag=",tag," images=",4 if tag=="before" else 6," simulation_unchanged=true")
	quit(0)

func _capture_game() -> void:
	var existed: bool=FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray=FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	var viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://main.tscn").instantiate()
	game.set("_smoke","facility-capture")
	viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.world.set_process(false)
	game.world.shake_enabled=false; game.world.scenery_cache_enabled=false
	game.sound.shutdown()
	game.profile.show_fps=false
	for language: String in ["zh","en"]:
		Locale.set_language(language); game.profile.language=language
		game._begin_local([{"id":1,"name":"","character":"ranger"}],19006)
		game.sim.state.enemies.clear()
		var offers: Array=[]
		var group: int=-1
		for chest: Dictionary in game.sim.state.chests:
			if chest.type=="choice" and (group<0 or int(chest.group)==group):
				group=int(chest.group); offers.append(chest)
		var center: Vector2=offers[1].pos
		var player: Dictionary=game.sim.state.players[1]
		player.pos=center+Vector2(-270,-4)
		player.vel=Vector2.ZERO; player.aim=Vector2.RIGHT
		player.grounded=true; player.invuln=0.0; player.coins=90
		game._notice.text=""; game._notice_time=0.0
		game.world.set_frame(game.sim.get_snapshot(),1,1.0)
		game.world.camera_position=center+Vector2(-15,-175)
		game.world._clock=.73
		game._update_hud(); game._refresh_interaction_focus()
		game.world.interaction_target=game._focus_target
		game.world.queue_redraw()
		for tick: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(DIRECTORY+tag+"-game-"+language+".png")==OK)
	game.queue_free(); await process_frame
	viewport.queue_free(); await process_frame
	assert(existed==FileAccess.file_exists("user://profile.cfg"))
	assert(saved==(FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()))
