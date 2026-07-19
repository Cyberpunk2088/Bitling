extends SceneTree

var failures: Array[String] = []
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var quality := root.get_node_or_null("ProductionQuality")
	_assert(quality != null, "ProductionQuality autoload exists")
	if quality == null:
		_finish()
		return
	quality.reset_runtime_state()

	var good_sample := {
		"profile": "mobile",
		"fps": 60.0,
		"frame_time_ms": 12.0,
		"static_memory_mb": 180.0,
		"video_memory_mb": 260.0,
		"node_count": 900.0,
		"object_count": 2200.0,
		"draw_calls": 320.0,
		"orphan_nodes": 0.0,
		"audio_latency_ms": 45.0
	}
	var bad_sample := {
		"profile": "mobile",
		"fps": 22.0,
		"frame_time_ms": 46.0,
		"static_memory_mb": 780.0,
		"video_memory_mb": 920.0,
		"node_count": 5200.0,
		"object_count": 11000.0,
		"draw_calls": 2400.0,
		"orphan_nodes": 4.0,
		"audio_latency_ms": 310.0
	}

	var good_violations: Array = quality.assess_sample(good_sample, "mobile")
	_assert(good_violations.is_empty(), "Healthy mobile sample stays inside production budgets")
	var bad_violations: Array = quality.assess_sample(bad_sample, "mobile")
	_assert(bad_violations.size() >= 8, "Degraded sample reports budget violations")
	var unknown: Array = quality.assess_sample({"profile": "unknown"}, "unknown")
	_assert(unknown.size() == 1, "Unknown device profile produces a diagnostic")

	quality.ingest_sample(bad_sample)
	_assert(str(quality.runtime_state) == "WATCH", "One degraded sample enters WATCH")
	quality.ingest_sample(bad_sample)
	quality.ingest_sample(bad_sample)
	_assert(str(quality.runtime_state) == "RED", "Repeated degraded samples enter RED")
	_assert(int(quality.consecutive_violation_samples) == 3, "Violation streak is tracked")

	quality.ingest_sample(good_sample)
	quality.ingest_sample(good_sample)
	quality.ingest_sample(good_sample)
	_assert(str(quality.runtime_state) == "GREEN", "Sustained recovery returns to GREEN")
	_assert(int(quality.consecutive_violation_samples) == 0, "Recovery clears the violation streak")

	for _index in range(150):
		quality.ingest_sample(good_sample)
	var history_limit := int(quality.manifest.get("history_limit", 120))
	_assert(quality.sample_history.size() == history_limit, "Telemetry history remains bounded")

	var report_path := "user://aaa_production_test_report.json"
	_assert(quality.flush_report(report_path), "Runtime report is written")
	var file := FileAccess.open(report_path, FileAccess.READ)
	_assert(file != null, "Runtime report can be reopened")
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_assert(parsed is Dictionary, "Runtime report contains valid JSON")
		if parsed is Dictionary:
			_assert(str(parsed.get("state", "")) == "GREEN", "Runtime report preserves final quality state")
	DirAccess.remove_absolute(report_path)

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[CI-AAA] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-AAA] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-AAA]   - %s" % failure)
	quit(1)

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
