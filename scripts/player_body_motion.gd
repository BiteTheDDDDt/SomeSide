class_name SidePlayerBodyMotion
extends RefCounted

## Canvas-owned visual history; never writes physics or replicated state.
const META: StringName = &"someside_body_motion"
const LAND_TIME: float = .22
const MAX_TRACKS: int = 64

static func reset(canvas: CanvasItem) -> void:
	if canvas.has_meta(META): canvas.remove_meta(META)

static func sample(canvas: CanvasItem, player: Dictionary, clock: float, gait: Dictionary, action: Dictionary) -> Dictionary:
	var tracks: Dictionary = canvas.get_meta(META,{})
	var key: String = str(player.get("id",0))+":"+str(player.get("character","ranger"))
	var track: Dictionary = tracks.get(key,{})
	var pos: Vector2 = player.get("pos",Vector2.ZERO)
	var velocity: Vector2 = player.get("vel",Vector2.ZERO)
	var grounded: bool = player.get("grounded",false)
	var dt: float = clock-float(track.get("clock",clock))
	var reset: bool = track.is_empty() or dt<0 or dt>.5 or pos.distance_to(track.get("pos",pos))>180
	if not reset and is_zero_approx(dt) and track.has("pose"): return track.pose
	var land_at: float = float(track.get("land_at",-100.0))
	var launch_at: float = float(track.get("launch_at",-100.0))
	var strength: float = float(track.get("strength",0.0))
	if reset:
		land_at=-100; launch_at=-100
	elif grounded and not bool(track.grounded) and float(track.vy)>60:
		land_at=clock
		strength=clampf((float(track.vy)-100)/650.0,.22,1.0)
	elif not grounded and bool(track.grounded) and velocity.y<0:
		launch_at=clock
	var dash: bool = float(player.get("dash_timer",0))>0
	var interrupted: bool = not grounded or dash or absf(velocity.x)>15 or bool(action.get("active",false)) or bool(player.get("dead",false))
	if interrupted: land_at=-100
	var weights: Dictionary = {}
	var phase: String = "ground"
	var landing: float = 0.0
	if dash:
		weights[3]=1.0; phase="dash"
	elif not grounded:
		var launch: float = 1.0-smoothstep(.025,.11,clock-launch_at)
		var apex: float = 1.0-smoothstep(35.0,105.0,absf(velocity.y))
		var rise: float = 1.0-smoothstep(-50.0,50.0,velocity.y)
		weights[4]=launch
		weights[5]=apex*(1-launch)
		weights[1]=(1-apex)*(1-launch)*rise
		weights[2]=(1-apex)*(1-launch)*(1-rise)
		phase="takeoff" if launch>.1 else ("apex" if apex>.1 else ("rise" if velocity.y<0 else "fall"))
	else:
		var elapsed: float = clock-land_at
		if elapsed>=0 and elapsed<LAND_TIME:
			# Impact sinks quickly; recovery is deliberately slower. A very small
			# upper-body rebound follows, without moving either sole.
			landing=strength*(smoothstep(0,.025,elapsed) if elapsed<.025 else 1.0-smoothstep(.055,LAND_TIME,elapsed))
			phase="compress" if elapsed<.065 else "settle"
		weights[6]=landing
		weights[0]=1.0-landing
	var offset := Vector2.ZERO
	var angle: float = 0.0
	if bool(gait.get("active",false)):
		offset=Vector2(gait.hip_shift)
		angle=float(gait.get("torso_angle",0.0))
	elif grounded and clock-land_at>.09 and clock-land_at<LAND_TIME:
		offset.y=-sin(PI*(clock-land_at-.09)/(LAND_TIME-.09))*.55*strength
	if bool(action.get("active",false)):
		angle+=float(action.get("body_angle",0))
		offset+=Vector2(action.get("body_shift",Vector2.ZERO))
	angle=clampf(angle,-.19,.19)
	# Everything is recomputed from bounded poses, never cumulatively added.
	offset=offset.clamp(Vector2(-3,-2),Vector2(3,2))
	var result: Dictionary = {"weights":weights,"phase":phase,"offset":offset,"angle":angle,"landing":landing,"strength":strength,"gait":gait}
	if tracks.size()>=MAX_TRACKS and not tracks.has(key): tracks.erase(tracks.keys()[0])
	tracks[key]={"clock":clock,"pos":pos,"grounded":grounded,"vy":velocity.y,"land_at":land_at,"launch_at":launch_at,"strength":strength,"pose":result}
	canvas.set_meta(META,tracks)
	return result

static func transform_point(point: Vector2, pose: Dictionary) -> Vector2:
	var pivot := Vector2(0,5)
	return pivot+(point-pivot).rotated(float(pose.angle))+Vector2(pose.offset)
