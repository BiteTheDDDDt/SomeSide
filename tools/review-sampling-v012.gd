extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Entities = preload("res://scripts/entity_renderer.gd")

class Probe extends Node2D:
	var offset := Vector2.ZERO
	var actors: Array = []
	var explicit_frame: int = -1
	func center(index: int) -> Vector2:
		return Vector2(100+(index%7)*170,150+(index/7)*280)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("10202c"))
		for index: int in range(actors.size()):
			var id: String=actors[index]
			draw_set_transform(Pixels.snap_position(self,center(index)+offset))
			if explicit_frame>=0:
				var frames: Array=Pixels._actors[id].frames
				if explicit_frame<frames.size():
					var frame: Dictionary=frames[explicit_frame]
					Pixels._draw(self,{"texture":frame.texture,"draw_target":frame.draw_target,"tint":Color.WHITE})
			elif id in ["ranger","vanguard"]:
				Entities.player_body(self,{"character":id,"grounded":true,"vel":Vector2.ZERO},0.0)
			else:
				Entities.enemy(self,{"kind":"boss" if id.begins_with("boss_") else id,"boss_style":id.trim_prefix("boss_"),"id":0,"vel":Vector2.ZERO},0.0)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Pixels.reload_manifest()
	if "--all-frames" in OS.get_cmdline_user_args():
		await _all_frames()
		return
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1920,1080)
	var canvas := Probe.new()
	canvas.actors=Pixels.actor_ids()
	root.add_child(canvas)
	await process_frame
	var actor_index: int=canvas.actors.find("skirmisher")
	var baseline: Image
	var report: Array=[]
	var suffix: String="before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suffix="): suffix=arg.trim_prefix("--suffix=")
	for phase: int in range(16):
		canvas.offset=Vector2(phase*.125,phase*.046875)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image=root.get_texture().get_image()
		var origin := Vector2i(((canvas.center(actor_index)+canvas.offset)*1.5).round())
		var crop: Image=shot.get_region(Rect2i(origin-Vector2i(112,150),Vector2i(225,300)))
		crop.save_png("res://tools/results/sampling-v012-%s-%02d.png"%[suffix,phase])
		if baseline==null: baseline=crop
		var changed: Array=[]
		for y: int in range(crop.get_height()):
			for x: int in range(crop.get_width()):
				var before: Color=baseline.get_pixel(x,y)
				var after: Color=crop.get_pixel(x,y)
				if before!=after:
					changed.append({"pos":[x,y],"before":before.to_html(),"after":after.to_html()})
		var position_value: Vector2=canvas.center(actor_index)+canvas.offset
		var snapped: Vector2=Pixels.snap_position(canvas,position_value)
		var projected: Vector2=canvas.get_viewport_transform()*snapped
		report.append({"phase":phase,"changed":changed,"hash":hash(crop.get_data()),"snapped":[snapped.x,snapped.y],"projected":[projected.x,projected.y]})
		print("SAMPLING phase=",phase," changed=",changed.size()," snapped=",snapped," projected=",projected)
	var frame: Dictionary=Pixels._actors.skirmisher.frames[0]
	print("SAMPLING_FRAME target=",frame.draw_target," atlas=",frame.texture.region," size=",frame.texture.atlas.get_size())
	var file := FileAccess.open("res://tools/results/sampling-v012-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	canvas.queue_free()
	await process_frame
	quit()

func _all_frames() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var canvas := Probe.new()
	canvas.actors=Pixels.actor_ids()
	root.add_child(canvas)
	var failures: Array=[]
	var checks: int=0
	for factor: float in [1.0,1.5,2.0]:
		root.size=Vector2i(Vector2(1280,720)*factor)
		await process_frame
		for pose: int in range(16):
			canvas.explicit_frame=pose
			var hashes: Dictionary={}
			for phase: int in range(16):
				canvas.offset=Vector2(phase*.125,phase*.046875)
				canvas.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var shot: Image=root.get_texture().get_image()
				for index: int in range(canvas.actors.size()):
					var id: String=canvas.actors[index]
					if pose>=Pixels._actors[id].frames.size(): continue
					var origin := Vector2i(((canvas.center(index)+canvas.offset)*factor).round())
					var size_value := Vector2i(Vector2(150,200)*factor)
					var crop: Image=shot.get_region(Rect2i(origin-size_value/2,size_value))
					if not hashes.has(id): hashes[id]={}
					hashes[id][hash(crop.get_data())]=true
			for id: String in hashes:
				checks+=1
				if hashes[id].size()!=1:
					failures.append({"actor":id,"frame":pose,"scale":factor,"patterns":hashes[id].size()})
	var report: Dictionary={"checks":checks,"phases_per_check":16,"failures":failures,"stats":Pixels.stats()}
	var file := FileAccess.open("res://tools/results/sampling-v012-all-frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ALL_FRAME_SAMPLING_RESULT ",JSON.stringify(report))
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
