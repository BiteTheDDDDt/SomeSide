extends SceneTree
const Base=preload("res://tools/capture-combat-unity-v0208.gd")
const World=preload("res://scripts/world_view.gd")
const Art=preload("res://scripts/facility_art.gd")
class Details extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,200),Color("24373f"))
		for i: int in range(3):
			var tier: String=["small","medium","large"][i]
			draw_string(ThemeDB.fallback_font,Vector2(30+i*320,24),tier+" / 2x detail",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("cbd1bb"))
			for j: int in range(3):
				var state: String=["idle","open","locked"][j]
				draw_texture_rect(Art.texture("cache",state,tier),Rect2(Vector2(62+i*320+j*95,151)+Art.BOUNDS.position*2,Art.BOUNDS.size*2),false)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var setup: Dictionary=Base.fixture("spit")
	var sim=setup.sim
	sim.state.enemies.clear(); sim.state.hazards.clear(); sim.state.chests.clear()
	var player: Dictionary=sim.state.players[1]
	var center: float=player.pos.x
	for i: int in range(3):
		var x: float=center-220+i*220
		var y: float=sim._surface_below(x,player.pos.y-20)-17
		var chest: Dictionary=sim._make_chest("cache",Vector2(x,y),[25,45,80][i],"nova")
		chest.tier=["small","medium","large"][i]
		sim.state.chests.append(chest)
	var view:=SubViewport.new(); view.size=Vector2i(960,740); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world=World.new(); world.screen_size=Vector2(960,540); world.scenery_cache_enabled=false; world.shake_enabled=false; view.add_child(world); world.set_process(false)
	world.set_frame(sim.get_snapshot(),1,1.0/60.0); world.camera_position=Vector2(center,player.pos.y-150); world.queue_redraw()
	var detail:=Details.new(); detail.position.y=540; view.add_child(detail)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tools/results/chests-v0208")
	assert(view.get_texture().get_image().save_png("res://tools/results/chests-v0208/tiers.png")==OK)
	print("CHEST_CAPTURE_RESULT passed=true")
	quit()
