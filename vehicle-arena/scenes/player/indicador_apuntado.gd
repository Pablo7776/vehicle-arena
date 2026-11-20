extends Node3D

## Círculo con una flecha alrededor del kart que muestra hacia dónde vas a disparar.
## La dirección se la pide a AimController (la misma que usa para disparar).
## Solo lo ve el dueño del kart y no se sincroniza por red: es una ayuda visual.

@export var vehicle: Node3D          # Kart1
@export var aim_controller: Node     # AimController
## Radio del círculo, en metros (el kart mide unos 1,8 x 3,5).
@export var radio := 2.3
## Altura respecto del centro del kart (negativo = más cerca del piso).
@export var altura := -0.2

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


func _process(_delta: float) -> void:
	if vehicle == null or aim_controller == null:
		return
	if not GDSync.is_gdsync_owner(vehicle) or vehicle._muerto:
		visible = false
		return
	visible = true
	global_position = vehicle.global_position + Vector3.UP * altura

	var dir: Vector3 = aim_controller.direccion_apuntado()
	# Sin apuntar (joystick suelto): se ve el círculo solo, sin flecha
	flecha.visible = dir != Vector3.ZERO
	if flecha.visible:
		global_basis = Basis.looking_at(dir, Vector3.UP)   # -Z mira hacia `dir`
