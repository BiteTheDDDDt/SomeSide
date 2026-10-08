extends SceneTree

const Simulation=preload("res://scripts/simulation.gd")
const Locale=preload("res://scripts/localization.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/facility_art.gd")
var passed: int=0
var failed: int=0

class View extends "res://scripts/world_view.gd":
	func _ready() -> void:
		var font:=FontVariation.new()
		font.base_font=load("res://assets/fonts/NotoSansSC.ttf")
		font.variation_opentype={2003265652:500.0}
		_font=font
		set_process(false)
	func _draw() -> void: pass

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error(message)

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	await process_frame
	var sim=Simulation.new()
	sim.start_run([{"id":1,"name":"Facility tests","character":"ranger"}],19006)
	var view=View.new()
	root.add_child(view)
	for stage: int in range(1,4):
		if stage>1: sim._build_stage(stage)
		view._frame=sim.state
		var original: PackedByteArray=var_to_bytes(sim.state)
		var rng_state: int=sim._rng.state
		for language: String in ["zh","en"]:
			Locale.set_language(language)
			var correct_rewards: bool=true
			var correct_currency: bool=true
			var readable_names: bool=true
			var groups: Dictionary={}
			for chest: Dictionary in sim.state.chests:
				var data: Dictionary=view.facility_label_data(chest)
				correct_rewards=correct_rewards and (data.item==chest.item and data.name==Locale.text(str(Content.definition(chest.item).name)) if chest.type=="choice" else data.item=="" and data.name==Locale.text(preload("res://scripts/chest_rules.gd").label(chest)))
				var expected_currency: String="hp" if chest.type=="blood" else ("challenge" if chest.type=="combat" else "coin")
				correct_currency=correct_currency and data.currency==expected_currency
				if expected_currency=="coin": correct_currency=correct_currency and data.cost_text==str(chest.cost)
				elif expected_currency=="hp": correct_currency=correct_currency and data.cost_text==Locale.format("%d 生命",[chest.cost])
				else: correct_currency=correct_currency and data.cost_text==Locale.text("挑战")
				var rect: Rect2=view.facility_label_rect(Vector2(640,360),chest,str(chest.type))
				readable_names=readable_names and rect.size.y==36 and rect.size.x<=144 and view._font.get_string_size(str(data.name),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=rect.size.x-12
				if chest.type=="choice":
					if not groups.has(chest.group): groups[chest.group]=[]
					groups[chest.group].append(chest)
			_check(correct_rewards,"Stage %d %s reveals choice offers and conceals other rewards"%[stage,language])
			_check(correct_currency,"Stage %d %s never represents blood/trial as a free gold purchase"%[stage,language])
			_check(readable_names,"Stage %d %s names and costs fit two compact lines at 11px"%[stage,language])
			for offers: Array in groups.values():
				var center: Vector2=offers[1].pos
				var rectangles: Array=[]
				for offer: Dictionary in offers:
					rectangles.append(view.facility_label_rect(Vector2(640,400)+Vector2(offer.pos)-center,offer,"choice"))
				var no_overlap: bool=true
				for i: int in range(3):
					for j: int in range(i+1,3): no_overlap=no_overlap and not Rect2(rectangles[i]).grow(2).intersects(rectangles[j])
				_check(no_overlap,"The real three-choice group in %s has no overlapping price labels"%language)
		_check(original==var_to_bytes(sim.state) and rng_state==sim._rng.state,"Facility display preserves stage %d state and RNG"%stage)
	var record: Dictionary=sim._make_chest("blood",Vector2.ZERO,22,"feather")
	sim.state.players[1].hp=22
	_check(not view.facility_label_data(record).affordable,"Blood offering cannot imply exact remaining HP is enough")
	sim.state.players[1].hp=23
	_check(view.facility_label_data(record).affordable,"Blood offering above its exact HP price is affordable")
	record.type="cache"; sim.state.players[1].coins=21
	_check(not view.facility_label_data(record).affordable,"Gold affordability uses the local player's current balance")
	sim.state.players[1].coins=22
	_check(view.facility_label_data(record).affordable,"Exact gold is sufficient")
	record.type="combat"; record.status="active"; record.remaining=3
	var info: Dictionary=view.facility_label_data(record)
	_check(info.currency=="challenge" and info.cost_text==Locale.format("剩余 %d",[3]) and info.item.is_empty() and info.name==Locale.text("试炼信标"),"Active trials conceal their reward and retain the authoritative remaining count")
	record.status="cleared"; record.opened=true
	info=view.facility_label_data(record)
	_check(info.state=="open" and info.name.is_empty() and info.cost_text==Locale.text("已完成"),"Cleared trials remove stale reward/price previews")
	record.type="choice"; record.locked=true
	info=view.facility_label_data(record)
	_check(info.state=="locked" and info.name.is_empty() and info.cost_text==Locale.text("已锁定"),"Unselected locked offers cannot look purchasable")
	record.type="cache"; record.locked=false
	_check(view.facility_label_data(record).cost_text==Locale.text("已开启"),"Opened chests explicitly show their used state")
	var kinds: Dictionary={}
	for kind: String in Art.KINDS:
		for state: String in ["idle","open","locked"]:
			var texture: Texture2D=Art.texture(kind,state)
			_check(texture==Art.texture(kind,state) and texture.get_size()==Vector2(64,64) and texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and texture.get_image().has_mipmaps(),kind+":"+state+" is cached with smooth sampling and fixed footprint")
			kinds[hash(texture.get_image().get_data())]=true
	Art.texture("combat","active")
	var budget: Dictionary=Art.cache_stats()
	_check(kinds.size()==15,"Each facility and depleted state has a distinct physical silhouette/material image")
	_check(budget.textures==16 and budget.bytes<=budget.max_bytes and budget.bytes<6*1024*1024,"All possible physical facility variants remain below 6MiB")
	_check(Art.texture("unknown","invalid")==Art.texture("cache","idle"),"Unknown display variants cannot create an unbounded texture cache")
	var ground: float=777.0
	var anchor: Vector2=Vector2(400,ground-17)+Vector2(0,7)
	_check(is_equal_approx(anchor.y+Art.BOUNDS.end.y,ground),"All new bases meet the actual supporting platform plane")
	var edge_offers: Array=[]
	for index: int in range(3):
		var offer: Dictionary=sim._make_chest("choice",Vector2((index-1)*112,0),123,["railgun","boomerang","resonator"][index])
		offer.group=1900; edge_offers.append(offer)
	view._frame={"chests":edge_offers}
	for center: Vector2 in [Vector2(40,24),Vector2(1240,24),Vector2(40,690),Vector2(1240,690)]:
		var boxes: Array=[]
		var edges_ok: bool=true
		for offer: Dictionary in edge_offers:
			var box: Rect2=view.facility_label_rect(center+Vector2(offer.pos),offer,"choice")
			edges_ok=edges_ok and box.position.x>=5 and box.position.y>=5 and box.end.x<=1275 and box.end.y<=715
			for previous: Rect2 in boxes: edges_ok=edges_ok and not previous.grow(1).intersects(box)
			boxes.append(box)
		_check(edges_ok,"The entire three-choice label group stays separated and inside the viewport at "+str(center)+" / "+str(boxes))
	var stable: Rect2=view.facility_label_rect(Vector2(640,400),edge_offers[1],"choice")
	view._clock=10000
	edge_offers.reverse()
	_check(stable==view.facility_label_rect(Vector2(640,400),edge_offers[1],"choice"),"Time and snapshot array reordering cannot shift the middle price label")
	var lower: Dictionary=sim._make_chest("cache",Vector2(0,90),37,"capacitor")
	edge_offers.append(lower)
	var lower_label: Rect2=view.facility_label_rect(Vector2(640,490),lower,"cache")
	_check(is_zero_approx(view._facility_label_obstruction(lower_label,Vector2(640,490),lower)),"A lower-platform chest's label avoids the actual shop bodies on the floor above")
	Locale.set_language("en")
	for definition: Dictionary in Content.passives()+Content.weapons()+Content.equipment():
		record=sim._make_chest("cache",Vector2.ZERO,123,definition.id)
		info=view.facility_label_data(record)
		var rect: Rect2=view.facility_label_rect(Vector2(640,300),record,"cache")
		_check(view._font.get_string_size(str(info.name),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=rect.size.x-12,"The complete English name of "+str(definition.id)+" remains readable without truncation")
	view.queue_free(); await process_frame
	print("FACILITIES_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
