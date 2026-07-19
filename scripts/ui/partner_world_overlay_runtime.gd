extends "res://scripts/ui/partner_world_overlay.gd"

## Runtime guard: forecast signals update the visible cards without re-evaluating the matrix.

func _on_forecast_updated(forecast: Array[Dictionary]) -> void:
	if not backdrop.visible:
		return
	_rebuild_evolution_cards(forecast)
	_apply_responsive_layout()
