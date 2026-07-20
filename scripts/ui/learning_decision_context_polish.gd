extends Node

## Final Wave 5 composition pass. Fills the decision area with actionable context
## instead of decorative emptiness and shrinks stacked mobile cards to content.

var _overlay: Node
var _service: Node
var _grid: GridContainer
var _decision_card: PanelContainer
var _approach_label: Label
var _transfer_label: Label
var _evolution_label: Label
var _adaptive_label: Label
var _active_adventure_id: String = ""
var _last_approach: String = ""
var _installed: bool = false

func _ready() -> void:
	call_deferred("_install")
	set_process(true)

func get_status() -> Dictionary:
	return {
		"installed": _installed,
		"context_cards": 4 if _installed else 0,
		"active_adventure": _active_adventure_id,
		"active_approach": _last_approach,
		"decision_height": _decision_card.size.y if _decision_card != null else 0.0
	}

func _process(_delta: float) -> void:
	if not _installed:
		return
	var approach := str(_overlay.get("_selected_approach"))
	if approach != _last_approach:
		_last_approach = approach
		_refresh_context()

func _install() -> void:
	_overlay = get_node_or_null("/root/LearningAdventureOverlay")
	_service = get_node_or_null("/root/LearningAdventures")
	if _overlay == null or _service == null:
		return
	_grid = _overlay.find_child("LearningSessionPolishGrid", true, false) as GridContainer
	if _grid == null or _grid.get_child_count() < 2:
		return
	_decision_card = _grid.get_child(1) as PanelContainer
	if _decision_card == null or _decision_card.get_child_count() == 0:
		return
	var margin := _decision_card.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return
	var column := margin.get_child(0) as VBoxContainer
	if column == null:
		return
	_add_context_section(column)
	_connect_signals()
	get_viewport().size_changed.connect(_apply_layout)
	_installed = true
	_last_approach = str(_overlay.get("_selected_approach"))
	_apply_layout()
	_refresh_from_snapshot()

func _add_context_section(column: VBoxContainer) -> void:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	column.add_child(separator)
	var title := Label.new()
	title.text = "WAS DIESES DENKEN VERÄNDERT"
	title.add_theme_color_override("font_color", Color("ffc85a"))
	title.add_theme_font_size_override("font_size", 11)
	column.add_child(title)
	_approach_label = _add_info_card(column, "DENKWEG", Color("42e8ff"))
	_transfer_label = _add_info_card(column, "EXPEDITION & TECHNIK", Color("64e6a2"))
	_evolution_label = _add_info_card(column, "EVOLUTIONSIMPULS", Color("a855f7"))
	_adaptive_label = _add_info_card(column, "ADAPTIVE REGEL", Color("f044d4"))

func _add_info_card(parent: VBoxContainer, heading: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("101a31"), Color(accent, 0.36), 13))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var kicker := Label.new()
	kicker.text = heading
	kicker.add_theme_color_override("font_color", accent)
	kicker.add_theme_font_size_override("font_size", 9)
	column.add_child(kicker)
	var value := Label.new()
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_color_override("font_color", Color("f4f7ff"))
	value.add_theme_font_size_override("font_size", 11)
	column.add_child(value)
	return value

func _connect_signals() -> void:
	for pair: Array in [
		["session_started", "_on_session_started"],
		["challenge_changed", "_on_challenge_changed"],
		["session_completed", "_on_session_completed"]
	]:
		var signal_name := str(pair[0])
		var callback := Callable(self, str(pair[1]))
		if _service.has_signal(signal_name) and not _service.is_connected(signal_name, callback):
			_service.connect(signal_name, callback)

func _on_session_started(session: Dictionary) -> void:
	_active_adventure_id = str(session.get("adventure_id", ""))
	_refresh_context()

func _on_challenge_changed(challenge: Dictionary) -> void:
	_active_adventure_id = str(challenge.get("adventure_id", _active_adventure_id))
	_refresh_context()

func _on_session_completed(result: Dictionary) -> void:
	_active_adventure_id = str(result.get("adventure_id", _active_adventure_id))
	_refresh_context()

func _refresh_from_snapshot() -> void:
	var snapshot := _service.call("get_snapshot") as Dictionary
	var active := snapshot.get("active_session", {}) as Dictionary
	_active_adventure_id = str(active.get("adventure_id", ""))
	_refresh_context()

func _refresh_context() -> void:
	if not _installed:
		return
	var data := _adventure_data(_active_adventure_id)
	var approach := _last_approach if not _last_approach.is_empty() else "observe"
	_approach_label.text = _approach_description(approach)
	if data.is_empty():
		_transfer_label.text = "Wähle ein Abenteuer, damit dein Bitling Wissen mit der Welt verbindet."
		_evolution_label.text = "Meisterschaft formt spätere Entwicklungsmöglichkeiten."
	else:
		_transfer_label.text = "%s stärkt %s und unterstützt die Expedition %s." % [
			str(data.get("title", "Dieses Abenteuer")),
			str(data.get("technique", "Technik")).replace("_", " ").to_upper(),
			str(data.get("expedition", "Weltpfad")).replace("_", " ").to_upper()
		]
		_evolution_label.text = "Erfolgreiche Runden erhöhen die Affinität %s." % str(data.get("evolution_affinity", "WACHSTUM")).replace("_", " ")
	_adaptive_label.text = "Fehler entfernen keinen Fortschritt. Schwierigkeit und nächste Aufgabe folgen der gezeigten Meisterschaft."

func _apply_layout() -> void:
	if not _installed:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var physical_width := float(get_tree().root.size.x)
	var width := minf(viewport_width, physical_width) if physical_width > 0.0 else viewport_width
	var stacked := width < 1040.0
	_decision_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if stacked else Control.SIZE_EXPAND_FILL
	_decision_card.custom_minimum_size = Vector2(0, 0 if stacked else 620)
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if stacked else Control.SIZE_EXPAND_FILL
	for label: Label in [_approach_label, _transfer_label, _evolution_label, _adaptive_label]:
		label.add_theme_font_size_override("font_size", 10 if width < 760.0 else 11)

func _adventure_data(adventure_id: String) -> Dictionary:
	if adventure_id.is_empty() or not _service.has_method("get_catalog"):
		return {}
	for entry_variant: Variant in _service.call("get_catalog"):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("id", "")) == adventure_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}

func _approach_description(approach: String) -> String:
	match approach:
		"compare":
			return "VERGLEICHEN sucht Unterschiede und Gemeinsamkeiten, bevor eine Entscheidung fällt."
		"experiment":
			return "AUSPROBIEREN testet eine Idee sicher und nutzt Rückmeldung für den nächsten Versuch."
		"explain":
			return "ERKLÄREN macht den Gedankengang sichtbar und verstärkt nachhaltige Meisterschaft."
		_:
			return "BEOBACHTEN sammelt Hinweise und schützt vor einer vorschnellen Antwort."

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
