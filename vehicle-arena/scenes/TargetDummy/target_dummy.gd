class_name TargetDummy
extends CharacterBody3D

@export var move_speed: float = 4.0
@export var gravity: float = 20.0
@export var turn_speed: float = 8.0
@export var wander_time_min: float = 1.5
@export var wander_time_max: float = 4.0
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D

var _move_dir: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)
	_pick_new_state()

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Temporizador de estado (caminar / quieto)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_pick_new_state()

	# Movimiento horizontal
	velocity.x = _move_dir.x * move_speed
	velocity.z = _move_dir.z * move_speed

	# Girar hacia donde camina
	if _move_dir.length() > 0.01:
		var target_yaw := atan2(-_move_dir.x, -_move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()

func _pick_new_state() -> void:
	if _move_dir == Vector3.ZERO:
		# Pasa a caminar en una dirección al azar
		var angle := randf() * TAU
		_move_dir = Vector3(cos(angle), 0.0, sin(angle))
		_state_timer = randf_range(wander_time_min, wander_time_max)
	else:
		# Pasa a quedarse quieto
		_move_dir = Vector3.ZERO
		_state_timer = randf_range(idle_time_min, idle_time_max)

func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
