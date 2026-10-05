# SomeSide v0.16 locomotion artwork

Generated with the built-in imagegen tool on 2026-10-05. The selected PNGs are copied byte-for-byte with original RGBA alpha; there is no image painting, background replacement, resampling, or Python pixel editing. Python only reads alpha/visor geometry to write crop, scale, and anchor metadata; Godot performs the existing logical-pixel bake.

## Selected files

- `ranger-locomotion-v3.png`: `C:/Users/pxl29/.codex/generated_images/01a1080d-1a01-73c3-9b02-8f618babf857/exec-5ebaaf51-7d55-4171-bfe8-0774e275cf25.png`
- `vanguard-locomotion-v3.png`: `C:/Users/pxl29/.codex/generated_images/01a1080d-1a01-73c3-9b02-8f618babf857/exec-c22d7183-44da-47c0-b1ad-855317581dbe.png`

Each source contains sixteen authored poses in four rows of four: eight running poses, eight lower retreat poses. The former v2 sheets still supply idle, rise, fall, dash, and landing. Their original run frames are not selected by the manifest. New source sheets are each 1254×1254, with eight source textures total below the unchanged 64MiB budget.

## Diagnosis and registration

The original eight-frame forward loop repeatedly put the same bright near leg ahead of the dark far leg, and reverse travel only played that loop backwards. This obscured which leg supported the character. Native rendering also compared ordinary bodies with the attack upper-body split in 96 cases: lower-body pixels matched exactly, so the extra-leg impression was not a duplicated draw or atlas-region bleed.

Early generated versions repeated this anatomy error and were rejected. Subsequent edits specifically exchanged near/far leg ownership, then added distinct planted, passing, and lifted-foot poses instead of repeated split stances. Head/visor registration plus a shared foot baseline keep body scale and the weapon attachment stable. Explicit per-frame crops exclude neighbouring cells; all source alpha is preserved.

The source grid is not blindly treated as chronological: forward clips use source order 0,1,2,4,5,6,7,3 so the lifted near foot returns through extension rather than jumping from forward extension straight to rear contact. The dedicated compact retreat poses run in source order 15..8 so planted feet sweep forward relative to the body during backward travel. This is a separate source animation, not the former reversed forward cycle. Phase advances by visible distance: forward stride 64 world pixels, retreat stride 48; switching between them retains the normalized contact phase. These remain small, eight-pose pixel sprites rather than motion-captured anatomical animation.

## Initial prompts

### Ranger

Reference: `ranger-v2.png`.

```text
Use case: identity-preserve. Asset type: transparent pixel-art animation sprite sheet for the 2D game SomeSide. Input image 1 is the existing character identity reference, NOT a pose-sequence model. Create a NEW precisely organized square 4-column x 4-row sprite sheet, exactly 16 full-body poses, on genuine transparent alpha. Prefer 1280x1280 pixels. Read left-to-right across each row. All 16 figures face RIGHT in clear side view and have the same body proportions, head height, helmet and shoulder registration, feet baseline, and scale. Each cell has ample transparent gutters; no cells touch. No labels, no text, no frame boxes, no shadows on the ground, no motion blur or ghost silhouettes, no weapons or effects.

The most important requirement is correct TWO-LEGGED HUMAN LOCOMOTION. Each figure has exactly two legs, two knees, two boots; no third leg, no repeated phantom limb, no extra ankle. The nearer leg is light and the farther leg is distinctly shadowed. The near and far leg take turns going in front and behind. Do NOT redraw the same light leg always sticking forwards! Maintain clean negative space between the legs. Use crisp limited-palette pixel-art edges and broad readable armor clusters, not soft rendering.

Frames 0-7, the upper two rows: FORWARD RUN to the right. Author one complete eight-frame gait, not two repeated four-frame loops: 0 near leg forward heel contact and far leg extended back; 1 near leg supports under the body and far heel lifts behind; 2 near leg moves behind as the far knee passes forward; 3 near leg pushes off behind and far knee extends forward; 4 FAR leg forward heel contact and NEAR leg extended behind (opposite of frame 0); 5 far leg supports under body and near heel lifts behind; 6 far leg moves behind as near knee passes forward; 7 far leg pushes off behind and near knee extends forward. Clear alternating near/far leg occlusion and slight running lean.

Frames 8-15, lower two rows: BACKPEDAL moving LEFT while still facing RIGHT, a distinct eight-frame retreat animation, not a reversed forward run. Slightly lower guarded stance, short quick backward steps, knees bend more, torso upright with weight settling toward the rear. Boots still point right. 8 near foot reaches back left with toe contact, far foot supports in front; 9 near foot plants as far heel lifts; 10 far knee tucks passing the near leg; 11 far foot reaches backward; 12 FAR foot contacts back left and NEAR foot supports in front (opposite frame 8); 13 far foot plants while near heel lifts; 14 near knee tucks passing the far leg; 15 near foot reaches backward again. Both complete cycles must remain readable at a 50-pixel tall in-game body.

Keep the arms tucked close to the torso at a calm waist-level ready pose, empty hands, because the game renders aimed weapon and attacking arms separately. Keep the reference helmet identity, silhouette, backpack, armor material, and character palette unchanged.
Character-specific invariant: RANGER: ivory helmet and armor, vivid cyan glass visor, dark desaturated teal undersuit and backpack, orange short scarf.
```

### Vanguard

Reference: `vanguard-v2.png`.

```text
Use case: identity-preserve. Asset type: transparent pixel-art animation sprite sheet for the 2D game SomeSide. Input image 1 is the existing character identity reference, NOT a pose-sequence model. Create a NEW precisely organized square 4-column x 4-row sprite sheet, exactly 16 full-body poses, on genuine transparent alpha. Prefer 1280x1280 pixels. Read left-to-right across each row. All 16 figures face RIGHT in clear side view and have the same body proportions, head height, helmet and shoulder registration, feet baseline, and scale. Each cell has ample transparent gutters; no cells touch. No labels, no text, no frame boxes, no shadows on the ground, no motion blur or ghost silhouettes, no weapons or effects.

The most important requirement is correct TWO-LEGGED HUMAN LOCOMOTION. Each figure has exactly two legs, two knees, two boots; no third leg, no repeated phantom limb, no extra ankle. The nearer leg is light and the farther leg is distinctly shadowed. The near and far leg take turns going in front and behind. Do NOT redraw the same light leg always sticking forwards! Maintain clean negative space between the legs. Use crisp limited-palette pixel-art edges and broad readable armor clusters, not soft rendering.

Frames 0-7, the upper two rows: FORWARD RUN to the right. Author one complete eight-frame gait, not two repeated four-frame loops: 0 near leg forward heel contact and far leg extended back; 1 near leg supports under the body and far heel lifts behind; 2 near leg moves behind as the far knee passes forward; 3 near leg pushes off behind and far knee extends forward; 4 FAR leg forward heel contact and NEAR leg extended behind (opposite of frame 0); 5 far leg supports under body and near heel lifts behind; 6 far leg moves behind as near knee passes forward; 7 far leg pushes off behind and near knee extends forward. Clear alternating near/far leg occlusion and slight running lean.

Frames 8-15, lower two rows: BACKPEDAL moving LEFT while still facing RIGHT, a distinct eight-frame retreat animation, not a reversed forward run. Slightly lower guarded stance, short quick backward steps, knees bend more, torso upright with weight settling toward the rear. Boots still point right. 8 near foot reaches back left with toe contact, far foot supports in front; 9 near foot plants as far heel lifts; 10 far knee tucks passing the near leg; 11 far foot reaches backward; 12 FAR foot contacts back left and NEAR foot supports in front (opposite frame 8); 13 far foot plants while near heel lifts; 14 near knee tucks passing the far leg; 15 near foot reaches backward again. Both complete cycles must remain readable at a 50-pixel tall in-game body.

Keep the arms tucked close to the torso at a calm waist-level ready pose, empty hands, because the game renders aimed weapon and attacking arms separately. Keep the reference helmet identity, silhouette, backpack, armor material, and character palette unchanged.
Character-specific invariant: VANGUARD: broad sturdy proportions, pale warm gold armored helmet and plates, amber orange glass visor, dark charcoal navy undersuit, blue teal short scarf and backpack. Exactly the same character as reference, not a new robot.
```

## Near/far-leg corrections

### Ranger

```text
Use case: precise-object-edit. Correct ONLY the LEG ANIMATION in the provided Ranger sprite atlas. Preserve the canvas size, alpha, 4x4 grid, ALL helmets, torsos, hands, scarves, backpacks, identities, and scales exactly. This sheet currently has the SAME LIGHT NEAR LEG IN FRONT in nearly every cell, so when animated it looks like three legs fluttering instead of alternating. This MUST be corrected. Do not merely recolor the existing legs.
Rows 1 and 3 remain unchanged. In ALL FOUR CELLS of ROW 2 and ALL FOUR CELLS of ROW 4, REDRAW BOTH LEGS in the OPPOSITE LEG PHASE: the large bright teal foreground thigh connects from the visible right hip DIAGONALLY BACK LEFT, and its cream shin/boot must be at the LEFT or tucked under the rear of the body. The dark shadowed far-side thigh connects behind the pelvis and reaches FORWARD RIGHT; its dark shin and boot appear on the RIGHT. So the row2 and row4 light near knee is on the LEFT and the dark far knee is on the RIGHT, opposite the rows above. The foreground bright leg must cross IN FRONT of the dark far leg, not emerge from it. Exactly two hips, two connected leg chains, two boots, never a third limb. In row2 column1, draw the bright near leg clearly straight back-left, dark far leg heel contacting front-right. Row2 column2 bright near leg bent backward-left, far leg planted. Row2 column3 bright near knee passing from left under body, far leg sweeping behind. Row2 column4 bright near knee lifts forward and dark far foot pushes off behind. Row4 follows the same near/far interchange but with compact backward-stepping footwork. This one anatomical correction has priority over retaining the old legs. No effects/text/shadows. Transparent alpha, pixel-art clusters. All other pixels and layout preserved.
```

### Vanguard

```text
Use case: precise-object-edit. Correct ONLY the LEG ANIMATION in the provided Vanguard sprite atlas. Preserve the canvas size, alpha, 4x4 grid, ALL helmets, torsos, hands, scarves, backpacks, identities, and scales exactly. This sheet currently has the SAME GOLD NEAR LEG IN FRONT in nearly every cell, so when animated it looks like three legs fluttering instead of alternating. This MUST be corrected. Do not merely recolor the existing legs.
Rows 1 and 3 remain unchanged. In ALL FOUR CELLS of ROW 2 and ALL FOUR CELLS of ROW 4, REDRAW BOTH LEGS in the OPPOSITE LEG PHASE: the large bright gold foreground thigh connects from the visible right hip DIAGONALLY BACK LEFT, and its gold shin/boot must be at the LEFT or tucked under the rear of the body. The dark shadowed far-side thigh connects behind the pelvis and reaches FORWARD RIGHT; its dark shin and boot appear on the RIGHT. So the row2 and row4 bright near knee is on the LEFT and the dark far knee is on the RIGHT, opposite the rows above. The foreground bright leg must cross IN FRONT of the dark far leg, not emerge from it. Exactly two hips, two connected leg chains, two boots, never a third limb. In row2 column1, draw the bright near leg clearly straight back-left, dark far leg heel contacting front-right. Row2 column2 bright near leg bent backward-left, far leg planted. Row2 column3 bright near knee passing from left under body, far leg sweeping behind. Row2 column4 bright near knee lifts forward and dark far foot pushes off behind. Row4 follows the same near/far interchange but with compact backward-stepping footwork. This one anatomical correction has priority over retaining the old legs. No effects/text/shadows. Transparent alpha, pixel-art clusters. All other pixels and layout preserved.
```

### Ranger second anatomical correction

```text
Edit the provided sprite sheet. This is an anatomical leg correction, NOT a style change. Keep all 16 upper bodies, scale, grid, transparent background, and the blue-visor orange-scarf Ranger identity exactly. The four sprites in ROW TWO need the foreground cream/teal armored leg reaching BACKWARD LEFT from the hip; the far leg reaches FORWARD RIGHT in dark charcoal shadow. Right now that foreground leg wrongly stays on the right exactly like row one. Fix it. In each of row two's four cells, the LEFT leg must be the dominant, thick, bright cream-shin-plated NEAR leg in front of the other leg, connected to the visible foreground hip. The RIGHT leg must be the thinner dark far leg behind. Do not place a bright kneecap or white shin plate on the right leg of row two. The near shin armor should visibly travel from right to left compared with row one. Apply the same foreground/background leg exchange to all four sprites in ROW FOUR compared to row three. ROWS ONE AND THREE remain completely unchanged. Redraw just these eight pairs of legs accurately with two and only two boots and correct connecting hip-knee-ankle chains. No third limb, no extra silhouette or shadow. Preserve genuine alpha and all pixels above the belt. This exact leg-side exchange is the ONLY requested change.
```

## Final phase corrections

### Ranger

```text
Correct the six duplicate leg poses in the attached Ranger 4x4 pixel sprite atlas. Keep upper bodies and transparent layout unchanged. Keep row 2 column 1's near-leg-back/far-leg-front contact pose. Now make row 2 a real moving sequence: row 2 column 2: DARK FAR LEG planted vertically under hip, BRIGHT NEAR LEG bent behind with its boot lifted high toward the butt. Row 2 column 3: DARK FAR LEG angles BACK LEFT toward the ground while BRIGHT NEAR KNEE comes FORWARD RIGHT and its foot hangs under that knee above ground. Row 2 column 4: BRIGHT NEAR LEG reaches FORWARD RIGHT in the air, DARK FAR LEG stretches BACK LEFT pushing off with just the toe. Thus each of these four columns must have different leg geometry, not the same split stance! Row 4 needs the same alternating support sequence but smaller, lower backpedal steps: column 2 dark foot under body and bright boot lifted behind; column 3 dark foot reaching front while bright knee tucked; column 4 bright foot reaching back-left and dark heel lifting. Keep all row 1 and row 3 pixels unchanged. In every cell exactly two connected legs with two boots. No new parts, labels, blur, or effects. Correct animation poses are more important than retaining the old wrong leg pixels.
```

### Vanguard

```text
Correct the leg phases in the attached Vanguard sprite atlas to complete an actual alternating running cycle. Preserve every upper body and the 4x4 transparent layout. Row 2 column 1 is the opposite contact pose and stays unchanged. Row 2 column 2 must have DARK FAR LEG planted vertically under hip, BRIGHT GOLD NEAR LEG bent behind with its boot lifted toward butt. Row 2 column 3: DARK FAR LEG angles BACK LEFT toward the ground, BRIGHT GOLD NEAR KNEE comes FORWARD RIGHT with its foot above ground. Row 2 column 4: BRIGHT GOLD NEAR LEG reaches FORWARD RIGHT in the air, DARK FAR LEG stretches BACK LEFT pushing off with toe. This is a true sequential leg cycle, every column different. Row 4 column 2 similarly has dark foot planted under body and bright boot lifted behind; row 4 column 3 has dark foot reaching forward and bright knee tucked; row 4 column 4 has bright foot reaching backward left and dark heel lifting, with compact low backward steps. Exactly two legs/two knees/two boots. Row 1 and row 3 stay unchanged. No blurred, repeated, disconnected or third leg. No text or background. Keep genuine transparent alpha.
```
