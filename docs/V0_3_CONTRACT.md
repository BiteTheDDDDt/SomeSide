# SomeSide 0.3 integration contract

Three changes: compact the persistent HUD; reduce initial movement, dash and firepower without breaking any no-item route; let nearby lingering pause ordinary enemy generation and difficulty growth.

The existing ownership, input, loot, snapshots and exact-interaction APIs in `V0_2_CONTRACT.md` remain valid. Root owns HUD changes. Simulation owns tuning and the exploration director. Tooling owns regression tests, documentation and versioned release outputs.

## Exploration and difficulty

- `state.time` remains the ordinary run clock. `state.threat_time` advances only while there is active exploration or a living player near an explicitly activated encounter. Difficulty uses threat time rather than total run time.
- Player exploration state uses `explore_anchor`, `explore_sites`, `explore_window` and `explore_budget`. Movement must reach genuinely new terrain; small back-and-forth movement, jumping in place and revisiting old sites must not continuously create waves.
- Initial stationary play creates no ambient wave. An exploration window and its budget expire rather than accumulating during rest. Dead, revived and newly positioned stage players receive a fresh anchor, not a free movement-triggered wave.
- Ambient enemies choose an active explorer, not a distant idle teammate. An active gate may reinforce around living players near the gate; an explicitly activated combat trial retains its own linked enemies and reward rule.
- Replicated `state.director` exposes `mode` (`rest`, `exploring`, `event`), `resting`, `explorers`, `event_active` and `threat_time` for presentation. UI reads the state; it does not run its own difficulty or spawn policy.

## Verification and release

The compact HUD keeps HP, stage/time/currency and three small action icons visible. Action names and passive relics are normally hidden; holding Alt reveals the relic strip and allows icon hover inspection. Nearby loot descriptions use at most two lines normally and expand on Alt, while harm and replacement warnings remain readable. `_slot_ui` keeps `icon`, hidden `name`, `bar`, `id`, plus `cooldown` and `panel`. `_hud_labels` is `health`, `expedition`, `objective`, `team`, `relics`, `hint`; `_objective_panel` is visible only for an active gate or a downed player. `_update_inspection_visibility()` applies held-key state every render frame.

`tests/test_director.gd` removes observed ambient enemies during idle tests so a saturated entity cap cannot disguise continuous respawning. It covers stationary, short patrol, repeated jumping, fresh exploration, expiry, old-route return, rest without budget burst, idle teammates, and gate/trial exceptions. Existing route tests use actual physics for both characters, all stages, no items and no dash, including interior takeoff/landing margins and ±12px takeoff tolerance. Stress tests inject their own load independently of exploration rules.

Release paths are `dist/v0.3.0/SomeSide.exe` and `dist/SomeSide-v0.3.0-windows-x64.zip`. Preserve prior versions and do not terminate a user's running game. After code freeze: full source suite, source four-process networking, release export, release four-process networking, and release two-process delay/loss with reliable result delivery. The build report records only final actual results and evidence paths.
