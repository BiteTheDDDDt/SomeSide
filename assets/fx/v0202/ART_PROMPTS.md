# Material-specific attack sprites — v0.20.2

Generated with the built-in `image_gen` tool and `transparent_background=true`. The original 1254 × 1254 RGBA PNG bytes are preserved; no pixel edits, background removal, or image resampling were applied. Godot imports each sheet once with a 1024 pixel size limit. Manifest rectangles select the observed nonuniform row positions, while fixed per-frame anchors and reference dimensions map the visible physical body onto the requested game footprint. The new sheets use nearest filtering; the six existing player-effect sheets retain their filtering. Multiple animation families share each imported texture, so the complete active cache remains eight textures / at most 32 MiB RGBA.

These are two distinct materials for every attack: quiet physical preparation and substantial active matter. No warning circles, path lines, wide fog fields, or generic fire vortices are present. All active frames retain visible matter instead of fading to empty during a damaging window.

Source directory: `C:/Users/pxl29/.codex/generated_images/01a110ee-6b29-78c0-9461-52646a32a5c6/`.

## Terrain atlas

Original tool output: `exec-d3f7d3d2-9ae7-486b-8853-49618a03b342.png`, copied as `terrain.png`. Rows: `spore_ready`, `spore_hit`, `stone_ready`, `stone_hit`, `earth_ready`, `earth_hit`.

Complete prompt:

```text
Use case: stylized-concept. Asset type: production transparent PIXEL ART sprite sheet for a side-view action game. Exactly FOUR COLUMNS and SIX ROWS, 24 distinct sprites in an evenly spaced 4x6 grid, square 1024x1024 canvas requested. Each row is four chronological frames of ONE effect. Genuine transparent background; no checkerboard, black background, labels, numbers, borders or grid lines. Clear empty gutters between all cells. Flat orthographic side view. Crisp chunky pixel-art clusters, deliberately small limited palettes, dark deep-purple contour around substantial objects, no smooth painterly gradients, no blurry smoke, no lens glow. Stable cell center and stable ground baseline 80% down every cell. Keep artwork fully inside each cell with 15% left/right and 12% top/bottom empty margins. No object crosses a cell boundary. Terrain materials must look physical and belong to a rocky alien landscape.
ROW 1: Four low, CLOSED green spore buds / seed sacs peeking out of the soil, slowly trembling and swelling. Dull olive and purple, no splashing or glow. Compact low silhouette. This is harmless preparation.
ROW 2: The same spores now violently burst upward into four successive sharp ACID SPLASH frames. Bright lime/yellow solid droplets with deep purple contours and pointed irregular splashes; substantial opaque dangerous material, no green fog, no circular explosion.
ROW 3: Four low stony fractures in the ground with a few short dull purple-gray stone shards emerging. Harmless trembling preparation, entirely low and flat.
ROW 4: Four frames of those fractures erupting into TALL jagged angular STONE SPIKES. Purple-gray opaque rock, pale lilac cutting edges, large solid sharp physical silhouettes. First frame spikes already tall, later vary chips and height subtly. No fire.
ROW 5: Four low heaps of trembling BROWN DIRT CLODS and a few tiny tossed pebbles. Harmless low earth disturbance, no dust cloud.
ROW 6: Four frames of a violent chunky soil eruption with brown and ochre ROCKS tossed upwards, angular soil fragments, short broad substantial column. Dominantly opaque rocks, no fluffy smoke, no bright fire.
Every row exactly 4 cells, exactly 6 rows. Readability at tiny 40px game scale matters. Strong visual difference between low dim preparation rows and tall solid active attack rows. Effects are sprites, never diagrammatic rings, lines, dashes, warning symbols, arrows or magical circles.
```

## Selected terrain revision

The first terrain atlas contained a soil foundation under spores, which was unsuitable for hazards that can lock onto an airborne target. A targeted built-in edit replaced those two rows with independent closed spore sacs and complete floating acid splats. This is the active atlas `terrain-v2.png`; the original `terrain.png` remains solely as provenance and is excluded from export. Both preserve original tool PNG bytes. The manifest was remeasured against the final source rather than assuming a uniform grid. Row 2 ends at source y=503, before the first stone fracture pixels; no flat cut edge is introduced.

Original tool output: `exec-79e63dc1-1872-451f-b86b-fb53a9eb4afd.png`. Edit reference: `E:/workplaces/opensource/gamedev/SomeSide/assets/fx/v0202/terrain.png`.

Complete edit prompt:

```text
Use case: precise-object-edit. Edit target: attached transparent pixel-art terrain sprite atlas. Make ONE targeted change: replace ONLY the first TWO ROWS (top eight sprites) with free-floating biological spore effects. Keep rows 3, 4, 5 and 6 and their rock/dirt sprites, positions, palette and shapes unchanged. Preserve genuine transparency, canvas layout, exactly four sprites in every row, exactly six rows, generous transparent gutters. Preserve crisp pixel-art style, dark-purple contours and small clustered highlights.
TOP ROW: four chronological CLOSED FLOATING SPORE SACS / seed pods, no soil, no rocks, no roots, no flat base. Dull olive-lime green ovoid seed suspended in empty transparent space. Compact closed benign preparation silhouette, subtle swelling only, about same small size in all 4. Stable center in each existing cell. No luminous aura.
SECOND ROW: four full strong ACID SPLAT BURSTS floating in empty transparent space, matching the same olive/lime spores. Irregular jagged splash in all directions around a bright lime/yellow opaque central liquid mass, with several substantial pointed droplets around it. No ground or rocks under or around the splash, NO horizontal foundation, no stump, no flat cut edge. A complete isolated splash silhouette including lower droplets. Each of the FOUR frames must already be fully dangerous, with substantial opaque bright liquid occupying most of the sprite's width AND height. Keep near-identical overall size in all four while sharp splash arms and droplets animate. Bright acidic lime/yellow-green and dark purple contour, do not change hue between frames. No fog, no smoke, no fire, no rings, circles, lines, markers or diagrams. Keep first row visibly quieter, darker, closed, compact; second row visibly open, bright, sharp, solid and damaging.
All other sixteen rocky and earthy sprites in rows 3–6 must remain as before. Do not add text or grid lines. Do not add a background. Keep every sprite complete and separate.
```

## Energy atlas

Original tool output: `exec-201d5b82-378c-4a27-aa84-f8bafee804c9.png`, copied as `energy.png`. Rows: `emitter`, `laser`, `rift`, `repair`, `spore_shot`, `crystal_shot`.

Complete prompt:

```text
Use case: stylized-concept. Asset type: production transparent PIXEL ART sprite sheet for a side-view action game. Exactly FOUR COLUMNS and SIX ROWS, 24 distinct sprites in evenly spaced 4x6 grid on square 1024x1024 canvas requested. Every row shows four chronological animation frames of ONE effect. Genuine transparent background; no checkerboard, background color, labels, numbers, borders or grid lines. Generous empty gutters. Each sprite stays entirely inside its cell with at least 12% transparent margins. Flat orthographic side view, crisp chunky pixel clusters and limited palettes, hard readable silhouettes with deep purple shadows; no photorealism, no painterly smoke, no blur or ambient glow.
ROW 1: Four compact small angular energy nuclei at the center of each cell, gathering from several purple fragments into a tight amber/coral seed. This is emitter preparation attached to a monster's mouth. Stage1 dim violet flecks, stage2 small violet knot, stage3 small purple/coral core, stage4 compact bright coral core. No rings, expanding halo, flame or giant explosion.
ROW 2: Four active laser frames pointed horizontally RIGHT. A thick SOLID WHITE HOT CORE with coral/purple angular ragged hot edges, horizontal and long, about 72% of cell width and 20% of cell height. Ends fit inside the cell. Visibly substantial lethal energy, no thin targeting line, no diffuse mist, no round aura, no fireball. Same length and axis in each frame, subtle changing jagged edge.
ROW 3: Four narrow vertical VIOLET TORN FISSURES opening. Jagged purple crack with pale violet interior, thin sharp solid edges, irregular torn silhouette, no ring, no circle, no orange color, no fiery vortex. Vertical rectangular aspect about 1:2.5.
ROW 4: Four compact MINT-GREEN angular healing-mote clusters that coalesce into a small faceted green pulse, 3-5 substantial diamond chips per frame. No ring or circle, no fiery vortex, no orange.
ROW 5: Four solid bright green SPIT SEED / ACID GLOB frames pointed RIGHT, opaque lime body with dark purple contour and small olive ragged trailing clumps. Compact egg-shaped side-view material, not smoke, no circular aura. Stable center.
ROW 6: Four solid sharp CRYSTAL projectile frames pointed RIGHT: a long pointed purple/coral diamond, pale coral tip and amethyst rear facets, dark-purple contours. Distinct from the green seeds. Stable center.
Exactly 6 rows and exactly 4 sprites in every row. Cohesive pixel-art game palette, each row visually distinct at 24px game scale. No weapons, characters or scene. Transparent margins around every sprite.
```
