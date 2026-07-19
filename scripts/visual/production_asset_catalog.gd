class_name ProductionAssetCatalog
extends RefCounted

## Canonical optional production asset locations. Runtime code must always check
## existence and keep a functional fallback so development builds remain playable.

const CHARACTER_ROOT := "res://assets/characters/bitling_omni"
const ROOM_ROOT := "res://assets/environments/neon_loft"
const UI_ROOT := "res://assets/ui/metafinal"
const AUDIO_ROOT := "res://assets/audio"

const CHARACTER_SCENE := CHARACTER_ROOT + "/bitling_omni.glb"
const CHARACTER_MATERIAL_PROFILE := CHARACTER_ROOT + "/material_profile.tres"
const CHARACTER_ANIMATION_LIBRARY := CHARACTER_ROOT + "/bitling_animations.res"
const ROOM_SCENE := ROOM_ROOT + "/neon_loft.glb"
const ROOM_LIGHTING_PROFILE := ROOM_ROOT + "/lighting_profile.tres"
const UI_THEME := UI_ROOT + "/metafinal_theme.tres"

const REQUIRED_CHARACTER_ANIMATIONS: Array[String] = [
	"idle",
	"blink",
	"look",
	"happy",
	"sad",
	"tired",
	"excited",
	"feed",
	"play",
	"learn",
	"care",
	"sleep",
	"surprised",
	"clumsy"
]

static func authored_character_available() -> bool:
	return ResourceLoader.exists(CHARACTER_SCENE)

static func authored_room_available() -> bool:
	return ResourceLoader.exists(ROOM_SCENE)

static func production_theme_available() -> bool:
	return ResourceLoader.exists(UI_THEME)

static func load_optional_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	return resource as PackedScene

static func inspect_animation_contract(root: Node) -> Dictionary:
	var available: Array[String] = []
	var missing: Array[String] = REQUIRED_CHARACTER_ANIMATIONS.duplicate()
	if root == null:
		return {"available": available, "missing": missing, "complete": false}
	for player_variant in root.find_children("*", "AnimationPlayer", true, false):
		var player := player_variant as AnimationPlayer
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			if library == null:
				continue
			for animation_name in library.get_animation_list():
				if animation_name not in available:
					available.append(animation_name)
	for required in REQUIRED_CHARACTER_ANIMATIONS:
		if required in available:
			missing.erase(required)
	return {
		"available": available,
		"missing": missing,
		"complete": missing.is_empty()
	}

static func production_manifest() -> Dictionary:
	return {
		"character_scene": CHARACTER_SCENE,
		"character_material_profile": CHARACTER_MATERIAL_PROFILE,
		"character_animation_library": CHARACTER_ANIMATION_LIBRARY,
		"room_scene": ROOM_SCENE,
		"room_lighting_profile": ROOM_LIGHTING_PROFILE,
		"ui_theme": UI_THEME,
		"character_available": authored_character_available(),
		"room_available": authored_room_available(),
		"theme_available": production_theme_available(),
		"required_animations": REQUIRED_CHARACTER_ANIMATIONS.duplicate()
	}
