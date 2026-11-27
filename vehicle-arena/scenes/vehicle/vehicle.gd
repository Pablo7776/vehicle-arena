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

@export_group("Enderezado automático")
## Segundos que tiene que estar volcado (y casi quieto) antes de enderezarse
@export var tiempo_volcado := 1.5
## Cuántos metros lo levanta al enderezarlo (después cae sobre las ruedas)
@export var altura_enderezado := 2.0
## Qué tan inclinado cuenta como volcado: 1 = derecho, 0 = de costado, -1 = ruedas arriba
@export_range(-1.0, 1.0) var inclinacion_volcado := 0.3
@export_group("")

@onready var vehicle_input = $VehicleInput
@onready var weapon: Weapon = $weapon
@onready var health: HealthComponent = $HealthComponent

var _en_reversa := false
var _muerto := false   # true = no maneja ni dispara (sin vida, o la partida terminó)
var _volcado_desde := -1.0   # cuándo empezó a estar volcado (-1 = no lo está)


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
	_revisar_volcado()

	# El disparo (mouse, Espacio y joystick) lo maneja AimController.


# Si el kart quedó volcado (de costado o con las ruedas para arriba) y casi
# quieto durante `tiempo_volcado` segundos, lo endereza solo.
# Corre solo en la máquina del dueño: el kart lo mueve él y la posición nueva
# les llega a los demás por el PropertySynchronizer, como siempre.
func _revisar_volcado() -> void:
	var cuanto_derecho := global_basis.y.dot(Vector3.UP)   # 1 = derecho, -1 = ruedas arriba
	var volcado := cuanto_derecho < inclinacion_volcado
	var casi_quieto := linear_velocity.length() < 3.0
	if not (volcado and casi_quieto):
		_volcado_desde = -1.0
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if _volcado_desde < 0.0:
		_volcado_desde = ahora
	elif ahora - _volcado_desde >= tiempo_volcado:
		_volcado_desde = -1.0
		_enderezar()


func _enderezar() -> void:
	# Mirando hacia donde apuntaba el frente del kart, pero derecho
	var adelante := global_basis.z
	adelante.y = 0.0
	if adelante.length() < 0.1:       # quedó parado de punta: usamos el "arriba"
		adelante = global_basis.y
		adelante.y = 0.0
	var giro := atan2(adelante.x, adelante.z) if adelante.length() > 0.01 else 0.0

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, giro),
			global_position + Vector3.UP * altura_enderezado)
	# Que no se vea "deslizándose" hasta la posición nueva:
	reset_physics_interpolation()                    # en tu pantalla
	var sync := get_node_or_null("PropertySynchronizer")
	if sync != null and sync.has_method("pause_interpolation"):
		sync.pause_interpolation(0.2)                # en las de los demás (GD-Sync)


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
