extends Node

## Connects existing authoritative interactions to the Legendary Slice story.

func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("interaction_completed"):
		var callback := Callable(self, "_on_interaction_completed")
		if not event_bus.is_connected("interaction_completed", callback):
			event_bus.connect("interaction_completed", callback)
	var director := get_node_or_null("/root/LegendarySlice")
	if director != null:
		if director.has_signal("beat_changed"):
			var beat_callback := Callable(self, "_on_beat_changed")
			if not director.is_connected("beat_changed", beat_callback):
				director.connect("beat_changed", beat_callback)
		if director.has_signal("slice_completed"):
			var complete_callback := Callable(self, "_on_slice_completed")
			if not director.is_connected("slice_completed", complete_callback):
				director.connect("slice_completed", complete_callback)

func _on_interaction_completed(interaction_id: String, _tags: Array[String]) -> void:
	var director := get_node_or_null("/root/LegendarySlice")
	if director == null:
		return
	match interaction_id:
		"feed", "care":
			if director.has_method("record_first_care"):
				director.record_first_care(interaction_id)
		_:
			pass

func _on_beat_changed(_previous_index: int, _current_index: int, beat: Dictionary) -> void:
	var objective := str(beat.get("objective", "Gemeinsam weitermachen."))
	_show_story_toast(objective)
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_navigation"):
		audio.play_navigation()

func _on_slice_completed(_snapshot: Dictionary) -> void:
	_show_story_toast("Der erste gemeinsame Handlungsbogen ist abgeschlossen. Eure Geschichte beginnt jetzt erst richtig.")
	var audio := get_node_or_null("/root/OmniAudio")
	if audio != null:
		if audio.has_method("play_action"):
			audio.play_action("level", 1.2)
		if audio.has_method("play_voice_chirp"):
			audio.play_voice_chirp("Wir haben unser erstes Versprechen gehalten.", "ECSTATIC")

func _show_story_toast(text: String) -> void:
	var toast := get_node_or_null("/root/DialogueToast")
	if toast != null:
		for method_name in ["show_dialogue", "show_message", "show_toast"]:
			if toast.has_method(method_name):
				toast.call(method_name, text)
				return
