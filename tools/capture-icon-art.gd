extends SceneTree

const Icons=preload("res://scripts/item_icons.gd")
const Content=preload("res://scripts/content.gd")
const DIRECTORY="res://tools/results/icon-art-v020/"
var tag: String="smooth"

class Catalogue extends Node2D:
	var entries: Array=[]
	var title: String=""
	var objects: bool=false
	func _draw() -> void:
		var font: Font=ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1280,1026),Color("08161d"))
		draw_string(font,Vector2(28,34),"SOMESIDE / ITEM ART / "+title.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("e6e6ce"))
		draw_string(font,Vector2(28,58),"Native 64 px + 24 px + 16 px / 27 relics, 8 weapons, 8 equipment",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("829e9f"))
		for index: int in range(entries.size()):
			var entry: Dictionary=entries[index]
			var p=Vector2(28+(index%8)*154,82+(index/8)*154)
			draw_rect(Rect2(p,Vector2(146,142)),Color("10232b"))
			draw_texture(Icons.pickup_texture(entry.id,64) if objects else Icons.texture(entry.id,64),p+Vector2(9,16))
			draw_texture(Icons.pickup_texture(entry.id,24) if objects else Icons.texture(entry.id,24),p+Vector2(85,37))
			draw_texture(Icons.pickup_texture(entry.id,16) if objects else Icons.texture(entry.id,16),p+Vector2(118,41))
			draw_string(font,p+Vector2(11,103),str(entry.id),HORIZONTAL_ALIGNMENT_LEFT,136,12,Color("e2e0cf"))
			draw_string(font,p+Vector2(11,123),str(entry.rarity),HORIZONTAL_ALIGNMENT_LEFT,136,10,Icons.rarity_color(entry.rarity))

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag=arg.trim_prefix("--tag=")
	var records: Array=Content.passives()+Content.weapons()+Content.equipment()
	var unique: Dictionary={}
	var object_unique: Dictionary={}
	var failures: Array=[]
	for entry: Dictionary in records:
		for pixels: int in [16,24,32,48,64,128,256]:
			var texture: Texture2D=Icons.texture(str(entry.id),pixels)
			if texture.get_size()!=Vector2(pixels,pixels): failures.append(str(entry.id)+" incorrect size "+str(pixels))
			if texture!=Icons.texture(str(entry.id),pixels): failures.append(str(entry.id)+" uncached")
			if pixels==64: unique[texture.get_image().get_data().hex_encode().hash()]=true
			var object_texture: Texture2D=Icons.pickup_texture(str(entry.id),pixels)
			if object_texture.get_size()!=Vector2(pixels,pixels) or object_texture!=Icons.pickup_texture(str(entry.id),pixels): failures.append(str(entry.id)+" object dimensions/cache")
			if object_texture==texture: failures.append(str(entry.id)+" framed cache collision")
			var image: Image=object_texture.get_image()
			var source_size: Vector2i=image.get_size()
			for corner: Vector2i in [Vector2i.ZERO,Vector2i(source_size.x-1,0),Vector2i(0,source_size.y-1),source_size-Vector2i.ONE]:
				if image.get_pixelv(corner).a>0: failures.append(str(entry.id)+" object background")
			if image.get_used_rect().size.x<source_size.x*.25 or image.get_used_rect().size.y<source_size.y*.2: failures.append(str(entry.id)+" missing silhouette")
			if pixels==64: object_unique[image.get_data().hex_encode().hash()]=true
	for id: String in ["phase_dash","guard_burst","shoulder_rush","cache","choice","blood","combat","equipment_cache","gate","revive","unknown"]:
		if Icons.texture(id,24).get_size()!=Vector2(24,24): failures.append(id+" utility")
	if unique.size()!=43: failures.append("Catalogue must retain 43 distinct icon images")
	if object_unique.size()!=43: failures.append("Transparent objects must retain 43 distinct silhouettes")
	if Icons.texture("grenade",1).get_width()!=16 or Icons.pickup_texture("grenade",999).get_width()!=256: failures.append("Size clamps")
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var native: bool=DisplayServer.get_name()!="headless"
	if native:
		var view=SubViewport.new()
		view.size=Vector2i(1280,1026)
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var page=Catalogue.new()
		page.entries=records; page.title=tag
		page.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		view.add_child(page)
		for frame: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		if view.get_texture().get_image().save_png(DIRECTORY+tag+"-catalogue.png")!=OK: failures.append("PNG save failed")
		page.objects=true; page.title=tag+" / TRANSPARENT OBJECTS"; page.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		if view.get_texture().get_image().save_png(DIRECTORY+tag+"-objects.png")!=OK: failures.append("Object PNG save failed")
		view.queue_free(); await process_frame
	var result: Dictionary={"tag":tag,"native":native,"count":records.size(),"unique":unique.size(),"transparent_unique":object_unique.size(),"sizes":[16,24,32,48,64,128,256],"failures":failures,"source_sha256":FileAccess.get_sha256("res://scripts/item_icons.gd")}
	FileAccess.open(DIRECTORY+tag+"-report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ICON_ART_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
