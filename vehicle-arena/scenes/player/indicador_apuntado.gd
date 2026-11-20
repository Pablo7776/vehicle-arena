extends Node3D

## Círculo con una flecha alrededor del kart que muestra hacia dónde vas a disparar.
## La dirección se la pide a AimController (la misma que usa para disparar).
## Solo lo ve el dueño del kart y no se sincroniza por red: es una ayuda visual.
## Aparece mientras apuntás con el joystick (Android) y un ratito después
## de cada disparo (PC y Android).

@export var vehicle: Node3D          # Kart1
@export var aim_controller: Node     # AimController
## Radio del círculo, en metros (el kart mide unos 1,8 x 3,5).
@export var radio := 2.3
## Altura respecto del centro del kart (negativo = más cerca del piso).
@export var altura := -0.2
## Segundos que queda visible después de disparar.
@export var tiempo_visible_tras_disparo := 1.0
## De ese tiempo, cuántos segundos finales usa para desvanecerse.
@export var duracion_desvanecer := 0.4

var _visible_hasta := 0.0           # momento (en segundos) hasta el que se muestra
var _ultima_direccion := Vector3.ZERO
var _material: StandardMaterial3D   # copia propia, para cambiarle la transparencia
var _alfa_base := 1.0
var _emision_base := 1.0

@onready var circulo: MeshInstance3D = $Circulo
@onready var flecha: MeshInstance3D = $Flecha


func _ready() -> void:
	# No hereda la inclinación del kart: siempre queda plano.
	# La posición la copiamos a mano en _process.
	top_level = true
	visible = false

	var torus := circulo.mesh as TorusMesh
	if torus != null:
		torus.inner_radius = radio - 0.08
		torus.outer_radius = radio + 0.08
	# La flecha (un prisma) queda acostada, con la punta hacia -Z,
	# justo afuera del círculo. Al girar este nodo, la flecha da la vuelta.
	flecha.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	flecha.position = Vector3(0.0, 0.0, -(radio + 0.45))

	# Copiamos el material para que el desvanecido no toque el recurso original
	# (lo comparten el círculo, la flecha y los indicadores de los otros karts).
	var original := circulo.mesh.surface_get_material(0) as StandardMaterial3D
	if original != null:
		_material = original.duplicate() as StandardMaterial3D
		_alfa_base = _material.albedo_color.a
		_emision_base = _material.emission_energy_multiplier
		circulo.material_override = _material
		flecha.material_override = _material

	if aim_controller != null:
		aim_controller.disparo.connect(_al_disparar)


func _al_disparar(direccion: Vector3) -> void:
	_ultima_direccion = direccion
	_visible_hasta = _ahora() + tiempo_visible_tras_disparo


func _process(_delta: float) -> void:
	if vehicle == null or aim_controller == null:
		return
	if not GDSync.is_gdsync_owner(vehicle) or vehicle._muerto:
		visible = false
		return
	var dir: Vector3 = aim_controller.direccion_apuntado()
	if dir != Vector3.ZERO:
		_ultima_direccion = dir   # en PC sigue al mouse mientras está visible

	# 1 = se ve entero, 0 = invisible. Mientras apuntás con el joystick, entero;
	# después de disparar, entero hasta que en el final se va apagando.
	var opacidad := 1.0
	if not aim_controller.apuntando_con_joystick():
		var restante := _visible_hasta - _ahora()
		opacidad = clampf(restante / maxf(duracion_desvanecer, 0.01), 0.0, 1.0)

	visible = opacidad > 0.0
	if not visible:
		return
	if _material != null:
		_material.albedo_color.a = _alfa_base * opacidad
		_material.emission_energy_multiplier = _emision_base * opacidad   # también se apaga el brillo

	global_position = vehicle.global_position + Vector3.UP * altura
	if _ultima_direccion != Vector3.ZERO:
		global_basis = Basis.looking_at(_ultima_direccion, Vector3.UP)   # -Z mira hacia la dirección


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0
