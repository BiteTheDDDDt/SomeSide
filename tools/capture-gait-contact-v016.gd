extends SceneTree
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")

class Contact extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,900),Color("0b1c24"))
		for row: int in range(4):
			var hero: String = "ranger" if row < 2 else "vanguard"
			var clip: String = "run" if row % 2 == 0 else "backpedal"
			var actor: Dictionary = Pixels._actors[hero]
			for col: int in range(8):
				var index: int = int(actor.animations[clip][col])
				var frame: Dictionary = actor.frames[index]
				var point := Vector2(100+col*200, row*225+112)
				draw_line(point+Vector2(-60,63),point+Vector2(60,63),Color("48655a"))
				draw_set_transform(point,0,Vector2.ONE*3)
				draw_texture_rect(frame.texture,frame.draw_target,false,Color.WHITE)
				draw_set_transform(Vector2.ZERO)
				draw_string(ThemeDB.fallback_font,point+Vector2(-88,96),hero+" "+clip+" #"+str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d4ded0"))

class CropProbe extends Node2D:
	var state: Dictionary = {}
	var phase_time: float = 0.0
	func _draw() -> void:
		draw_set_transform(Vector2(48,40))
		Pixels.draw_player(self,state,phase_time)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	Pixels.reload_manifest()
	var view := SubViewport.new()
	view.size = Vector2i(1600,900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.add_child(Contact.new())
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://tools/results/gait-v016/contact.png")
	view.queue_free()
	var probes: Array = []
	var views: Array = []
	for split: bool in [false,true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(96,80)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var probe := CropProbe.new()
		viewport.add_child(probe)
		probes.append(probe)
		views.append(viewport)
	var checks: int = 0
	var mismatches: int = 0
	for hero: String in ["ranger","vanguard"]:
		for clip: String in ["run","backpedal"]:
			for index: int in range(8):
				for angle: float in [0.0,0.16,-0.12]:
					for split: int in range(2):
						var probe: CropProbe = probes[split]
						Pixels.reset_tracks(probe)
						probe.state = {"id":1,"character":hero,"pos":Vector2.ZERO,"aim":Vector2.RIGHT,"vel":Vector2(245 if clip=="run" else -245,0),"grounded":true}
						Pixels.tracked_frame_for(probe,hero,probe.state,0,true)
						var actor: Dictionary = Pixels._actors[hero]
						probe.phase_time = .065*(index+.25)
						probe.state.pos.x = float(actor.stride_distances[clip])*(index+.25)/8.0*(1 if clip=="run" else -1)
						if split==1: probe.state._melee_pose = {"active":true,"draw_origin":Vector2(48,40),"facing":1.0,"body_angle":angle}
						probe.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var plain: Image = views[0].get_texture().get_image()
					var cut: Image = views[1].get_texture().get_image()
					# Below the upper body's possible waist rotation, both legs must
					# be pixel-identical with/without an active ranged/melee action.
					var rect := Rect2i(0,51,96,29)
					if plain.get_region(rect).get_data() != cut.get_region(rect).get_data(): mismatches += 1
					checks += 1
	for viewport: SubViewport in views: viewport.queue_free()
	await process_frame
	print("GAIT_CROP_CAPTURE_RESULT poses=32 split_comparisons=",checks," lower_body_mismatches=",mismatches)
	quit(0 if mismatches==0 else 1)
