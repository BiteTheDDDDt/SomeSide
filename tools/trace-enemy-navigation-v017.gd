extends SceneTree

const Simulation=preload("res://scripts/simulation.gd")
const DT: float=1.0/60.0

# The previous navigation branch, isolated from unrelated current gameplay.
# This retains the real collision, gravity and pursuit paths for an A/B trace.
class PreviousNavigation extends "res://scripts/simulation.gd":
	func _enemy_platform_navigation(enemy: Dictionary, target: Dictionary, _support: Rect2, _dt: float) -> Dictionary:
		if Vector2(target.pos).y-Vector2(enemy.pos).y < -48.0:
			return {"jump_speed":690.0 if enemy.kind=="boss" else 650.0}
		return {}
	func _move_enemy(enemy: Dictionary, target: Dictionary, dt: float, target_support: Rect2=Rect2()) -> void:
		var jumps: int=int(enemy.get("nav_jumps",0))
		super._move_enemy(enemy,target,dt,target_support)
		if int(enemy.nav_jumps)>jumps: enemy.jump_cd=1.7

func _initialize() -> void:
	var report: Dictionary={"physics_hz":60,"seed":1707,"scenarios":[]}
	for scenario: String in ["short_jump","stable_upper_platform"]:
		for previous: bool in [true,false]:
			var sim=PreviousNavigation.new() if previous else Simulation.new()
			sim.start_run([{"id":1,"name":"Navigation trace","character":"ranger"}],1707)
			sim.state.world_size=Vector2(2400,1100)
			sim.state.floor_y=1000.0
			sim.state.platforms=[Rect2(0,1000,2400,100)]
			sim.state.enemies=[]
			sim.state.chests=[]
			sim._spawn_clock=9999.0
			var player: Dictionary=sim.state.players[1]
			player.pos=Vector2(1050,979)
			player.grounded=true
			player.vel=Vector2.ZERO
			player.invuln=9999.0
			if scenario=="stable_upper_platform":
				sim.state.platforms.append(Rect2(700,910,650,28))
				player.pos.y=889.0
			for index: int in range(12):
				var enemy: Dictionary=sim._spawn_enemy("crawler",Vector2(790+index*9,983))
				enemy.grounded=true
				enemy.attack_cd=9999.0
				enemy.jump_cd=0.0
			var frames: Array=[]
			var first_jumps: Dictionary={}
			var jump_batches: Dictionary={}
			for tick: int in range(360):
				sim.step(DT,{1:{"jump":scenario=="short_jump" and tick==30,"jump_held":tick<46}})
				var positions: Array=[]
				for enemy: Dictionary in sim.state.enemies:
					positions.append([enemy.pos.x,enemy.pos.y,enemy.vel.y,enemy.nav_jumps])
					if enemy.nav_jumps>0 and not first_jumps.has(enemy.id):
						first_jumps[enemy.id]=tick
						jump_batches[tick]=int(jump_batches.get(tick,0))+1
				frames.append({"tick":tick,"player_y":player.pos.y,"enemies":positions})
			var peak_batch: int=0
			for count: int in jump_batches.values(): peak_batch=maxi(peak_batch,count)
			var settled: int=0
			for enemy: Dictionary in sim.state.enemies:
				if enemy.grounded and absf(enemy.pos.y-(893.0 if scenario=="stable_upper_platform" else 983.0))<0.1: settled+=1
			var summary: Dictionary={"scenario":scenario,"version":"before" if previous else "after","enemies_jumped":first_jumps.size(),"peak_first_jumps_same_tick":peak_batch,"first_jump_ticks":first_jumps.values(),"settled_on_expected_floor":settled}
			report.scenarios.append({"summary":summary,"frames":frames})
			print("ENEMY_NAVIGATION_TRACE ",JSON.stringify(summary))
	var path: String="res://tools/results/enemy-navigation-v017.json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("ENEMY_NAVIGATION_TRACE_FILE ",ProjectSettings.globalize_path(path))
	quit()
