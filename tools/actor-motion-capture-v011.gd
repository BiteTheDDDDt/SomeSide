extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
var label: String = "before"

class Canvas extends Node2D:
	var offset: Vector2 = Vector2.ZERO
	var stable: bool = false
	func actor_position(value: Vector2) -> Vector2:
		return Pixels.snap_position(self, value) if stable else value
	func _draw() -> void:
		draw_rect(Rect2(0,0,512,384), Color("10202c"))
		draw_set_transform(actor_position(Vector2(100,110)+offset))
		Entities.player_body(self,{"character":"ranger","grounded":true,"vel":Vector2.ZERO},0.0)
		draw_set_transform(actor_position(Vector2(250,110)+offset))
		Entities.enemy(self,{"kind":"crawler","id":0,"vel":Vector2.ZERO},0.0)
		draw_set_transform(actor_position(Vector2(365,260)+offset))
		Entities.enemy(self,{"kind":"boss","boss_style":"stone","id":0,"vel":Vector2.ZERO},0.0)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label=argument.trim_prefix("--label=")
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var canvas := Canvas.new()
	canvas.stable = label != "before"
	root.add_child(canvas)
	root.content_scale_size=Vector2i(512,384)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var results: Array=[]
	for factor: float in [1.0,1.5,2.0]:
		root.size=Vector2i(Vector2(512,384)*factor)
		await process_frame
		print("TRANSFORMS ",factor," viewport=",canvas.get_viewport_transform()," canvas=",canvas.get_global_transform_with_canvas()," stretch=",root.get_stretch_transform())
		var crops: Array=[]
		var unique: Dictionary={}
		var differences: Array=[]
		var sheet: Image=Image.create(8*104,4*128,false,Image.FORMAT_RGBA8)
		for step: int in range(32):
			canvas.offset=Vector2(step*.125,step*.046875)
			canvas.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image=root.get_texture().get_image()
			var origin: Vector2i=Vector2i(((Vector2(100,110)+canvas.offset)*factor).round())
			var crop: Image=shot.get_region(Rect2i(origin-Vector2i(40,64),Vector2i(80,112)))
			unique[hash(crop.get_data())]=true
			if not crops.is_empty():
				var old: Image=crops[0]
				var changed: int=0
				for y: int in range(112):
					for x: int in range(80):
						if old.get_pixel(x,y)!=crop.get_pixel(x,y): changed+=1
				differences.append(changed)
			crops.append(crop)
			sheet.blit_rect(crop,Rect2i(0,0,80,112),Vector2i((step%8)*104,(step/8)*128))
		var total: float=0.0
		for changed: int in differences: total+=changed
		results.append({"scale":factor,"distinct_patterns":unique.size(),"mean_changed_pixels":total/differences.size()})
		sheet.save_png("res://tools/results/actor-motion-"+label+"-"+str(factor)+".png")
	print("ACTOR_MOTION_CAPTURE ",JSON.stringify(results))
	var file=FileAccess.open("res://tools/results/actor-motion-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	canvas.queue_free()
	await process_frame
	quit(0)
