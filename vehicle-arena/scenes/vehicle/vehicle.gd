extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 9000.0
## Freno: con masa 1000, entre 25 y 30 es un frenado fuerte.
@export var FUERZA_FRENO := 30.0
## Potencia de la marcha atrás, como fracción de ENGINE_POWER (0.5 = la mitad).
@export var POTENCIA_REVERSA := 0.5
## Por debajo de esta velocidad (m/s) el auto se considera detenido y entra la reversa.
@export var VELOCIDAD_DETENIDO := 1.0
## HUD de munición (el CanvasLayer con hud.gd). Se asigna en la escena del jugador.
@export var ammo_hud: CanvasLayer

@onready var vehicle_input = $VehicleInput
@onready var weapon: Weapon = $weapon
@onready var health: HealthComponent = $HealthComponent

var _en_reversa := false
var _muerto := false   # estado local de cada peer, se deduce de health.current (sincronizado)


func _ready() -> void:
	add_to_group("vehiculos")   # el GameManager cuenta los vivos con este grupo
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	if ammo_hud != null:
		weapon.municion_cambiada.connect(ammo_hud.actualizar_municion)
		ammo_hud.actualizar_municion(weapon.municion_actual, weapon.municion_maxima)


# El cartel con nombre y vida lo maneja cartel_jugador.gd (escena del jugador)
func _on_health_changed(current: float, _max_value: float) -> void:
	# current llega sincronizado, así que esto corre en TODOS los peers
	if current <= 0.0 and not _muerto:
		_morir()


func _morir() -> void:
	_muerto = true
	engine_force = 0.0
	steering = 0.0
	brake = 10.0
	# acá: explosión, humo, oscurecer el modelo, etc.


# died se emite solo en el host: es el momento de revisar si terminó la partida
func _on_died() -> void:
	if GDSync.is_host():
		get_tree().get_first_node_in_group("game_manager").revisar_ganador()


func _physics_process(delta: float) -> void:
	if not GDSync.is_gdsync_owner(self):
		return

	# vehículo muerto: no maneja ni dispara
	if _muerto:
		return

	steering = move_toward(
		steering,
		vehicle_input.steering * MAX_STEER,
		delta * 10
	)

	_aplicar_motor_y_freno()

	# Disparo con teclado: hacia adelante del kart.
	# (El joystick de Android dispara desde AimController, también con weapon.shoot)
	if Input.is_action_just_pressed("disparar"):
		weapon.shoot(global_transform.basis.z)


# Freno que se convierte en marcha atrás:
# mientras mantenés el freno, el auto frena; cuando ya casi no se mueve,
# empieza a ir para atrás. Al soltar el freno se sale de la reversa.
func _aplicar_motor_y_freno() -> void:
	if vehicle_input.brake > 0.0:
		if not _en_reversa and linear_velocity.length() < VELOCIDAD_DETENIDO:
			_en_reversa = true
		if _en_reversa:
			brake = 0.0
			engine_force = -ENGINE_POWER * POTENCIA_REVERSA * vehicle_input.brake
		else:
			engine_force = 0.0
			brake = FUERZA_FRENO * vehicle_input.brake
	else:
		_en_reversa = false
		brake = 0.0
		engine_force = vehicle_input.throttle * ENGINE_POWER


func curar(amount: float) -> void:
	health.heal(amount)
