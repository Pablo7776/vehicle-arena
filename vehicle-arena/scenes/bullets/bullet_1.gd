extends Hitbox

@export var speed: float = 1200.0
@export var life_time: float = 20.0

@export_group("Seguimiento del suelo")
@export var hover_height: float = 0.8        # distancia fija sobre el suelo
@export_flags_3d_physics var ground_mask: int = 1   # layer del suelo
@export var ray_up: float = 3.0              # desde cuánto más arriba sale el rayo
@export var ray_down: float = 10.0           # cuánto baja buscando el suelo
@export var follow_smooth: float = 20.0      # más alto = sigue el terreno más rápido

var direction: Vector3
var deals_damage: bool = true

func _ready() -> void:
	super._ready()
	if deals_damage:
		hit_landed.connect(func(_h): queue_free())
	else:
		set_deferred("monitoring", false)   # copia visual: no detecta golpes
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position -= direction * speed * delta
	_follow_ground(delta)

func _follow_ground(delta: float) -> void:
	var from := global_position + Vector3.UP * ray_up
	var to := global_position + Vector3.DOWN * ray_down
	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return   # sin suelo debajo (un hueco): mantiene la altura actual
	var target_y: float = result.position.y + hover_height
	global_position.y = lerpf(global_position.y, target_y, clampf(follow_smooth * delta, 0.0, 1.0))
