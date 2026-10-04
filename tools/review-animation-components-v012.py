"""Read-only alpha/component audit; emits metadata, never changes source pixels.

Importable helpers also supported initial crop authoring. The default command
only inspects sheets; actors.json is the reviewed source of truth. Requires
Pillow, NumPy and SciPy for these optional development-only checks.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SHEETS = {
    "forest-enemies-v2": ["crawler", "spitter", "spore_moth"],
    "canyon-enemies-v2": ["charger", "burrower", "drone"],
    "ruins-enemies-v2": ["sentinel", "skirmisher", "conductor"],
    "bosses-v2": ["boss_spore", "boss_stone", "boss_prism"],
}
SPEED = {"crawler":116,"spitter":78,"spore_moth":120,"charger":96,"burrower":64,"drone":135,"sentinel":55,"skirmisher":102,"conductor":88}
RADIUS = {"crawler":19,"spitter":21,"spore_moth":19,"charger":24,"burrower":21,"drone":18,"sentinel":23,"skirmisher":20,"conductor":22}
FLYING = {"spore_moth","drone","conductor"}

def landmark(rgba, labels, obj, kind):
    x,y,w,h = obj["bbox"]
    patch = rgba[y:y+h,x:x+w]
    r,g,b = [patch[:,:,channel].astype(float) for channel in range(3)]
    yy,xx = np.mgrid[0:h,0:w]
    mask = labels[y:y+h,x:x+w] == obj["component"]
    if kind == "spitter": mask &= (r>170)&(g>85)&(b<100)&(xx<w*.6)&(yy<h*.65)
    elif kind == "drone": mask &= (r<120)&(g>165)&(b>190)&(xx>w*.72)&(yy>h*.4)
    elif kind == "conductor": mask &= (r>215)&(g>145)&(b<95)&(yy<h*.6)
    elif kind == "spore_moth": mask &= (r>160)&(g>100)&(b<80)&(xx>w*.6)&(yy>h*.3)&(yy<h*.85)
    elif kind == "crawler": mask &= (r>180)&(g>70)&(b<100)&(xx>w*.55)&(yy>h*.2)&(yy<h*.7)
    elif kind == "charger": mask &= (r>215)&(g>135)&(b<100)&(xx>w*.66)
    elif kind == "burrower": mask &= (r>180)&(g>90)&(b<80)&(xx>w*.5)&(yy<h*.65)
    elif kind == "sentinel": mask &= (r>210)&(g>115)&(b<95)&(xx>w*.52)&(yy<h*.5)
    elif kind == "skirmisher": mask &= (r>210)&(g>125)&(b<90)&(xx>w*.6)&(yy<h*.45)
    elif kind == "boss_spore": mask &= (r>185)&(g>80)&(b<90)&(xx>w*.3)&(xx<w*.75)&(yy>h*.35)&(yy<h*.6)
    elif kind == "boss_stone": mask &= (r>180)&(g>85)&(b<105)&(xx>w*.23)&(xx<w*.52)&(yy>h*.35)&(yy<h*.65)
    elif kind == "boss_prism": mask &= (r>210)&(g>110)&(b<90)&(xx>w*.3)&(xx<w*.7)&(yy>h*.2)&(yy<h*.6)
    if mask.sum()<5:
        return np.array(obj["centroid"]), int(mask.sum())
    ys,xs=np.nonzero(mask)
    return np.array([xs.mean()+x,ys.mean()+y]), int(mask.sum())

def enemy_entries(name, rgba, labels, report, old):
    entries = {}
    details = {}
    for row,kind in zip(report["rows"],SHEETS[name]):
        if len(row)!=8: raise ValueError((name,kind,"expected eight frames"))
        boss=kind.startswith("boss_")
        scale = old[kind]["scale"] * old[kind]["frames"][0]["rect"][3] / np.median([obj["bbox"][3] for obj in row[:4 if boss else 6]])
        ref = row[0]["bbox"]
        features = [landmark(rgba,labels,obj,kind) for obj in row]
        previous_frame=old[kind]["frames"][0]
        initial=np.array([ref[0]+previous_frame["anchor"][0]/previous_frame["rect"][2]*ref[2],ref[1]+previous_frame["anchor"][1]/previous_frame["rect"][3]*ref[3]])
        frames=[]
        frame_audit=[]
        for index,obj in enumerate(row):
            x,y,w,h=obj["bbox"]
            anchor=initial+features[index][0]-features[0][0]
            if kind not in FLYING and kind not in {"boss_spore","boss_prism"}: anchor[1]=y+h-(44 if boss else RADIUS[kind])/scale
            x0,y0=max(0,x-2),max(0,y-2)
            x1,y1=min(rgba.shape[1],x+w+2),min(rgba.shape[0],y+h+2)
            ys,xs=np.nonzero(labels[y:y+h,x:x+w]==obj["component"])
            nearest=np.argmin((xs+x-obj["centroid"][0])**2+(ys+y-obj["centroid"][1])**2)
            seed=[int(xs[nearest]+x),int(ys[nearest]+y)]
            crop_labels=labels[y0:y1,x0:x1]
            other_ids=[entry["component"] for other_row in report["rows"] for entry in other_row if entry["component"]!=obj["component"]]
            contamination=int(np.isin(crop_labels,other_ids).sum())
            frame={"rect":[x0,y0,x1-x0,y1-y0],"anchor":[round(float(anchor[0]-x0),4),round(float(anchor[1]-y0),4)],"duration":0.18 if boss and index<6 else 0.08}
            # Metadata can request runtime isolation when rectangular crops
            # intersect a neighbouring frame. It never modifies the PNG.
            if contamination: frame["component_seed"]=seed
            frames.append(frame)
            frame_audit.append({"feature":features[index][0].tolist(),"feature_pixels":features[index][1],"neighbor_pixels":contamination,"seed":seed})
        clips={"idle":[0,1,2,3],"move":[0,1,2,3],"windup":[4,5],"attack":[6,7]} if boss else {"idle":list(range(6)) if kind in FLYING else [0],"move":list(range(6)),"windup":[6],"attack":[7]}
        entries[kind]={"texture":"res://assets/sprites/"+name+".png","scale":round(float(scale),7),"movement_speed":75 if boss else SPEED[kind],"frames":frames,
            "animations":clips,
            "animation_modes":{"idle":"loop","move":"loop","windup":"once","attack":"once"}}
        lo=np.floor(np.min([-np.array(frame["anchor"])*scale for frame in frames],axis=0))
        hi=np.ceil(np.max([(np.array(frame["rect"][2:])-np.array(frame["anchor"]))*scale for frame in frames],axis=0))
        yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
        for frame,audit,obj in zip(frames,frame_audit,row):
            x,y,w,h=frame["rect"]
            sx=np.floor((xx+.5)/scale+frame["anchor"][0]+x).astype(int)
            sy=np.floor((yy+.5)/scale+frame["anchor"][1]+y).astype(int)
            inside=(sx>=x)&(sy>=y)&(sx<x+w)&(sy<y+h)
            values=labels[np.clip(sy,0,labels.shape[0]-1),np.clip(sx,0,labels.shape[1]-1)]
            body_ids=[entry["component"] for other_row in report["rows"] for entry in other_row if entry["component"]!=obj["component"]]
            foreign=inside&np.isin(values,body_ids)
            audit["baked_neighbor_pixels"]=int(foreign.sum())
            if foreign.any():
                cut=int(sx[foreign].max())+1
                own_lost=int((inside&(sx<cut)&(values==obj["component"])).sum())
                audit["possible_left_trim"]={"cut":cut,"own_baked_pixels_lost":own_lost}
                if own_lost==0 and cut<x+w:
                    # The final moth's left gutter contains a neighbour tip,
                    # but none of its own logical-pixel samples. Tightening only
                    # that unused gutter preserves every rendered body pixel.
                    delta=cut-x
                    frame["rect"][0]=cut
                    frame["rect"][2]-=delta
                    frame["anchor"][0]=round(frame["anchor"][0]-delta,4)
                    audit["baked_neighbor_pixels"]=0
                    audit["source_gutter_trim"]=delta
            if audit["baked_neighbor_pixels"]==0: frame.pop("component_seed",None)
        details[kind]={"scale":scale,"frames":frame_audit}
    return entries,details

def inspect(name):
    rgba = np.array(Image.open(ROOT / "assets/sprites" / (name + ".png")))
    alpha = rgba[:, :, 3]
    labels, _ = ndimage.label(alpha > 128, np.ones((3, 3)))
    components = []
    for index, section in enumerate(ndimage.find_objects(labels), 1):
        if section is None:
            continue
        mask = labels[section] == index
        count = int(mask.sum())
        if count < 3000:
            continue
        foreign_labels = labels[section][(~mask) & (alpha[section] > 128)]
        foreign = {int(k): int(v) for k, v in zip(*np.unique(foreign_labels, return_counts=True))}
        ys, xs = np.nonzero(mask)
        components.append({"component": index, "bbox": [section[1].start, section[0].start,
            section[1].stop - section[1].start, section[0].stop - section[0].start],
            "pixels": count, "foreign": foreign, "centroid": [float(xs.mean() + section[1].start), float(ys.mean() + section[0].start)]})
    # Body-center order handles actual uneven row spacing, not uniform cells.
    components.sort(key=lambda value: value["centroid"][1])
    row_size = 4 if name in {"canyon-enemies-v2","bosses-v2"} else 8
    spatial_rows = [sorted(components[offset:offset+row_size],key=lambda value:value["centroid"][0]) for offset in range(0,len(components),row_size)]
    if name=="bosses-v2":
        # Floating crystals belong to the prism despite being disconnected from
        # its body. Actual inter-row blank gaps define row bands; nearest body
        # within that band owns each accessory component.
        boundaries=[0]+[(max(v["bbox"][1]+v["bbox"][3] for v in a)+min(v["bbox"][1] for v in b))/2 for a,b in zip(spatial_rows,spatial_rows[1:])]+[rgba.shape[0]]
        known={obj["component"] for obj in components}
        for label,section in enumerate(ndimage.find_objects(labels),1):
            if section is None or label in known: continue
            ys,xs=np.nonzero(labels[section]==label)
            if len(xs)<2: continue
            center=np.array([xs.mean()+section[1].start,ys.mean()+section[0].start])
            row_index=max(0,min(len(spatial_rows)-1,int(np.searchsorted(boundaries,center[1])-1)))
            obj=min(spatial_rows[row_index],key=lambda value:abs(value["centroid"][0]-center[0]))
            x,y,w,h=obj["bbox"]
            x0,y0=min(x,section[1].start),min(y,section[0].start)
            x1,y1=max(x+w,section[1].stop),max(y+h,section[0].stop)
            obj["bbox"]=[x0,y0,x1-x0,y1-y0]
        # Feature measurement may sample detached crystals too; main body
        # labels still define core registration and prevent accidental drift.
    rows=[spatial_rows[i]+spatial_rows[i+1] for i in range(0,len(spatial_rows),2)] if row_size==4 else spatial_rows
    return rgba, labels, {"size": [rgba.shape[1], rgba.shape[0]], "body_count": len(components), "rows": rows}

if __name__ == "__main__":
    report = {}
    for name, kinds in SHEETS.items():
        rgba, labels, result = inspect(name)
        report[name] = result
        print(name, "components", result["body_count"])
    output = ROOT / "tools/results/components-v012.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2), encoding="utf-8")
