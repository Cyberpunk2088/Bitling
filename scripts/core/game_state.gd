extends Node

# =====================================================================
# GAME STATE: Persistent Bitling State Management
# =====================================================================
# Zentrale Verwaltung für Spielzustand, Speichern/Laden und Initialisierung
# =====================================================================

# Game State Enums
enum Phase { EGG, BABY, TODDLER, CHILD, TEEN, ADULT, ELDER }
enum Era { TERMINAL, NEURAL, QUANTUM }
enum Mood { HAPPY, SAD, ANGRY, CURIOUS, SLEEPY, CONTENT }

# Core Stats
var level: int = 1
var xp: float = 0.0
var total_xp: float = 0.0
var phase: Phase = Phase.EGG
var era: Era = Era.TERMINAL
var play_time_seconds: float = 0.0
var days_played: int = 0

# Attributes
var mood: Mood = Mood.HAPPY
var hunger: float = 50.0
var energy: float = 80.0
var happiness: float = 70.0
var curiosity: float = 80.0
var health: float = 100.0

# Memory & Story
var memories: Array = []
var story_flags: Dictionary = {}

# Save File Path
const SAVE_PATH: String = "user://bitling_save.dat"

signal state_changed
signal level_up(new_level: int)

func _ready() -> void:
	print("[GameState] Initialized")
	load_game_state()

func initialize_new_game() -> void:
	"""
	Initialisiert den Spielstand für einen komplett neuen Spieler.
	Überspringt die Egg-Phase und startet direkt als BABY (Instant Hatch).
	"""
	level = 10
	xp = 0.0
	total_xp = 50.0
	phase = Phase.BABY
	era = Era.TERMINAL
	play_time_seconds = 0.0
	days_played = 1
	mood = Mood.HAPPY
	hunger = 50.0
	energy = 80.0
	happiness = 70.0
	curiosity = 80.0
	health = 100.0
	
	add_memory("birth", "The moment I first saw you. The screen flickered, and there I was.")
	story_flags["hatched"] = true
	story_flags["first_interaction_shown"] = false
	
	print("[GameState] New game initialized → Bitling spawned as BABY (Instant Hatch)")
	save_game_state()

func add_memory(key: String, text: String) -> void:
	"""Adds a memory entry."""
	var memory_entry = {
		"key": key,
		"text": text,
		"timestamp": Time.get_ticks_msec()
	}
	memories.append(memory_entry)
	print("[GameState] Memory added: %s" % key)

func gain_xp(amount: float, source: String = "unknown") -> void:
	"""Gains XP and checks for level up."""
	xp += amount
	total_xp += amount
	
	var xp_threshold = level * 100.0
	if xp >= xp_threshold:
		xp -= xp_threshold
		level_up_internal()
	
	print("[GameState] +%f XP from %s (Total: %f)" % [amount, source, total_xp])

func level_up_internal() -> void:
	"""Internal level up logic."""
	level += 1
	level_up.emit(level)
	print("[GameState] LEVEL UP! → Level %d" % level)

func set_mood(new_mood: Mood) -> void:
	"""Sets the Bitling's mood."""
	if mood != new_mood:
		mood = new_mood
		state_changed.emit()
		print("[GameState] Mood changed to: %s" % Mood.keys()[new_mood])

func update_stats(hunger_delta: float = 0.0, energy_delta: float = 0.0, happiness_delta: float = 0.0) -> void:
	"""Updates vital stats."""
	hunger = clamp(hunger + hunger_delta, 0.0, 100.0)
	energy = clamp(energy + energy_delta, 0.0, 100.0)
	happiness = clamp(happiness + happiness_delta, 0.0, 100.0)
	state_changed.emit()

func save_game_state() -> void:
	"""Saves the current game state to disk."""
	var save_data = {
		"level": level,
		"xp": xp,
		"total_xp": total_xp,
		"phase": phase,
		"era": era,
		"play_time_seconds": play_time_seconds,
		"days_played": days_played,
		"mood": mood,
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness,
		"curiosity": curiosity,
		"health": health,
		"memories": memories,
		"story_flags": story_flags,
		"last_save_time": Time.get_datetime_string_from_system()
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("[GameState] Game saved successfully")
	else:
		push_error("[GameState] Failed to save game state!")

func load_game_state() -> void:
	"""Loads the game state from disk (if it exists)."""
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameState] No save file found. Use initialize_new_game() for first launch.")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var data = JSON.parse_string(content)
		
		if data:
			level = data.get("level", 1)
			xp = data.get("xp", 0.0)
			total_xp = data.get("total_xp", 0.0)
			phase = data.get("phase", Phase.EGG)
			era = data.get("era", Era.TERMINAL)
			play_time_seconds = data.get("play_time_seconds", 0.0)
			days_played = data.get("days_played", 0)
			mood = data.get("mood", Mood.HAPPY)
			hunger = data.get("hunger", 50.0)
			energy = data.get("energy", 80.0)
			happiness = data.get("happiness", 70.0)
			curiosity = data.get("curiosity", 80.0)
			health = data.get("health", 100.0)
			memories = data.get("memories", [])
			story_flags = data.get("story_flags", {})
			
			print("[GameState] Game loaded successfully (Level %d, Phase %s)" % [level, Phase.keys()[phase]])
		else:
			push_error("[GameState] Failed to parse save data!")
	else:
		push_error("[GameState] Failed to open save file!")

func has_save_file() -> bool:
	"""Returns true if a save file exists."""
	return FileAccess.file_exists(SAVE_PATH)

func get_state_summary() -> String:
	"""Returns a human-readable summary of the current game state."""
	return "[Level %d] %s | Hunger: %.0f | Energy: %.0f | Happiness: %.0f" % [
		level,
		Phase.keys()[phase],
		hunger,
		energy,
		happiness
	]
