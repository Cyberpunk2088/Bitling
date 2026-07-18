extends Node

# =====================================================================
# ARCHITEKTUR-KERN: PROJECT ZIELMETAFINALOMNI FOR BITLING
# =====================================================================
# Kontroll-Spine aus Verfassung, Sicherheit und Zuverlässigkeit
# Singularity Architect: Sichert Datenintegrität & Systemarchitektur
# Resonance Lead: Taktet die Team- und Operator-Frequenz
# Matrix Sync: Hält das Ökosystem in synchroner Verschränkung
# =====================================================================

const MIN_INTEGRITY: float = 100.0
var bitling_integrity: float = 100.0
var impulse_resource_pool: float = 1000.0

var last_input_time: int = 0
var input_delays: Array = []
const BASELINE_DELAY_MS: float = 400.0

enum SystemPhase { EVOLUTION, ANOMALY_TRIGGER, SYNC_COOLDOWN }
var current_phase = SystemPhase.EVOLUTION

# UI-Elemente
var background_node: ColorRect
var dialog_label: Label
var integrity_bar: ProgressBar

# Animations-Elemente (Prozeduraler Bitling)
var bitling_avatar: ColorRect
var core_pulse: ColorRect

func _ready() -> void:
	last_input_time = Time.get_ticks_msec()
	_create_ui_dynamically()
	_singularity_architect_log("Bitling Kern-Spine hochgefahren. Verfassung aktiv.")
	_update_ui_elements()
	_start_idle_animation()

func _process(delta: float) -> void:
	# Kontinuierliche kognitive Schicht-Rotation
	if core_pulse:
		core_pulse.rotation += 1.5 * delta

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_play_interaction_animation(event.position)
		
		var current_time = Time.get_ticks_msec()
		var delay = current_time - last_input_time
		last_input_time = current_time
		if delay < 4000:
			_resonance_lead_process(delay)

# --- PROZEDURALE ANIMATIONEN (TWEENS) ---

# 1. Idle-Animation (Atmen des Avatars)
func _start_idle_animation() -> void:
	if bitling_avatar:
		var tween = create_tween().set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(bitling_avatar, "scale", Vector2(1.1, 1.1), 1.2)
		tween.tween_property(bitling_avatar, "scale", Vector2(0.95, 0.95), 1.2)

# 2. Interaktions-Animation (Squash & Stretch bei Touch)
func _play_interaction_animation(touch_pos: Vector2) -> void:
	if bitling_avatar:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
		
		bitling_avatar.scale = Vector2(1.3, 0.7)
		tween.tween_property(bitling_avatar, "scale", Vector2(1.0, 1.0), 0.4)
		
		if core_pulse:
			core_pulse.color = Color(1.0, 1.0, 1.0, 1.0)
			var core_tween = create_tween()
			core_tween.tween_property(core_pulse, "color", Color(0.0, 0.8, 1.0, 0.6), 0.3)

# 3. Matrix-Sync Transformations-Animation (Anomalie)
func _matrix_sync_trigger_anomalie() -> void:
	current_phase = SystemPhase.ANOMALY_TRIGGER
	_singularity_architect_log("Kognitive Anomalie erkannt. Exekutivschicht transformiert.")
	
	if background_node:
		var tween = create_tween()
		tween.tween_property(background_node, "color", Color(0.4, 0.1, 0.15, 1.0), 1.5)
		
	if bitling_avatar:
		var avatar_tween = create_tween().set_parallel(true)
		avatar_tween.tween_property(bitling_avatar, "color", Color(0.9, 0.2, 0.2, 1.0), 1.0)
		avatar_tween.tween_property(bitling_avatar, "rotation_degrees", 360.0, 1.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
	if dialog_label:
		dialog_label.text = "Operator, deine System-Resonanz weicht ab. Atme tief aus. Dein Bitling hält das System stabil."
		
	bitling_integrity = MIN_INTEGRITY
	_update_ui_elements()

# --- INITIALISIERUNG & SPECHERSYSTEM ---

func _create_ui_dynamically() -> void:
	background_node = ColorRect.new()
	background_node.color = Color(0.08, 0.08, 0.12, 1.0)
	background_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background_node)
	
	bitling_avatar = ColorRect.new()
	bitling_avatar.color = Color(0.2, 0.6, 0.9, 1.0)
	bitling_avatar.custom_minimum_size = Vector2(120, 120)
	bitling_avatar.pivot_offset = Vector2(60, 60)
	bitling_avatar.position = Vector2(130, 350)
	add_child(bitling_avatar)
	
	core_pulse = ColorRect.new()
	core_pulse.color = Color(0.0, 0.8, 1.0, 0.6)
	core_pulse.custom_minimum_size = Vector2(40, 40)
	core_pulse.pivot_offset = Vector2(20, 20)
	core_pulse.position = Vector2(40, 40)
	bitling_avatar.add_child(core_pulse)
	
	integrity_bar = ProgressBar.new()
	integrity_bar.max_value = 100
	integrity_bar.value = 100
	integrity_bar.custom_minimum_size = Vector2(300, 30)
	integrity_bar.position = Vector2(40, 80)
	add_child(integrity_bar)
	
	dialog_label = Label.new()
	dialog_label.text = "Bitling-System online. Berühre den Bildschirm..."
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.custom_minimum_size = Vector2(300, 100)
	dialog_label.position = Vector2(40, 150)
	add_child(dialog_label)

func _resonance_lead_process(delay: float) -> void:
	input_delays.append(delay)
	if input_delays.size() > 8:
		input_delays.pop_front()
		
	var sum: float = 0.0
	for d in input_delays:
		sum += d
	var avg_delay = sum / input_delays.size()
	
	if avg_delay < BASELINE_DELAY_MS:
		impulse_resource_pool += 15.0 # Impuls-Maximierung allokiert Ressourcen
	
	if avg_delay > (BASELINE_DELAY_MS * 1.6) and current_phase == SystemPhase.EVOLUTION:
		_matrix_sync_trigger_anomalie()

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