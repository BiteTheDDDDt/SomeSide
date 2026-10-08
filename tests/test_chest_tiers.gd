extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Rules=preload("res://scripts/chest_rules.gd")
const Natural=preload("res://scripts/natural_threats.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/facility_art.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error(label)
func _initialize() -> void:
	var sim=Sim.new()
	sim.start_run([{"id":1,"name":"Cache audit","character":"ranger"}],20808)
	var counts: Array=[]
	for tier: String in Rules.TIERS:
		var rare: int=0
		for i: int in range(2000):
			var id: String=sim._random_item(true,"cache_"+tier)
			if Content.rarity_rank(str(Content.definition(id).rarity))>=2: rare+=1
		counts.append(rare)
	check(counts[0]<counts[1] and counts[1]<counts[2],"Real seeded loot rolls improve rare/legendary frequency with cache tier: "+str(counts))
	for stage: int in range(1,4):
		sim._build_stage(stage)
		var tiers: Dictionary={}
		for chest: Dictionary in sim.state.chests:
			if chest.type=="cache": tiers[Rules.tier(chest)]=true
			var record: Dictionary=sim._interaction_record("chest",chest,sim.state.players[1])
			check(record.item==chest.item if chest.type=="choice" else record.item.is_empty() and record.category.is_empty(),"Inspection reveals only three-choice rewards")
		check(tiers.size()==3,"Stage "+str(stage)+" contains all three cache grades")
	var previous: float=0
	for amount: float in [0.0,.1,.25,.5,.75,1.0]:
		var points: PackedVector2Array=Natural.warning_points(Vector2(33,77),48,amount)
		var length: float=0
		for i: int in range(1,points.size()): length+=points[i-1].distance_to(points[i])
		check(length>=previous and absf(length-TAU*48*amount)<1,"Warning arc follows charge progress without closing the unfinished gap")
		previous=length
		for point: Vector2 in points: check(absf(point.distance_to(Vector2(33,77))-48)<.01,"Progress stays on the true danger radius")
	var hashes: Dictionary={}
	for tier: String in Rules.TIERS:
		for state: String in ["idle","open","locked"]:
			var texture: Texture2D=Art.texture("cache",state,tier)
			hashes[hash(texture.get_image().get_data())]=true
	check(hashes.size()==9,"All cache grades have distinct closed/open/locked artwork")
	print("CHEST_TIERS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
