"""Register generated locomotion source sheets; reads pixels, writes metadata only.
Original PNG bytes and alpha are never resized, painted, masked, or rewritten.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
manifest_path = ROOT / 'assets/sprites/actors.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
report = {}
for character in ('ranger', 'vanguard'):
    relative = f'assets/sprites/{character}-locomotion-v3.png'
    pixels = np.asarray(Image.open(ROOT / relative).convert('RGBA'))
    labels, _ = ndimage.label(pixels[:, :, 3] > 32)
    parts = []
    for label, slices in enumerate(ndimage.find_objects(labels), 1):
        if slices is None:
            continue
        area = np.count_nonzero(labels[slices] == label)
        if area > 3000:
            parts.append((slices[0].start, slices[1].start, slices))
    assert len(parts) == 16, (character, len(parts))
    # Row y spans are much smaller than inter-row gutters. Explicit crops are
    # necessary: generation does not promise an evenly spaced atlas grid.
    parts.sort()
    rows = [sorted(parts[i:i+4], key=lambda item: item[1]) for i in range(0,16,4)]
    parts = [part for row in rows for part in row]
    actor = manifest['actors'][character]
    frames = actor['frames'][:16]
    measured = []
    for sequence_index, (_, _, slices) in enumerate(parts):
        y0, y1 = slices[0].start, slices[0].stop
        x0, x1 = slices[1].start, slices[1].stop
        # Read a clean, identity-specific visor patch above the chest. Its fixed
        # position and the planted-foot baseline jointly register the actor.
        rgba = pixels[y0:y1,x0:x1].astype(float) / 255
        r,g,b,a = rgba.transpose(2,0,1)
        yy,xx = np.indices(a.shape)
        feature = (a > 0.5) & (yy < a.shape[0]*0.35)
        if character == 'ranger':
            feature &= (g > r*1.3) & (b > r*1.3) & (b > 0.35) & (g > 0.35)
            visor_target_x, visor_target_y = 2.8, -19.5
        else:
            feature &= (r > g*1.35) & (g > .22) & (r > .5) & (b < g*.5)
            visor_target_x, visor_target_y = 1.1, -20.5
        assert np.count_nonzero(feature) > 100, (character,sequence_index,'visor')
        feature_y, feature_x = np.where(feature)
        center_x, center_y = float(feature_x.mean())+x0, float(feature_y.mean())+y0
        retreat = sequence_index >= 8
        if retreat:
            visor_target_y += 2.0
        scale = (21.0 - visor_target_y) / (y1-center_y)
        # Crop padding leaves all original visible edge pixels intact.
        rect = [max(0,x0-2),max(0,y0-2),0,0]
        rect[2] = min(pixels.shape[1],x1+2)-rect[0]
        rect[3] = min(pixels.shape[0],y1+2)-rect[1]
        frame = {
            'rect': rect,
            'anchor': [round(center_x - visor_target_x/scale - rect[0],6),
                       round(y1 - 21.0/scale - rect[1],6)],
            'duration': .065,
            'texture': 'res://' + relative,
            'scale': round(scale,9)
        }
        if retreat:
            frame['shoulder'] = [0,-3]
            frames.append(frame)
        else:
            frames[sequence_index+4] = frame
        measured.append({'frame':sequence_index,'rect':rect,'scale':scale,'visor_count':int(np.count_nonzero(feature))})
    actor['frames'] = frames
    actor['animations']['run'] = [4,5,6,8,9,10,11,7]
    actor['animations']['backpedal'] = [23,22,21,20,19,18,17,16]
    actor['animation_modes']['backpedal'] = 'loop'
    actor['stride_distance'] = 64
    actor['stride_distances'] = {'run':64,'backpedal':48}
    report[character] = measured
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'tools/results/gait-v016/registration.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Registered 16 distinct locomotion frames per hero; all generated source pixels unchanged.')
