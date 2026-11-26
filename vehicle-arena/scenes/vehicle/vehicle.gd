extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 12000.0
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
var _muerto := false   # true = no maneja ni dispara (sin vida, o la partida terminó)


func _ready() -> void:
	add_to_group("vehiculos")   # el game_manager los detiene a todos al terminar la partida
	# Interpolación de física solo para TU kart (lo mueve tu física). Los karts de
	# los demás los mueve la red (PropertySynchronizer) en cada imagen: si Godot los
	# interpolara además, se verían con retraso o a los saltos.
	GDSync.connect_gdsync_owner_changed(self, func(_dueno): _actualizar_interpolacion())
	_actualizar_interpolacion()
	GDSync.expose_func(_empujon_remoto, ENUMS.EXPOSE_PERMISSION.HOST)   # el empujón lo ordena el jabalí, que corre en el host
	GDSync.expose_func(_balas_remoto, ENUMS.EXPOSE_PERMISSION.HOST)     # las balas las da el ítem, que decide el host
	health.health_changed.connect(_on_health_changed)
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


func _actualizar_interpolacion() -> void:
	if GDSync.is_gdsync_owner(self):
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	else:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	reset_physics_interpolation()


## Lo llama el game_manager en todas las máquinas cuando termina la partida:
## el kart frena y deja de manejar y disparar (AimController también mira _muerto).
func detener() -> void:
	_muerto = true
	engine_force = 0.0
	steering = 0.0
	brake = FUERZA_FRENO


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

	# El disparo (mouse, Espacio y joystick) lo maneja AimController.


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


## Lo llama el jabalí (que corre en el host) cuando embiste a este kart.
## La posición del kart la manda su DUEÑO: si el host lo empujara en su copia,
## el dueño lo pisaría en el frame siguiente. Por eso el empujón se le pide
## al dueño (clase 10: "el servidor decide, el dueño ejecuta").
func recibir_empujon(impulso: Vector3) -> void:
	if GDSync.is_gdsync_owner(self):
		apply_central_impulse(impulso)
	else:
		GDSync.call_func_on(GDSync.get_gdsync_owner(self), _empujon_remoto, [impulso])


# Corre en la máquina del dueño. Los parámetros llegan empaquetados en un Array.
func _empujon_remoto(data) -> void:
	var impulso: Vector3 = data[0] if data is Array else data
	apply_central_impulse(impulso)


## Lo llama el ítem de munición (en el host) cuando este kart lo agarra.
## La munición la lleva el DUEÑO en su máquina (no viaja por red), así que
## el host se la pide a él: igual que el empujón, el host decide y el dueño ejecuta.
func recibir_balas(cantidad: int) -> void:
	if GDSync.is_gdsync_owner(self):
		weapon.recargar(cantidad)
	else:
		GDSync.call_func_on(GDSync.get_gdsync_owner(self), _balas_remoto, [cantidad])


# Corre en la máquina del dueño. Los parámetros llegan empaquetados en un Array.
func _balas_remoto(data) -> void:
	var cantidad: int = int(data[0]) if data is Array else int(data)
	weapon.recargar(cantidad)


func curar(amount: float) -> void:
	health.heal(amount)
