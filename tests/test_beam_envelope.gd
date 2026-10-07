extends SceneTree
const Envelope=preload("res://scripts/beam_envelope.gd")
const Art=preload("res://scripts/enemy_attack_visual.gd")
const Geometry=preload("res://scripts/combat_geometry.gd")
const Capture=preload("res://tools/capture-combat-unity-v0206.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS: ",label)
	else: failed+=1; push_error(label)
func _initialize() -> void:
	var previous: float=0.0
	for progress: float in [.0,.1,.3,.5,.65,.9,1.0]:
		var sample: Dictionary=Art.beam_sample({"delay":1.5*(1-progress),"telegraph_max":1.5,"length":720,"radius":12,"active":false})
		check(sample.warning_reach>=previous and sample.warning_reach<=1,"Warning extends monotonically without overshooting")
		previous=sample.warning_reach
	check(previous==1,"Warning reaches full range before release")
	var dashes: PackedVector2Array=Geometry.dashed_boundary(PackedVector2Array([Vector2.ZERO,Vector2(31,0)]),false)
	check(dashes.size()==6 and dashes[-1]==Vector2(31,0),"Open aim line does not double back or become a capsule")
	check(Envelope.sample(.55)==Vector2.ZERO and Envelope.sample(0)==Vector2.ZERO,"No phantom beam at start or expiration")
	check(Envelope.sample(.53).x<1 and Envelope.sample(.48)==Vector2.ONE,"Beam visibly extends then holds full range and width")
	check(Envelope.sample(.05).y<Envelope.sample(.15).y and Envelope.sample(.15).y<1,"Last 210ms progressively contract, not merely dim")
	for remaining: float in [.3,.05]:
		var setup: Dictionary=Capture.fixture("beam",false)
		var sim=setup.sim
		var hazard: Dictionary=sim.state.hazards[0]
		hazard.active=true; hazard.delay=0.0; hazard.ttl=remaining
		var player: Dictionary=sim.state.players[1]
		player.invuln=0
		player.pos=Vector2(hazard.pos)+Vector2(hazard.dir)*150+Vector2(hazard.dir).orthogonal()*24
		var hp: float=player.hp
		sim._step_hazards(.001)
		check((float(player.hp)<hp)==(remaining>.1),"Actual damage matches full-width versus contracted beam")
		var sample: Dictionary=Art.beam_sample(hazard)
		check(sample.envelope==Envelope.sample(hazard.ttl) and not sample.warning_visible,"Renderer and authority share the same live envelope without warning overlay")
	print("BEAM_ENVELOPE_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
