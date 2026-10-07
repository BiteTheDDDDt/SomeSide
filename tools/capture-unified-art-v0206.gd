extends SceneTree

const Entities=preload("res://scripts/entity_renderer.gd")
const Players=preload("res://scripts/illustrated_player_renderer.gd")
const Weapons=preload("res://scripts/weapon_art.gd")
const Icons=preload("res://scripts/item_icons.gd")
const Facilities=preload("res://scripts/facility_art.gd")
const Content=preload("res://scripts/content.gd")

class Gallery extends Node2D:
	func label_at(p: Vector2,value: String) -> void:
		draw_string(ThemeDB.fallback_font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("cbd1bb"))
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,1100),Color("24373f"))
		label_at(Vector2(24,28),"SomeSide / illustrated materials / v0.20.6")
		for row: int in range(2):
			var character: String="ranger" if row==0 else "vanguard"
			label_at(Vector2(24,62+row*145),character+" / 3x poses")
			for pose: int in range(4):
				var f: Dictionary=Players.frame(character,pose)
				draw_set_transform(Vector2(100+pose*190,123+row*145),0,Vector2(2.5,2.5))
				draw_texture_rect(f.texture,f.target,false)
				draw_set_transform(Vector2.ZERO)
			for column: int in range(2):
				var id: String=["crawler","spitter","charger","sentinel"][row*2+column]
				draw_set_transform(Vector2(940+column*210,123+row*145),0,Vector2(2,2))
				Entities.enemy(self,{"kind":id,"attack_dir":Vector2.RIGHT,"radius":18,"hp":100,"max_hp":100},0)
				draw_set_transform(Vector2.ZERO)
		label_at(Vector2(24,350),"Weapons / shared held + inventory silhouettes / 2x")
		for i: int in range(8):
			draw_set_transform(Vector2(25+i*156,386),0,Vector2(2,2))
			Weapons.draw(self,Weapons.IDS[i])
			draw_set_transform(Vector2.ZERO)
			label_at(Vector2(25+i*156,421),Weapons.IDS[i])
		label_at(Vector2(24,463),"Facilities / idle, open, locked / 1x")
		for i: int in range(5):
			for state_index: int in range(3):
				var state: String=["idle","open","locked"][state_index]
				draw_texture_rect(Facilities.texture(Facilities.KINDS[i],state),Rect2(Vector2(30+i*250+state_index*70,532)+Facilities.BOUNDS.position,Facilities.BOUNDS.size),false)
			label_at(Vector2(25+i*250,568),Facilities.KINDS[i])
		label_at(Vector2(24,614),"43 inventory objects / 48px icon + 24px ground object")
		var items: Array=Content.passives()+Content.weapons()+Content.equipment()
		for i: int in range(items.size()):
			var p:=Vector2(24+(i%9)*139,633+(i/9)*89)
			draw_texture_rect(Icons.texture(items[i].id,48),Rect2(p,Vector2(48,48)),false)
			draw_texture_rect(Icons.pickup_texture(items[i].id,24),Rect2(p+Vector2(57,21),Vector2(24,24)),false)
			label_at(p+Vector2(0,66),items[i].id)

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/results/unified-v0206")
	var view:=SubViewport.new(); view.size=Vector2i(1280,1100); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	view.add_child(Gallery.new())
	await process_frame; await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png("res://tools/results/unified-v0206/catalogue.png")==OK)
	print("UNIFIED_ART_CAPTURE_RESULT passed=true")
	quit()
