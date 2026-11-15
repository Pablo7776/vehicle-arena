class_name TargetDummy
extends CharacterBody3D

@export var move_speed: float = 6.0
@export var gravity: float = 20.0
@export var turn_speed: float = 8.0

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D
@onready var estado_label: Label3D = $Label3D2  # un segundo Label3D, ponelo más arriba
@onready var nav: NavigationAgent3D = $NavigationAgent3D



var hambre: float = 0.0
var estado: String = "":
	set(v):
		estado = v
		if estado_label:
			estado_label.text = v

var _moving := false
var _dash_vel := Vector3.ZERO
var _dash_t := 0.0

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)

func go_to(pos: Vector3) -> void:
	nav.target_position = pos
	_moving = true

func stop() -> void:
	_moving = false

func has_arrived() -> bool:
	return nav.is_navigation_finished()

func mirar_a(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.3)

func dash(dir: Vector3, speed: float, duration: float) -> void:
	_moving = false
	_dash_vel = dir.normalized() * speed
	_dash_t = duration

func _physics_process(delta: float) -> void:
	hambre = minf(hambre + delta * 2.0, 100.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_vel.x
		velocity.z = _dash_vel.z
	else:
		var dir := Vector3.ZERO
		if _moving and not nav.is_navigation_finished():
			dir = nav.get_next_path_position() - global_position
			dir.y = 0.0
			dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if dir.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn_speed * delta)
	move_and_slide()

func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
	
func set_estado(texto: String) -> void:
	estado = texto
