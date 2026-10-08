extends SceneTree
const Locale=preload("res://scripts/localization.gd")
const DIRECTORY: String="res://tools/results/entry-v0220/"
func _initialize() -> void: run.call_deferred()
func buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button: result.append({"text":node.text,"rect":str(node.get_global_rect()),"center":str(node.get_global_rect().get_center())})
	for child: Node in node.get_children(): result.append_array(buttons(child))
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	root.size=Vector2i(1280,720)
	var game: Node=load("res://main.tscn").instantiate()
	game.set("_smoke","ui")
	root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.sound.shutdown()
	var report: Dictionary={}
	for language: String in ["en","zh"]:
		Locale.set_language(language)
		for page: String in ["menu","characters","settings","lobby"]:
			if page=="lobby":
				game.hosting=true; game.local_id=1
				game.roster=[{"id":1,"name":"Host","character":"ranger","ready":true},{"id":2,"name":"Friend","character":"vanguard","ready":false}]
			game.call("_show_"+page)
			for i: int in range(4): await process_frame
			report[language+"/"+page]=buttons(game.ui)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(DIRECTORY+language+"-"+page+".png")
	FileAccess.open(DIRECTORY+"buttons.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free(); await process_frame
	quit(0)
