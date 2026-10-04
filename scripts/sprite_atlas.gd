class_name SideSpriteAtlas
extends RefCounted

## A bounded, one-shot native render cache. The owning world frees its atlas
## with the scene. Headless runs and callers without prepare retain vector art.
const ENABLED_META: StringName = &"someside_sprite_cache_enabled"

class Painter extends Node2D:
	var entries: Array
	var scale_factor: float
	var paint: Callable

	func _draw() -> void:
		for entry: Dictionary in entries:
			var bounds: Rect2 = entry.bounds
			var region: Rect2 = entry.region
			draw_set_transform(region.position - bounds.position * scale_factor, 0.0, Vector2.ONE * scale_factor)
			paint.call(self, entry.data)
		draw_set_transform(Vector2.ZERO)

static func layout(source: Array, scale_factor: float = 2.0, width: int = 4096) -> Dictionary:
	var entries: Array = []
	for original: Dictionary in source:
		var entry: Dictionary = original.duplicate(false)
		var bounds: Rect2 = entry.bounds
		entry["pixel_size"] = Vector2i(ceili(bounds.size.x * scale_factor), ceili(bounds.size.y * scale_factor))
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.pixel_size.y != b.pixel_size.y: return a.pixel_size.y > b.pixel_size.y
		if a.pixel_size.x != b.pixel_size.x: return a.pixel_size.x > b.pixel_size.x
		return str(a.key) < str(b.key)
	)
	var x: int = 2
	var y: int = 2
	var row_height: int = 0
	var regions: Dictionary = {}
	for entry: Dictionary in entries:
		var dimensions: Vector2i = entry.pixel_size
		if x + dimensions.x + 2 > width:
			x = 2
			y += row_height + 2
			row_height = 0
		entry["region"] = Rect2(Vector2(x, y), Vector2(dimensions))
		regions[entry.key] = {"source": entry.region, "target": entry.bounds}
		x += dimensions.x + 2
		row_height = maxi(row_height, dimensions.y)
	var height: int = ceili(float(y + row_height + 2) / 16.0) * 16
	return {"entries": entries, "regions": regions, "size": Vector2i(width, height), "bytes": width * height * 4, "scale": scale_factor}

static func prepare(canvas: Node2D, metadata: StringName, entries: Array, paint: Callable, max_bytes: int, width: int = 4096) -> void:
	if DisplayServer.get_name() == "headless" or canvas.has_meta(metadata):
		return
	var plan: Dictionary = layout(entries, 2.0, width)
	# Keep allocation bounded if the catalogue grows; do not allocate an oversized
	# target even for one frame. The authored vector fallback remains available.
	if int(plan.bytes) > max_bytes:
		plan = layout(entries, 1.5, width)
	if int(plan.bytes) > max_bytes or int(plan.size.y) > 4096:
		return
	var viewport := SubViewport.new()
	viewport.name = str(metadata)
	viewport.size = plan.size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	canvas.add_child(viewport)
	var painter := Painter.new()
	painter.entries = plan.entries
	painter.scale_factor = float(plan.scale)
	painter.paint = paint
	viewport.add_child(painter)
	canvas.set_meta(metadata, {"viewport": viewport, "texture": viewport.get_texture(), "regions": plan.regions, "bytes": plan.bytes, "max_bytes": max_bytes, "size": plan.size, "scale": plan.scale, "entries": entries.size(), "builds": 1, "ready_frame": Engine.get_process_frames() + 2})

static func cache(canvas: Node2D, metadata: StringName) -> Dictionary:
	if not bool(canvas.get_meta(ENABLED_META, true)):
		return {}
	var record: Dictionary = canvas.get_meta(metadata, {})
	if record.is_empty() or Engine.get_process_frames() < int(record.ready_frame):
		return {}
	return record

static func stats(canvas: Node2D, metadata: StringName) -> Dictionary:
	var record: Dictionary = canvas.get_meta(metadata, {})
	if record.is_empty():
		return {"ready": false, "bytes": 0, "entries": 0, "builds": 0}
	return {"ready": not cache(canvas, metadata).is_empty(), "bytes": record.bytes, "max_bytes": record.max_bytes, "size": record.size, "scale": record.scale, "entries": record.entries, "builds": record.builds}

static func draw_region(canvas: Node2D, record: Dictionary, key: String, target: Rect2 = Rect2()) -> bool:
	var region: Dictionary = record.regions.get(key, {})
	if region.is_empty():
		return false
	canvas.draw_texture_rect_region(record.texture, region.target if target.size == Vector2.ZERO else target, region.source)
	return true
