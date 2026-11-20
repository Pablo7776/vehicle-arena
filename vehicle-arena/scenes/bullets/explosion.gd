extends Node3D

## Explosión de la bala: una esfera de luz que se agranda rápido y se apaga.
## Se crea en TODAS las máquinas (es visual), pero solo la de quien disparó
## (`hace_dano = true`) daña a lo que tenga Hurtbox dentro del radio.
## El daño pasa por el mismo camino que una bala normal: Hurtbox -> HealthComponent
## -> el host lo valida.

@export var radio := 6.0          # metros
@export var duracion := 0.35      # segundos que tarda en agrandarse y apagarse

# Los completa la bala antes de llamar a explotar()
var damage := 15.0
var source_peer_id := 1
var hace_dano := false
var collision_mask := 11          # qué capas puede dañar (la misma máscara que la bala)

@onready var esfera: MeshInstance3D = $Esfera


## La bala lo llama después de agregarla al árbol y ubicarla.
func explotar() -> void:
	# Copia del material para poder apagarlo sin tocar el de otras explosiones
	var material := esfera.get_active_material(0).duplicate() as StandardMaterial3D
	esfera.material_override = material
	esfera.scale = Vector3.ONE * 0.2   # la malla mide 1 de radio

	var tween := create_tween().set_parallel(true)
	tween.tween_property(esfera, "scale", Vector3.ONE * radio, duracion) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if material != null:
		tween.tween_property(material, "albedo_color:a", 0.0, duracion)
		tween.tween_property(material, "emission_energy_multiplier", 0.0, duracion)
	tween.chain().tween_callback(queue_free)

	if hace_dano:
		await get_tree().physics_frame   # las consultas de física van en el paso de física
		_danar_alrededor()


func _danar_alrededor() -> void:
	var forma := SphereShape3D.new()
	forma.radius = radio
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), global_position)
	consulta.collision_mask = collision_mask
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false

	var ya_danados := {}   # un objeto puede tener varias Hurtbox: se daña una sola vez
	for resultado in get_world_3d().direct_space_state.intersect_shape(consulta, 32):
		var hurtbox := resultado.collider as Hurtbox
		if hurtbox == null or ya_danados.has(hurtbox.health):
			continue
		ya_danados[hurtbox.health] = true
		var hit := HitData.new()
		hit.amount = damage
		hit.source_peer_id = source_peer_id
		hit.hit_position = global_position
		hurtbox.receive_hit(hit)
