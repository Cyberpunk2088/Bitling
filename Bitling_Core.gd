extends Node

# =====================================================================
# ARCHITEKTUR-KERN: PROJECT ZIELMETAFINALOMNI FOR BITLING
# =====================================================================
# Singularity Architect: Sichert Datenintegrität & Systemarchitektur[span_2](start_span)[span_2](end_span)
# Resonance Lead: Taktet die Team- und Operator-Frequenz[span_3](start_span)[span_3](end_span)
# Matrix Sync: Hält das Ökosystem in synchroner Verschränkung[span_4](start_span)[span_4](end_span)
# =====================================================================

const MIN_INTEGRITY: float = 100.0
var bitling_integrity: float = 100.0
var impulse_resource_pool: float = 1000.0

var last_input_time: int = 0
var input_delays: Array = []
const BASELINE_DELAY_MS: float = 400.0

enum SystemPhase { EVOLUTION, ANOMALY_TRIGGER, SYNC_COOLDOWN }
var current_phase = SystemPhase.EVOLUTION

var background_node: ColorRect
var dialog_label: Label
var integrity_bar: ProgressBar

func _ready() -> void:
	last_input_time = Time.get_ticks_msec()
	_create_ui_dynamically()
	_singularity_architect_log("Bitling Kern-Spine hochgefahren. Verfassung aktiv.")[span_5](start_span)[span_5](end_span)
	_update_ui_elements()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var current_time = Time.get_ticks_msec()
		var delay = current_time - last_input_time
		last_input_time = current_time
		if delay < 4000:
			_resonance_lead_process(delay)

func _resonance_lead_process(delay: float) -> void:
	input_delays.append(delay)
	if input_delays.size() > 8:
		input_delays.pop_front()
		
	var sum: float = 0.0
	for d in input_delays:
		sum += d
	var avg_delay = sum / input_delays.size()
	
	if avg_delay < BASELINE_DELAY_MS:
		impulse_resource_pool += 15.0 # Impuls-Maximierung allokiert Ressourcen[span_6](start_span)[span_6](end_span)
	
	if avg_delay > (BASELINE_DELAY_MS * 1.6) and current_phase == SystemPhase.EVOLUTION:
		_matrix_sync_trigger_anomalie()

func _matrix_sync_trigger_anomalie() -> void:
	current_phase = SystemPhase.ANOMALY_TRIGGER
	_singularity_architect_log("Kognitive Anomalie erkannt. Exekutivschicht transformiert.")[span_7](start_span)[span_7](end_span)
	
	if background_node:
		var tween = create_tween()
		tween.tween_property(background_node, "color", Color(0.85, 0.5, 0.25, 1.0), 1.5)
		
	if dialog_label:
		dialog_label.text = "Operator, deine System-Resonanz weicht ab. Atme tief aus. Dein Bitling hält das System stabil."
		
	bitling_integrity = MIN_INTEGRITY
	_update_ui_elements()

func _create_ui_dynamically() -> void:
	background_node = ColorRect.new()
	background_node.color = Color(0.1, 0.1, 0.15, 1.0)
	background_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background_node)
	
	integrity_bar = ProgressBar.new()
	integrity_bar.max_value = 100
	integrity_bar.value = 100
	integrity_bar.custom_minimum_size = Vector2(300, 40)
	integrity_bar.position = Vector2(50, 80)
	add_child(integrity_bar)
	
	dialog_label = Label.new()
	dialog_label.text = "Bitling-System online. Berühre den Bildschirm..."
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(300, 100)
	dialog_label.position = Vector2(50, 200)
	add_child(dialog_label)

func _singularity_architect_log(action_text: String) -> void:
	print("[Singularity Architect] ", action_text)
	var file = FileAccess.open("user://bitling_secure_spine.dat", FileAccess.WRITE)
	if file:
		var secure_packet = {
			"game": "Bitling",
			"timestamp": Time.get_datetime_string_from_system(),
			"integrity_status": "SECURE",
			"current_phase": current_phase,
			"resource_pool": impulse_resource_pool,
			"action": action_text
		}
		file.store_string(JSON.stringify(secure_packet))
		file.close()

func _update_ui_elements() -> void:
	if integrity_bar:
		integrity_bar.value = bitling_integrity
