extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 9000.0

@onready var vehicle_input = $VehicleInput
@export var bullet_scene: PackedScene
@onready var punto_disparo: Marker3D = $PuntoDisparo

@onready var health: HealthComponent = $HealthComponent
@onready var label: Label3D = $Label3D

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)

func _on_health_changed(current: float, max_value: float) -> void:
	label.text = "HP: %d / %d" % [current, max_value]


func _physics_process(delta: float) -> void:
	if not GDSync.is_gdsync_owner(self):
		return
	
	print("steering input: ", vehicle_input.steering)
	steering = move_toward(
		steering,
		vehicle_input.steering * MAX_STEER,
		delta * 10
	)

	engine_force = vehicle_input.throttle * ENGINE_POWER
	
	if Input.is_action_just_pressed("disparar"):
		disparar()
		
func disparar() -> void:
	var bala = bullet_scene.instantiate()

	get_tree().root.add_child(bala)

	bala.global_position = punto_disparo.global_position
	bala.direction = -global_transform.basis.z
