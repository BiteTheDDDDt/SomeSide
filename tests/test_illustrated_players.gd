extends SceneTree
const Players=preload("res://scripts/illustrated_player_renderer.gd")
const Style=preload("res://scripts/art_style.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,message: String) -> void:
	if ok: passed+=1; print("PASS: ",message)
	else: failed+=1; push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var sheet: Texture2D=null
	for character: String in ["ranger","vanguard"]:
		for index: int in range(4):
			var f: Dictionary=Players.frame(character,index)
			var source: Rect2=f.region
			if sheet==null: sheet=f.texture.atlas
			check(f.texture.atlas==sheet,"All character poses share a single source allocation")
			check(Rect2(Vector2.ZERO,sheet.get_size()).encloses(source),character+" pose UVs remain inside atlas")
			check(f.texture==Players.frame(character,index).texture,"Portrait/world requests reuse the same pose resource")
			check(Rect2(f.target).size.y<50 and Rect2(f.target).size.y>30,"Illustration retains game-scale body dimensions")
			if index==0: check(is_equal_approx(Rect2(f.target).end.y,21),"Idle soles match existing ground-contact baseline")
	check(Players._frames.size()==8,"All supported poses require exactly eight bounded frame views")
	check(Players.frame("unknown").is_empty(),"Unknown character cannot silently receive another class's body")
	check(sheet.get_width()*sheet.get_height()*4<8*1024*1024,"Shared player atlas fits an 8 MiB uncompressed budget")
	check(Style.material(Color("071219"))==Style.SHADOW,"Object shadows use approved charcoal instead of near-black")
	check(Style.material(Color("fff0cf")).r>.8,"Shadow compression preserves a readable bright tier")
	print("ILLUSTRATED_PLAYERS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
