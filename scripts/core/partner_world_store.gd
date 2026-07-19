extends Node

## Independent persistence boundary for the clean-room partner-world systems.
## Keeping this data optional preserves compatibility with older central saves.

const SAVE_VERSION := 1
const SAVE_PATH := "user://partner_world.json"
const TEMP_PATH := "user://partner_world.tmp"
const BACKUP_PATH := "user://partner_world.backup.json"
const SAVE_DEBOUNCE_SECONDS := 1.0

var _save_pending: bool = false
var _save_elapsed: float = 0.0
var _loading: bool = false

func _ready() -> void:
	call_deferred("_initialize")
	set_process(true)

func _process(delta: float) -> void:
	if not _save_pending or _loading:
		return
	_save_elapsed += maxf(delta, 0.0)
	if _save_elapsed >= SAVE_DEBOUNCE_SECONDS:
		save_now()

func _initialize() -> void:
	load_now()
	var world := get_node_or_null("/root/PartnerWorld")
	if world != null:
		_connect_signal(world, "care_quality_changed", _queue_save)
		_connect_signal(world, "care_strain_recorded", _queue_save)
		_connect_signal(world, "life_stage_changed", _queue_save)
		_connect_signal(world, "technique_learned", _queue_save)
		_connect_signal(world, "autonomous_action_resolved", _queue_save)
		_connect_signal(world, "citizen_recruited", _queue_save)
		_connect_signal(world, "settlement_rank_changed", _queue_save)
		_connect_signal(world, "legacy_seed_created", _queue_save)
	var matrix := get_node_or_null("/root/EvolutionMatrix")
	if matrix != null:
		_connect_signal(matrix, "forecast_updated", _queue_save)
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_signal("state_changed"):
		var callable := Callable(self, "_on_game_state_changed")
		if not state.state_changed.is_connected(callable):
			state.state_changed.connect(callable)

func queue_save() -> void:
	if _loading:
		return
	_save_pending = true
	_save_elapsed = 0.0

func save_now() -> bool:
	if _loading:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"partner_world": _export_service("/root/PartnerWorld"),
		"evolution_matrix": _export_service("/root/EvolutionMatrix"),
		"saved_at": int(Time.get_unix_time_from_system())
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(SAVE_PATH) and not _read_payload(SAVE_PATH).is_empty():
		_copy_file(SAVE_PATH, BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			return false
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			_copy_file(BACKUP_PATH, SAVE_PATH)
		return false
	_save_pending = false
	_save_elapsed = 0.0
	return true

func load_now() -> bool:
	_loading = true
	for path in [SAVE_PATH, BACKUP_PATH]:
		var payload := _read_payload(path)
		if payload.is_empty():
			continue
		_import_service("/root/PartnerWorld", payload.get("partner_world", {}))
		_import_service("/root/EvolutionMatrix", payload.get("evolution_matrix", {}))
		_loading = false
		_save_pending = false
		_save_elapsed = 0.0
		return true
	_loading = false
	return false

func reset_persistent_state() -> void:
	_loading = true
	_reset_service("/root/PartnerWorld")
	_reset_service("/root/EvolutionMatrix")
	_loading = false
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	queue_save()

func _queue_save(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	queue_save()

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "new_game":
		reset_persistent_state()
	elif key in ["interaction", "loaded", "hatched"]:
		queue_save()

func _connect_signal(source: Object, signal_name: StringName, target: Callable) -> void:
	if not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, target):
		source.connect(signal_name, target)

func _export_service(path: String) -> Dictionary:
	var service := get_node_or_null(path)
	if service == null or not service.has_method("export_state"):
		return {}
	var value: Variant = service.call("export_state")
	return value.duplicate(true) if value is Dictionary else {}

func _import_service(path: String, data_variant: Variant) -> void:
	if not data_variant is Dictionary:
		return
	var service := get_node_or_null(path)
	if service != null and service.has_method("import_state"):
		service.call("import_state", (data_variant as Dictionary).duplicate(true))

func _reset_service(path: String) -> void:
	var service := get_node_or_null(path)
	if service != null and service.has_method("reset_state"):
		service.call("reset_state")

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var payload := parsed as Dictionary
	if int(payload.get("version", 0)) <= 0:
		return {}
	return payload

func _copy_file(source: String, target: String) -> bool:
	var source_file := FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	var bytes := source_file.get_buffer(source_file.get_length())
	source_file.close()
	var target_file := FileAccess.open(target, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(bytes)
	target_file.close()
	return true
