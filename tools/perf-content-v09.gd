extends SceneTree

const Content = preload("res://scripts/content.gd")

func _initialize() -> void:
	var ids: Array[String] = []
	for entry in Content.passives() + Content.weapons() + Content.equipment():
		ids.append(entry.id)
	var samples: Array[float] = []
	var checksum: int = 0
	for batch in range(7):
		var start: int = Time.get_ticks_usec()
		for index in range(5000):
			var entry: Dictionary = Content.definition(ids[index % ids.size()])
			checksum += str(entry.name).length()
		var elapsed: float = float(Time.get_ticks_usec() - start) / 1000.0
		if batch > 0:
			samples.append(elapsed)
	samples.sort()
	var result: Dictionary = {"lookups_per_batch": 5000, "batches_ms": samples, "median_ms": samples[samples.size() / 2], "checksum": checksum}
	print("CONTENT_PERF ", JSON.stringify(result))
	quit()
