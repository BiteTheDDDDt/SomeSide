# Natural warning materials — v0.20.1

Generated with the built-in `image_gen` tool, `transparent_background=true`. Selected original PNG bytes and alpha are preserved. No raster pixel edits or external image editing were used. Each original is 1254 × 1254 despite the requested 1024²; Godot's one-time import size limit is 1024². The two new sheets add 8 MiB, bringing all 8 active sheets / 64 frames to 32 MiB RGBA. Manifest rectangles and fixed anchors use original source coordinates; runtime sampling applies normalized UVs against the imported texture. There is no per-frame texture creation.

`ion_stream` is a broad filled, translucent, irregular plasma-vapor warning along the locked attack axis. Its eight frames progressively concentrate internally, without any geometric center line, capsule or edge outline. `dust_cloud` is a filled neutral near-square dusty volume, suitable for tinted area hazards and overlapping low ground disturbances. Both remain visible at the minimum FX level; geometry and lifetime remain authority-authored. The charge lane uses three unequal overlapping cloud instances, not repeated markers.

Source folder: `C:/Users/pxl29/.codex/generated_images/01a1080d-1a01-73c3-9b02-8f618babf857/`.

## ion_stream

Raw tool output: `exec-22497cb5-ca71-4cab-93a9-1e6a3a11be17.png`. Saved in this folder as `ion-stream.png`.

Complete generation prompt:

```text
Use case: stylized-concept. Asset type: production game VFX animation sprite atlas. Genuine transparent PNG, exactly 1024x1024 requested. EXACTLY 8 sequential frames in TWO COLUMNS by FOUR ROWS regular grid. No labels, grid, borders, background or checkerboard art. Each cell 512x256. Each sprite has identical center at cell-local (256,128), stays wholly within x24..488 and y42..214. Transparent generous gutters separate every cell. Direction is horizontal, +X to the RIGHT. Fine detailed hand-painted energy/dust for side-scrolling 2D game. Organic irregular textured material, broken wisps and soft but crisp readable contours, NOT vector artwork. No straight line, no laser beam core, no concentric circles, no outlined rings, no capsule boundary, no arrows, no glyphs, no repeated icons. Temporal order reads left-to-right then next row; 8 smoothly connected frames of one effect, no unrelated variants. All frames must retain a visible continuous footprint across nearly full width, with soft tapered ragged ends, but do not include solid background color. SUBJECT: a wide ribbon of translucent IONIZED VAPOR in deep amber / copper / pale cream. This is the warning BEFORE a laser fires: flowing smoky volume and curling cloud billows pulled toward the LEFT edge emitter, no visible emitter object. Frame1 broad sparse smoky ribbon; frame2 accumulating rolling ion clouds; frame3 cloudy curls pulled left; frame4 denser energetic cloud currents; frame5 tighter branching ribbons within the cloud; frame6 concentrated pale plasma filaments woven through cloud; frame7 tense luminous wisps; frame8 fully charged finely textured vapor with pale cream tendrils. The broad mist footprint stays about140px tall in ALL8; concentration occurs INTERNALLY, not by turning the whole strip into a thin line. The center must remain softly irregular, never a straight white line. Internal bright filaments curve, turn and branch, no long straight lines. Detailed feathered translucent plume, quiet at frame1 and clearly stronger at frame8. Entire sprite visible; keep clean alpha gutters.
```

## dust_cloud

Raw tool output: `exec-78ef95dc-ab82-440c-b157-7ae541ad34bc.png`. Saved in this folder as `dust-cloud.png`.

Complete generation prompt:

```text
Use case: stylized-concept. Asset type: production 2D game VFX sprite animation atlas. Generate genuine transparent PNG, 1024x1024 requested. EXACTLY EIGHT sequential frames, TWO COLUMNS by FOUR ROWS regular grid. Cell512x256. Each cloud centered EXACTLY at cell-local(256,128). Keep entire sprite within central220x220 square with >=18px transparent gutter top/bottom and >=140px gutter left/right. ONE near-square irregular dusty cloud per cell, not a horizontal strip. No background/checkerboard, no labels/grid/borders. Subject: eight smoothly connected looping phases of a tangible ground DUST CLOUD / SPORE MIST VOLUME: pale gray cream and soft desaturated warm taupe, many curling lacy billows, tiny gritty motes, irregular ragged silhouette and layered semi-transparent density. Filled center contains detailed gently turbulent dust, not a transparent hole. All eight maintain similarly broad area and visible volume, not fade to empty. Cloud organically swells and circulates with slight changes in lobes; same stable center. Fine hand-painted game sprite texture, cohesive across frames, no fire, no bright star core, no energy ring, no perfect circle, no glyph, no vector line or target mark. Main volume about200px wide x190px tall, entire fringe fits220x220. Do not crowd rows. Frames1..8 smoothly loop as a cloud being disturbed from below, then slowly curling inward.
```
