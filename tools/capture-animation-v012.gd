extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
const OUT: String = "res://tools/results/animation-v012/"
const GROUPS: Dictionary = {"ranger": ["ranger"], "vanguard": ["vanguard"], "rainforest": ["crawler", "spitter", "spore_moth"], "canyon": ["drone", "charger", "burrower"], "ruins": ["sentinel", "skirmisher", "conductor"], "bosses": ["boss_spore", "boss_stone", "boss_prism"]}

class Gallery:
	extends "res://scripts/world_view.gd"
	var page: String = "ranger"
	var sample: int = -1
	var seen: Dictionary = {}
	var drawn_frames: int = 0

	func _ready() -> void:
		set_process(false) # Only the gallery draws; no world, profile or cache warmup.

	func words(at: Vector2, message: String, size_value: int = 16, tint: Color = Color("9bafab")) -> void:
		draw_string(ThemeDB.fallback_font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, tint)

	func body(id: String, frame: Dictionary, at: Vector2, scale_value: float, weapon: bool) -> void:
		draw_set_transform(at, 0.0, Vector2.ONE * scale_value)
		draw_texture_rect(frame.texture, frame.get("draw_target", frame.target), false, Color.WHITE)
		if weapon:
			var shoulder: Vector2 = at + Vector2(frame.get("shoulder", Pose.shoulder_position(Vector2.ZERO))) * scale_value
			draw_set_transform(shoulder, -0.08, Vector2.ONE * scale_value)
			_draw_weapon("pulse_rifle" if id == "ranger" else "arc_blade")
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(get_viewport_rect().size)), Color("0b1c24"))
		words(Vector2(28, 36), "SomeSide  /  v0.12  /  " + ("TRACKED ANIMATION" if sample >= 0 else page.to_upper()), 24, Color("e6e6d7"))
		words(Vector2(28, 65), "Actual baked game frames. Heroes 3x, enemies and bosses 2x. Weapons follow the authored shoulder pivot.")
		if sample >= 0:
			montage()
			return
		drawn_frames = 0
		var heroes: bool = page in ["ranger", "vanguard"]
		var columns: int = 4 if heroes or page == "bosses" else 8
		var cell := Vector2(386, 218) if heroes else (Vector2(386, 326) if page == "bosses" else Vector2(193, 286))
		for actor_index: int in range(GROUPS[page].size()):
			var id: String = GROUPS[page][actor_index]
			var actor: Dictionary = Pixels._actors[id]
			for frame_index: int in range(actor.frames.size()):
				var slot: int = actor_index * 8 + frame_index
				var corner: Vector2 = Vector2(28, 88) + Vector2(slot % columns, slot / columns) * cell
				draw_rect(Rect2(corner, cell - Vector2(8, 8)), Color("294149"), false)
				var labels: Array[String] = []
				for animation: String in ["idle", "run", "move", "rise", "fall", "dash", "land", "windup", "attack"]:
					for member: Variant in actor.animations.get(animation, []):
						if int(member) == frame_index:
							labels.append(animation)
							break
				words(corner + Vector2(10, 24), "%s  #%02d" % [id, frame_index], 14)
				words(corner + Vector2(10, cell.y - 20), "/".join(labels), 12, Color("e7b76c"))
				body(id, actor.frames[frame_index], corner + cell * Vector2(0.46, 0.53), 3.0 if heroes else 2.0, heroes)
				drawn_frames += 1

	func montage() -> void:
		var time: float = float(sample) / 60.0
		words(Vector2(1260, 36), "%03d / 120    %.3f s" % [sample + 1, time], 17, Color("e7b76c"))
		for index: int in range(2):
			var id: String = "ranger" if index == 0 else "vanguard"
			var state: Dictionary = {"id": index + 1, "pos": Vector2(time * 50, 0), "grounded": true, "vel": Vector2.ZERO, "dash_timer": 0.0}
			if time >= 0.3 and time < 1.0: state.vel = Vector2(245, 0)
			elif time >= 1.0 and time < 1.5:
				state.grounded = false
				state.vel = Vector2(150, -200 if time < 1.25 else 200)
			elif time >= 1.75: state.dash_timer = 0.1
			var frame: Dictionary = Pixels.tracked_frame_for(self, id, state, time, true)
			seen[id + ":" + str(frame.animation)] = true
			var center := Vector2(380 + index * 800, 192)
			body(id, frame, center, 3.0, true)
			words(center + Vector2(-130, 122), "%s  /  %s  /  #%02d" % [id.to_upper(), frame.animation, frame.index], 18)
		var enemies: Array = GROUPS.rainforest + GROUPS.canyon + GROUPS.ruins + GROUPS.bosses
		for index: int in range(enemies.size()):
			var id: String = enemies[index]
			var state: Dictionary = {"id": index + 20, "pos": Vector2.ZERO, "vel": Vector2(110, 0), "flying": id in ["drone", "spore_moth", "conductor"], "telegraph": maxf(0.0, 1.6 - time) if time >= 1.0 and time < 1.6 else 0.0, "telegraph_max": 0.6, "attack_kind": "", "attack_cd": 0.0, "attack_cooldown": 3.0}
			if time >= 1.6 and time < 1.78:
				state.attack_kind = "gallery"
				state.attack_cd = 3.0 - (time - 1.6)
			var frame: Dictionary = Pixels.tracked_frame_for(self, id, state, time)
			seen[id + ":" + str(frame.animation)] = true
			var center: Vector2 = Vector2(95 + index * 175, 437) if index < 9 else Vector2(265 + (index - 9) * 532, 747)
			body(id, frame, center, 2.0, false)
			words(center + Vector2(-72, 116 if index < 9 else 170), "%s  #%02d" % [id, frame.index], 14)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native rendering is required for this capture tool.")
		quit(1)
		return
	var stats: Dictionary = Pixels.stats()
	var expected: int = 0
	for group: Array in GROUPS.values():
		for id: String in group:
			if not Pixels._actors.has(id): quit(1); return
			expected += Pixels._actors[id].frames.size()
	if expected != 128 or int(stats.textures) != 6 or not stats.errors.is_empty():
		push_error("The v0.12 production manifest must contain 128 frames and 6 valid sheets: " + str(stats))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i.ZERO
	var capture_view := SubViewport.new()
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_view)
	var gallery := Gallery.new()
	capture_view.add_child(gallery)
	var contact_frames: int = 0
	for page: String in GROUPS:
		capture_view.size = Vector2i(1600, 2060 if page == "bosses" else 1000)
		gallery.page = page
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(capture_view.get_texture().get_image().save_png(OUT + "contact-" + page + ".png") == OK)
		contact_frames += gallery.drawn_frames
	capture_view.size = Vector2i(1600, 960)
	Pixels.reset_tracks(gallery)
	for index: int in range(120):
		gallery.sample = index
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(capture_view.get_texture().get_image().save_png(OUT + "frame-%03d.png" % index) == OK)
	print("ANIMATION_CAPTURE_RESULT ", JSON.stringify({"contacts": 6, "contact_frames": contact_frames, "montage_frames": 120, "step": 1.0 / 60.0, "actors": stats, "states_seen": gallery.seen.keys(), "profile_used": false}))
	gallery.queue_free()
	await process_frame
	quit(0 if contact_frames == 128 else 1)
