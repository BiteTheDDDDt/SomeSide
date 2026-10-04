# SomeSide implementation contract

Godot 4.x, GDScript. Root scene `main.tscn` uses `scripts/main.gd`. Root owns UI, input, networking, sound and persistence. Agents own individual files below; do not edit other owners' files.

## Simulation (`scripts/simulation.gd`, class_name SideSimulation, extends RefCounted)

Pure dictionary state, world units equal pixels. Fixed 60 Hz. Origin top left. All entity positions refer to **center**. Vector2 is allowed in state (RPC Variant supported). No scene dependencies.

Public fields: `state: Dictionary`, `events: Array` (last step events). API:
- `start_run(roster: Array, seed_value: int = 1)` roster records `{id: int, name: String, character: String}`; character `ranger` or `vanguard`.
- `step(delta: float, commands: Dictionary)` peer ID -> command `{move: float, jump: bool, drop: bool, aim: Vector2, fire: bool, skill: bool, dash: bool, interact: bool}`. aim is normalized world direction. All actions except fire and move are rising-edge input. Store last aim if near zero.
- `add_player(id: int, name: String, character: String)` / `remove_player(id: int)`.
- `get_snapshot() -> Dictionary` returns full deep copy.
- `apply_snapshot(snapshot: Dictionary)` replaces state with deep copy.
- `predict_player(player: Dictionary, command: Dictionary, delta: float) -> void`: ONLY same movement physics, modifies given player; uses state platforms. No authoritative combat consequences.
- `static func item_catalog() -> Array` and `static func character_catalog() -> Array` for UI.

State keys:
`phase`: `playing`, `won`, `lost`; `stage`: 1..3; `time`: seconds entire run; `stage_time`; `seed`; `kills`; `difficulty`: float; `players`: Dictionary keyed integer peer IDs; `enemies`: Array; `projectiles`: Array; `pickups`: Array; `chests`: Array; `platforms`: Array of Rect2; `world_size`: dynamic Vector2 for each stage (see V0_4_CONTRACT.md); `gate`: Dictionary `{pos: Vector2, active: bool, charge: float, ready: bool}`; `boss_alive`: bool.

Player: `{id,name,character,pos:Vector2,vel:Vector2,aim:Vector2,hp:float,max_hp:float,shield:float,coins:int,items:Dictionary(item_id->count),dead:bool,grounded:bool,fire_cd:float,skill_cd:float,dash_cd:float,invuln:float,kills:int,revive:float}`. Extra fields allowed. Ranger dimensions half(12,21); Vanguard half(14,23); use common half(12,21) physics if easier.
Enemy: `{id:int,kind:String,pos:Vector2,vel:Vector2,hp:float,max_hp:float,elite:bool}` with kinds `crawler`,`drone`,`spitter`,`boss`.
Projectile: `{id:int,pos:Vector2,vel:Vector2,team:String,kind:String,ttl:float,radius:float}` plus owner/damage etc. Team `player` or `enemy`.
Pickup: `{id:int,pos:Vector2,kind:String,item:String}` kind `coin`,`heal`,`item`. Chest: `{id:int,pos:Vector2,cost:int,opened:bool,item:String}`.
Events (max useful ~64/step): `{type:String,pos:Vector2, ...}` types `shoot`,`hit` (`amount`,`crit`),`death`,`explosion`,`slash`,`dash`,`pickup` (`player`,`item`),`stage`,`win`,`lose`,`gate`,`revive`. Root consumes sound; renderer consumes visuals. No RPC object references.
Catalog item records `{id,name,description,color:Color}`. Characters `{id,name,description,color:Color}`.
Design: 3 fixed variation platform maps, time difficulty, interact chest/gate/revive, charge gate with spawned boss, after kill+charge E at gate next stage; stage3 won. Use seeded RNG on authority. Two distinctly different characters; 6+ stacking items, several combat synergies bounded. Death co-op revive / all dead lost. Drop through one-way platforms. Simulate collision numerically for testability and prediction. Keep AI and counts bounded.

## Renderer (`scripts/world_view.gd`, class_name SideWorldView, extends Node2D)
API `set_frame(snapshot: Dictionary, local_id: int, delta: float)`, `push_events(events: Array)`, `screen_to_world(screen_position: Vector2) -> Vector2`, `world_to_screen(world_position: Vector2) -> Vector2`; public `camera_position: Vector2`, `screen_size: Vector2`. Root uses viewport 1280x720 canvas stretch. Draw in viewport coordinates with custom camera conversion (do not add Camera2D). World view drawn behind CanvasLayer UI. Smooth local camera around local player; initial/menu snapshot optional (root supplies preview sim). Can read all state above; tolerate missing fields. No UI HUD from renderer. Procedural artwork with Godot primitives, dramatic atmospheric neon/teal-orange alien landscape, parallax, rain, distinct animated characters and weapon aiming, readable enemies/projectiles, portals/chests/items, impact particles and numbers. Colors and silhouettes polished. Do NOT create placeholder rectangles-only look. No external assets required. Use antialiased draw methods. Renderer supports screenshot via main root separately.

## Root / network (`scripts/main.gd`)
Root owns server-authority simulation and 20Hz state snapshots, peer input + local movement prediction/replay, UI/HUD/lobby/pause/settings, sound generated via AudioStreamWAV, command line smoke hooks, saves, title/results. RPC events with dedupe. ENet port 27841 max4. No public service or Steam credentials assumed. Lobby join direct address; explicit connection errors/timeouts. Main starts server lobby or solo locally.

## Tooling agent
Install Godot portable under tools/runtime (or shared gamedev/tools if appropriate), verify official checksum; create tools/run.ps1 and root Play.cmd robust relative paths, Editor.cmd, export setup if feasible, README.md in Chinese, docs/ARCHITECTURE.md, meaningful tests/test_simulation.gd, network smoke orchestration after root hook ready. Do not edit root/simulation/renderer.
