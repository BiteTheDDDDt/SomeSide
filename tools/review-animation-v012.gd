extends SceneTree

## Independent content audit. Reads the real baked production frames without
## changing their pixels, renderer state, simulation snapshots or user profile.
const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
var issues: Array[String] = []
var require_expanded: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _measure(image: Image, target: Rect2) -> Dictionary:
	var count: int = 0
	var shoulder: int = 0
	var upper_count: int = 0
	var upper_sum := Vector2.ZERO
	var feet: float = -INF
	var top: float = INF
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x,y).a < 0.25: continue
			var local: Vector2 = target.position + Vector2(x + 0.5,y + 0.5)
			count += 1
			feet = maxf(feet,local.y + 0.5)
			top = minf(top,local.y - 0.5)
			if Rect2(-5,-10,12,12).has_point(local): shoulder += 1
			if Rect2(-12,-25,25,22).has_point(local):
				upper_count += 1
				upper_sum += local
	var center: Vector2 = upper_sum / maxf(1,upper_count)
	return {"visible_pixels":count,"shoulder_patch_pixels":shoulder,"top":top,"feet":feet,
		"upper_centroid":[center.x,center.y],"pixel_hash":hash(image.get_data())}

func _run() -> void:
	require_expanded = "--expanded" in OS.get_cmdline_user_args()
	Pixels.reload_manifest()
	var stats: Dictionary = Pixels.stats()
	if stats.actors != 14: issues.append("Production manifest must resolve all 14 actors")
	for error: String in stats.errors: issues.append(error)
	var report: Dictionary = {"stats":stats,"actors":{},"issues":issues}
	var total: int = 0
	for id: String in Pixels.actor_ids():
		var actor: Dictionary = Pixels._actors[id]
		var frames: Array = []
		var unique: Dictionary = {}
		var target: Rect2 = actor.frames[0].draw_target
		for index: int in range(actor.frames.size()):
			var frame: Dictionary = actor.frames[index]
			if frame.draw_target != target or target.position != target.position.round() or target.size != frame.texture.get_size():
				issues.append("Unstable logical canvas/anchor: %s frame %d" % [id,index])
			var texture: AtlasTexture = frame.texture
			if not texture.atlas is CanvasTexture or texture.atlas.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
				issues.append("Pixel sampler changed: %s frame %d" % [id,index])
			var measured: Dictionary = _measure(texture.get_image(),target)
			measured.index = index
			measured.duration = frame.duration
			frames.append(measured)
			unique[measured.pixel_hash] = true
			if measured.visible_pixels == 0: issues.append("Empty baked frame: %s frame %d" % [id,index])
		var animations: Dictionary = {}
		for animation: String in actor.animations:
			var hashes: Dictionary = {}
			var duration: float = 0.0
			var centroid_min := Vector2(INF,INF)
			var centroid_max := Vector2(-INF,-INF)
			var feet_min: float = INF
			var feet_max: float = -INF
			for index: Variant in actor.animations[animation]:
				var frame: Dictionary = frames[int(index)]
				hashes[frame.pixel_hash] = true
				duration += float(frame.duration)
				var center := Vector2(float(frame.upper_centroid[0]),float(frame.upper_centroid[1]))
				centroid_min = centroid_min.min(center)
				centroid_max = centroid_max.max(center)
				feet_min = minf(feet_min,float(frame.feet))
				feet_max = maxf(feet_max,float(frame.feet))
			var span: Vector2 = centroid_max-centroid_min
			animations[animation] = {"sequence_count":actor.animations[animation].size(),"unique_pixels":hashes.size(),"duration":duration,
				"upper_centroid_span":[span.x,span.y],"foot_span":feet_max-feet_min,"indices":actor.animations[animation]}
		if require_expanded:
			var hero: bool = id in ["ranger","vanguard"]
			var expected: int = (24 if actor.animations.has("backpedal") else 16) if hero else 8
			if frames.size() != expected or unique.size() != expected:
				issues.append("Expanded %s must have %d actually distinct baked poses (found %d frames, %d distinct)" % [id,expected,frames.size(),unique.size()])
			var required_clips: Dictionary = {"idle":4,"run":8,"rise":1,"fall":1,"dash":1,"land":1} if hero else ({"idle":4,"windup":2,"attack":2} if id.begins_with("boss_") else {"move":6,"windup":1,"attack":1})
			if hero and expected == 24:
				required_clips.backpedal = 8
			for clip: String in required_clips:
				if not animations.has(clip) or int(animations[clip].unique_pixels) != int(required_clips[clip]):
					issues.append("Missing expanded unique clip frames: %s/%s needs %d" % [id,clip,required_clips[clip]])
		# Shared shoulder/muzzle must not drift with an authored animation frame.
		if id in ["ranger","vanguard"]:
			var player: Dictionary = {"id":1,"character":id,"pos":Vector2(1600.25,999.5),"aim":Vector2(0.8,-0.6),"weapon":"pulse_rifle","grounded":true,"vel":Vector2(245,0),"items":{}}
			var before: PackedByteArray = var_to_bytes(player)
			var muzzle: Vector2 = Pose.muzzle_position(player)
			for sample: int in range(120):
				Pixels.frame_for(id,player,sample/60.0,true)
				if Pose.muzzle_position(player) != muzzle or var_to_bytes(player) != before:
					issues.append("Animation changed gameplay body/gun state: "+id)
					break
		total += frames.size()
		report.actors[id] = {"frames":frames,"frame_count":frames.size(),"unique_baked_frames":unique.size(),"animations":animations,
			"draw_rect":[target.position.x,target.position.y,target.size.x,target.size.y]}
		print("ANIMATION_AUDIT ",id," frames=",frames.size()," unique=",unique.size()," clips=",JSON.stringify(animations))
	report["total_frames"] = total
	var result_path: String = "res://tools/results/animation-v012-review.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): result_path=argument.trim_prefix("--output=")
	var file := FileAccess.open(result_path,FileAccess.WRITE)
	if file == null: issues.append("Unable to write audit report")
	else: file.store_string(JSON.stringify(report,"\t"))
	print("ANIMATION_REVIEW_RESULT actors=",stats.actors," frames=",total," issues=",JSON.stringify(issues))
	quit(0 if issues.is_empty() else 1)
