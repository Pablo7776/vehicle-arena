extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 9000.0
@export var hud: CanvasLayer
@onready var vehicle_input = $VehicleInput
var municion_maxima: int = 30
var municion_actual: int = 30
@export var bullet_scene: PackedScene
@onready var punto_disparo: Marker3D = $PuntoDisparo

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D

var _muerto := false   # estado local de cada peer, se deduce de health.current (sincronizado)


func _ready() -> void:
	add_to_group("vehiculos")   # el GameManager cuenta los vivos con este grupo
	GDSync.expose_func(spawn_bullet_remote)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current, health.max_health)
	if hud:
		hud.actualizar_municion(municion_actual, municion_maxima)

func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]
	# current llega sincronizado, así que esto corre en TODOS los peers
	if current <= 0.0 and not _muerto:
		_morir()

func _morir() -> void:
	_muerto = true
	engine_force = 0.0
	steering = 0.0
	brake = 10.0
	# acá: explosión, humo, oscurecer el modelo, etc.

# died se emite solo en el host: es el momento de revisar si terminó la partida
func _on_died() -> void:
	if GDSync.is_host():
		get_tree().get_first_node_in_group("game_manager").revisar_ganador()


func _physics_process(delta: float) -> void:
	if not GDSync.is_gdsync_owner(self):
		return
	
	# vehículo muerto: no maneja ni dispara
	if _muerto:
		return
	
	#print("steering input: ", vehicle_input.steering)
	steering = move_toward(
		steering,
		vehicle_input.steering * MAX_STEER,
		delta * 10
	)

	engine_force = vehicle_input.throttle * ENGINE_POWER
	
	if Input.is_action_just_pressed("disparar"):
		disparar()
		
func disparar() -> void:
	var pos := punto_disparo.global_position
	var dir := -global_transform.basis.z
	spawn_bullet(pos, dir, true)                      # mi copia, hace daño
	GDSync.call_func(spawn_bullet_remote, [pos, dir]) # copias de los demás, solo visuales


# Receptor remoto: recibe UN solo argumento
#func spawn_bullet_remote(a = null, b = null) -> void:
	#print("[REMOTO] llegó | a: ", a, " | b: ", b)
	#var pos
	#var dir
	#if a is Array:        # llegó empaquetado: [pos, dir]
	#	pos = a[0]
	#	dir = a[1]
	#else:                 # llegó como dos argumentos sueltos
	#	pos = a
	#	dir = b
	#spawn_bullet(pos, dir, false)
func spawn_bullet_remote(data) -> void:
	spawn_bullet(data[0], data[1], false)

func spawn_bullet(pos: Vector3, dir: Vector3, deals_damage: bool) -> void:
	#print("[BALA] spawn | deals_damage: ", deals_damage, " | nodo: ", get_path())
	var bala = bullet_scene.instantiate()
	bala.direction = dir
	bala.deals_damage = deals_damage
	get_tree().root.add_child(bala)
	bala.global_position = pos
	
func curar(amount: float) -> void:
	health.heal(amount)
