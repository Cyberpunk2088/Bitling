extends SceneTree

const Wave2Stage := preload("res://scripts/ui/production_bitling_stage_3d_v8.gd")

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	_test_performance_director_contract()
	await _test_stage_expression_and_touch_contract()
	await _test_audio_reactivity_contract()
	await _test_main_scene_integration()
	if failures.is_empty():
		print("[CI-WAVE2] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-WAVE2] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-WAVE2]   - %s" % failure)
	quit(1)

func _test_performance_director_contract() -> void:
	var director := root.get_node_or_null("CharacterPerformance")
	_assert(director != null, "CharacterPerformance autoload exists")
	if director == null:
		return
	var contract: Dictionary = director.get_performance_contract()
	_assert((contract.get("intents", []) as Array).size() >= 10, "Performance director exposes at least ten gameplay intents")
	_assert((contract.get("touch_zones", []) as Array).size() >= 8, "Performance director exposes eight touch zones")
	_assert((contract.get("phases", []) as Array).size() == 7, "All seven lifecycle phases have timing profiles")

	var play_snapshot: Dictionary = director.request_action("play", 1.0)
	_assert(str(play_snapshot.get("event", "")) == "play", "Play creates a dedicated performance event")
	_assert(str(play_snapshot.get("gesture", "")) == "bounce_spin", "Play uses a readable full-body gesture")
	_assert(str(play_snapshot.get("expression", "")) == "ecstatic", "Play uses an ecstatic face")
	_assert(float(play_snapshot.get("duration", 0.0)) >= 1.5, "Play performance has visible screen time")

	var head_touch: Dictionary = director.request_touch("head", Vector2(0.0, -0.5))
	var belly_touch: Dictionary = director.request_touch("belly", Vector2(0.0, 0.2))
	_assert(str(head_touch.get("gesture", "")) == "head_pat", "Head touch has a unique response")
	_assert(str(belly_touch.get("gesture", "")) == "belly_laugh", "Belly touch has a unique response")
	_assert(str(head_touch.get("gesture", "")) != str(belly_touch.get("gesture", "")), "Touch zones do not collapse into one generic reaction")

	var dialogue_snapshot: Dictionary = director.request_dialogue("Ich habe im Signal ein neues Muster erkannt.", "learn")
	_assert(bool(dialogue_snapshot.get("speaking", false)), "Dialogue activates speaking performance")
	_assert(str(dialogue_snapshot.get("expression", "")) == "curious", "Learning dialogue uses contextual expression")
	_assert(float(dialogue_snapshot.get("speech_rate", 0.0)) > 0.0, "Dialogue includes phase-aware speech timing")

func _test_stage_expression_and_touch_contract() -> void:
	var stage := Wave2Stage.new()
	stage.name = "Wave2CharacterTestStage"
	stage.size = Vector2(720.0, 720.0)
	stage.custom_minimum_size = Vector2(720.0, 720.0)
	root.add_child(stage)
	await process_frame
	await process_frame
	await process_frame

	var initial: Dictionary = stage.get_character_life_snapshot()
	_assert(bool(initial.get("facial_rig", false)), "Procedural fallback has brows and cheek expression rig")
	_assert(int(initial.get("speech_ring_count", 0)) == 3, "Speech visualization has three layered pulses")
	_assert(int(initial.get("emotion_spark_count", 0)) >= 8, "High-energy emotion has a substantial spark rig")

	var director := root.get_node_or_null("CharacterPerformance")
	if director != null:
		var play_snapshot: Dictionary = director.request_action("play", 1.0)
		stage.apply_performance(play_snapshot)
		await process_frame
		await process_frame
		var active: Dictionary = stage.get_character_life_snapshot()
		var performance: Dictionary = active.get("performance", {}) as Dictionary
		_assert(str(performance.get("gesture", "")) == "bounce_spin", "Stage receives semantic gameplay gesture")
		_assert(float(active.get("blend", 0.0)) > 0.0, "Stage blends into a performance instead of snapping")

		var speech_snapshot: Dictionary = director.request_dialogue("Zing. Das klingt nach einer Verbindung.", "check_in")
		stage.apply_performance(speech_snapshot)
		await process_frame
		await process_frame
		var speaking: Dictionary = stage.get_character_life_snapshot()
		_assert(int(speaking.get("visible_speech_rings", 0)) == 3, "Speaking is visibly represented around the mouth")

	_assert(str(stage.call("_classify_touch_zone", Vector2(100.0, 90.0))) == "ear_left", "Upper-left touch maps to left ear")
	_assert(str(stage.call("_classify_touch_zone", Vector2(620.0, 90.0))) == "ear_right", "Upper-right touch maps to right ear")
	_assert(str(stage.call("_classify_touch_zone", Vector2(360.0, 110.0))) == "head", "Upper-center touch maps to head")
	_assert(str(stage.call("_classify_touch_zone", Vector2(360.0, 360.0))) == "belly", "Center touch maps to belly")
	_assert(str(stage.call("_classify_touch_zone", Vector2(150.0, 530.0))) == "paw_left", "Lower-left touch maps to left paw")
	_assert(str(stage.call("_classify_touch_zone", Vector2(560.0, 530.0))) == "paw_right", "Lower-right touch maps to right paw")
	_assert(str(stage.call("_classify_touch_zone", Vector2(620.0, 690.0))) == "tail", "Bottom-right touch maps to tail")

	var baby_motion: Dictionary = Wave2Stage.PHASE_MOTION["BABY"] as Dictionary
	var senior_motion: Dictionary = Wave2Stage.PHASE_MOTION["SENIOR"] as Dictionary
	_assert(float(baby_motion.get("tempo", 0.0)) > float(senior_motion.get("tempo", 0.0)), "Baby movement is visibly quicker than Senior movement")
	_assert(float(baby_motion.get("bob", 0.0)) > float(senior_motion.get("bob", 0.0)), "Lifecycle changes body-motion amplitude")

	stage.queue_free()
	await process_frame

func _test_audio_reactivity_contract() -> void:
	var audio := root.get_node_or_null("OmniAudio")
	var director := root.get_node_or_null("CharacterPerformance")
	_assert(audio != null, "OmniAudio autoload exists")
	_assert(director != null, "Performance director is available to audio test")
	if audio == null or director == null:
		return
	if audio.has_method("set_ambience_enabled"):
		audio.set_ambience_enabled(false)
	var before: Dictionary = audio.get_audio_status()
	director.request_action("care", 0.9)
	await process_frame
	var after_action: Dictionary = audio.get_audio_status()
	_assert(int(after_action.get("performance_cues", 0)) > int(before.get("performance_cues", 0)), "Gameplay performance produces an audio cue")
	_assert((after_action.get("buses", []) as Array).has("Voice"), "Audio contract contains a dedicated Voice bus")
	_assert((after_action.get("buses", []) as Array).has("Ambience"), "Audio contract contains a dedicated Ambience bus")

	var dialogue_before := int(after_action.get("dialogue_cues", 0))
	audio.play_voice_performance("Miri kala. Das Signal antwortet.", "HAPPY", "CHILD", "explore")
	var after_dialogue: Dictionary = audio.get_audio_status()
	_assert(int(after_dialogue.get("dialogue_cues", 0)) == dialogue_before + 1, "Contextual speech schedules a phase-aware voice contour")

	audio.set_environment("ROOFTOPS")
	_assert(str(audio.get_audio_status().get("environment", "")) == "ROOFTOPS", "Story environment changes ambience profile")
	audio.play_touch_reaction("ear_left", "HAPPY", "BABY", 0.8)
	var touch_status: Dictionary = audio.get_audio_status()
	_assert(int(touch_status.get("voices", 0)) + int(touch_status.get("scheduled", 0)) > 0, "Touch reaction produces audible or scheduled voices")
	audio.stop_all()

func _test_main_scene_integration() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_assert(packed != null, "Premium main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	var director := main.get_node_or_null("MetafinalVisualDirector")
	_assert(director != null and director.get_script().resource_path.ends_with("metafinal_visual_director_v9.gd"), "Main scene hosts Wave 2 performance through the Wave 3 visual director")
	var stage := main.find_child("LegendaryWave3LivingHomeStage3D", true, false)
	_assert(stage != null, "Main scene retains the Wave 2 character rig inside the Wave 3 stage")
	if director != null and director.has_method("get_wave2_status"):
		var status: Dictionary = director.get_wave2_status()
		_assert(status.has("performance") and status.has("audio") and status.has("stage"), "Visual director exposes integrated performance diagnostics")
	main.queue_free()
	await process_frame

func _assert(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
