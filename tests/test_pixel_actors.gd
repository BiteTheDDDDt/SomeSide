extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Entities = preload("res://scripts/entity_renderer.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
var passed: int = 0
var failed: int = 0

class Probe extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 320, 180), Color.BLACK)
		draw_set_transform(Vector2(100, 100), 0.0, Vector2.ONE * 12.0)
		Entities.player_body(self, {"character": "ranger", "grounded": true, "vel": Vector2.ZERO}, 0.0)
		draw_set_transform(Vector2(240, 100), 0.0, Vector2(-12, 12))
		Pixels.draw_enemy(self, {"kind": "drone", "id": 0, "vel": Vector2.ZERO}, 0.0)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fixture() -> Dictionary:
	return {"texture": "fixture", "scale": 1.0, "frames": [
		{"rect": [0, 0, 3, 3], "anchor": [1, 2], "duration": 0.1},
		{"rect": [4, 0, 2, 4], "anchor": [1, 3], "duration": 0.2}],
		"animations": {"idle": [0], "run": [0, 1], "move": [0, 1], "jump": [1], "windup": [1], "attack": [1]}}

func _run() -> void:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(0, 0, 1, 3), Color.RED)
	image.fill_rect(Rect2i(1, 0, 1, 3), Color.GREEN)
	image.fill_rect(Rect2i(4, 0, 2, 4), Color.BLUE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var manifest: Dictionary = {"version": 1, "actors": {"ranger": _fixture(), "drone": _fixture(), "boss_stone": _fixture()}}
	var before_manifest: PackedByteArray = var_to_bytes(manifest)
	Pixels.install_manifest(manifest, {"fixture": texture})
	_check(Pixels.actor_ids().size() == 3 and Pixels.available("ranger"), "Explicit manifest records activate player, enemy and boss sprites")
	_check(Pixels.stats().textures == 1 and Pixels.stats().bytes == 8 * 8 * 4, "Actors sharing a sheet allocate one texture within the bounded cache")
	_check(var_to_bytes(manifest) == before_manifest, "Building atlas frames leaves the supplied manifest unchanged")
	var player: Dictionary = {"character": "ranger", "grounded": true, "vel": Vector2(100, 0), "items": {"feather": 2}}
	var before_player: PackedByteArray = var_to_bytes(player)
	var first: Dictionary = Pixels.frame_for("ranger", player, 0.05, true)
	var second: Dictionary = Pixels.frame_for("ranger", player, 0.15, true)
	_check(first.index == 0 and second.index == 1 and Pixels.frame_for("ranger", player, 0.35, true).index == 0, "Animation honors each independently timed frame and loops deterministically")
	_check(first.source == Rect2(0, 0, 3, 3) and second.source == Rect2(4, 0, 2, 4), "Crops use explicit nonuniform rectangles rather than assuming equal cells")
	_check(first.target == Rect2(-1, -2, 3, 3) and second.target == Rect2(-1, -3, 2, 4), "Per-frame center anchors keep different-size crops aligned")
	_check(first.texture is AtlasTexture and first.texture.atlas is CanvasTexture and first.texture.atlas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Nearest filtering belongs to the pixel texture, independently of the world canvas")
	_check(Pixels.bounds("ranger").encloses(first.target) and Pixels.bounds("ranger").encloses(second.target), "Actor bounds include the union of every animation crop")
	_check(var_to_bytes(player) == before_player, "Frame selection does not modify player state or relic inventory")
	player.grounded = false
	player.vel = Vector2(0, -50)
	_check(Pixels.animation_for(player, true) == "rise" and Pixels.frame_for("ranger", player, 0.0, true).index == 1, "An ascending player chooses the authored jump frame")
	player.vel = Vector2(0, 50)
	_check(Pixels.animation_for(player, true) == "fall", "A descending player has a separate animation selector")
	player.dash_timer = 0.1
	_check(Pixels.animation_for(player, true) == "dash", "Dash animation is presentation-only and wins over the ordinary airborne selector")
	var enemy: Dictionary = {"kind": "drone", "telegraph": 0.6, "vel": Vector2.ZERO}
	_check(Pixels.frame_for("drone", enemy, 0.0).index == 1, "A telegraph selects its windup pose without changing the attack timer")
	enemy.telegraph = 0.0
	enemy.attack_kind = "pounce"
	enemy.attack_cd = 2.8
	enemy.attack_cooldown = 2.8
	_check(Pixels.animation_for(enemy) == "attack", "The actual attack cooldown exposes a short release pose after windup")
	enemy.flash = 0.1
	_check(Color(Pixels.frame_for("drone", enemy, 0.0).tint).r > 1.0, "Hit flash brightens the sprite without adding state or allocating variants")
	_check(Pixels.enemy_id({"kind": "boss", "boss_style": "stone"}) == "boss_stone" and Pixels.enemy_id({"kind": "boss", "biome": "ruins"}) == "boss_prism", "Boss styles and biome fallback resolve to their distinct authored actors")
	_check(Pixels.frame_for("unavailable", {}, 0.0).is_empty() and Pixels.bounds("drone").size != Vector2.ZERO, "Unknown pixel art uses fallback while loaded definitions expose their crop bounds")
	var probe := Probe.new()
	probe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(320, 180)
	root.add_child(probe)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var rendered: Image = root.get_texture().get_image()
		rendered.save_png("res://tools/results/pixel-nearest-fixture-v010.png")
		_check(rendered.get_pixel(94, 88).r > 0.95 and rendered.get_pixel(106, 88).g > 0.95 and rendered.get_pixel(118, 88).r < 0.02, "The real Entities player entrypoint renders the cropped red/green body and transparent margin")
		_check(rendered.get_pixel(246, 88).r > 0.95 and rendered.get_pixel(234, 88).g > 0.95, "The legacy pixel renderer preserves the caller's left-facing mirror")
		var crisp: bool = true
		for x in range(90, 110):
			var pixel: Color = rendered.get_pixel(x, 88)
			crisp = crisp and (pixel.r > 0.98 or pixel.g > 0.98) and not (pixel.r > 0.02 and pixel.g > 0.02)
		_check(crisp and probe.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Pixel edges remain nearest-sampled even when the surrounding world uses linear filtering")
	probe.queue_free()
	await process_frame
	var invalid: Dictionary = _fixture()
	invalid.frames[1].rect = [7, 0, 8, 4]
	Pixels.install_manifest({"version": 1, "actors": {"bad": invalid, "missing": {"texture": "missing", "frames": []}}}, {"fixture": texture})
	_check(not Pixels.available("bad") and not Pixels.available("missing") and Pixels.stats().errors.size() == 2, "Out-of-bounds crops and missing textures fail safely without half-installed actors")
	Pixels.reload_manifest()
	var actual_stats: Dictionary = Pixels.stats()
	_check(actual_stats.errors.is_empty(), "The installed production manifest has no invalid actors or textures")
	_check(actual_stats.actors == 14 and actual_stats.textures == 8, "Production art requires all fourteen actors and eight actual source sheets, including both dedicated locomotion sheets")
	if int(actual_stats.actors) > 0:
		var sim = Simulation.new()
		sim.start_run([{"id": 1, "name": "Pixels", "character": "ranger"}], 1010)
		var world = WorldView.new()
		root.add_child(world)
		world.set_process(false)
		_check(not world.has_meta(Entities.CACHE_META), "Complete production pixel art avoids allocating the unused enemy vector atlas")
		var snapshot: Dictionary = sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		world.set_frame(snapshot, 1, 1.0 / 60.0)
		await process_frame
		_check(var_to_bytes(snapshot) == before, "The actual world renders production pixel actors without mutating a network snapshot")
		world.queue_free()
		await process_frame
	print("PIXEL_ACTOR_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
