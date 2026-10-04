class_name SideLocale
extends RefCounted

## Exact source lookup intentionally leaves player names and authoritative
## identifiers alone. Only the caller's display language selects a translation.
static var current_language: String = "en"
const TRANSLATIONS: Dictionary = preload("res://scripts/localization_data.gd").TEXTS

static func set_language(language: String) -> void:
	current_language = language if language in ["zh", "en"] else "en"

static func choose_language(saved: String, system_locale: String) -> String:
	if saved in ["zh", "en"]:
		return saved
	var normalized: String = system_locale.strip_edges().to_lower().replace("_", "-")
	return "zh" if normalized == "zh" or normalized.begins_with("zh-") else "en"

static func text(source: String) -> String:
	return source if current_language == "zh" else str(TRANSLATIONS.get(source, source))

static func format(source: String, args: Array) -> String:
	return text(source) if args.is_empty() else text(source) % args

static func has_translation(source: String) -> bool:
	return TRANSLATIONS.has(source)
