"""Read-only independent eye/core registration check against final manifest."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "assets/sprites/actors.json").read_text(encoding="utf-8"))
actor = manifest["actors"]["spore_moth"]
rgba = np.array(Image.open(root / actor["texture"].removeprefix("res://")))
records=[]
for index,frame in enumerate(actor["frames"]):
    x,y,w,h=frame["rect"]
    patch=rgba[y:y+h,x:x+w]
    r,g,b,a=[patch[:,:,channel] for channel in range(4)]
    yy,xx=np.mgrid[0:h,0:w]
    mask=(a>128)&(r>220)&(g>120)&(b<70)&(xx>w*.6)&(yy>h-90)&(yy<h-40)
    labels,_=ndimage.label(mask,np.ones((3,3)))
    parts=[]
    for label in range(1,int(labels.max())+1):
        ys,xs=np.nonzero(labels==label)
        if len(xs)>=3: parts.append((len(xs),xs.mean(),ys.mean()))
    parts.sort(reverse=True)
    if not parts:
        records.append({"index":index,"error":"no eye marker"})
        continue
    count,cx,cy=parts[0]
    logical=(np.array([cx,cy])-np.array(frame["anchor"]))*actor["scale"]
    records.append({"index":index,"pixels":count,"source":[cx+x,cy+y],"logical":logical.tolist()})
print(json.dumps(records,indent=2))
valid=np.array([entry["logical"] for entry in records[:6] if "logical" in entry])
print("MOTH_EYE_SPAN",np.ptp(valid,axis=0).tolist())
(root/"tools/results/animation-core-v012-review.json").write_text(json.dumps(records,indent=2),encoding="utf-8")
if "--apply-moth" in sys.argv:
    target=np.array(records[0]["logical"])/actor["scale"]
    for frame,record in zip(actor["frames"],records):
        frame["anchor"]=[round(float(v),4) for v in np.array(record["source"])-np.array(frame["rect"][:2])-target]
    (root/"assets/sprites/actors.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print("Applied only spore_moth frame anchors")
