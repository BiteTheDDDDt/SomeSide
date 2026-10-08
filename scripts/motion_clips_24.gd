class_name SideMotionClips24
extends RefCounted

## Twenty-four real pose samples per clip, independent of display FPS.
## Curves are baked once; playback interpolates neighboring poses. Contact,
## targeting, collision and damage phase switches remain outside this module.
const COUNT: int = 24
const MAX_CLIPS: int = 512
static var _clips: Dictionary = {}

static func bake(id: String, evaluator: Callable, loop: bool = false, times: PackedFloat64Array=PackedFloat64Array()) -> Dictionary:
	if _clips.has(id): return _clips[id]
	if _clips.size()>=MAX_CLIPS: _clips.erase(_clips.keys()[0])
	var frames: Array=[]
	if times.is_empty():
		for i: int in range(COUNT): times.append(float(i)/(COUNT if loop else COUNT-1))
	assert(times.size()==COUNT)
	for t: float in times: frames.append(evaluator.call(t))
	_clips[id]={"frames":frames,"loop":loop,"times":times}
	return _clips[id]

static func times_at(critical: Array) -> PackedFloat64Array:
	var times: Array[float]=[0.0,1.0]
	for t: float in critical:
		if t>0 and t<1 and not times.has(t): times.append(t)
	times.sort()
	while times.size()<COUNT:
		var largest: int=0
		for i: int in range(times.size()-1):
			if times[i+1]-times[i]>times[largest+1]-times[largest]: largest=i
		times.insert(largest+1,(times[largest]+times[largest+1])*.5)
	return PackedFloat64Array(times)

static func mix(a: Variant,b: Variant,t: float) -> Variant:
	if a is float or a is Vector2 or a is Color: return lerp(a,b,t)
	if a is Dictionary:
		var result: Dictionary={}
		for key: Variant in a:
			result[key]=lerp_angle(float(a[key]),float(b[key]),t) if key=="spin" else mix(a[key],b.get(key,a[key]),t)
		return result
	return a if t<.5 else b

static func play(clip: Dictionary, progress: float) -> Dictionary:
	var loop: bool=clip.loop
	var p: float=fposmod(progress,1.0) if loop else clampf(progress,0,1)
	var times: PackedFloat64Array=clip.times
	var first: int=0
	while first<COUNT-1 and p>=times[first+1]: first+=1
	var next: int=(first+1)%COUNT if loop else mini(first+1,COUNT-1)
	var blend: float=clampf(inverse_lerp(times[first],1.0 if next==0 else times[next],p),0,1) if next!=first else 0.0
	var result: Dictionary=mix(clip.frames[first],clip.frames[next],blend)
	result["frame"]=first
	result["next_frame"]=next
	result["frame_blend"]=blend
	result["frame_count"]=COUNT
	return result

static func sample(id: String, progress: float, evaluator: Callable, loop: bool=false, times: PackedFloat64Array=PackedFloat64Array()) -> Dictionary:
	return play(bake(id,evaluator,loop,times),progress)

static func curve(keys: Array, t: float) -> float:
	for i: int in range(1,keys.size()):
		if t<=float(keys[i][0]):
			var p: float=inverse_lerp(float(keys[i-1][0]),float(keys[i][0]),t)
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),smoothstep(0,1,p))
	return float(keys[-1][1])

static func player(action: String,p: float) -> Dictionary:
	if action in ["takeoff","rise","apex","fall"]:
		var clip: Dictionary=bake("player/jump",func(t: float):
			var frame: int=roundi(t*23)
			if frame<5: return _player_pose("takeoff",frame/4.0)
			if frame<12: return _player_pose("rise",(frame-5)/6.0)
			if frame<16: return _player_pose("apex",(frame-12)/3.0)
			return _player_pose("fall",(frame-16)/7.0))
		var bounds: Array={"takeoff":[0,4],"rise":[5,11],"apex":[12,15],"fall":[16,23]}[action]
		return play(clip,lerpf(bounds[0],bounds[1],clampf(p,0,1))/23.0)
	return sample("player/"+action,p,func(t: float): return _player_pose(action,t),action in ["idle","run","backpedal"])

static func _player_pose(action: String,t: float) -> Dictionary:
	var shift:=Vector2.ZERO
	var angle: float=0.0
	var cloth: float=0.0
	match action:
		"run", "backpedal":
			shift=Vector2(sin(TAU*t)*.45,-absf(sin(TAU*t))*.65+(.6 if action=="backpedal" else 0.0))
			angle=-sin(TAU*t)*.024
			cloth=sin(TAU*t-.7)*.85
		"stop":
			shift.x=curve([[0,1.0],[.25,.4],[.55,-.22],[1,0]],t)
			angle=curve([[0,.025],[.35,-.014],[1,0]],t)
			cloth=sin(PI*t)*.65
		"takeoff":
			shift.y=curve([[0,0],[.18,-.75],[.62,-.35],[1,0]],t)
			angle=sin(PI*t)*.018; cloth=-sin(PI*t)*.7
		"rise":
			shift.y=-sin(PI*t)*.3; angle=sin(PI*t)*.012; cloth=-sin(PI*t)*.8
		"apex":
			shift.y=-sin(PI*t)*.45; cloth=sin(PI*t)*.6
		"fall":
			shift.y=sin(PI*t)*.3; angle=-sin(PI*t)*.016; cloth=sin(PI*t)*.8
		"land":
			shift.y=curve([[0,0],[.13,.4],[.26,.3],[.65,-.55],[1,0]],t)
			cloth=curve([[0,0],[.22,1.1],[.58,-.5],[1,0]],t)
		"dash":
			shift.x=-sin(PI*t)*.6; cloth=-sin(PI*t)*1.0
		"idle":
			cloth=sin(TAU*t-.6)*.2
		"death":
			angle=curve([[0,0],[.35,-.05],[1,-.1]],t); shift.y=sin(t*PI*.5)*.8
	return {"shift":shift,"angle":angle,"cloth":cloth}

static func swing(progress: float) -> Dictionary:
	return sample("player/foot_swing",progress,func(t: float):
		return {"h00":float(2*t*t*t-3*t*t+1),"h10":float(t*t*t-2*t*t+t),"h01":float(-2*t*t*t+3*t*t),"h11":float(t*t*t-t*t),"lift":sin(PI*t),"angle":-.3*sin(TAU*t)})

static func fx(family: String,stage: String,p: float) -> Dictionary:
	if stage in ["ready","active","ending"] and family!="blink":
		var clip: Dictionary=bake("fx/"+family,func(t: float):
			var frame: int=roundi(t*23)
			return _fx_pose(family,["ready","active","ending"][mini(frame/8,2)],(frame%8)/7.0))
		var first: int={"ready":0,"active":8,"ending":16}[stage]
		return play(clip,lerpf(first,first+7,clampf(p,0,1))/23.0)
	return sample("fx/"+family+"/"+stage,p,func(t: float): return _fx_pose(family,stage,t))

static func _fx_pose(family: String,stage: String,t: float) -> Dictionary:
	var organic: bool=family=="spore"
	var scale_y: float=1.0
	var spread: float=0.0
	var bend: float=0.0
	if stage=="ready":
		scale_y=1.0+sin(PI*t)*(.045 if organic else .018)
		bend=sin(PI*t)*(.4+.6*t)*(.015 if organic else .005)
	elif stage=="active":
		scale_y=curve([[0,.78 if organic else .72],[.12,1.0],[.32,.98],[.7,.94],[1,.84]],t)
		spread=curve([[0,0],[.18,.04],[.65,.07],[1,.10]],t) if organic else 0.0
		bend=sin(PI*t)*(.035 if organic else .008)
	elif stage=="ending":
		scale_y=curve([[0,.94],[.35,.78],[1,.35]],t)
		spread=t*.16; bend=sin(PI*t)*(.05 if organic else .025)
	elif stage=="depart": scale_y=curve([[0,1],[.2,1.08],[.58,.45],[1,.08]],t)
	elif stage=="arrive": scale_y=curve([[0,.18],[.22,1.06],[.5,1],[1,.4]],t)
	return {"scale_y":scale_y,"spread":spread,"bend":bend,"progress":t}

static func stats() -> Dictionary:
	return {"clips":_clips.size(),"frames":_clips.size()*COUNT,"max_clips":MAX_CLIPS}
