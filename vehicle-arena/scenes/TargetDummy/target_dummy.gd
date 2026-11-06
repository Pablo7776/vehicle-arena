class_name TargetDummy
extends CharacterBody3D

@export var move_speed: float = 4.0
@export var gravity: float = 20.0
@export var turn_speed: float = 8.0
@export var wander_range: float = 30.0
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D
@onready var nav: NavigationAgent3D = $NavigationAgent3D

var _idle_timer: float = 0.0

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)
	await _wait_for_nav_map()
	_pick_new_target()

func _wait_for_nav_map() -> void:
	var map := get_world_3d().navigation_map
	# El mapa está vacío (iteration_id 0) hasta que se sincroniza con la región
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var dir := Vector3.ZERO

	if nav.is_navigation_finished():
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_pick_new_target()
	else:
		var next_pos := nav.get_next_path_position()
		dir = next_pos - global_position
		dir.y = 0.0
		dir = dir.normalized()

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if dir.length() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()

func _pick_new_target() -> void:
	var map := get_world_3d().navigation_map
	var found := false

	for i in 10:
		var random_point := global_position + Vector3(
			randf_range(-wander_range, wander_range),
			0.0,
			randf_range(-wander_range, wander_range)
		)
		var candidate := NavigationServer3D.map_get_closest_point(map, random_point)
		# Descartar el (0,0,0) que devuelve un mapa vacío, y destinos lejanos
		if candidate != Vector3.ZERO and candidate.distance_to(random_point) <= wander_range * 0.5:
			nav.target_position = candidate
			found = true
			break

	if not found:
		push_warning("TargetDummy: no hay malla de navegación cerca de " + str(global_position))
		nav.target_position = global_position   # quedarse quieto

	_idle_timer = randf_range(idle_time_min, idle_time_max)
func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
