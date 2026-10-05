extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
const World = preload("res://scripts/world_view.gd")
const Sound = preload("res://scripts/soundscape.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ",label)
	else: failed += 1; push_error("FAIL: "+label)
func _fresh(count: int = 1, seed_value: int = 1701):
	var sim = Simulation.new()
	var roster: Array = []
	for id: int in range(1,count+1): roster.append({"id":id,"name":"Gold","character":"ranger"})
	sim.start_run(roster,seed_value)
	sim.state.world_size=Vector2(8400,1900); sim.state.floor_y=1800.0
	sim.state.platforms=[Rect2(0,1800,8400,100)]; sim._spawn_clock=9999.0
	for player: Dictionary in sim.state.players.values():
		player.pos=Vector2(400+int(player.id)*30,1779); player.invuln=9999.0
	return sim
func _kill(sim, elite: bool = false, kind: String = "crawler") -> Dictionary:
	var enemy: Dictionary=sim._spawn_enemy(kind,Vector2(1300,1780),elite)
	sim._damage_enemy(enemy,1000000.0,1,false,0)
	return enemy
func _collect(sim, ticks: int = 250) -> void:
	for index: int in range(ticks): sim._step_coin_pickups(DT)
func _events(sim) -> Array:
	return sim.events.filter(func(event):return event.type=="pickup" and event.get("kind","")=="coin")
func _pending(sim) -> int:
	var total: int=0
	for coin: Dictionary in sim.state.coin_pickups: total+=int(coin.amount)
	return total
func _run() -> void:
	var sim=_fresh()
	var player: Dictionary=sim.state.players[1]
	var enemy: Dictionary=sim._spawn_enemy("crawler",Vector2(1300,1780))
	sim._spawn_projectile(enemy.pos-Vector2(50,0),Vector2(6000,0),"player","bullet",1000000.0,1,1.0,3.0)
	sim.step(DT,{})
	_check(player.coins==35 and sim.state.coin_pickups.size()==1 and sim.state.kills==1,"Actual distant projectile kill drops gold before crediting it")
	_check(_events(sim).is_empty() and sim.events.any(func(e):return e.type=="coin_drop"),"Scatter and arrival are distinct events")
	var original: Vector2=sim.state.coin_pickups[0].pos
	_collect(sim,8)
	_check(player.coins==35 and sim.state.coin_pickups[0].pos!=original and not sim.state.coin_pickups[0].seeking,"Visible scatter precedes attraction")
	_collect(sim)
	_check(player.coins==39 and sim.state.coin_pickups.is_empty(),"Distant gold seeks the stationary player without backtracking")
	var rewards: Array=_events(sim)
	_check(rewards.size()==1 and rewards[0].amount==4 and rewards[0].recipients==[1],"Arrival pays the complete reward once")
	_check(Vector2(rewards[0].pos).distance_to(player.pos)<8 and rewards[0].owner==1 and rewards[0].base_amount==4,"Arrival feedback is at the collector with reward metadata")
	_collect(sim)
	_check(player.coins==39 and _events(sim).size()==1,"Settled gold cannot be recollected")
	sim=_fresh(4)
	sim.state.players[2].items.harvest=2; sim.state.players[3].items.harvest=1000
	sim.state.players[3].dead=true; sim.state.players[4].items.harvest=2
	_kill(sim,true)
	_check(_pending(sim)==12 and sim.state.players[1].coins==35,"Best living harvest bonus locks at death")
	sim.state.players[2].items.harvest=1000; sim.state.players[4].dead=true
	_collect(sim)
	_check(sim.state.players.values().all(func(p):return p.coins==47),"All teammates including downed allies receive the full locked amount")
	_check(_events(sim).back().bonus_player==2 and _events(sim).back().recipients==[1,2,3,4],"Stable bonus tie-break and recipient ordering survive flight")
	_kill(sim,true); _collect(sim)
	_check(sim.state.players[1].coins==65,"Extreme harvest retains double-base cap")
	var dead_enemy: Dictionary=_kill(sim)
	var balance: int=sim.state.players[1].coins
	var pending: int=_pending(sim)
	sim._damage_enemy(dead_enemy,1000000.0,1,false,0); sim._kill_enemy(dead_enemy,sim.state.players[1],1,0)
	_check(_pending(sim)==pending,"Duplicate death cannot create a second flight")
	_collect(sim)
	_check(sim.state.players[1].coins==balance+pending,"Duplicate death yields one eventual payout")
	var boss: Dictionary=_kill(sim,false,"boss")
	var boss_reward: int=(9 if boss.elite else 4)*2+35
	_check(_pending(sim)==boss_reward and sim.state.pickups.filter(func(p):return p.kind=="item").size()>=2,"Boss keeps fixed bonus and manual rewards")
	_collect(sim)
	_check(_events(sim).back().amount==boss_reward and _events(sim).back().fixed_bonus==35,"Boss arrival reports its combined reward")
	sim=_fresh(2); sim.state.players[2].pos=Vector2(1300,1779); _kill(sim)
	_check(sim.state.coin_pickups[0].target==2,"Gold initially seeks the nearest living teammate")
	sim.remove_player(2); _collect(sim)
	_check(sim.state.players[1].coins==39,"Collector disconnect safely retargets gold")
	_kill(sim); sim.state.players[1].dead=true; sim._step_coin_pickups(DT)
	_check(sim.state.players[1].coins==43 and sim.state.coin_pickups.is_empty(),"No living collector settles currency rather than losing it")
	sim=_fresh(); sim._drop_coin_pickup(4,Vector2(7800,100),1); _collect(sim)
	_check(sim.state.players[1].coins==39,"Extremely distant coins have bounded settlement time")
	sim._drop_coin_pickup(9,Vector2(3000,100),1); sim._build_stage(2)
	_check(sim.state.players[1].coins==48 and sim.state.coin_pickups.is_empty(),"Stage transition settles pending gold")
	for index: int in range(Simulation.MAX_PICKUPS): sim._spawn_pickup(Vector2(2000,1600),"item","overclock",1)
	var before: int=sim.state.players[1].coins
	for index: int in range(100): sim._drop_coin_pickup(4,Vector2(2000+index,1600),1)
	_check(sim.state.coin_pickups.size()==Simulation.MAX_COIN_PICKUPS and sim.state.pickups.size()==Simulation.MAX_PICKUPS,"Flights have a separate capped budget without evicting manual loot")
	_check(sim.state.players[1].coins-before+_pending(sim)==400,"Budget overflow preserves all currency")
	_collect(sim)
	_check(sim.state.players[1].coins==before+400,"Overflow plus normal arrivals pay the exact total")
	sim.events.clear()
	for index: int in range(64): sim._emit("notice",Vector2.ZERO,{"message":"fixture"})
	sim._drop_coin_pickup(4,Vector2(800,1779),1); _collect(sim)
	_check(sim.state.players[1].coins==before+404 and sim.events.size()<=64,"Saturated cosmetic events never block the reward")
	var plain=_fresh(); var magnet=_fresh(); magnet.state.players[1].items.magnet=5
	for sample in [plain,magnet]: sample._drop_coin_pickup(4,Vector2(1800,1779),1)
	_collect(plain,40); _collect(magnet,40)
	_check(Vector2(magnet.state.coin_pickups[0].pos).distance_to(magnet.state.players[1].pos)<Vector2(plain.state.coin_pickups[0].pos).distance_to(plain.state.players[1].pos),"Magnet stacks accelerate attraction")
	sim=_fresh(2); sim.state.players[1].items.harvest=1
	sim._spawn_pickup(sim.state.players[1].pos,"coin","",20); sim._step_pickups(DT)
	_check(sim.state.players[1].coins==58 and sim.state.players[2].coins==58,"Authored coins keep collector bonus and shared payout")
	var item: Dictionary=sim._spawn_pickup(sim.state.players[1].pos,"item","feather",1); sim._step_pickups(DT)
	_check(not sim.state.players[1].items.has("feather") and sim.state.pickups.has(item),"Gold never auto-picks nearby relics")
	var first=_fresh(2,1777); var second=_fresh(2,1777)
	for index: int in range(12): _kill(first,index%3==0); _kill(second,index%3==0)
	_check(var_to_bytes(first.state)==var_to_bytes(second.state),"Scatter and targeting are seeded reproducible")
	var replica=Simulation.new(); replica.apply_snapshot(first.get_snapshot())
	var gold_before: PackedByteArray=var_to_bytes(replica.state.coin_pickups)
	for index: int in range(30): replica.predict_player(replica.state.players[1],{"move":1.0},DT)
	_check(gold_before==var_to_bytes(replica.state.coin_pickups) and replica.state.players[1].coins==35 and replica.events.is_empty(),"Prediction cannot move gold or credit it")
	_collect(first); replica.apply_snapshot(first.get_snapshot()); replica.apply_snapshot(first.get_snapshot())
	_check(replica.state.players[1].coins==first.state.players[1].coins and replica.state.coin_pickups.is_empty(),"Repeated snapshots converge without duplicate credit")
	var view:=World.new(); root.add_child(view); view.set_process(false)
	var samples: Array=[{"type":"coin_drop","pos":Vector2(120,120),"amount":9},{"type":"pickup","kind":"coin","amount":9,"pos":Vector2(140,120)}]
	var source: PackedByteArray=var_to_bytes(samples); view.push_events(samples)
	_check(view._effects.any(func(e):return e.kind=="coin_collect") and view._numbers.any(func(n):return n.text=="+9"),"Arrival flashes gold and displays the amount")
	_check(var_to_bytes(samples)==source,"Visual feedback leaves events unchanged")
	for index: int in range(200): view.push_events(samples)
	_check(view._effects.size()<=World.MAX_EFFECTS and view._numbers.size()<=World.MAX_DAMAGE_NUMBERS,"Mass collection retains visual budgets")
	_check(Sound.event_sound(samples[0])=="coin_scatter" and Sound.event_sound(samples[1])=="coin","Drop and arrival have distinct sounds")
	view.queue_free(); await process_frame
	print("COIN_REWARDS_TEST_RESULT passed=%d failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
