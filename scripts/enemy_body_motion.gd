class_name SideEnemyBodyMotion
extends RefCounted

## Distinct visual rhythms sampled from authority timers, not render ticks.
const Rig=preload("res://scripts/enemy_rig_24.gd")
const Keys=preload("res://scripts/actor_key_poses.gd")
const PROFILES: Dictionary = {
	"crawler":{"release":.055,"recover":.22},
	"spitter":{"release":.085,"recover":.32},
	"boss_stone":{"release":.075,"recover":.48}}

static func sample(enemy: Dictionary, id: String) -> Dictionary:
	var kind: String = str(enemy.get("attack_kind",""))
	var remaining: float = maxf(0,float(enemy.get("telegraph",0)))
	var winding: bool = remaining>0
	var progress: float = clampf(1-remaining/maxf(.01,float(enemy.get("telegraph_max",.8))),0,1)
	var elapsed: float = maxf(0,float(enemy.get("attack_cooldown",3))-float(enemy.get("attack_cd",0)))
	var charging: float = float(enemy.get("charge_timer",0))
	var default_profile: Dictionary={"release":.055,"recover":.22}
	if kind in ["beam","prism_beam","prism_cross"]: default_profile={"release":.055,"recover":.55}
	elif kind in ["mortar","spore_volley","spore_bloom"]: default_profile={"release":.05,"recover":.30}
	elif kind=="mend": default_profile={"release":.07,"recover":.38}
	elif kind=="blink": default_profile={"release":.035,"recover":.18}
	var profile: Dictionary = PROFILES.get(id,default_profile)
	var weights: Dictionary = {}
	var phase: String = "ready"
	if kind.is_empty(): return {"weights":weights,"phase":phase,"winding":false,"progress":0.0,"amount":0.0}
	if winding:
		weights[0]=smoothstep(.0,.10,progress)
		phase="coil"
	elif charging>0:
		# Hold the airborne/extended key pose for the real lunge, rather than
		# starting recovery while the creature is still travelling forward.
		var duration: float = .35 if kind=="pounce" else (.72 if kind=="stone_charge" else .58)
		var charge_phase: float = clampf(1-charging/duration,0,1)
		weights[1]=1.0-smoothstep(.74,1.0,charge_phase)
		weights[2]=1.0-float(weights[1])
		phase="release" if charge_phase<.74 else "brace"
	elif elapsed-(.35 if kind=="pounce" else (.72 if kind=="stone_charge" else (.58 if kind=="charge" else 0.0)))<float(profile.recover):
		if kind in ["pounce","charge","stone_charge"]: elapsed=maxf(float(profile.release),elapsed-(.35 if kind=="pounce" else (.72 if kind=="stone_charge" else .58)))
		var release_end: float = float(profile.release)
		if elapsed<release_end:
			weights[1]=1.0
			phase="release"
		else:
			var t: float = (elapsed-release_end)/(float(profile.recover)-release_end)
			var transfer: float = smoothstep(.40,.56,t)
			var fade: float = 1.0-smoothstep(.80,1,t)
			weights[2]=(1-transfer)*fade
			weights[3]=transfer*fade
			phase="recover"
	var amount: float = 0.0
	if winding: amount=smoothstep(0,1,progress)
	elif not weights.is_empty():
		amount=lerpf(1,-.35,smoothstep(0,float(profile.release),elapsed)) if elapsed<float(profile.release) else -.35*(1-smoothstep(float(profile.release),float(profile.recover),elapsed))
	return {"weights":weights,"phase":phase,"winding":winding,"progress":progress,"amount":amount,"elapsed":elapsed,"rig_stage":"coil" if winding else ("release" if phase in ["release","brace"] else ("recover" if not weights.is_empty() else "idle")),"rig_progress":progress if winding else (clampf(1-charging/(.35 if kind=="pounce" else (.72 if kind=="stone_charge" else .58)),0,1) if charging>0 else (clampf(elapsed/float(profile.release),0,1) if elapsed<float(profile.release) else clampf((elapsed-float(profile.release))/(float(profile.recover)-float(profile.release)),0,1)))}

static func claw_origin(enemy: Dictionary) -> Vector2:
	var rhythm: Dictionary=sample(enemy,"crawler")
	var rig: Dictionary=Rig.sample("crawler",str(enemy.get("attack_kind","pounce")),str(rhythm.get("rig_stage","idle")),float(rhythm.get("rig_progress",0)),false)
	var anchor:=Vector2(27,11)
	var total: float=0.0
	var result:=Vector2.ZERO
	Keys.prepare()
	for index: int in rhythm.weights:
		var weight: float=rhythm.weights[index]
		var description: Dictionary=Keys._data.actors.crawler.frames[index]
		var f: Dictionary=Keys.frame("crawler",index)
		var pixel:=Vector2(description.claw[0],description.claw[1])
		var point: Vector2=Rect2(f.target).position+pixel*.20
		point=Rig.bend(point,pixel/Rect2(f.region).size,Rect2(f.target),rig)
		result+=point*weight; total+=weight
	return result+anchor*(1.0-total)
