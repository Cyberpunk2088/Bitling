extends "res://scripts/ui/production_bitling_stage_3d_v2.gd"

const AssetCatalog := preload("res://scripts/visual/production_asset_catalog.gd")

var _authored_character_active := false
var _authored_room_active := false
var _authored_animation_player: AnimationPlayer
var _active_authored_animation := ""

func _build_room() -> void:
	var room_scene: PackedScene = AssetCatalog.load_optional_scene(AssetCatalog.ROOM_SCENE)
	if room_scene == null:
		super._build_room()
		return
	var instance: Node = room_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		super._build_room()
		return
	var room := instance as Node3D
	room.name = "AuthoredNeonLoft"
	_world.add_child(room)
	_authored_room_active = true

func _build_bitling() -> void:
	var character_scene: PackedScene = AssetCatalog.load_optional_scene(AssetCatalog.CHARACTER_SCENE)
	if character_scene == null:
		super._build_bitling()
		return
	var instance: Node = character_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		super._build_bitling()
		return
	_bitling = Node3D.new()
	_bitling.name = "AuthoredBitlingRig"
	_bitling.position = Vector3(0.0, -0.12, 0.20)
	_world.add_child(_bitling)
	var authored_root := instance as Node3D
	authored_root.name = "AuthoredBitlingModel"
	_bitling.add_child(authored_root)
	_authored_animation_player = _find_animation_player(authored_root)
	_authored_character_active = true
	_play_authored_animation("idle")

func set_mood(value: String) -> void:
	mood = value.to_upper()
	if not _authored_character_active:
		super.set_mood(value)
		return
	match mood:
		"ECSTATIC":
			_play_authored_animation("excited")
		"HAPPY":
			_play_authored_animation("happy")
		"TIRED":
			_play_authored_animation("tired")
		"SAD", "DISTRESSED":
			_play_authored_animation("sad")
		_:
			_play_authored_animation("idle")

func play_reaction() -> void:
	super.play_reaction()
	if _authored_character_active:
		_play_authored_animation("surprised")

func _process(delta: float) -> void:
	if not _authored_character_active:
		super._process(delta)
		return
	if not _active or _bitling == null:
		return
	_elapsed += delta
	_reaction = move_toward(_reaction, 0.0, delta * 2.8)
	var motion_scale: float = 0.25 if _reduce_motion_enabled() else 1.0
	_bitling.position.y = -0.12 + sin(_elapsed * 1.75) * 0.035 * motion_scale + _reaction * 0.06
	_bitling.rotation.y = sin(_elapsed * 0.48) * 0.025 * motion_scale
	for index in range(_platform_rings.size()):
		_platform_rings[index].rotation.y += delta * (0.22 + float(index) * 0.08) * (1.0 if index % 2 == 0 else -1.0)
	_update_light_pulse()
	for index in range(_ambient_sparks.size()):
		var spark: Node3D = _ambient_sparks[index]
		spark.position.y += delta * (0.03 + 0.015 * float(index % 4))
		if spark.position.y > 3.9:
			spark.position.y = 0.45

func play_action_animation(action_name: String) -> void:
	if not _authored_character_active:
		play_reaction()
		return
	var animation_map: Dictionary = {
		"feed": "feed",
		"play": "play",
		"learn": "learn",
		"care": "care",
		"rest": "sleep"
	}
	var animation_name: String = str(animation_map.get(action_name, "surprised"))
	_play_authored_animation(animation_name)

func authored_assets_status() -> Dictionary:
	return {
		"character": _authored_character_active,
		"room": _authored_room_active,
		"animation_contract": AssetCatalog.inspect_animation_contract(_bitling) if _authored_character_active else {
			"available": [],
			"missing": AssetCatalog.REQUIRED_CHARACTER_ANIMATIONS.duplicate(),
			"complete": false
		}
	}

func _play_authored_animation(animation_name: String) -> void:
	if _authored_animation_player == null:
		return
	if not _authored_animation_player.has_animation(animation_name):
		if animation_name != "idle" and _authored_animation_player.has_animation("idle"):
			_authored_animation_player.play("idle", 0.18)
			_active_authored_animation = "idle"
		return
	if _active_authored_animation == animation_name and _authored_animation_player.is_playing():
		return
	_authored_animation_player.play(animation_name, 0.16)
	_active_authored_animation = animation_name

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	var found: Node = root_node.find_child("*", true, false)
	if found is AnimationPlayer:
		return found as AnimationPlayer
	for candidate in root_node.find_children("*", "AnimationPlayer", true, false):
		return candidate as AnimationPlayer
	return null
