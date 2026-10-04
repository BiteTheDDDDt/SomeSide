# SomeSide 0.4 integration contract

The latest user request replaces v0.3's idle difficulty pause: difficulty now follows elapsed run time, while lingering still does not continuously replenish ambient enemies. Three genuinely larger and different maps replace the small staircase variations. Stacking combat relics strengthens bounded visual effects. The persistent HUD stays compact; M opens an optional map.

## Dynamic stage state

`scripts/stage_layouts.gd` authors each stage. `state.world_size`, `floor_y`, `spawn`, `stage_name`, `biome`, `landmarks`, `platforms`, `chests` and `gate` are authoritative and included in snapshots. Landmark records contain `pos`, `name`, `kind`, `style`, `scale`. Every rectangle in `platforms` is a real surface and must be reachable with the starting single jump, no item and no dash. Decorative terrain is renderer-only. Interactables stand on reachable surfaces; gates require reaching their elevated platform.

Rainforest is 7200×1900 with 48 platforms, canyon 5600×2800 with 45, ruins 8400×2300 with 54. Each has 18 facilities. Collision, prediction, enemy spawn limits, dropped-item recovery, camera and the map must consume current dimensions rather than the former 3200×1100 constants.

## Time and encounter rules

After a 45-second initial grace period, difficulty gains one level per 120 seconds, plus 0.45 per stage after the first. `threat_time = max(0, time - 45)` and `difficulty = 1 + threat_time/120 + (stage-1)*0.45`; `tier` and `difficulty_tier` expose its integer level. New enemies receive higher health; enemy damage follows current difficulty. Existing wounded enemies do not refill health.

The finite exploration-window policy is retained: initial idle, short patrols, jumps in place and old-route revisits do not continuously replenish enemies. Expired budgets never accumulate during rest. Nearby active gates and explicitly activated trials retain their encounter rules. `director.resting` means replenishment is paused, not that enemies are harmless or time difficulty is frozen.

## Presentation and controls

Combat events and projectiles carry `visual_stacks` and `visual_strength` (tier 0..3). These are presentation metadata; renderer effects do not change damage, simulation state or snapshots. Effects, damage numbers and camera shake have bounded budgets. `world.fx_scale` and `world.shake_enabled` use profile settings `effects` (0.5..1.5) and `shake` (boolean).

M calls `_show_map()` and displays `SideMapView` in the existing modal overlay. It receives the current dynamic state, platforms, facilities, landmarks, gate and player positions. M or Esc closes it through `_resume()`. Solo pauses; cooperative simulation keeps running. Map and settings tests must preserve the user's saved profile.

## Release

Use `dist/v0.4.0/SomeSide.exe` and `dist/SomeSide-v0.4.0-windows-x64.zip`; preserve prior versions. After freeze run the full source suite, source four-process networking, export, release four-process networking and release two-process delay/loss with reliable result delivery. Record actual counts, hashes, final evidence and public-network limitations concisely in `BUILD_REPORT.md`.
