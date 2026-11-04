extends Node

@export var joystick: VirtualJoystick
@export var weapon: Weapon
@export var camera: Camera3D

func _ready() -> void:
	joystick.flicked.connect(_on_flicked)

func _on_flicked(input_vector: Vector2) -> void:
	weapon.shoot(_screen_to_world(-input_vector))

func _screen_to_world(dir2d: Vector2) -> Vector3:
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	return right * dir2d.x + forward * -dir2d.y
	
