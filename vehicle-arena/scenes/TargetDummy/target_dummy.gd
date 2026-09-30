class_name TargetDummy
extends StaticBody3D

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)

func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
