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
## Solo en el host: ID del jugador que dio el último golpe (-1 si nadie).
## Cuando la vida llega a 0, este es el que lo mató.
var ultimo_atacante: int = -1

func _ready() -> void:
	current = max_health
	GDSync.expose_func(_host_apply_damage)   # cualquiera avisa un golpe; el host lo valida
	GDSync.expose_func(_host_heal, ENUMS.EXPOSE_PERMISSION.HOST)      # curar lo decide el host (ítem)

# Lo llama el Hurtbox en el peer donde se detectó el golpe.
# atacante = ID del jugador que disparó (-1 si no se sabe).
func apply_damage(amount: float, atacante: int = -1) -> void:
	if is_dead:
		return
	if GDSync.is_host():
		_host_apply_damage([amount, atacante])
	else:
		GDSync.call_func_on(GDSync.get_host(), _host_apply_damage, [amount, atacante])

# Solo el host aplica el daño realmente.
# Llega como [daño, atacante] (call_func empaqueta los parámetros en un Array).
func _host_apply_damage(data = null) -> void:
	if not GDSync.is_host() or is_dead or invulnerable:
		return

	var amount: float = 0.0
	var atacante: int = -1
	if data is Array:
		if data.size() > 0:
			amount = float(data[0])
		if data.size() > 1:
			atacante = int(data[1])
	elif data != null:
		amount = float(data)

	if validator:
		# Limita el daño por jugador: cada atacante tiene su propio intervalo
		amount = validator.validate(atacante, amount)
		if amount < 0.0:
			return

	ultimo_atacante = atacante
	current = max(current - amount, 0.0)
	damaged.emit(amount)
	if current <= 0.0:
		is_dead = true
		died.emit()   # solo en el host: ultimo_atacante es quien lo mató

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
	ultimo_atacante = -1
	current = max_health
