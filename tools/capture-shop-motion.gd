extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var label: String = "after"
var directory: String

class ShopView extends "res://scripts/world_view.gd":
	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_process(false)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("10252d"))
		draw_line(Vector2(0,427),Vector2(1280,427),Color("48605d"),2.0)
		_draw_chests()
		_draw_pickups()
		draw_string(_font,Vector2(40,52),"THREE-CHOICE SHOP / 60 Hz CAPTURE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e9f3da"))
		draw_string(_font,Vector2(40,82),"Three real shop offers, equipment bay, ground loot; original selection rules.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("7df3d0"))
	func icon_rect(chest: Dictionary) -> Rect2:
		var p: Vector2=world_to_screen(chest.pos)+Vector2(0,7)
		if has_method("facility_icon_rect"):
			p=Pixels.snap_position(self,p)
			return call("facility_icon_rect",p,chest,str(chest.type))
		var offset: Vector2=Vector2(-12,-27) if chest.type=="equipment" else Vector2(-12,-41+sin(_clock*2.0+p.x)*1.5)
		return Rect2(p+offset,Vector2(24,24))

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label=argument.trim_prefix("--label=")
	_run.call_deferred()

func _capture(view: ShopView) -> Image:
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	directory="res://tools/results/shop-motion-"+label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1280,720)
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Shop capture","character":"ranger"}],20261005)
	var shops: Array=[]
	var group: int=-1
	for chest: Dictionary in sim.state.chests:
		if chest.type=="choice" and (group==-1 or group==int(chest.group)):
			group=int(chest.group)
			shops.append(chest.duplicate(true))
	assert(shops.size()==3)
	for index: int in range(3): shops[index].pos=Vector2(540+index*100,410)
	shops.append({"id":9001,"pos":Vector2(960,410),"type":"equipment","item":"grenade","opened":false})
	var view:=ShopView.new()
	view._frame={"chests":shops,"pickups":[{"id":9002,"pos":Vector2(690,540),"kind":"item","item":"feather","rarity":"uncommon"},{"id":9003,"pos":Vector2(790,540),"kind":"item","item":"glass","rarity":"rare"}]}
	view.interaction_target={"kind":"pickup","id":9003}
	root.add_child(view)
	var original: PackedByteArray=var_to_bytes(view._frame)
	var report: Dictionary={"label":label,"refresh_hz":60,"sequences":[],"sampling":[]}
	for moving: bool in [false,true]:
		var mode: String="moving" if moving else "stationary"
		var samples: Array=[]
		for frame: int in range(120):
			view._clock=float(frame)/60.0
			view.camera_position=Vector2(640+(float(frame)*2.5 if moving else 0.0),360)
			var shot: Image=await _capture(view)
			shot.get_region(Rect2i(160,340,1000,260)).save_png(directory+"/%s-%03d.png"%[mode,frame])
			if frame==0: shot.save_png(directory+"/"+mode+"-full.png")
			var positions: Array=[]
			for index: int in range(3):
				var chest: Dictionary=shops[index]
				var rect: Rect2=view.icon_rect(chest)
				positions.append([rect.position.x,rect.position.y,rect.position.y-(view.world_to_screen(chest.pos).y+7.0)])
			samples.append(positions)
		report.sequences.append({"mode":mode,"frames":120,"duration":2.0,"positions":samples})
	for scale_factor: float in [1.0,1.5,2.0]:
		root.size=Vector2i(Vector2(1280,720)*scale_factor)
		await process_frame
		var patterns: Array=[{},{},{},{}]
		var opaque_patterns: Array=[{},{},{},{}]
		var first_pixels: Array=[null,null,null,null]
		var max_channel_delta: Array=[0,0,0,0]
		var sheet: Image=Image.create(8*104,4*88,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("10252d"))
		for sample: int in range(32):
			view._clock=0.73
			view.camera_position=Vector2(640+sample*.125,360+sample*.046875)
			var shot: Image=await _capture(view)
			for index: int in range(4):
				var rect: Rect2=view.icon_rect(shops[index])
				var crop: Image=shot.get_region(Rect2i(Vector2i((rect.position*scale_factor).round()),Vector2i(rect.size*scale_factor)))
				patterns[index][hash(crop.get_data())]=true
				# Exclude the translucent rim: underlying antialiased hologram
				# beams can differ by a channel value without changing icon pixels.
				var inset: int=int(4.0*scale_factor)
				var opaque: Image=crop.get_region(Rect2i(Vector2i.ONE*inset,crop.get_size()-Vector2i.ONE*inset*2))
				opaque_patterns[index][hash(opaque.get_data())]=true
				var pixels: PackedByteArray=opaque.get_data()
				if first_pixels[index]==null: first_pixels[index]=pixels
				for channel: int in range(pixels.size()):
					max_channel_delta[index]=maxi(max_channel_delta[index],absi(int(pixels[channel])-int(first_pixels[index][channel])))
				if index==3:
					crop.resize(72,72,Image.INTERPOLATE_NEAREST)
					sheet.blit_rect(crop,Rect2i(0,0,72,72),Vector2i(sample%8*104,sample/8*88))
		sheet.save_png(directory+"/sampling-equipment-%s.png"%scale_factor)
		var counts: Array=[]
		var opaque_counts: Array=[]
		for unique: Dictionary in patterns: counts.append(unique.size())
		for unique: Dictionary in opaque_patterns: opaque_counts.append(unique.size())
		report.sampling.append({"scale":scale_factor,"phases":32,"distinct_icon_patterns":counts,"opaque_icon_patterns":opaque_counts,"max_opaque_channel_delta":max_channel_delta})
	report.input_immutable=original==var_to_bytes(view._frame)
	var file:=FileAccess.open(directory+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("SHOP_MOTION_CAPTURE ",JSON.stringify({"path":directory,"frames":240,"sampling":report.sampling,"input_immutable":report.input_immutable}))
	view.queue_free()
	await process_frame
	quit(0)
