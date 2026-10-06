# SomeSide v0.20.0 attack FX source record

Generated using the built-in `image_gen` tool with `transparent_background=true`. Original selected PNG bytes and generated alpha are preserved. No Python or other image pixel editing was used. Godot imports selected sheets at a maximum of 1024 × 1024; the source files are 1254 × 1254. Runtime draws stable manifest rectangles/anchors and never creates a texture per frame. Six active sheets, 48 distinct frames, 24 MiB RGBA imported texture budget; no mipmaps.

The initial tool request specified 1024², but the delivered source is 1254². The final manifest records actual coordinates. Early burst.png and wave.png are retained as unselected generation history; burst-v2.png and wave-v2.png correct crowded original layouts. Missile, wave and aura were edited using the built-in image tool into a cool friendly palette; the source warm variants remain at the recorded generation folder. Generated components were visually inspected and alpha/crop boundaries checked. Phase selection uses replicated game timers. Charge/burst are one-shot progress; missile/wave/aura retain a visible core for their whole loop. Missile anchor is the mechanical warhead center, wave anchor is the leading blade, and body-centred families use the emitter / clear central opening.

Generation folder: `C:/Users/pxl29/.codex/generated_images/01a1080d-1a01-73c3-9b02-8f618babf857/`.

## charge

Selected raw tool output: `exec-6659a808-c8c7-4262-bcf3-82ae550a38a6.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D side-scrolling sci-fi game VFX sprite sheet. Create a genuinely transparent PNG sprite atlas, exactly 1024 x 1024 pixels. Fine pixel-painted / hand-painted game FX: crisp irregular clusters with rich internal turbulence and controlled luminous edges, highly readable at small game scale; NOT flat vector icons, NOT circles/lines/radar diagrams. No labels, no border, no grid, no background, no checkerboard artwork, no floor, no characters. Exactly eight sequential animation frames, laid out in a perfectly regular FOUR COLUMNS by TWO ROWS grid. Each invisible cell is 256x512 pixels. The visual is centered at identical cell-local coordinate (128,256). All pixels must stay within central 224x224 square of each cell, with empty transparent gutters. Reading order left-to-right top row then bottom row. Every cell has ONE complete isolated effect, same camera, same stable anchor and same scale convention. Eight smoothly connected, meaningfully different time steps, not unrelated variants. Do not shift each effect's center between frames. SUBJECT: a warm ivory and amber plasma gathering animation. Eight stages from sparse curving ember wisps, to denser spiral inward ribbons, to a compressed textured white-hot nucleus with frayed orange corona and tiny sparks. The visual grows more concentrated and powerful toward final cell; final nucleus retains recognizable texture rather than a white solid disk. No complete circular outlines or schematic rings. Frame 1 10% gathered, 2 20%, 3 35%, 4 50%, 5 65%, 6 80%, 7 92%, 8 fully charged.
```

## burst

Selected raw tool output: `exec-899d1f3f-cd98-467f-8e70-162216d107b6.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D side-scrolling sci-fi game VFX sprite sheet. Create a genuinely transparent PNG sprite atlas, exactly 1024 x 1024 pixels. Fine pixel-painted / hand-painted game FX: crisp irregular clusters with rich internal turbulence and controlled luminous edges, highly readable at small game scale; NOT flat vector icons, NOT circles/lines/radar diagrams. No labels, no border, no grid, no background, no checkerboard artwork, no floor, no characters. Exactly eight sequential animation frames, laid out in a perfectly regular FOUR COLUMNS by TWO ROWS grid. Each invisible cell is 256x512 pixels. The visual is centered at identical cell-local coordinate (128,256). All pixels must stay within central 224x224 square of each cell, with empty transparent gutters. Reading order left-to-right top row then bottom row. Every cell has ONE complete isolated effect, same camera, same stable anchor and same scale convention. Eight smoothly connected, meaningfully different time steps, not unrelated variants. Do not shift each effect's center between frames. SUBJECT: organic spore impact / energy explosion animation. A pale creamy core with warm ochre and mossy neutral smoke lobes, ragged luminous shards, many detailed tiny flecks. First cell compact impact ignition, second flash, third erupting irregular starburst, fourth largest billowing organic explosion, fifth lobes fragment, sixth dispersing curling dust, seventh sparse glowing pieces, eighth dim dissipating wisps. Painterly fine pixel texture, not a geometric star or circle. Keep color mostly warm cream so runtime green/orange tints stay usable.
```

## missile

Selected raw tool output: `exec-441d07db-c2d1-47c9-bc30-94206aacdbc5.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D side-scrolling sci-fi game VFX sprite sheet. Create a genuinely transparent PNG sprite atlas, exactly 1024 x 1024 pixels. Fine pixel-painted / hand-painted game FX: crisp irregular clusters with rich internal turbulence and controlled luminous edges, highly readable at small game scale; NOT flat vector icons, NOT circles/lines/radar diagrams. No labels, no border, no grid, no background, no checkerboard artwork, no floor, no characters. Exactly eight sequential animation frames, laid out in a perfectly regular FOUR COLUMNS by TWO ROWS grid. Each invisible cell is 256x512 pixels. The visual is centered at identical cell-local coordinate (128,256). All pixels must stay within central 224x224 square of each cell, with empty transparent gutters. Reading order left-to-right top row then bottom row. Every cell has ONE complete isolated effect, same camera, same stable anchor and same scale convention. Eight smoothly connected, meaningfully different time steps, not unrelated variants. Do not shift each effect's center between frames. SUBJECT: a small detailed sci-fi seeker missile projectile pointing horizontally RIGHT, actual dark steel/ivory ceramic casing, pointed nose at right, brass collar, two clearly defined small swept fins, narrow amber exhaust plume trailing left with irregular flame tongues. Missile's mechanical body fixed at center (128,256) in each cell, same identical silhouette and dimensions. Only the exhaust flickers and contracts/extends across eight smoothly loopable frames. Body length about100px; entire body+exhaust span 210px max, height80px max. NOT a glowing orb, NOT an arrow icon.
```

## wave

Selected raw tool output: `exec-8da2c494-3ab1-41dc-8f3d-d1eaf3e5998f.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D side-scrolling sci-fi game VFX sprite sheet. Create a genuinely transparent PNG sprite atlas, exactly 1024 x 1024 pixels. Fine pixel-painted / hand-painted game FX: crisp irregular clusters with rich internal turbulence and controlled luminous edges, highly readable at small game scale; NOT flat vector icons, NOT circles/lines/radar diagrams. No labels, no border, no grid, no background, no checkerboard artwork, no floor, no characters. Exactly eight sequential animation frames, laid out in a perfectly regular FOUR COLUMNS by TWO ROWS grid. Each invisible cell is 256x512 pixels. The visual is centered at identical cell-local coordinate (128,256). All pixels must stay within central 224x224 square of each cell, with empty transparent gutters. Reading order left-to-right top row then bottom row. Every cell has ONE complete isolated effect, same camera, same stable anchor and same scale convention. Eight smoothly connected, meaningfully different time steps, not unrelated variants. Do not shift each effect's center between frames. SUBJECT: a travelling shock wave / blade of force pointing to the RIGHT. A tall curved broken crescent of pale white-hot compressed energy with rich amber turbulent fluid streaks streaming left from its two tips and hollow ragged inner wake. Eight smoothly loopable living animation frames of the same crescent; it stays centered and does not move across cell. Tall about200px, width150px. The crescent should have substantial textured thickness, torn feathery internal streaks and lively wisps, never a plain smooth arc, line or vector C.
```

## aura

Selected raw tool output: `exec-b11bceda-41fd-4314-a47b-39549ca137e0.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D side-scrolling sci-fi game VFX sprite sheet. Create a genuinely transparent PNG sprite atlas, exactly 1024 x 1024 pixels. Fine pixel-painted / hand-painted game FX: crisp irregular clusters with rich internal turbulence and controlled luminous edges, highly readable at small game scale; NOT flat vector icons, NOT circles/lines/radar diagrams. No labels, no border, no grid, no background, no checkerboard artwork, no floor, no characters. Exactly eight sequential animation frames, laid out in a perfectly regular FOUR COLUMNS by TWO ROWS grid. Each invisible cell is 256x512 pixels. The visual is centered at identical cell-local coordinate (128,256). All pixels must stay within central 224x224 square of each cell, with empty transparent gutters. Reading order left-to-right top row then bottom row. Every cell has ONE complete isolated effect, same camera, same stable anchor and same scale convention. Eight smoothly connected, meaningfully different time steps, not unrelated variants. Do not shift each effect's center between frames. SUBJECT: an animated ambient energy aura surrounding an EMPTY CLEAR CENTER. Eight smooth looping phases of separate flame-like pale cream/amber wisps rising and orbiting a central transparent gap, loose roughly round silhouette with broken asymmetrical tendrils and tiny embers. Center opening at least80px diameter remains actually transparent, outer extent about200px. A tactile ethereal fire veil, NOT a mathematically circular ring, NOT a shield outline, NOT concentric rings or a glyph. Keep volume irregular but evenly centered, frame8 loops naturally to frame1.
```

## beam

Selected raw tool output: `exec-660322c1-8806-4fcf-8cd5-da3ca564f821.png`.

Initial prompt (verbatim):

```text
Use case: stylized-concept. Asset type: production 2D sci-fi game animated laser texture. Create a genuinely transparent PNG sprite atlas EXACTLY 1024 x 1024 pixels, exactly TWO COLUMNS by FOUR ROWS, eight equal 512x256 invisible cells, read left-to-right then next row. Each cell contains ONE horizontal laser pointing RIGHT, centered on cell-local y=128. Beam begins at x=24 and ends at x=488; all texture must stay inside x16..496 and y68..188, with clean transparent gutters. Eight smoothly connected animation frames: 1 ignition thin ragged stream, 2 rapidly opening brighter jet, 3 broad full-power beam, 4 full-power turbulent ribbons, 5 bright braided flow, 6 thinning energy, 7 fragmented weak discharge, 8 final wispy residual discharge. Fixed start/end anchors across all8. Fine hand-painted pixel energy texture, warm pale ivory hot core with amber/orange edge filaments, braided streaks, cloudy energetic turbulence, uneven torn silhouette and tiny attached spark tongues. A textured plasma current, not a straight rectangular bar or vector line, not perfect geometric shapes. Beam must remain visually horizontal and not curved overall. No muzzle objects, no targets, no scene, no labels, no grid, no borders, no checkerboard art, only eight isolated transparent VFX frames.
```

## Friendly palette edit

Applied separately to missile, wave and aura, referencing their warm first output. Warm source files: exec-387d6576-1d16-4c7f-b0f9-4b561cfd6265.png, exec-c30467ff-3bc1-4eff-b469-4e5ffcd82140.png, exec-7be632fd-07ed-44bd-aa52-183033fb7bf6.png.

```text
Edit this exact transparent game VFX sprite sheet. Preserve EXACTLY its eight frames, positions, silhouettes, anchors, internal detail, mechanical body where present, canvas size and transparency. Change ONLY the luminous warm orange/amber energy and flames into cool cyan/ice-blue energy with a pale neutral white core. Keep dark metal neutral gray. No orange fire remains. Do not add anything, do not move, rescale or rearrange cells. All eight frames remain continuously visible and smoothly loopable. Keep true alpha transparency.
```

## Layout correction

Applied separately to burst.png and cool wave.png to create selected burst-v2.png / wave-v2.png, preserving originals. Exact prompt:

```text
Edit this transparent eight-frame game VFX sheet. Keep the same effect identity, detailed painted energy texture, palette and eight-frame temporal order. Crucial production correction: REARRANGE into EXACTLY TWO COLUMNS by FOUR ROWS on a 1024x1024 transparent canvas. Each cell512x256. Shrink each entire effect proportionally to fit entirely inside a 210x210 square, centered EXACTLY at each cell center (256,128), (768,128), (256,384), (768,384), (256,640), (768,640), (256,896), (768,896). No visible effect pixels may come within20px of its cell's top or bottom, or within100px of its cell's left or right edges. VERY WIDE EMPTY TRANSPARENT GUTTERS between sprites. Preserve relative growth/dissipation of the burst if present; do not normalize early tiny burst to big size. For a crescent, preserve a continuously substantial core in all8frames; it loops and doesn't vanish. Entire each effect must be separated from all neighbors with transparent space. No labels, no grid, no dividers. Preserve true alpha, no background or checkerboard. Do NOT crop a frame at any edge.
```
