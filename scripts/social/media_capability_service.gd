extends Node

## Read-only capability probe for consent-based voice and camera sessions.
## It never starts recording, feed monitoring or permission prompts by itself.

signal capabilities_changed(snapshot: Dictionary)

var capabilities: Dictionary = {}

func _ready() -> void:
	refresh()

func refresh() -> Dictionary:
	var microphone_configured := bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	var camera_count := 0
	var front_camera_available := false
	var camera_monitoring_active := true
	if CameraServer.has_method("is_monitoring_feeds"):
		camera_monitoring_active = bool(CameraServer.call("is_monitoring_feeds"))
	if camera_monitoring_active:
		camera_count = CameraServer.get_feed_count()
		for feed in CameraServer.feeds():
			if feed != null and int(feed.get_position()) == int(CameraFeed.FEED_FRONT):
				front_camera_available = true
				break
	capabilities = {
		"microphone_configured": microphone_configured,
		"audio_capture_class": ClassDB.class_exists("AudioEffectCapture"),
		"camera_monitoring_active": camera_monitoring_active,
		"camera_feed_count": camera_count,
		"front_camera_available": front_camera_available,
		"websocket_available": ClassDB.class_exists("WebSocketPeer"),
		"webrtc_class_available": ClassDB.class_exists("WebRTCPeerConnection"),
		"native_video_transport_ready": false,
		"platform": OS.get_name()
	}
	capabilities_changed.emit(capabilities.duplicate(true))
	return capabilities.duplicate(true)

func can_start_voice(local_consent: bool, remote_consent: bool) -> bool:
	return local_consent and remote_consent \
		and bool(capabilities.get("microphone_configured", false)) \
		and bool(capabilities.get("audio_capture_class", false))

func can_start_video(local_consent: bool, remote_consent: bool) -> bool:
	return local_consent and remote_consent \
		and bool(capabilities.get("camera_monitoring_active", false)) \
		and bool(capabilities.get("front_camera_available", false)) \
		and bool(capabilities.get("native_video_transport_ready", false))

func get_blockers(channel: String) -> Array[String]:
	var blockers: Array[String] = []
	match channel:
		"voice":
			if not bool(capabilities.get("microphone_configured", false)):
				blockers.append("Audio input is disabled in Project Settings")
			if not bool(capabilities.get("audio_capture_class", false)):
				blockers.append("AudioEffectCapture is unavailable")
		"video":
			if not bool(capabilities.get("camera_monitoring_active", false)):
				blockers.append("Camera feeds are not monitored before explicit consent")
			if not bool(capabilities.get("front_camera_available", false)):
				blockers.append("No active front-camera feed is available")
			if not bool(capabilities.get("native_video_transport_ready", false)):
				blockers.append("A supported native video transport adapter is still required")
		_:
			blockers.append("Unknown media channel")
	return blockers

func get_snapshot() -> Dictionary:
	return capabilities.duplicate(true)
