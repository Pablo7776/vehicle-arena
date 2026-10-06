class_name HealthComponent
extends Node

signal health_changed(current: float, max_value: float)
signal damaged(hit: HitData)
signal died

@export var max_health: float = 100.0
@export var invulnerable: bool = false

var current: float = 0.0:
	set(value):
		current = value
		health_changed.emit(current, max_health)

var is_dead: bool = false

#func _ready() -> void:
	#current = max_health
	
func _ready() -> void:
	current = max_health
	print("[HP] ready | host: ", GDSync.is_host(), " | owner: ", GDSync.get_gdsync_owner(self))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if GDSync.is_host():
			current -= 10

func apply_damage(hit: HitData) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	if not invulnerable:
		current = max(current - hit.amount, 0.0)
	damaged.emit(hit)
	if current <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current = min(current + amount, max_health)

func reset() -> void:
	is_dead = false
	current = max_health
