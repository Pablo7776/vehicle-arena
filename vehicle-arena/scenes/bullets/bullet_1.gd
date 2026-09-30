extends Area3D

@export var speed: float = 200.0
@export var damage: int = 10
@export var life_time: float = 3.0

var direction: Vector3

func _ready() -> void:
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position -= direction * speed * delta
