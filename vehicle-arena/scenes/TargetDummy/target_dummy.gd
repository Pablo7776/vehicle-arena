class_name TargetDummy
extends CharacterBody3D

# Estados del animal. Más adelante se puede agregar ATTACK (ver _update_state).
enum State { WANDER, FLEE }

@export var move_speed: float = 4.0       # velocidad al deambular
@export var gravity: float = 20.0
@export var turn_speed: float = 8.0
@export var wander_range: float = 30.0
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

@export_group("Huida")
@export var threat_group := "vehiculos"          # grupo de lo que lo asusta
@export var flee_speed: float = 50.0              # velocidad al huir
@export var flee_trigger_distance: float = 25.0  # huye si un vehículo está más cerca que esto
@export var flee_safe_distance: float = 40.0     # deja de huir cuando está más lejos que esto
@export var flee_run_distance: float = 30.0      # cuánto se aleja en cada tramo
@export var flee_repath_time: float = 0.4        # cada cuánto recalcula hacia dónde huir

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D
@onready var nav: NavigationAgent3D = $NavigationAgent3D

var state: State = State.WANDER
var _idle_timer: float = 0.0
var _repath_timer: float = 0.0
var _nav_listo := false


func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)
	await _wait_for_nav_map()
	_nav_listo = true
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

	# Hasta que el mapa de navegación esté listo, solo se aplica la gravedad
	if not _nav_listo:
		move_and_slide()
		return

	var threat := _nearest_threat()
	_update_state(threat)

	var dir := Vector3.ZERO
	var speed := move_speed
	match state:
		State.WANDER:
			dir = _wander(delta)
		State.FLEE:
			dir = _flee(delta, threat)
			speed = flee_speed

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if dir.length() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()


# --- Estados ---------------------------------------------------------------

# Acá se deciden las transiciones. Para agregar ATTACK, sumá el estado al enum,
# una transición acá (por ejemplo "si hay un vehículo a menos de 5 m -> ATTACK")
# y una función _attack() en el match de _physics_process.
func _update_state(threat: Node3D) -> void:
	var dist := INF
	if threat != null:
		dist = _flat_distance_to(threat)

	match state:
		State.WANDER:
			if dist < flee_trigger_distance:
				_set_state(State.FLEE)
		State.FLEE:
			if dist > flee_safe_distance:
				_set_state(State.WANDER)


func _set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.FLEE:
			_repath_timer = 0.0     # calcula hacia dónde huir enseguida
		State.WANDER:
			_pick_new_target()


func _wander(delta: float) -> Vector3:
	if nav.is_navigation_finished():
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_pick_new_target()
		return Vector3.ZERO
	return _direction_to_next_path()


func _flee(delta: float, threat: Node3D) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0 and threat != null:
		_repath_timer = flee_repath_time
		_pick_flee_target(threat.global_position)
	if nav.is_navigation_finished():
		return Vector3.ZERO
	return _direction_to_next_path()


# --- Navegación ------------------------------------------------------------

func _direction_to_next_path() -> Vector3:
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	return d.normalized()


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


# Prueba varias direcciones alejándose de la amenaza y elige el destino más lejano de ella.
# Así, si hay un borde del mapa o una pared, busca una salida en vez de quedarse trabado.
func _pick_flee_target(threat_pos: Vector3) -> void:
	var map := get_world_3d().navigation_map
	var away := global_position - threat_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()

	var best := global_position
	var best_score := -INF
	for angle: float in [-90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0]:
		var d := away.rotated(Vector3.UP, deg_to_rad(angle))
		var p := NavigationServer3D.map_get_closest_point(map, global_position + d * flee_run_distance)
		if p == Vector3.ZERO:
			continue
		var score := p.distance_to(threat_pos)
		if score > best_score:
			best_score = score
			best = p

	nav.target_position = best


# --- Amenazas --------------------------------------------------------------

func _nearest_threat() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(threat_group):
		var v := node as Node3D
		if v == null or v.get("_muerto"):   # ignora los vehículos destruidos
			continue
		var d := _flat_distance_to(v)
		if d < nearest_dist:
			nearest_dist = d
			nearest = v
	return nearest


func _flat_distance_to(other: Node3D) -> float:
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(other.global_position.x, other.global_position.z)
	return a.distance_to(b)


func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
