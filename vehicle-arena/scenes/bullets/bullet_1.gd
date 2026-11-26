extends Hitbox

@export var speed: float = 1200.0
@export var life_time: float = 20.0

@export_group("Seguimiento del suelo")
@export var hover_height: float = 0.8        # distancia fija sobre el suelo
@export_flags_3d_physics var ground_mask: int = 1   # layer del suelo
@export var ray_up: float = 3.0              # desde cuánto más arriba sale el rayo
@export var ray_down: float = 10.0           # cuánto baja buscando el suelo
@export var follow_smooth: float = 20.0      # más alto = sigue el terreno más rápido

@export_group("Explosión")
@export var explosion_scene: PackedScene = preload("res://scenes/bullets/explosion.tscn")
@export var explosion_damage: float = 15.0   # el host limita cada golpe a 25 (DamageValidator)
## Si explota sola al terminar su recorrido. Apagado: solo explota con el botón
## EXPLOTAR, y si llega al final sin detonarla simplemente desaparece.
@export var explota_al_final := false
## Si al pegarle directo a algo se ve la explosión (visual, sin daño extra).
@export var explota_al_impactar := false

var direction: Vector3
var deals_damage: bool = true
var _exploto := false

func _ready() -> void:
	super._ready()
	if deals_damage:
		# Golpe directo: el daño ya lo hizo el Hitbox
		hit_landed.connect(_al_impactar)
	else:
		set_deferred("monitoring", false)   # copia visual: no detecta golpes
	# Al terminar su recorrido (alcance del arma) explota o desaparece.
	# Pasa en todas las máquinas a la vez, porque todas las copias tienen el mismo life_time.
	await get_tree().create_timer(life_time).timeout
	if explota_al_final:
		explotar(deals_damage)
	else:
		_exploto = true   # ya no se puede detonar
		queue_free()


func _al_impactar(_hurtbox) -> void:
	if explota_al_impactar:
		explotar(false)
	else:
		_exploto = true
		queue_free()


## Crea la explosión donde está la bala y la borra.
## `con_dano`: si la explosión daña lo que tiene alrededor (solo la bala de quien disparó).
func explotar(con_dano: bool) -> void:
	if _exploto:
		return
	_exploto = true
	if explosion_scene != null:
		var e := explosion_scene.instantiate()
		e.damage = explosion_damage
		e.source_peer_id = source_peer_id
		e.hace_dano = con_dano
		e.collision_mask = collision_mask
		get_tree().current_scene.add_child(e)
		e.global_position = global_position
		e.reset_physics_interpolation()
		e.explotar()
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
