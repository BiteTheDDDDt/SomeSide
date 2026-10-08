class_name SideIllustratedEnemies
extends RefCounted

## Original generated RGBA atlas is sampled unchanged. A small UV mesh gives
## local limbs/wing motion and pins the firing organ to the real launch point.
const Geometry=preload("res://scripts/combat_geometry.gd")
const Attack=preload("res://scripts/enemy_attack_visual.gd")
const Motion=preload("res://scripts/enemy_body_motion.gd")
const Rig=preload("res://scripts/enemy_rig_24.gd")
const Keys=preload("res://scripts/actor_key_poses.gd")
const TEXTURE_PATH="res://assets/art/unified-v0206/enemies-grey.png"
const GRID: int=10
const MAX_MESHES: int=384
# Pixel regions are measured from the alpha silhouettes, not equal grid cells.
# Target rectangles use the existing grounded baseline (17, boss 44).
const DEFINITIONS: Dictionary={
	"crawler":{"region":Rect2(14,99,362,263),"target":Rect2(-40,-35,70,52)},
	"spitter":{"region":Rect2(411,67,302,284),"target":Rect2(-28,-31,54,48),"organ":Vector2(.944,.37)},
	"spore_moth":{"region":Rect2(748,14,319,344),"target":Rect2(-36,-42,65,66)},
	"drone":{"region":Rect2(1082,35,358,327),"target":Rect2(-37,-32,70,64),"organ":Vector2(.965,.56)},
	"charger":{"region":Rect2(14,387,380,282),"target":Rect2(-43,-39,76,56)},
	"burrower":{"region":Rect2(368,460,409,210),"target":Rect2(-45,-23,80,40)},
	"sentinel":{"region":Rect2(778,392,266,270),"target":Rect2(-44,-20,52,37),"organ":Vector2(.835,.37)},
	"skirmisher":{"region":Rect2(1094,386,340,293),"target":Rect2(-32,-39,66,56)},
	"conductor":{"region":Rect2(45,678,278,392),"target":Rect2(-24,-34,46,64),"organ":Vector2(.775,.49)},
	"boss_stone":{"region":Rect2(326,685,411,385),"target":Rect2(-65,-74,120,118)},
	"boss_spore":{"region":Rect2(744,664,348,416),"target":Rect2(-54,-50,102,124),"organ":Vector2(.82,.38)},
	"boss_prism":{"region":Rect2(1108,678,324,393),"target":Rect2(-55,-30,100,120),"organ":Vector2(.557,.26)},
}
static var _texture: Texture2D
static var _meshes: Dictionary={}
static var _order: Array[String]=[]

static func identity(e: Dictionary) -> String:
	return "boss_"+str(e.get("boss_style","spore")) if str(e.get("kind",""))=="boss" else str(e.get("kind",""))

static func bounds(e: Dictionary) -> Rect2:
	var definition: Dictionary=DEFINITIONS.get(identity(e),{})
	if definition.is_empty(): return Rect2()
	return Rect2(definition.target).grow(28.0)

static func sample(e: Dictionary, clock: float) -> Dictionary:
	var id: String=identity(e)
	if not DEFINITIONS.has(id): return {}
	var action: Dictionary=Attack.attack_sample(e)
	var moving: float=clampf(absf(Vector2(e.get("vel",Vector2.ZERO)).x)/100,0,1)
	var phase: float=fposmod(clock*(7.0 if id in ["charger","boss_stone"] else 9.0)+float(e.get("id",0))*.61,TAU)
	# Subpixel-sized quantization keeps a bounded reusable mesh cache without
	# moving the whole sprite or tying its position to rounded animation frames.
	phase=snappedf(phase,TAU/24.0)
	var rhythm: Dictionary=Motion.sample(e,id)
	var amount: float=snappedf(float(rhythm.amount),.05)
	var stage: String=str(rhythm.get("rig_stage","idle"))
	var clip_progress: float=float(rhythm.get("rig_progress",0))
	if stage=="idle":
		stage="move" if moving>.1 else "idle"
		clip_progress=phase/TAU
	# Cache exactly the 24 attack/locomotion poses; continuous entity
	# positions and firing sockets are independent of these pose indices.
	var rig: Dictionary=Rig.sample(id,str(e.get("attack_kind","idle")),stage,clip_progress,false)
	var direction: Vector2=Geometry.local_direction(e)
	return {"id":id,"phase":phase,"moving":snappedf(moving,.25),"amount":amount,"aim":direction,
		"charged":float(e.get("charge_timer",0))>0,"organ":Geometry.source_offset(e,direction),
		"flash":float(e.get("flash",0))>0,"rhythm":rhythm,"rig":rig,"rig_stage":stage}

static func key_vertices(data: Dictionary, index: int) -> Dictionary:
	var f: Dictionary=Keys.frame(data.id,index)
	var target: Rect2=f.target
	var source: Rect2=f.region
	var positions:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var mouth: Vector2=target.position+Vector2(f.socket)*float(Keys._data.actors[data.id].scale)
	var aim: Vector2=data.aim
	var xs: Array[float]=[]
	var ys: Array[float]=[]
	for i: int in range(9): xs.append(i/8.0); ys.append(i/8.0)
	var organ: Vector2=Vector2(f.socket)/source.size
	if data.id=="spitter": xs.append(organ.x); ys.append(organ.y); xs.sort(); ys.sort()
	elif data.id=="crawler":
		var claw: Array=Keys._data.actors.crawler.frames[index].claw
		xs.append(float(claw[0])/source.size.x); ys.append(float(claw[1])/source.size.y); xs.sort(); ys.sort()
	for v: float in ys:
		for u: float in xs:
			var point: Vector2=target.position+Vector2(u,v)*target.size
			point=Rig.bend(point,Vector2(u,v),target,data.rig) if data.has("rig") else point
			if data.id=="spitter":
				# Each authored mouth has its own socket. Its rigid front patch
				# stays on the unchanged authoritative projectile launch point.
				var rig_mouth: Vector2=Rig.bend(mouth,organ,target,data.rig) if data.has("rig") else mouth
				var relative: Vector2=point-rig_mouth
				var pinned: Vector2=Vector2(data.organ)+aim*relative.x+Vector2(-aim.y,aim.x)*relative.y
				var weight: float=smoothstep(organ.x-.32,organ.x-.08,u)*(1.0-smoothstep(organ.y+.18,organ.y+.38,v))
				point=point.lerp(pinned,weight)
			positions.append(point)
			uv.append((source.position+Vector2(u,v)*source.size)/Vector2(1448,1086))
	var width: int=xs.size()
	for y: int in range(ys.size()-1):
		for x: int in range(width-1):
			var i: int=y*width+x
			indices.append_array(PackedInt32Array([i,i+1,i+width,i+1,i+width+1,i+width]))
	return {"positions":positions,"uv":uv,"indices":indices}

static func _mesh(shape: Dictionary) -> ArrayMesh:
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=shape.positions
	arrays[Mesh.ARRAY_TEX_UV]=shape.uv
	arrays[Mesh.ARRAY_INDEX]=shape.indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _remember(key: String, shape: Dictionary) -> ArrayMesh:
	if _meshes.has(key): return _meshes[key]
	var mesh: ArrayMesh=_mesh(shape)
	if _order.size()>=MAX_MESHES: _meshes.erase(_order.pop_front())
	_order.append(key); _meshes[key]=mesh
	return mesh

static func vertices(data: Dictionary) -> Dictionary:
	var def: Dictionary=DEFINITIONS[data.id]
	var target: Rect2=def.target
	var source: Rect2=def.region
	var positions:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var xs: Array[float]=[]
	var ys: Array[float]=[]
	for i: int in range(GRID+1): xs.append(i/float(GRID)); ys.append(i/float(GRID))
	if def.has("organ"):
		xs.append(float(def.organ.x)); ys.append(float(def.organ.y)); xs.sort(); ys.sort()
	var amount: float=data.amount
	var phase: float=data.phase
	var moving: float=data.moving
	var flying: bool=data.id in ["spore_moth","drone","conductor","boss_spore","boss_prism"]
	for v: float in ys:
		for u: float in xs:
			var pixel: Vector2=source.position+Vector2(u,v)*source.size
			# Clip only transparent gutter corners that otherwise contain part
			# of a neighboring atlas silhouette. No raster pixels are edited.
			if str(data.id)=="burrower":
				if pixel.y<530: pixel.x=maxf(pixel.x,405)
				if pixel.y>635: pixel.x=minf(pixel.x,750)
			if str(data.id)=="charger" and pixel.y>545: pixel.x=minf(pixel.x,368)
			var local_uv: Vector2=(pixel-source.position)/source.size
			var point: Vector2=target.position+local_uv*target.size
			var base: Vector2=point
			point=Rig.bend(point,local_uv,target,data.rig) if data.has("rig") else point
			if flying:
				var wing: float=(1.0-smoothstep(.38,.78,u))*(1.0-smoothstep(.58,.9,v))
				if data.id in ["spore_moth","drone"]: point.y+=sin(phase)*wing*(5.0 if data.id=="spore_moth" else 2.0)
				else: point.x+=sin(phase*.5+v*2)*smoothstep(.5,1,v)*1.7
			else:
				var leg: float=smoothstep(.55,.92,v)
				var stride: float=sin(phase+u*TAU)
				point.x+=stride*leg*3.0*moving
				point.y-=maxf(0,stride)*leg*2.0*moving
			var foot: float=target.end.y if not flying else target.get_center().y
			point.y=foot+(point.y-foot)*(1.0-.065*amount)
			point.x+=-amount*2*(1.0-v)
			if bool(data.charged): point.x+=(u-.45)*4*(1.0-v*.4)
			if def.has("organ"):
				var anchor: Vector2=target.position+Vector2(def.organ)*target.size
				# A rigid front patch preserves the whole eye/mouth silhouette;
				# only the neck transition blends. Radial pinning collapses faces.
				var weight: float=smoothstep(float(def.organ.x)-.30,float(def.organ.x)-.08,local_uv.x)
				weight*=1.0-smoothstep(float(def.organ.y)+.18,float(def.organ.y)+.38,local_uv.y)
				# Floating creatures can orient as one rigid body; bending only
				# their face at steep aim angles folds wings and hanging limbs.
				if data.id in ["drone","conductor","boss_spore"]: weight=1.0
				var aim: Vector2=Vector2.RIGHT if data.id in ["sentinel","boss_prism"] else Vector2(data.aim)
				var rig_anchor: Vector2=Rig.bend(anchor,Vector2(def.organ),target,data.rig) if data.has("rig") else anchor
				var relative: Vector2=point-rig_anchor if data.id in ["drone","conductor","boss_spore"] else base-anchor
				# Canvas Y points down; Vector2.orthogonal() points up for RIGHT
				# and would invert the face patch, folding it through the body.
				var pinned: Vector2=Vector2(data.organ)+aim*relative.x+Vector2(-aim.y,aim.x)*relative.y
				point=point.lerp(pinned,weight)
			positions.append(point); uv.append(pixel/Vector2(1448,1086))
	var width: int=xs.size()
	for y: int in range(ys.size()-1):
		for x: int in range(width-1):
			var index: int=y*width+x
			indices.append_array(PackedInt32Array([index,index+1,index+width,index+1,index+width+1,index+width]))
	return {"positions":positions,"uv":uv,"indices":indices}

static func draw(c: CanvasItem,e: Dictionary,clock: float) -> bool:
	var data: Dictionary=sample(e,clock)
	if data.is_empty(): return false
	if _texture==null: _texture=load(TEXTURE_PATH) as Texture2D
	if _texture==null: return false
	var weights: Dictionary=data.rhythm.weights if Motion.PROFILES.has(data.id) else {}
	var total: float=0.0
	var tint: Color=Color(1.25,1.25,1.25) if bool(data.flash) else Color.WHITE
	for index: int in weights:
		var weight: float=weights[index]
		if weight<.005: continue
		total+=weight
		var pose_key: String="key/%s/%d/%s/%s/%s/%d"%[data.id,index,str(data.aim),str(data.organ),data.rig_stage,int(data.rig.frame)]
		var pose_mesh: ArrayMesh=_meshes.get(pose_key)
		if pose_mesh==null: pose_mesh=_remember(pose_key,key_vertices(data,index))
		var pose: Dictionary=Keys.frame(data.id,index)
		c.draw_mesh(pose_mesh,pose.texture.atlas,Transform2D.IDENTITY,Color(tint,weight))
	if total>=.995: return true
	var key: String="%s/%.4f/%.2f/%.2f/%.4f/%s/%s"%[data.id,data.phase,data.moving,data.amount,Vector2(data.aim).angle(),str(data.charged),str(data.organ)]+"/"+str(data.rig_stage)+"/"+str(data.rig.frame)
	var mesh: ArrayMesh=_meshes.get(key)
	if mesh==null:
		var shape: Dictionary=vertices(data)
		mesh=_remember(key,shape)
	c.draw_mesh(mesh,_texture,Transform2D.IDENTITY,Color(tint,1-total))
	return true
