extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Entities = preload("res://scripts/entity_renderer.gd")

class Gallery:
	extends "res://scripts/world_view.gd"
	var page: String = "heroes"
	var body_clock: float = 0.0

	func _draw() -> void:
		var face: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1280, 900), Color("0c1922"))
		draw_string(face, Vector2(32, 39), "SOMESIDE  /  AUTHORED PIXEL ACTORS  /  " + page.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d8dfcb"))
		draw_string(face, Vector2(32, 65), "Actual entity entrypoints. Transparent source crops; nearest texture sampler; independent weapons.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7fa19f"))
		if page == "heroes":
			for row: int in range(2):
				for frame: int in range(6):
					var center: Vector2 = Vector2(94 + frame * 202, 264 + row * 327)
					var player: Dictionary = {"character": "ranger" if row == 0 else "vanguard", "grounded": frame != 5, "vel": Vector2.ZERO if frame == 0 else Vector2(140, -100 if frame == 5 else 0), "items": {}}
					var clock: float = 0.01 if frame <= 1 else (frame - 1) * 0.11 + 0.01
					draw_string(face, center + Vector2(-48, -113), ["IDLE", "RUN 1", "RUN 2", "RUN 3", "RUN 4", "JUMP"][frame], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("88b8b2"))
					draw_line(center + Vector2(-67, 43), center + Vector2(97, 43), Color("24404c"), 1)
					draw_set_transform(center, 0, Vector2.ONE * 2.0)
					Entities.player_body(self, player, clock)
					draw_set_transform(center + Vector2(0, -10), 0, Vector2.ONE * 2.0)
					_draw_weapon("pulse_rifle" if row == 0 else "arc_blade")
					draw_set_transform(Vector2.ZERO)
				draw_string(face, Vector2(34, 365 + row * 327), "RANGER  /  0.125 source scale" if row == 0 else "VANGUARD  /  0.125 source scale", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c7bc97"))
		else:
			var kinds: Array = ["crawler", "spitter", "spore_moth"] if page == "rainforest" else (["drone", "charger", "burrower"] if page == "canyon" else (["sentinel", "skirmisher", "conductor"] if page == "ruins" else ["boss_spore", "boss_stone", "boss_prism"]))
			for row: int in range(3):
				var id: String = kinds[row]
				draw_string(face, Vector2(30, 99 + row * 262), id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c7bc97"))
				for frame: int in range(4):
					var center: Vector2 = Vector2(154 + frame * 310, 235 + row * 262)
					var enemy: Dictionary = {"kind": "boss" if id.begins_with("boss_") else id, "boss_style": id.trim_prefix("boss_"), "id": 0, "vel": Vector2.RIGHT * 70, "telegraph": 0.5 if frame == 2 else 0.0, "attack_kind": "probe" if frame == 3 else "", "attack_cd": 3.0 if frame == 3 else 0.0, "attack_cooldown": 3.0, "elite": false}
					var clock: float = 0.01 if frame == 0 else 0.25
					if id in ["spore_moth", "drone"] and frame == 1: clock = 0.12
					if not id.begins_with("boss_") and id not in ["spore_moth", "drone"] and frame == 1: clock = 0.17
					draw_set_transform(center, 0, Vector2.ONE * (1.5 if id.begins_with("boss_") else 2.5))
					Entities.enemy(self, enemy, clock)
					draw_set_transform(Vector2.ZERO)
					draw_string(face, center + Vector2(-54, 89), ["MOVE A", "MOVE B", "WINDUP", "ATTACK"][frame], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("88b8b2"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 900)
	var canvas := Gallery.new()
	root.add_child(canvas)
	canvas.set_process(false)
	for page: String in ["heroes", "rainforest", "canyon", "ruins", "bosses"]:
		canvas.page = page
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/results/pixel-actors-v010-" + page + ".png")
	print("PIXEL_ACTOR_GALLERY ", JSON.stringify(Pixels.stats()))
	canvas.queue_free()
	await process_frame
	quit(0)
