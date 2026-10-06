extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 9000.0
@export var hud: CanvasLayer
@onready var vehicle_input = $VehicleInput
var municion_maxima: int = 30
var municion_actual: int = 30
@export var bullet_scene: PackedScene
@onready var punto_disparo: Marker3D = $PuntoDisparo
@export var ammo_hud: CanvasLayer
@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D

signal municion_cambiada(actual, maxima)

func _ready() -> void:	
	if hud:
		hud.actualizar_municion(municion_actual, municion_maxima)
		GDSync.expose_func(spawn_bullet_remote)
		health.health_changed.connect(_on_health_changed)
		_on_health_changed(health.current, health.max_health)
	if ammo_hud != null:
		municion_cambiada.connect(ammo_hud.actualizar_municion)
		ammo_hud.actualizar_municion(municion_actual, municion_maxima)
func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]



func _physics_process(delta: float) -> void:
	if not GDSync.is_gdsync_owner(self):
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
	if municion_actual > 0:
		municion_actual -= 1
		
		# Agregamos este print temporal para ver la consola
		print("Pum! Balas restantes: ", municion_actual) 
		
		municion_cambiada.emit(municion_actual, municion_maxima)
		
		var pos := punto_disparo.global_position
		var dir := -global_transform.basis.z
		spawn_bullet(pos, dir, true)
		GDSync.call_func(spawn_bullet_remote, [pos, dir])
	else:
		print("¡Sin munición! Bloqueando disparo.")

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
