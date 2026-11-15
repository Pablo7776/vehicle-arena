extends Node

@export var joystick: VirtualJoystick
@export var weapon: Weapon
@export var camera: Camera3D
@export var vehicle: Node3D   # arrastrá acá Kart1 (el VehicleBody3D)

func _ready() -> void:
	joystick.flicked.connect(_on_flicked)
	# GD-Sync puede tardar un momento en asignar el dueño
	await get_tree().create_timer(0.5).timeout
	if vehicle != null and not GDSync.is_gdsync_owner(vehicle):
		joystick.hide()                      # deja de recibir toques
		joystick.process_mode = Node.PROCESS_MODE_DISABLED

func _on_flicked(input_vector: Vector2) -> void:
	if vehicle == null or not GDSync.is_gdsync_owner(vehicle):
		return
	if vehicle._muerto:
		return
	weapon.shoot(_screen_to_world(-input_vector))

func _screen_to_world(dir2d: Vector2) -> Vector3:
	var cam := camera if camera != null else get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var right := cam.global_transform.basis.x
	var forward := -cam.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	return right * dir2d.x + forward * -dir2d.y
