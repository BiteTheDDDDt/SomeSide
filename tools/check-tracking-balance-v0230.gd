extends SceneTree
## Repeatable probes, not a substitute for human balance feedback. No balance
## overrides are applied in production; the five accuracy fixtures suppress AI.
const Sim=preload("res://scripts/simulation.gd")
const Content=preload("res://scripts/content.gd")
const NEW_IDS: Array[String]=["arc_needle","star_seeker","hunting_beacon"]
const OUTPUT="res://tools/results/tracking-v0230/balance.json"
var report: Dictionary={"version":"0.23.0","step_hz":60,"accuracy":[],"survival":[],"loot_weights":[]}

func _initialize() -> void:
	for scenario: String in ["single_boss","crowd","moving","close_orbit","platform_height"]:
		for weapon: String in ["pulse_rifle","railgun","arc_needle","star_seeker"]:
			report.accuracy.append(accuracy(scenario,weapon))
	for scenario: String in ["close_pressure","spore_boss","stone_boss","prism_boss"]:
		for role: String in ["ranger","vanguard","weaver"]:
			report.survival.append(survival(scenario,role))
	weights()
	DirAccess.make_dir_recursive_absolute("res://tools/results/tracking-v0230")
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRACKING_BALANCE_REPORT accuracy_cases=",report.accuracy.size()," survival_cases=",report.survival.size()," path=",OUTPUT)
	quit(0)

func fresh(role: String="ranger"):
	var sim=Sim.new()
	sim.start_run([{"id":1,"name":"Probe","character":role}],8230)
	sim.state.platforms=[Rect2(0,800,6000,200)]
	sim.state.solid_cover=[Rect2(0,800,6000,200)]
	sim.state.floor_y=800.0; sim.state.chests.clear(); sim.state.pickups.clear(); sim.state.enemies.clear(); sim._spawn_clock=99999
	var p: Dictionary=sim.state.players[1]
	p.pos=Vector2(1000,779); p.grounded=true; p.vel=Vector2.ZERO; p.invuln=0.0
	return sim

func accuracy(scenario: String,weapon: String) -> Dictionary:
	# Weaver adds no free ranged passive shot. Use it without marks/skills so
	# these counts measure the weapon alone, including its ordinary crit chance.
	var sim=fresh("weaver"); var p: Dictionary=sim.state.players[1]; p.weapon=weapon
	if scenario=="platform_height": sim.state.platforms.append(Rect2(1250,650,260,24))
	var targets: Array=[]
	for i: int in range(10 if scenario=="crowd" else 1):
		var e: Dictionary=sim._spawn_enemy("boss" if scenario=="single_boss" else "crawler",Vector2(1300+i*22,770-(i%3)*20))
		e.hp=100000; e.max_hp=100000; e.attack_cd=999; e.move_speed=0; targets.append(e)
	var shots: int=0; var hits: int=0; var damage: float=0; var max_live: int=0
	for tick: int in range(720):
		var time: float=tick/60.0
		var target: Dictionary=targets[0]
		match scenario:
			"moving": target.pos=Vector2(1300+sin(time*1.8)*150,690+sin(time*2.5)*60)
			"close_orbit": target.pos=p.pos+Vector2(cos(time*2.2)*100,sin(time*2.2)*70-40)
			"platform_height": target.pos=Vector2(1350,600+sin(time)*45)
		# The same five-degree aiming error is applied to all weapons.
		p.aim=(Vector2(target.pos)-(Vector2(p.pos)+Vector2(0,-14))).normalized().rotated(deg_to_rad(5))
		p.fire_cd=maxf(0,float(p.fire_cd)-1.0/60)
		sim.events.clear()
		if p.fire_cd<=0: sim._fire_weapon(p)
		sim._step_projectiles(1.0/60)
		for event: Dictionary in sim.events:
			if event.type=="shoot": shots+=1
			if event.type=="hit": hits+=1; damage+=float(event.amount)
		max_live=maxi(max_live,sim.state.projectiles.size())
	return {"scenario":scenario,"weapon":weapon,"seconds":12,"aim_error_degrees":5,"shots":shots,"hits":hits,"hit_rate":float(hits)/maxi(1,shots),"damage":damage,"effective_dps":damage/12.0,"peak_projectiles":max_live,"ai":false,"target_hp":100000,"control":"Weaver without marks, skills, equipment or relics; weapon-only; ordinary crit chance remains"}

func survival(scenario: String,role: String) -> Dictionary:
	var sim=fresh(role); var p: Dictionary=sim.state.players[1]
	var boss: Dictionary={}
	if scenario=="close_pressure":
		for i: int in range(6): sim._spawn_enemy("crawler",Vector2(1000+(70+i*28)*(-1 if i%2==0 else 1),779))
	else:
		sim.state.biome={"spore_boss":"rainforest","stone_boss":"canyon","prism_boss":"ruins"}[scenario]
		boss=sim._spawn_enemy("boss",Vector2(1330,735))
	var seconds: float=0; var initial_hp: float=float(p.hp); var damage_received: float=0; var peak: int=0
	for tick: int in range(2400):
		if bool(p.dead) or sim.state.enemies.is_empty(): break
		var nearest: Dictionary=sim._nearest_enemy(p.pos,10000)
		var offset: Vector2=Vector2(nearest.pos)-Vector2(p.pos)
		var desired: float=105 if role=="vanguard" else 240
		var move: float=signf(offset.x) if absf(offset.x)>desired+35 else (-signf(offset.x) if absf(offset.x)<desired-35 else 0)
		# All classes use the same basic kiting/jump controller and their own
		# real initial loadout/ability. No invulnerability or healing fixture.
		var command: Dictionary={"aim":offset.normalized(),"move":move,"fire":true,"dash":tick%30==0,"skill":tick%30==0,"jump":tick%95==0,"jump_held":tick%95<18}
		var before: float=float(p.hp)
		sim.step(1.0/60,{1:command})
		damage_received+=maxf(0,before-float(p.hp)); seconds+=1.0/60
		peak=maxi(peak,sim.state.projectiles.size())
	return {"scenario":scenario,"role":role,"elapsed":seconds,"outcome":"dead" if bool(p.dead) else ("cleared" if sim.state.enemies.is_empty() else "time_limit"),"starting_hp":initial_hp,"remaining_hp":float(p.hp),"damage_received":damage_received,"boss_hp":float(boss.get("hp",0)),"peak_projectiles":peak,"items":p.items,"control":"scripted kiting, jump every 95 ticks, own skills/equipment; no invulnerability"}

func weights() -> void:
	var sim=fresh()
	for category: String in ["weapon","equipment","mixed_gear"]:
		var catalog: Array=Content.weapons() if category=="weapon" else (Content.equipment() if category=="equipment" else Content.weapons()+Content.equipment())
		# Real eligible pool: four starters are never dropped; also remove
		# current equipment, ground rewards and history as _gear_candidates does.
		sim.state.pickups.clear(); sim.state.chests.clear(); sim.state.loot_history={"gear":[],"passive":[]}
		var candidates: Array=sim._gear_candidates("" if category=="mixed_gear" else category,false)
		for source: String in ["ambient","equipment","boss"]:
			var counts: Array=[0,0,0,0]; var rarity: Array=sim.rarity_weights(source)
			for e: Dictionary in candidates:
				if str(e.id) not in NEW_IDS: counts[Content.rarity_rank(str(e.rarity))]+=1
			var old_mass: float=0; var new_mass: float=0; var added: Dictionary={}
			for e: Dictionary in candidates:
				var rank: int=Content.rarity_rank(str(e.rarity))
				var weight: float=float(rarity[rank])/maxi(1,int(counts[rank]))
				if str(e.id) in NEW_IDS: new_mass+=weight; added[e.id]=weight
				else: old_mass+=weight
			var total: float=old_mass+new_mass
			for id: String in added: added[id]=float(added[id])/total
			report.loot_weights.append({"stage":1,"category":category,"source":source,"eligible_ids":candidates.map(func(e: Dictionary)->String:return str(e.id)),"old_raw_mass":old_mass,"new_raw_mass":new_mass,"old_probability_multiplier":old_mass/total,"new_conditional_probabilities":added,"old_relative_weights_unchanged":true,"assumptions":"Ranger solo, starter IDs excluded, no ground rewards, no gear history"})
