extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_actual_kill()
	_test_cooperation()
	_test_idempotence_and_boss()
	_test_budget_and_secondary_kills()
	_test_legacy_and_manual_loot()
	_test_snapshot_prediction_and_seed()
	print("COIN_REWARDS_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)

func _check(value: bool, message: String) -> void:
	if value:
		passed+=1
		print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)

func _fresh(count: int = 1, seed_value: int = 1401):
	var roster: Array=[]
	for id: int in range(1,count+1): roster.append({"id":id,"name":"Coin"+str(id),"character":"ranger"})
	var simulation=Simulation.new()
	simulation.start_run(roster,seed_value)
	simulation._spawn_clock=9999.0
	for id: int in range(1,count+1):
		var player: Dictionary=simulation.state.players[id]
		player.pos=Vector2(400+(id-1)*1800,simulation.state.floor_y-21.0)
		player.invuln=9999.0
	return simulation

func _kill(simulation, elite: bool = false, owner: int = 1, kind: String = "crawler") -> Dictionary:
	var enemy: Dictionary=simulation._spawn_enemy(kind,Vector2(1300,simulation.state.floor_y-20.0),elite)
	simulation._damage_enemy(enemy,1000000.0,owner,false,0)
	return enemy

func _coin_events(simulation) -> Array:
	return simulation.events.filter(func(event): return event.get("type")=="pickup" and event.get("kind")=="coin")

func _ground_coins(simulation) -> Array:
	return simulation.state.pickups.filter(func(pickup): return pickup.kind=="coin")

func _test_actual_kill() -> void:
	var simulation=_fresh()
	var player: Dictionary=simulation.state.players[1]
	var before: int=player.coins
	var enemy: Dictionary=simulation._spawn_enemy("crawler",Vector2(1200,player.pos.y))
	# The real simulation step moves this projectile and performs swept damage;
	# the player is far outside every possible coin attraction radius.
	simulation._spawn_projectile(enemy.pos-Vector2(50,0),Vector2(6000,0),"player","bullet",1000000.0,1,1.0,3.0)
	simulation.step(DT,{})
	_check(player.coins==before+4 and simulation.state.kills==1,"An actual distant projectile kill credits ordinary gold during the same authority step")
	_check(_ground_coins(simulation).is_empty(),"Enemy gold leaves no physical coin to chase or expire")
	var rewards: Array=_coin_events(simulation)
	_check(rewards.size()==1 and rewards[0].automatic and rewards[0].amount==4 and rewards[0].recipients==[1],"One cosmetic event describes the already-committed shared payout")
	_check(rewards[0].source=="enemy_kill" and rewards[0].owner==1 and rewards[0].base_amount==4 and rewards[0].fixed_bonus==0 and rewards[0].item=="","Payout metadata separates kill ownership, base reward and manual item feedback")
	var balance: int=player.coins
	for index: int in range(120): simulation.step(DT,{})
	_check(player.coins==balance,"Waiting after the kill cannot collect the same gold a second time")

func _test_cooperation() -> void:
	var simulation=_fresh(4)
	simulation.state.players[2].items.harvest=2
	simulation.state.players[3].items.harvest=1000
	simulation.state.players[3].dead=true
	simulation.state.players[4].items.harvest=2
	_kill(simulation,true,1)
	var equal: bool=true
	for player: Dictionary in simulation.state.players.values(): equal=equal and player.coins==47
	_check(equal,"Each distant or downed teammate gets the full12 gold elite reward, not a divided share")
	var reward: Dictionary=_coin_events(simulation).back()
	_check(reward.bonus_player==2 and reward.owner==1 and reward.recipients==[1,2,3,4],"Best living harvest bonus is shared without last-hit competition; equal bonuses use a stable ID tie break")
	simulation.state.players[2].items.harvest=1000
	_kill(simulation,true,4)
	_check(simulation.state.players[1].coins==65,"Extreme harvest stacks retain the existing doubled-gold cap")
	simulation.remove_player(2)
	_kill(simulation,false,999)
	_check(simulation.state.players[1].coins==70 and _coin_events(simulation).back().bonus_player==4,"Disconnected owners cannot block rewards and are excluded from bonus selection")
	for player: Dictionary in simulation.state.players.values(): player.dead=true
	_kill(simulation,false,999)
	_check(simulation.state.players[1].coins==74 and _coin_events(simulation).back().bonus_player==-1,"A final lingering kill pays base gold safely even when no collector is alive")

func _test_idempotence_and_boss() -> void:
	var simulation=_fresh(2)
	simulation.state.players[2].items.harvest=100
	var enemy: Dictionary=_kill(simulation)
	var balance: int=simulation.state.players[1].coins
	var event_count: int=_coin_events(simulation).size()
	simulation._damage_enemy(enemy,1000000.0,1,false,0)
	simulation._kill_enemy(enemy,simulation.state.players[1],1,0)
	_check(simulation.state.players[1].coins==balance and _coin_events(simulation).size()==event_count,"Repeated damage and death callbacks cannot duplicate a payout")
	var boss: Dictionary=_kill(simulation,false,1,"boss")
	var reward: Dictionary=_coin_events(simulation).back()
	var base: int=9 if boss.elite else 4
	_check(simulation.state.players[1].coins==balance+base*2+35 and simulation.state.players[2].coins==simulation.state.players[1].coins,"Boss preserves its ordinary gold plus fixed35 per teammate, without multiplying the fixed bonus")
	_check(reward.amount==base*2+35 and reward.fixed_bonus==35,"Boss feedback reports a single combined reward")
	var items: Array=simulation.state.pickups.filter(func(pickup): return pickup.kind=="item")
	_check(items.size()>=2 and _ground_coins(simulation).is_empty(),"Boss still drops manual equipment/relic rewards while gold is automatic")

func _test_budget_and_secondary_kills() -> void:
	var simulation=_fresh()
	for index: int in range(Simulation.MAX_PICKUPS): simulation._spawn_pickup(Vector2(2000,600),"item","overclock",1)
	var before: int=simulation.state.players[1].coins
	_kill(simulation)
	_check(simulation.state.players[1].coins==before+4 and simulation.state.pickups.size()==Simulation.MAX_PICKUPS,"A full manual-loot budget cannot delete or delay automatic gold")
	simulation.events.clear()
	for index: int in range(64): simulation._emit("notice",Vector2.ZERO,{"player":1,"message":"fixture"})
	_kill(simulation)
	_check(simulation.state.players[1].coins==before+8 and simulation.events.size()<=64,"Payout succeeds independently of a saturated cosmetic event budget")
	var chain=_fresh()
	chain.state.players[1].items.ember=1
	for index: int in range(3):
		var target: Dictionary=chain._spawn_enemy("crawler",Vector2(1000+index*24,500))
		target.hp=1.0
	chain._damage_enemy(chain.state.enemies[0],1000000.0,1,false,0)
	_check(chain.state.kills==3 and chain.state.players[1].coins==47 and _coin_events(chain).size()==3,"Bounded secondary kills each credit gold exactly once")

func _test_legacy_and_manual_loot() -> void:
	var simulation=_fresh(2)
	var player: Dictionary=simulation.state.players[1]
	player.items.harvest=1
	simulation.state.players[2].items.harvest=100
	simulation._spawn_pickup(player.pos,"coin","",20)
	simulation._step_pickups(DT)
	_check(player.coins==58 and simulation.state.players[2].coins==58 and _coin_events(simulation).size()==1,"Explicit legacy/environment coin pickups preserve collector bonus and one shared payout event")
	var item: Dictionary=simulation._spawn_pickup(player.pos,"item","feather",1)
	simulation._step_pickups(DT)
	_check(not player.items.has("feather") and simulation.state.pickups.has(item),"Automatic gold never auto-collects a nearby relic")
	player.pos=item.pos
	simulation._interact(player,{"kind":"pickup","id":item.id})
	_check(player.items.get("feather",0)==1,"The existing exact E interaction still grants the manual relic")

func _test_snapshot_prediction_and_seed() -> void:
	var server=_fresh(2)
	_kill(server,true)
	var snapshot: Dictionary=server.get_snapshot()
	var replica=Simulation.new()
	replica.apply_snapshot(snapshot)
	var before: int=replica.state.players[1].coins
	for index: int in range(30): replica.predict_player(replica.state.players[1],{"move":1.0,"fire":true,"interact":true},DT)
	_check(replica.state.players[1].coins==before and replica.events.is_empty(),"Client movement replay cannot predict or duplicate authority-side gold")
	replica.apply_snapshot(snapshot)
	replica.apply_snapshot(snapshot)
	_check(replica.state.players[1].coins==server.state.players[1].coins and replica.state.players[2].coins==server.state.players[2].coins,"Repeated snapshots converge to authority balances without adding rewards")
	_check(bytes_to_var(var_to_bytes(_coin_events(server)))==_coin_events(server),"Currency feedback contains only serializable values for multiplayer events")
	var first=_fresh(2,1477)
	var second=_fresh(2,1477)
	for index: int in range(12):
		_kill(first,index%3==0)
		_kill(second,index%3==0)
	_check(var_to_bytes(first.state)==var_to_bytes(second.state) and var_to_bytes(first.events)==var_to_bytes(second.events),"Automatic rewards retain seeded deterministic simulation and event ordering")
