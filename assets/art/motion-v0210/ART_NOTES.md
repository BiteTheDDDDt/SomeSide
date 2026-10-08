# SomeSide v0.21.0 — supplemental animation poses

2026-10-08。使用内置 image_gen 工具，未使用 CLI。沿用已批准素材，新增姿态，不重做背景或实体造型。源 PNG 与 alpha 原样保存；UV 区域、脚底和攻击器官位置是外部元数据。每张导入限制 1024 像素长边；角色 AtlasTexture 区域换算导入尺寸，怪物及特效 UV 按源图比例采样。

- player-keys.png：两行三列，两名角色各三个新增姿态（起跳、最高点、落地），来源 exec-4046213c-70a1-4054-97b0-100669875a9b.png。
- enemy-keys.png：三种现有怪物各四个关节变化姿态，来源 exec-b6c4350a-9924-4e51-83ae-7dc8b97c305a.png。图集实际布局使用逐帧测量区域；喷吐口逐帧绑定现有权威发射点。
- fx-inbetweens.png：孢子、地刺各一个爆发过渡及一个破碎结束姿态，来源 exec-1d23125c-a1fb-4812-a850-2c80569820ab.png。与原有八帧合计各十张原画。
- 原始图集仍在 assets/art/unified-v0206 与 assets/fx/v0209。没有复制帧凑数；瞬移保留原八帧，仅重排两端节奏。

原画帧数、网格采样档位、动作时长和游戏帧率是不同概念：原画分别为角色每人新增三张、样例怪物每种新增四张、地面特效每种十张；网格缓存量化仍为 32 档。动作进度由秒数、实际位移和权威计时器驱动，不随渲染帧数累计。孢子/地刺伤害仍约 220ms，余效仍 200ms，阶段内采用不同帧时长且不跨阶段淡化。

## Full prompts

### player-keys.png

Use case: identity-preserve. Asset type: transparent game animation key pose atlas for SomeSide.
Input image is the APPROVED existing player atlas. Preserve EXACT identity, silhouette design, armor shapes, proportions, olive/cream ranger with rust scarf on first row, taupe heavy vanguard with blue scarf on second row; same hard edged illustrated shading, upper left light, same side view facing RIGHT. This is animation supplementation, NOT redesign.
Produce a clean EXACT 3 columns x 2 rows transparent RGBA atlas. Every cell same dimensions, same character scale across poses, no weapons (weapons independently aimed in game). Full bodies, generous transparent gutter, never cross a cell.
Each row has three NEW articulated poses of its same character:
column1 immediate takeoff extension, rear ankle pointed downward, front knee raising modestly, chest extending, pelvis lifting; NOT crouching anticipation.
column2 airborne apex, legs gathering loosely below hips, shoulders balanced, scarf rising slightly behind; distinctive from original tightly tucked falling pose.
column3 landing compression, BOTH soles on one identical ground baseline, knees bent, hips lowered, chest tilted slightly forward, stable head, hands tucked near original shoulder sockets. Important: genuine joint articulation, not squeezed image. Landing should be moderate, not extreme squat.
All pose hip horizontal anchors centered identically. Same head size and limb length as original. Keep shoulders near original height in first two poses and lower by modest amount landing. No muzzle, no weapon, no effects, no outlines added, no ground/shadow, no text/grid/borders. Background genuinely transparent. Match approved source precisely.

### enemy-keys.png

Use case: identity-preserve. Asset type: transparent supplemental game animation key pose atlas. Input image is the APPROVED SomeSide monster atlas. Do NOT redesign any monster. Only animate three existing creatures: crawler at TOP LEFT (olive low crouching pounce beast with muscular hindquarters, curling tail and two big front claws); spitter at TOP ROW SECOND (olive pear-shaped swollen abdomen, two short legs, curled feelers, trumpet tooth mouth); stone boss at BOTTOM ROW SECOND (huge taupe angular rocky gorilla, sloped boulder shoulders, small pointed head, enormous knuckles).
Create EXACT 4 equal columns x 3 equal rows, transparent RGBA, complete side view facing RIGHT in every cell. Row1 crawler, row2 spitter, row3 stone boss. Scale invariant within each row (same bone lengths, head size), generous gutters. SAME approved palette, hard edge two/three shading tiers, light upper left, muted charcoal shadows not black, same detail density. No effects, bullets, dust, shadows, floor, text or grid.
Four genuinely articulated key poses per row:
Crawler: 1 hindlegs deeply coiled with front claws planted, neck low; 2 explosive push-off hindlegs extending behind and front claws reaching forward, elongated articulated body without stretch; 3 contact foreclaws braced down under shoulders, hindlegs gathering; 4 recovering low ready stance tail relaxing.
Spitter: 1 recoil body behind planted feet, belly holding breath, trumpet closed slightly; 2 neck/mouth extended forward OPEN with upper and lower jaws separated and abdomen compressed by articulation; 3 short backward recoil after spit, jaw partly closing, feelers lagging; 4 abdomen and mouth settling to approved neutral profile.
Stone boss: 1 weight shifted onto rear leg, FRONT huge fist raised back near shoulder, knees flexed; 2 front fist clearly driven down to ground, rear shoulder counterrotated, torso leaning into blow; 3 BOTH knuckles supporting weight, head lowered, heavy compressed stance; 4 slow return of rear shoulder and head to approved neutral.
Not four stretched copies. Maintain original identity and anatomy, claws, limbs, eyes, color. For grounded poses all support feet/knuckles share a fixed baseline at 92 percent of their cell height. Head/hip centered consistent each row, intentional reach from actual joints only. Transparent background.

### fx-inbetweens.png

Use case: identity-preserve. Asset type: supplemental transparent animation cells for SomeSide selected spore A and stone spike C. The two reference sheets are APPROVED artwork; keep EXACT design, colors, broad hard edge shading, upper left light, proportions, materials, detail density. Do not reinvent effects.
Produce EXACT 2 columns x 2 rows transparent RGBA sheet. Uniform equal cell dimensions, same ground baseline at 92% cell height, same footprint width within each row, generous gutter, no cell overlap.
TOP ROW, olive spore A:
left NEW burst in-between: two thick fleshy husk lobes just peeled apart, narrow rising split at center and first few short teardrop seeds escaping, a distinct EARLY explosive rupture between sealed pod and tall existing splash, NOT a closed seed or full height splash.
right NEW ending pose: husk lobes fully separated into three disconnected flat curled scraps, airborne droplets already absent, small scattered disconnected seeds lying close to ground, no intact pod or complete boundary.
BOTTOM ROW, taupe layered ground spikes C:
left NEW rising in-between: two substantial angled slabs halfway thrust upward, front low slabs tilted out, central blade angled rather than vertical, distinct from existing first burst and peak, same rock faceting.
right NEW ending pose: main blade broken into 4 disconnected short shards falling at low height, loose separated flat rubble, no continuous wall or pointed full-height spires.
No warning rings, no glow, no particles outside fixed footprint, no black outline or backdrop, no floor, no shadow, no text, no frame borders. Actual alpha transparent background. Preserve approved style; this is timing support, not concept variants.
