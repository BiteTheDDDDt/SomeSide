extends SceneTree

const Art = preload("res://scripts/weapon_art.gd")
const Simulation = preload("res://scripts/simulation.gd")
const DIRECTORY: String = "res://tools/results/weapon-art-v018/"

class Catalogue extends Node2D:
	const WeaponArt = preload("res://scripts/weapon_art.gd")
	var icons: Array[Texture2D] = []
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for id: String in WeaponArt.IDS:
			var bitmap := Image.new()
			assert(bitmap.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">'+WeaponArt.icon_drawing(id)+'</svg>') == OK)
			icons.append(ImageTexture.create_from_image(bitmap))
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,1230),Color("0b1921"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font,Vector2(24,30),"SomeSide | shared weapon materials",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("dce4d3"))
		for heading: Array in [[24,"WEAPON"],[207,"1x"],[340,"4x / REST"],[628,"ICON"],[735,"4x / MECHANISM"],[1030,"AIM"],[1225,"LIVE CHARACTER POSES / 2x"]]:
			draw_string(font,Vector2(heading[0],65),heading[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("96aca8"))
		for index: int in range(WeaponArt.IDS.size()):
			var id: String = WeaponArt.IDS[index]
			var y: float = 140+index*140
			draw_rect(Rect2(16,y-59,1568,134),Color("102630") if index%2==0 else Color("10212a"))
			draw_string(font,Vector2(24,y+4),id,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d2ded0"))
			draw_set_transform(Vector2(211,y))
			WeaponArt.draw(self,id)
			draw_set_transform(Vector2(331,y),0,Vector2(4,4))
			WeaponArt.draw(self,id)
			draw_set_transform(Vector2.ZERO)
			draw_texture(icons[index],Vector2(626,y-32))
			draw_set_transform(Vector2(748,y),0,Vector2(4,4))
			WeaponArt.draw(self,id,1.0,1.0)
			draw_set_transform(Vector2(1115,y-19),2.75,Vector2(2,-2))
			WeaponArt.draw(self,id)
			draw_set_transform(Vector2(1054,y+34),-.8,Vector2(2,2))
			WeaponArt.draw(self,id)
			draw_set_transform(Vector2.ZERO)

class Actors extends "res://scripts/world_view.gd":
	func _ready() -> void:
		set_process(false)
		_font = ThemeDB.fallback_font
	func _draw() -> void:
		_draw_players()

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,1230)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Catalogue.new())
	for index: int in range(8):
		var sim = Simulation.new()
		sim.start_run([{"id":1,"name":"","character":"ranger"},{"id":2,"name":"","character":"vanguard"}],18018)
		sim.state.enemies.clear()
		sim.state.platforms = [Rect2(0,600,5000,60)]
		for key: int in [1,2]:
			var player: Dictionary = sim.state.players[key]
			player.pos = Vector2(2024 if key==1 else 2140,579)
			player.vel = Vector2.ZERO
			player.weapon = Art.IDS[index]
			player.grounded = true
			player.invuln = 0.0
			player.aim = Vector2(1,-.08) if key==1 else Vector2(-1,-.18)
		var actors := Actors.new()
		actors.screen_size = Vector2(184,68)
		actors.scale = Vector2(2,2)
		actors.scenery_cache_enabled = false
		# A weapon raised above the head must never appear in the previous row.
		var cell := Control.new()
		cell.position = Vector2(1210,78+index*140)
		cell.size = Vector2(368,134)
		cell.clip_contents = true
		viewport.add_child(cell)
		cell.add_child(actors)
		for tick: int in range(10 if Art.IDS[index] == "arc_blade" else 7):
			sim.events.clear()
			for key: int in [1,2]:
				var player: Dictionary = sim.state.players[key]
				sim._step_player(player,{"fire":key==2 and tick==0,"aim":player.aim,"move":0},1.0/60.0)
			actors._process(1.0/60.0)
			actors._frame = sim.get_snapshot()
			actors._local_id = 99
			actors.push_events(sim.events)
			actors.camera_position = Vector2(2080,571)
		actors.queue_redraw()
	for tick: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(DIRECTORY+"contact.png") == OK)
	print("WEAPON_ART_CAPTURE_RESULT native=true weapons=8 cache=",Art.cache_stats())
	quit(0)
