extends "res://scripts/ui/metafinal_visual_director_v2.gd"

const RadialStatusMeter := preload("res://scripts/ui/radial_status_meter.gd")
const RELATIONSHIP_ACCENT := Color("ff3ed1")

var _relationship_meter: Control

func _install() -> void:
	super._install()
	_install_relationship_meter()
	_refresh_relationship_meter()
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain != null and not brain.relationship_changed.is_connected(_on_relationship_meter_changed):
		brain.relationship_changed.connect(_on_relationship_meter_changed)

func _install_relationship_meter() -> void:
	var label_variant: Variant = _dashboard.get("relationship_label")
	if not label_variant is Label:
		return
	var relationship_label := label_variant as Label
	var column := relationship_label.get_parent()
	if column == null or column.find_child("RelationshipProductionRow", false, false) != null:
		return
	column.remove_child(relationship_label)
	var row := HBoxContainer.new()
	row.name = "RelationshipProductionRow"
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	relationship_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relationship_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(relationship_label)
	_relationship_meter = RadialStatusMeter.new()
	_relationship_meter.name = "TrustRadialMeter"
	_relationship_meter.configure("VERTRAUEN", RELATIONSHIP_ACCENT)
	_relationship_meter.custom_minimum_size = Vector2(104.0, 104.0)
	row.add_child(_relationship_meter)

func _refresh_relationship_meter() -> void:
	if _relationship_meter == null:
		return
	var brain := get_node_or_null("/root/CompanionBrain")
	if brain == null:
		return
	_relationship_meter.call("set_value", float(brain.trust))

func _on_relationship_meter_changed(_old_value: float, _new_value: float) -> void:
	_refresh_relationship_meter()
