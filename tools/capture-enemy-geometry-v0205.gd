extends SceneTree
const Art=preload("res://scripts/geometric_enemies.gd")
const Catalog=preload("res://scripts/enemy_catalog.gd")
class Probe extends Node2D:
	var records: Array=[]
	var readonly: bool=true
	func _draw() -> void:
		draw_rect(Rect2(0,0,1200,2160),Color("183039"))
		for row: int in range(records.size()):
			for column: int in range(6):
				var e: Dictionary=records[row].duplicate(true)
				var angle: float=[0.0,.7,-.7,PI*.5,-PI*.5,PI][column]
				e.attack_dir=Vector2.from_angle(angle)
				e.telegraph=.7 if column%2==0 else 0.0
				e.telegraph_max=1.0; e.attack_cd=2.97; e.attack_cooldown=3.0
				e.vel=Vector2(80,0); e.charge_timer=.2 if column==3 else 0.0
				var before: PackedByteArray=var_to_bytes(e)
				draw_set_transform(Vector2(column*200+100,row*180+80),0,Vector2(-1 if column==5 else 1,1))
				Art.draw(self,e,1.4)
				readonly=readonly and before==var_to_bytes(e)
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font,Vector2(5,row*180+14),str(records[row].kind)+" "+str(records[row].get("boss_style","")),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var view:=SubViewport.new(); view.size=Vector2i(1200,2160); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var probe:=Probe.new()
	for row: Dictionary in Catalog.catalog():
		probe.records.append({"kind":row.id,"radius":row.radius,"id":1,"attack_kind":row.attack_kind,"hp":100,"max_hp":100})
	for style: String in ["stone","spore","prism"]:
		probe.records.append({"kind":"boss","radius":44,"id":2,"boss_style":style,"attack_kind":"spore_volley" if style=="spore" else ("prism_cross" if style=="prism" else "stone_spikes"),"hp":40,"max_hp":100})
	view.add_child(probe)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(probe.readonly)
	assert(view.get_texture().get_image().save_png("res://tools/results/combat-unity-v0205/aim-matrix.png")==OK)
	print("ENEMY_GEOMETRY_NATIVE_RESULT bodies=12 poses=72 readonly=",probe.readonly)
	quit()

