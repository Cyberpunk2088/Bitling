extends Node

## Runtime production telemetry and budget enforcement for BITLING OMNI.
## The service never silently changes gameplay. It records objective violations so
## performance regressions can be reproduced and blocked by tests or release tooling.

signal quality_state_changed(old_state: String, new_state: String, snapshot: Dictionary)
signal budget_violation_detected(violation: Dictionary)

const MANIFEST_PATH := "res://production/aaa_quality_manifest.json"
const REPORT_PATH := "user://aaa_runtime_quality_report.json"
const BYTES_PER_MIB := 1048576.0
const STATE_GREEN := "GREEN"
const STATE_WATCH := "WATCH"
const STATE_RED := "RED"

var manifest: Dictionary = {}
var runtime_state: String = STATE_GREEN
var consecutive_violation_samples: int = 0
var last_sample: Dictionary = {}
var last_violations: Array[Dictionary] = []
var sample_history: Array[Dictionary] = []
var _sample_elapsed: float = 0.0
var _report_elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	manifest = _load_manifest()
	set_process(true)

func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_sample_elapsed += safe_delta
	_report_elapsed += safe_delta
	var interval := maxf(float(manifest.get("runtime_sample_interval_seconds", 1.0)), 0.25)
	if _sample_elapsed >= interval:
		_sample_elapsed = 0.0
		ingest_sample(capture_runtime_sample())
	if _report_elapsed >= 30.0:
		_report_elapsed = 0.0
		flush_report()

func capture_runtime_sample() -> Dictionary:
	var sample := {
		"timestamp": int(Time.get_unix_time_from_system()),
		"profile": get_device_profile(),
		"fps": float(Performance.get_monitor(Performance.TIME_FPS)),
		"frame_time_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
		"static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / BYTES_PER_MIB,
		"video_memory_mb": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / BYTES_PER_MIB,
		"node_count": float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": float(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"draw_calls": float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"orphan_nodes": float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"audio_latency_ms": float(Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY)) * 1000.0
	}
	return sample

func get_device_profile() -> String:
	var width := 0.0
	if get_tree() != null and get_tree().root != null:
		width = float(get_tree().root.size.x)
	if OS.has_feature("mobile") or (width > 0.0 and width < 700.0):
		return "mobile"
	if width > 0.0 and width < 1180.0:
		return "tablet"
	return "desktop"

func assess_sample(sample: Dictionary, profile_override: String = "") -> Array[Dictionary]:
	var profile := profile_override if not profile_override.is_empty() else str(sample.get("profile", get_device_profile()))
	var budgets: Dictionary = manifest.get("runtime_budgets", {}).get(profile, {})
	if budgets.is_empty():
		return [{"metric": "profile", "actual": profile, "reason": "unknown_budget_profile"}]
	var violations: Array[Dictionary] = []
	_assess_minimum(sample, budgets, "fps", "fps_min", violations)
	_assess_maximum(sample, budgets, "frame_time_ms", "frame_time_ms_max", violations)
	_assess_maximum(sample, budgets, "static_memory_mb", "static_memory_mb_max", violations)
	_assess_maximum(sample, budgets, "video_memory_mb", "video_memory_mb_max", violations)
	_assess_maximum(sample, budgets, "node_count", "node_count_max", violations)
	_assess_maximum(sample, budgets, "object_count", "object_count_max", violations)
	_assess_maximum(sample, budgets, "draw_calls", "draw_calls_max", violations)
	_assess_maximum(sample, budgets, "orphan_nodes", "orphan_nodes_max", violations, false)
	_assess_maximum(sample, budgets, "audio_latency_ms", "audio_latency_ms_max", violations)
	return violations

func ingest_sample(sample: Dictionary) -> Dictionary:
	last_sample = sample.duplicate(true)
	last_violations = assess_sample(last_sample)
	if last_violations.is_empty():
		consecutive_violation_samples = maxi(consecutive_violation_samples - 1, 0)
	else:
		consecutive_violation_samples += 1
		for violation in last_violations:
			budget_violation_detected.emit(violation.duplicate(true))
	var grace := maxi(int(manifest.get("violation_grace_samples", 3)), 1)
	var next_state := STATE_GREEN
	if consecutive_violation_samples >= grace:
		next_state = STATE_RED
	elif consecutive_violation_samples > 0:
		next_state = STATE_WATCH
	var old_state := runtime_state
	runtime_state = next_state
	var history_entry := {
		"sample": last_sample.duplicate(true),
		"violations": last_violations.duplicate(true),
		"state": runtime_state,
		"score": _quality_score(last_violations)
	}
	sample_history.append(history_entry)
	var history_limit := maxi(int(manifest.get("history_limit", 120)), 10)
	while sample_history.size() > history_limit:
		sample_history.pop_front()
	if old_state != runtime_state:
		quality_state_changed.emit(old_state, runtime_state, get_snapshot())
	return history_entry

func get_snapshot() -> Dictionary:
	return {
		"state": runtime_state,
		"consecutive_violation_samples": consecutive_violation_samples,
		"profile": str(last_sample.get("profile", get_device_profile())),
		"last_sample": last_sample.duplicate(true),
		"violations": last_violations.duplicate(true),
		"score": _quality_score(last_violations),
		"history_size": sample_history.size()
	}

func flush_report(path: String = REPORT_PATH) -> bool:
	var report := get_snapshot()
	report["generated_at"] = Time.get_datetime_string_from_system()
	report["history"] = sample_history.duplicate(true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return true

func reset_runtime_state() -> void:
	runtime_state = STATE_GREEN
	consecutive_violation_samples = 0
	last_sample.clear()
	last_violations.clear()
	sample_history.clear()
	_sample_elapsed = 0.0
	_report_elapsed = 0.0

func _assess_minimum(sample: Dictionary, budgets: Dictionary, metric: String, budget_key: String, violations: Array[Dictionary]) -> void:
	if not sample.has(metric) or not budgets.has(budget_key):
		return
	var actual := float(sample.get(metric, 0.0))
	var target := float(budgets.get(budget_key, 0.0))
	# Zero is used by headless or unsupported monitors and is treated as unavailable.
	if actual <= 0.0:
		return
	if actual < target:
		violations.append({"metric": metric, "actual": actual, "target": target, "rule": "minimum"})

func _assess_maximum(sample: Dictionary, budgets: Dictionary, metric: String, budget_key: String, violations: Array[Dictionary], skip_zero: bool = true) -> void:
	if not sample.has(metric) or not budgets.has(budget_key):
		return
	var actual := float(sample.get(metric, 0.0))
	var target := float(budgets.get(budget_key, 0.0))
	if skip_zero and actual <= 0.0:
		return
	if actual > target:
		violations.append({"metric": metric, "actual": actual, "target": target, "rule": "maximum"})

func _quality_score(violations: Array[Dictionary]) -> float:
	return clampf(100.0 - float(violations.size()) * 12.5, 0.0, 100.0)

func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("AAA quality manifest missing: %s" % MANIFEST_PATH)
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("AAA quality manifest could not be opened")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("AAA quality manifest is invalid JSON")
		return {}
	return parsed as Dictionary
