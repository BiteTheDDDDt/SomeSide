extends SceneTree

const Locale=preload("res://scripts/localization.gd")
var game: Node
var findings: Array=[]
var reviewed: int=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1280,720)
	var existed: bool=FileAccess.file_exists("user://profile.cfg")
	var before: PackedByteArray=FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	game=load("res://main.tscn").instantiate()
	game._smoke="ui-independent-review"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	for language: String in ["zh","en"]:
		Locale.set_language(language)
		for page: String in ["menu","characters","settings","join","guide"]:
			game.call("_show_"+page)
			await _audit(language+"-"+page)
		game.roster=[]
		for id: int in range(1,5): game.roster.append({"id":id,"name":"WWWWWWWWWWWWWWWWWW","character":"vanguard","ready":id%2==0})
		game.hosting=true
		game._show_lobby()
		await _audit(language+"-lobby-long-names")
		game.hosting=false
		game.online=false
		game._begin_local(game.roster,2611)
		for player: Dictionary in game.sim.state.players.values():
			player.kills=9999
			player.items={"overclock":99,"glass":99}
		for page: String in ["inventory","map","pause"]:
			game.call("_show_"+page)
			await _audit(language+"-"+page)
			game._resume()
		game.sim.state.phase="won"
		game._show_results()
		await _audit(language+"-results-four-long-names")
	var untouched: bool=FileAccess.file_exists("user://profile.cfg")==existed and (not existed or FileAccess.get_file_as_bytes("user://profile.cfg")==before)
	var report: Dictionary={"pages":reviewed,"findings":findings,"profile_unchanged":untouched}
	FileAccess.open("res://tools/results/v011-ui-independent-review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI_REVIEW ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if findings.is_empty() and untouched else 1)

func _controls(node: Node) -> Array[Control]:
	var result: Array[Control]=[]
	if node is Control: result.append(node)
	for child: Node in node.get_children(): result.append_array(_controls(child))
	return result

func _audit(title: String) -> void:
	for index: int in range(4): await process_frame
	reviewed+=1
	var controls: Array[Control]=_controls(game.overlay)
	var candidates: Array[Control]=[]
	for control: Control in controls:
		if not control.is_visible_in_tree(): continue
		if control.focus_mode!=Control.FOCUS_NONE and not (control is BaseButton and control.disabled): candidates.append(control)
		if control is BaseButton and not Rect2(0,0,1280,720).encloses(control.get_global_rect()): findings.append({"page":title,"issue":"button outside viewport","text":control.text})
		if control is Label and control.autowrap_mode==TextServer.AUTOWRAP_OFF and control.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING:
			var width: float=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
			if width>control.size.x+1.5: findings.append({"page":title,"issue":"unwrapped label clipped","text":control.text,"text_width":width,"control_width":control.size.x})
	if candidates.is_empty():
		findings.append({"page":title,"issue":"no keyboard-focusable controls"})
		return
	var focus: Control=candidates[0]
	var visited: Dictionary={}
	for index: int in range(candidates.size()+2):
		if visited.has(focus.get_instance_id()): break
		visited[focus.get_instance_id()]=true
		if not game.overlay.is_ancestor_of(focus): findings.append({"page":title,"issue":"focus leaves current overlay"})
		var next: Control=focus.find_next_valid_focus()
		if next==null:
			findings.append({"page":title,"issue":"broken keyboard focus traversal"})
			break
		focus=next
	print("UI_REVIEW_PAGE ",title," focusable=",candidates.size()," traversed=",visited.size())
