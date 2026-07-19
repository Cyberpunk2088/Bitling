extends "res://scripts/ui/signal_settlement_map.gd"

## Typed path renderer that avoids ordering Variants or Strings through min/max.

func _draw_paths() -> void:
	var drawn: Dictionary = {}
	for district_id_variant in _districts.keys():
		var district_id := str(district_id_variant)
		var district: Dictionary = _districts[district_id]
		var start := _to_screen(_district_position(district_id))
		for neighbor_variant in district.get("neighbors", []):
			var neighbor := str(neighbor_variant)
			if not _districts.has(neighbor):
				continue
			var edge_key := "%s:%s" % [district_id, neighbor]
			var reverse_key := "%s:%s" % [neighbor, district_id]
			if drawn.has(edge_key) or drawn.has(reverse_key):
				continue
			drawn[edge_key] = true
			var end := _to_screen(_district_position(neighbor))
			var neighbor_data: Dictionary = _districts[neighbor]
			var unlocked := bool(district.get("unlocked", false)) and bool(neighbor_data.get("unlocked", false))
			var color := Color(COLOR_PATH, 0.72) if unlocked else Color(COLOR_LOCKED, 0.30)
			draw_line(start, end, color, 7.0, true)
			draw_line(start, end, Color(COLOR_PATH_ACTIVE, 0.12) if unlocked else Color.TRANSPARENT, 2.0, true)
