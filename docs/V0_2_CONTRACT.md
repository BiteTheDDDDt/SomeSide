# SomeSide 0.2 integration contract

User changes: starting single jump; all three maps traversable without items or dash; optional extra-air-jump relic makes shortcuts. Manual ground loot with icon/name/effect/explicit harm; rare monster loot. Diverse interactables. One replaceable primary weapon and one replaceable active equipment. Improve HUD/UI clarity.

## Ownership
- simulation agent: scripts/simulation.gd (+ optional scripts/content.gd owned by you); pure rule/state/API changes.
- art agent: scripts/world_view.gd, NEW scripts/item_icons.gd, scripts/art_preview.gd.
- root: scripts/main.gd UI/input/network integration, project version.
- testing agent: tests/*, tools/*, docs/README, export presets/build/package. Coordinate test expectations with simulation agent.

## New shared APIs / fields
- Keep old Simulation public API, preserve original 10 passive IDs.
- `Simulation.item_catalog()` contains all passive relics, including `feather` (one extra air jump per stack) and `glass` (+damage / -maximum HP with explicit warning).
- `Simulation.weapon_catalog()` and `Simulation.equipment_catalog()` arrays.
- `Simulation.loot_definition(id: String) -> Dictionary`: catalog record `{id,name,description,color:Color,category:String,rarity:String,warning:String}`. category = `passive`, `weapon`, `equipment`. Empty warning allowed. All records must contain these fields. Weapon extra `fire_interval` optional; equipment `cooldown` optional.
- Proposed weapon IDs: `pulse_rifle`, `arc_blade`, `scattergun`, `railgun`. Equipment IDs: `grenade`, `shockwave`, `repair_field`, `aegis`. Send root/art any differences immediately.
- Player new `weapon:String`, `equipment:String`; continue fire_cd, skill_cd. Ranger starts pulse_rifle+grenade, Vanguard arc_blade+shockwave. Items only contain passives.
- Pickup kinds keep coin/heal auto collectible; ALL loot (passive/weapon/equipment) `kind="item"`, `item=<catalog ID>`; NEVER auto attracts or auto grants. Ground loot survives until selected, trade old equipment to ground. Per-pickup optional `cooldown:float` stores remaining active CD, decrement normally. Preserve max(current/dropped cooldown, small equip lock) to prevent swapping cooldown reset.
- `sim.interaction_for(player_id: int) -> Dictionary`: nearest actionable target within physical range. Keys `{kind:String,id:int,pos:Vector2,title:String,description:String,prompt:String,warning:String,item:String,category:String,affordable:bool}`; kinds pickup/chest/gate/revive. `id` is network stable, gate -1, revive teammate ID. Include price/risk in description/prompt. Empty dictionary if none. Priority rescue emergency; otherwise nearest object (loot wins reasonable tie). Must work on replicated state without sim RNG.
- `sim.interaction_candidates(player_id: int) -> Array`: all in-range actionable records with the same fields, stable priority/distance/ID ordering; rescue first, loot preferred in reasonable ties. `interaction_for` is the first candidate or `{}`. Fully overlapping loot must remain individually selectable, including choosing a beneficial item without taking a harmful one first.
- Root uses F to cycle candidates and stores the exact `{kind,id}` in `_interaction_selection` while it remains valid. `_refresh_interaction_focus()` updates `_focus_target` from that selection on each rendered frame. The world highlight, detailed card and the next E command all consume this same displayed target. Leaving range removes the stale selection. Card footer shows the cycling key and candidate index/count.
- Commands optional `interact_target:Dictionary {kind:String,id:int}`. Root samples displayed target on E. Server validates exact target still exists/in range; never silently substitutes a different loot item. If field missing, use interaction_for for existing automation/tests. Simulation `_interact(player, target={})` should allow test direct call.
- Chests state `type` = `cache`, `choice`, `blood`, `combat`, `equipment` (or `chance` if added); retain id,pos,cost,opened,item. Choice shop 3 terminals share `group` and other choices lock after one purchase. UI reads interaction_for; art differentiates types. Blood uses nonlethal health payment for reward; combat challenge opens a reward after its own linked wave dies (not ambient spawns). NO automatic equipping from any chest: rewards go to ground.
- Enemy normal item drop ~3%, elite ~8%; boss drop explicit guaranteed; authority-only RNG once per dead enemy. Document exact values in catalog/README. Avoid guaranteed early harmful loot and avoid flooding ground.
- Event `pickup` for actual selected loot, `drop`/`interact` optional for world feedback, error feedback event `notice` with `{player:int,message:String}`. Existing type events preserved.

## Art API
`scripts/item_icons.gd`, class_name SideItemIcons, extends RefCounted. `static func texture(id: String, size: int = 64) -> Texture2D` returns cached unique readable icon for every catalog ID (native SVG/procedural okay). World + HUD share this. Root may preload script and call directly. Ground loot icon and thin rarity beam; nearest focused target highlight via public `interaction_target:Dictionary={}` on world view. UI draws detailed panel, world only concise E/item name if needed (avoid duplicate giant labels). Distinguish main weapon in character pose independent of character.

## Root UI direction
Compact readable top-left HP, top-right stage/time/difficulty; top-center actionable objective and fine progress. Bottom center: primary/active/dash slots with pictograms, keys, readable cooldown rings/bars and current weapon/equipment names. Passive inventory as icon strip + stack badges, details in Tab inventory; no wall of item names. Nearby interactable panel includes icon, name, category, effect, explicit downside, E action, current replacement warning. Preserve clear sight of player. Update guide for single jump + feather, equipment replacement and new facilities. Update local attack prediction to weapon (not character). Send interact target in validated RPC input.

## Verification
Real movement reachability in each stage with no items, no air jump, no dash, both characters; test shortcut unlocked by feather. Reject second jump initially, allow N stacks correctly. Overlap NEVER automatically picks loot. Explicit E picks exactly one; co-op simultaneous requests cannot double-grant; replacing gear drops previous and cannot reset cooldown. Tests cover all facility costs/choice lock/challenge reward, drop RNG bounds and no duplicate on death. Update former tests instead of keeping obsolete double-jump assertions. Final 4-process + impaired network, actual rendered screenshots, 0.2.0 standalone EXE/zip.
