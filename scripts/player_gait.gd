class_name SidePlayerGait
extends RefCounted

## Presentation-only two-link legs. A stride is world travel, not a sprite clock.
## Only these two chains draw below the waist during locomotion.
const META: StringName = &"someside_player_gait"
const MAX_TRACKS: int = 64
const SOLE_Y: float = 21.0
const CUT_Y: float = 1.0
const THIGH: float = 12.5
const SHIN: float = 12.5
const CONTACT_TRAVEL: float = 28.0
const SETTLE_TIME: float = 0.12
const INK: Color = Color("101d25")

static func reset(canvas: CanvasItem) -> void:
	if canvas.has_meta(META): canvas.remove_meta(META)

static func profile(speed: float, backwards: bool) -> Dictionary:
	var pace: float = clampf((speed - 45.0) / 200.0,0.0,1.0)
	var stride: float = lerpf(54.0,108.0 if backwards else 120.0,pace)
	stride = maxf(stride,speed/2.6)
	return {"stride":stride,"contact":CONTACT_TRAVEL/stride,"lift":lerpf(4.0,7.0 if backwards else 11.0,pace),"backwards":backwards}

static func _foot(phase: float, description: Dictionary, direction: float) -> Dictionary:
	var contact: float = float(description.contact)
	var reach: float = CONTACT_TRAVEL * 0.5
	if phase < contact:
		return {"offset":Vector2(direction*(reach-float(description.stride)*phase),SOLE_Y-3.0),"planted":true,"angle":0.0}
	var t: float = clampf((phase-contact)/(1.0-contact),0.0,1.0)
	# Begin/end the swing traveling backward relative to the body. Bounding the
	# tangent keeps very high movement bonuses within a human leg's reach.
	var tangent: float = -minf(72.0,float(description.stride)*(1.0-contact))
	var x: float = (2*t*t*t-3*t*t+1)*(-reach) + (t*t*t-2*t*t+t)*tangent + (-2*t*t*t+3*t*t)*reach + (t*t*t-t*t)*tangent
	var lift: float = sin(PI*t)*float(description.lift)
	return {"offset":Vector2(direction*x,SOLE_Y-3.0-lift),"planted":false,"angle":-0.3*sin(TAU*t)}

static func knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var delta: Vector2 = ankle-hip
	var distance: float = clampf(delta.length(),0.01,THIGH+SHIN-0.01)
	var along: Vector2 = delta.normalized()
	var projected: float = (THIGH*THIGH-SHIN*SHIN+distance*distance)/(2.0*distance)
	var height: float = sqrt(maxf(0.0,THIGH*THIGH-projected*projected))
	# Knees always fold toward the facing side, including a backward step.
	var perpendicular := Vector2(along.y,-along.x)
	if perpendicular.x < 0.0: perpendicular = -perpendicular
	return hip+along*projected+perpendicular*height

static func sample(canvas: CanvasItem, state: Dictionary, clock: float, animation: String) -> Dictionary:
	var position_value: Vector2 = state.get("pos",Vector2.ZERO)
	var velocity: Vector2 = state.get("vel",Vector2.ZERO)
	var aim: Vector2 = state.get("aim",Vector2.RIGHT)
	var facing: float = 1.0 if aim.x >= 0.0 else -1.0
	var active_state: bool = bool(state.get("grounded",false)) and not bool(state.get("dead",false)) and float(state.get("dash_timer",0.0)) <= 0.0
	var running: bool = active_state and animation in ["run","backpedal"] and absf(velocity.x)>15.0
	var key: String = str(state.get("id",0))+":"+str(state.get("character","ranger"))
	var cache: Dictionary = canvas.get_meta(META,{})
	var track: Dictionary = cache.get(key,{})
	var dt: float = clock-float(track.get("clock",clock))
	var restarted: bool = track.is_empty() or dt < 0.0 or dt > 0.5 or position_value.distance_squared_to(track.get("pos",position_value)) > 180.0*180.0
	if not active_state or animation not in ["run","backpedal","idle"]:
		cache.erase(key)
		canvas.set_meta(META,cache)
		return {"active":false}
	if not running and (restarted or float(track.get("settle",0.0)) >= SETTLE_TIME):
		cache.erase(key)
		canvas.set_meta(META,cache)
		return {"active":false}
	if not restarted and is_zero_approx(dt) and track.has("pose"):
		return _local_pose(track.pose,position_value,facing)
	var direction: float = signf(velocity.x) if absf(velocity.x)>15.0 else float(track.get("direction",facing))
	var backwards: bool = direction*facing < 0.0
	var description: Dictionary = profile(absf(velocity.x),backwards)
	var travel: float = 0.0 if restarted else absf(position_value.x-Vector2(track.pos).x)
	var phase: float = 0.0 if restarted else float(track.phase)
	var turn: float = maxf(0.0,float(track.get("turn",0.0))-maxf(0.0,dt))
	var travel_consumed: bool = false
	if running and not restarted and direction != float(track.direction):
		# Put the already-leading foot in charge of the new stance. Continuing
		# the old support half-cycle after a reversal can stretch a leg past its
		# reach, even though the foot itself remains correctly pinned.
		var leading: int = 0 if (Vector2(track.legs[0].world).x-Vector2(track.legs[1].world).x)*direction >= 0.0 else 1
		var offset: float = (Vector2(track.legs[leading].world).x-position_value.x)*direction
		var contact_phase: float = clampf((CONTACT_TRAVEL*.5-offset)/float(description.stride),0.0,float(description.contact))
		phase = fposmod(contact_phase-leading*.5,1.0)
		track.legs[leading].planted = true
		track.legs[1-leading].planted = false
		turn = .09
		travel_consumed = true
	elif running and not restarted and not is_equal_approx(float(description.stride),float(track.pose.profile.stride)):
		# Guarding/braking changes cycle length, not the remaining ground each
		# planted leg can cover. Reconstruct that stance from its world anchor;
		# retaining the old normalized phase would keep a foot down too long.
		var support: int = -1
		for index: int in range(2):
			if bool(track.legs[index].planted) and (support < 0 or float(track.legs[index].phase) < float(track.legs[support].phase)):
				support = index
		if support >= 0:
			var relative: float = (Vector2(track.legs[support].world).x-position_value.x)*direction
			var contact_phase: float = maxf(0.0,(CONTACT_TRAVEL*.5-relative)/float(description.stride))
			phase = fposmod(contact_phase-support*.5,1.0)
			travel_consumed = true
	if running and not travel_consumed: phase = fposmod(phase+travel/float(description.stride),1.0)
	var settle: float = 0.0 if running else float(track.get("settle",0.0))+maxf(0.0,dt)
	var legs: Array = []
	for index: int in range(2):
		var leg_phase: float = fposmod(phase+index*0.5,1.0)
		var foot: Dictionary = _foot(leg_phase,description,direction)
		var previous: Dictionary = track.get("legs",[])[index] if not restarted else {}
		var target: Vector2 = position_value+Vector2(foot.offset)
		if not previous.is_empty() and bool(foot.planted) and bool(previous.planted):
			# Anchor in world space: a planted foot cannot skate when animation
			# cadence, camera interpolation, aiming or movement direction changes.
			target.x = Vector2(previous.world).x
		if running and not previous.is_empty() and turn > 0.0 and not bool(foot.planted):
			# Reverse from the current pose, without teleporting both feet across
			# the hips. This leg replants naturally at the next contact phase.
			target.x = move_toward(Vector2(previous.world).x,target.x,maxf(1.0,travel*1.8))
		if not running:
			var rest := position_value+Vector2((-5.0 if index==0 else 2.0)*facing,SOLE_Y-3.0)
			var origin: Vector2 = previous.get("stop_origin",previous.get("world",rest))
			var progress: float = smoothstep(0.0,SETTLE_TIME,settle)
			target = origin.lerp(rest,progress)
			foot.planted = progress >= 1.0
			foot.angle = 0.0
			foot["stop_origin"] = origin
		foot["world"] = target
		foot["phase"] = leg_phase
		legs.append(foot)
	var pose: Dictionary = {"active":true,"phase":phase,"legs":legs,"backwards":backwards,"profile":description,"settle":settle,"hip_shift":Vector2(sin(TAU*phase)*0.45,0.6 if backwards else 0.0)}
	track = {"clock":clock,"pos":position_value,"phase":phase,"direction":direction,"legs":legs,"pose":pose,"settle":settle,"turn":turn}
	if cache.size() >= MAX_TRACKS and not cache.has(key): cache.erase(cache.keys()[0])
	cache[key] = track
	canvas.set_meta(META,cache)
	return _local_pose(pose,position_value,facing)

static func _local_pose(pose: Dictionary, position_value: Vector2, facing: float) -> Dictionary:
	var result: Dictionary = pose.duplicate(true)
	for index: int in range(2):
		var leg: Dictionary = result.legs[index]
		var relative: Vector2 = Vector2(leg.world)-position_value
		leg["ankle"] = Vector2(relative.x*facing,relative.y)
		leg["hip"] = Vector2(-1.5 if index==0 else 1.5,2.0)+Vector2(result.hip_shift)
		leg["knee"] = knee(leg.hip,leg.ankle)
	return result

# Small code-authored pixel plates, deliberately matching the ivory/teal and
# bronze/charcoal suits. These contain no complete limb silhouettes: four rigid
# parts can only be attached to the two explicit hip-knee-ankle chains above.
static var _parts: Dictionary = {}
const PATTERNS: Dictionary = {
	"thigh":["  #####  "," ##ddd## "," #tlltd# ","#tlllttd#","#tlltttd#","#tlltttd#","#tlttttd#","#tttttdd#","#tttttdd#","#atttddd#","#aattdd# "," #attdd# "," #dddd#  ","  #####  "],
	"shin":["  ####  "," #dddd# ","#dahhad#","#aahhad#","#aahadd#","#aaaddd#","#aaaddd#","#aaaddd#","#aaddd# ","#adddd# "," #ddd#  "," #ttd#  "," #ddd#  "," #####  "],
	"knee":["  ###  "," #hha# ","#hhaaad","#aaaadd","#aaadd#"," #ddd# ","  ###  "],
	"boot":["  ####   "," ##ttd#  ","#daaadd##","#aaahhaad","#########"]}

static func _part(character: String, kind: String) -> Texture2D:
	var key: String = character+":"+kind
	if _parts.has(key): return _parts[key]
	var gold: bool = character=="vanguard"
	var palette: Dictionary = {
		" ":Color.TRANSPARENT,"#":INK,
		"d":Color("675440") if gold else Color("354e53"),
		"t":Color("54505a") if gold else Color("50716b"),
		"l":Color("77716b") if gold else Color("709387"),
		"a":Color("c19b68") if gold else Color("babda6"),
		"h":Color("edc588") if gold else Color("e8e1c4")}
	var rows: Array = PATTERNS[kind]
	var image := Image.create(str(rows[0]).length(),rows.size(),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in range(rows.size()):
		for x: int in range(str(rows[y]).length()): image.set_pixel(x,y,palette[str(rows[y]).substr(x,1)])
	var sampler := CanvasTexture.new()
	sampler.diffuse_texture = ImageTexture.create_from_image(image)
	sampler.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_parts[key] = sampler
	return sampler

static func _textured_quad(canvas: Node2D, texture: Texture2D, origin: Vector2, across: Vector2, down: Vector2, tint: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([origin,origin+across,origin+across+down,origin+down]),PackedColorArray([tint]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),texture)

static func _segment(canvas: Node2D, character: String, kind: String, start: Vector2, end: Vector2, width: float, tint: Color) -> void:
	var along: Vector2 = (end-start).normalized()
	var across := Vector2(along.y,-along.x)
	_textured_quad(canvas,_part(character,kind),start-along*.7-across*width*.5,across*width,end-start+along*1.4,tint)

static func draw(canvas: Node2D, pose: Dictionary, character: String, tint: Color) -> void:
	var cloth: Color = Color("54505a") if character=="vanguard" else Color("50716b")
	for index: int in range(2):
		var leg: Dictionary = pose.legs[index]
		var shade: float = .64 if index==0 else 1.0
		var color_value: Color = Color(shade,shade,shade,1)*tint
		var hip: Vector2 = leg.hip
		var joint: Vector2 = leg.knee
		var ankle: Vector2 = leg.ankle
		_segment(canvas,character,"thigh",hip,joint,8.0 if index==1 else 7.0,color_value)
		_segment(canvas,character,"shin",joint,ankle,7.0 if index==1 else 6.0,color_value)
		canvas.draw_texture_rect(_part(character,"knee"),Rect2(joint-Vector2(3.5,3.5),Vector2(7,7)),false,color_value)
		var along: Vector2 = Vector2.RIGHT.rotated(float(leg.angle))
		var down: Vector2 = Vector2.DOWN.rotated(float(leg.angle))
		_textured_quad(canvas,_part(character,"boot"),ankle-along*3-down*2,along*9,down*5,color_value)
	# The hip fabric overlaps the retained belt by one pixel, closing the seam.
	var hips: Vector2 = Vector2(pose.hip_shift)
	canvas.draw_rect(Rect2(Vector2(-7,-1)+hips,Vector2(13,5)),INK)
	canvas.draw_rect(Rect2(Vector2(-6,-1)+hips,Vector2(11,4)),cloth*tint)
	canvas.draw_rect(Rect2(Vector2(-5,0)+hips,Vector2(8,2)),cloth.lightened(.14)*tint)
