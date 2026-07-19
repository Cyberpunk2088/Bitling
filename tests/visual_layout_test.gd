extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_runtime_nodes()
	await process_frame
	await _test_layout(Vector2i(390, 844), 1, true, false, "phone")
	await _test_layout(Vector2i(900, 1200), 2, false, false, "tablet")
	await _test_layout(Vector2i(1440, 900), 3, false, true, "laptop")
	_test_production_asset_contract()
	if failures.is_empty():
		print("[CI-VISUAL] PASS: %d assertions" % assertions)
		quit(0)
		return
	push_error("[CI-VISUAL] FAIL: %d of %d assertions failed" % [failures.size(), assertions])
	for failure in failures:
		push_error("[CI-VISUAL]   - %s" % failure)
	quit(1)

func _ensure_runtime_nodes() -> void:
	var definitions: Array = [
		["EventBus", "res://scripts/core/event_bus.gd"],
		["StreakService", "res://scripts/core/streak_service.gd"],
		["QuestService", "res://scripts/core/quest_service.gd"],
		["PlatformService", "res://scripts/core/platform_service.gd"],
		["CompanionBrain", "res://scripts/core/companion_brain.gd"],
		["WellbeingGuard", "res://scripts/core/wellbeing_guard.gd"],
		["AdaptiveLearning", "res://scripts/core/adaptive_learning.gd"],
		["EvolutionService", "res://scripts/core/evolution_service.gd"],
		["VitalityService", "res://scripts/core/vitality_service.gd"],
		["ExplorationService", "res://scripts/core/exploration_service.gd"],
		["GameState", "res://scripts/core/game_state.gd"]
	]
	for definition in definitions:
		var node_name := str(definition[0])
		if root.has_node(node_name):
			continue
		var script := load(str(definition[1])) as Script
		_assert(script != null, "Runtime script loads: %s" % definition[1])
		if script == null:
			continue
		var instance := script.new() as Node
		instance.name = node_name
		root.add_child(instance)

func _test_layout(viewport_size: Vector2i, expected_columns: int, expect_mobile_nav: bool, expect_desktop_nav: bool, label: String) -> void:
	root.size = viewport_size
	var scene := load("res://main.tscn") as PackedScene
	_assert(scene != null, "%s main scene loads" % label)
	if scene == null:
		return
	var dashboard := scene.instantiate()
	root.add_child(dashboard)
	await process_frame
	await process_frame
	await process_frame

	var main_grid := dashboard.get("main_grid") as GridContainer
	var center_panel := dashboard.get("center_panel") as PanelContainer
	var left_panel := dashboard.get("left_panel") as PanelContainer
	var right_panel := dashboard.get("right_panel") as PanelContainer
	var bottom_navigation := dashboard.get("bottom_navigation") as PanelContainer
	var desktop_navigation := dashboard.get("desktop_navigation") as HBoxContainer
	var stage := dashboard.get("stage") as Control
	var action_buttons: Dictionary = dashboard.get("action_buttons")
	var needs_bars: Dictionary = dashboard.get("needs_bars")

	_assert(main_grid != null, "%s main grid exists" % label)
	_assert(center_panel != null, "%s center panel exists" % label)
	_assert(left_panel != null, "%s statistics panel exists" % label)
	_assert(right_panel != null, "%s quest/social panel exists" % label)
	_assert(stage != null, "%s Bitling stage exists" % label)
	if main_grid != null:
		_assert(main_grid.columns == expected_columns, "%s uses %d responsive columns" % [label, expected_columns])
		if viewport_size.x < 900:
			_assert(main_grid.get_child(0) == center_panel, "%s prioritizes Bitling stage first" % label)
		elif viewport_size.x >= 1180:
			_assert(main_grid.get_child(0) == left_panel, "%s places statistics at left" % label)
			_assert(main_grid.get_child(1) == center_panel, "%s keeps Bitling stage centered" % label)
			_assert(main_grid.get_child(2) == right_panel, "%s places quests at right" % label)
	_assert(bottom_navigation != null and bottom_navigation.visible == expect_mobile_nav, "%s mobile navigation visibility is correct" % label)
	_assert(desktop_navigation != null and desktop_navigation.visible == expect_desktop_nav, "%s desktop navigation visibility is correct" % label)
	_assert(action_buttons.size() == 5, "%s exposes five primary actions" % label)
	_assert(needs_bars.size() == 5, "%s exposes five live needs" % label)
	if stage != null:
		_assert(stage is SubViewportContainer, "%s uses a real 3D SubViewport stage" % label)
		_assert(stage.has_method("set_mood"), "%s stage accepts mood state" % label)
		_assert(stage.has_method("set_rarity"), "%s stage accepts rarity state" % label)
		_assert(stage.custom_minimum_size.y >= 390.0, "%s stage preserves visual prominence" % label)
		_assert(stage.find_child("Production3DViewport", true, false) is SubViewport, "%s stage owns a production 3D viewport" % label)
		_assert(stage.find_child("ProductionPassportCard", true, false) is PanelContainer, "%s stage exposes the holographic passport" % label)

	for key in action_buttons.keys():
		var button := action_buttons[key] as Button
		_assert(button != null, "%s action %s remains a button" % [label, key])
		if button != null:
			_assert(button.find_child("Glyph", true, false) != null, "%s action %s has a vector neon glyph" % [label, key])

	var relationship_meter := dashboard.find_child("TrustRadialMeter", true, false)
	_assert(relationship_meter != null, "%s displays the radial trust meter" % label)

	dashboard.queue_free()
	await process_frame

func _test_production_asset_contract() -> void:
	var catalog_script := load("res://scripts/visual/production_asset_catalog.gd") as Script
	_assert(catalog_script != null, "Production asset catalog loads")
	if catalog_script == null:
		return
	var manifest: Dictionary = catalog_script.production_manifest()
	_assert(str(manifest.get("character_scene", "")).ends_with(".glb"), "Character contract targets GLB")
	_assert(str(manifest.get("room_scene", "")).ends_with(".glb"), "Room contract targets GLB")
	var animations: Array = manifest.get("required_animations", [])
	_assert(animations.size() >= 12, "Production character contract defines the required animation set")

func _assert(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
