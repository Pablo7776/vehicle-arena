class_name HealthComponent
extends Node

signal health_changed(current: float, max_value: float)
signal damaged(amount: float)
signal died

@export var validator: DamageValidator   # opcional
@export var max_health: float = 100.0
@export var invulnerable: bool = false

var current: float = 0.0:
	set(value):
		current = value
		health_changed.emit(current, max_health)

var is_dead: bool = false

func _ready() -> void:
	current = max_health
	GDSync.expose_func(_host_apply_damage)
	GDSync.expose_func(_host_heal)

# Lo llama el Hurtbox en el peer donde se detectó el golpe
func apply_damage(amount: float) -> void:
	if is_dead:
		return
	if GDSync.is_host():
		_host_apply_damage(amount)
	else:
		GDSync.call_func_on(GDSync.get_host(), _host_apply_damage, [amount])

# Solo el host aplica el daño realmente
func _host_apply_damage(data = null) -> void:
	if not GDSync.is_host() or is_dead or invulnerable:
		return

	var amount: float = 0.0
	if data is Array and data.size() > 0:
		amount = float(data[0])
	elif data != null:
		amount = float(data)

	if validator:
		var sender: int = GDSync.get_client_id()   # temporal, ver abajo
		amount = validator.validate(sender, amount)
		if amount < 0.0:
			return

	current = max(current - amount, 0.0)
	damaged.emit(amount)
	if current <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead:
		return
	if GDSync.is_host():
		_host_heal(amount)
	else:
		GDSync.call_func_on(GDSync.get_host(), _host_heal, [amount])
		

func _host_heal(data = null) -> void:
	if not GDSync.is_host() or is_dead:
		return
	var amount: float = 0.0
	if data is Array and data.size() > 0:
		amount = float(data[0])
	elif data != null:
		amount = float(data)
	current = min(current + clampf(amount, 0.0, max_health), max_health)

func reset() -> void:
	if not GDSync.is_host():
		return
	is_dead = false
	current = max_health
