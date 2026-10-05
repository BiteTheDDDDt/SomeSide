extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0/60.0
const DIRECTORY: String = "res://tools/results/coins-v017/"
class View extends "res://scripts/world_view.gd":
	func _ready() -> void:
		set_process(false)
		_font = ThemeDB.fallback_font
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("091c25"))
		var floor_y: float = world_to_screen(Vector2(0,600)).y
		draw_rect(Rect2(0,floor_y,1280,720-floor_y),Color("253b42"))
		for index: int in range(0,1280,40): draw_line(Vector2(index,floor_y),Vector2(index,floor_y+8),Color("50736b"),1.0)
		_draw_enemies(); _draw_players(); _draw_coin_pickups(); _draw_effects()
		draw_string(_font,Vector2(40,55),"GOLD / SCATTER > ATTRACT > COLLECT",HORIZONTAL_ALIGNMENT_LEFT,-1,25,CREAM)
		draw_string(_font,Vector2(40,90),"Stay still. Gold automatically follows a living teammate.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,TEAL)
		draw_string(_font,Vector2(1040,58),"GOLD  %d" % int(_frame.players[1].coins),HORIZONTAL_ALIGNMENT_LEFT,-1,27,GOLD)
		draw_string(_font,Vector2(40,667),"Actual simulation and renderer / full shared reward on arrival",HORIZONTAL_ALIGNMENT_LEFT,-1,16,CREAM)
		draw_string(_font,Vector2(40,694),"Coins in flight: %d  |  time %.2fs" % [Array(_frame.coin_pickups).size(),float(_frame.time)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,TEAL)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var verify: bool = "--verify-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" and not verify: quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var sim = Simulation.new()
	sim.start_run([{"id":1,"name":"","character":"ranger"}],1717)
	sim.state.world_size=Vector2(1280,720); sim.state.floor_y=600.0
	sim.state.platforms=[Rect2(0,600,1280,120)]; sim.state.chests=[]; sim.state.enemies=[]
	sim._spawn_clock=9999.0
	var player: Dictionary=sim.state.players[1]
	player.pos=Vector2(640,579); player.grounded=true; player.invuln=9999.0
	var targets: Array=[]
	for index: int in range(4):
		var enemy: Dictionary=sim._spawn_enemy("crawler",Vector2([270,380,920,1030][index],580),index>=2)
		enemy.speed=0.0; enemy.attack_cd=9999.0; enemy.grounded=true
		targets.append(enemy)
	var viewport: SubViewport
	var view: View
	if not verify:
		viewport=SubViewport.new(); viewport.size=Vector2i(1280,720)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		view=View.new(); view.screen_size=Vector2(1280,720); view.shake_enabled=false; view.scenery_cache_enabled=false
		viewport.add_child(view)
	var drops: int=0; var collections: int=0; var peak: int=0; var trace: Array=[]
	for tick: int in range(240):
		sim.step(DT,{})
		if tick==45 or tick==90:
			var start: int=0 if tick==45 else 2
			for index: int in range(start,start+2): sim._damage_enemy(targets[index],float(targets[index].hp),1,false,0)
		for event: Dictionary in sim.events:
			if event.type=="coin_drop": drops+=1
			if event.type=="pickup" and event.get("kind","")=="coin": collections+=1
		peak=maxi(peak,sim.state.coin_pickups.size())
		trace.append({"tick":tick,"balance":player.coins,"flying":sim.state.coin_pickups.size()})
		if verify: continue
		view._process(DT); view._frame=sim.get_snapshot(); view.camera_position=Vector2(640,420)
		view._update_render_positions(DT); view.push_events(sim.events); view.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(DIRECTORY+"frame-%03d.png"%tick)
	var report: Dictionary={"passed":player.coins==61 and drops==4 and collections==4 and peak>0,"native":not verify,"frames":240,"fps":60,"balance":player.coins,"drops":drops,"collections":collections,"peak":peak}
	FileAccess.open(DIRECTORY+("verify.json" if verify else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open(DIRECTORY+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace))
	if not verify: viewport.queue_free(); await process_frame
	print("COINS_CAPTURE_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
