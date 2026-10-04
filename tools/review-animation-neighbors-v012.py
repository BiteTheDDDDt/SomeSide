"""Read-only final production check: no neighbour body enters any baked pixel."""
from pathlib import Path
import json
import runpy
import sys
import numpy as np

root=Path(__file__).resolve().parents[1]
helpers=runpy.run_path(str(root/"tools/review-animation-components-v012.py"))
manifest=json.loads((root/"assets/sprites/actors.json").read_text(encoding="utf-8"))
report={}
for name,kinds in helpers["SHEETS"].items():
    rgba,labels,data=helpers["inspect"](name)
    all_ids=[obj["component"] for row in data["rows"] for obj in row]
    for kind,objects in zip(kinds,data["rows"]):
        actor=manifest["actors"][kind]
        scale=actor["scale"]
        frames=actor["frames"]
        lo=np.floor(np.min([-np.array(frame["anchor"])*scale for frame in frames],axis=0))
        hi=np.ceil(np.max([(np.array(frame["rect"][2:])-np.array(frame["anchor"]))*scale for frame in frames],axis=0))
        yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
        found=[]
        for frame,obj in zip(frames,objects):
            x,y,w,h=frame["rect"]
            sx=np.floor((xx+.5)/scale+frame["anchor"][0]+x).astype(int)
            sy=np.floor((yy+.5)/scale+frame["anchor"][1]+y).astype(int)
            inside=(sx>=x)&(sy>=y)&(sx<x+w)&(sy<y+h)
            values=labels[np.clip(sy,0,labels.shape[0]-1),np.clip(sx,0,labels.shape[1]-1)]
            other=[value for value in all_ids if value!=obj["component"]]
            contamination=int((inside&np.isin(values,other)).sum())
            if contamination and kind=="spore_moth" and "--repair-moth-phase" in sys.argv:
                original=np.array(frame["anchor"])
                candidates=sorted([(dx*.05,dy*.05) for dx in range(-40,41) for dy in range(-40,41)],key=lambda pair:pair[0]**2+pair[1]**2)
                for dx,dy in candidates:
                    test_anchor=original+np.array([dx,dy])
                    tx=np.floor((xx+.5)/scale+test_anchor[0]+x).astype(int)
                    ty=np.floor((yy+.5)/scale+test_anchor[1]+y).astype(int)
                    valid=(tx>=x)&(ty>=y)&(tx<x+w)&(ty<y+h)
                    samples=labels[np.clip(ty,0,labels.shape[0]-1),np.clip(tx,0,labels.shape[1]-1)]
                    if not (valid&np.isin(samples,other)).any():
                        frame["anchor"]=[round(float(v),4) for v in test_anchor]
                        contamination=0
                        print("MOTH_PHASE_REPAIR anchor_delta_source",dx,dy,"logical",dx*scale,dy*scale)
                        break
            found.append(contamination)
        report[kind]=found
(root/"tools/results/animation-neighbors-v012-review.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
bad=sum(sum(counts) for counts in report.values())
if "--repair-moth-phase" in sys.argv and not bad:
    (root/"assets/sprites/actors.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("ANIMATION_NEIGHBOR_REVIEW",json.dumps(report),"foreign_pixels",bad)
raise SystemExit(1 if bad else 0)
