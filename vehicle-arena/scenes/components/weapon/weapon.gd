class_name Weapon
extends Node

@export var muzzle: Node3D          # PuntoDisparo
@export var bullet_scene: PackedScene
@export var damage: float = 10.0
@export var max_range: float = 25.0
@export var bullet_speed: float = 40.0
@export var fire_rate: float = 0.25

var _last_shot_time: float = 0.0

# direction: dirección en el mundo (plano XZ), no hace falta que esté normalizada
func shoot(direction: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot_time < fire_rate:
		return

	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	_last_shot_time = now

	var b := bullet_scene.instantiate()
	b.direction = -direction            # tu bala usa "-=", por eso va negada
	b.speed = bullet_speed
	b.life_time = max_range / bullet_speed
	b.damage = damage
	b.source_peer_id = GDSync.get_client_id()
	get_tree().current_scene.add_child(b)
	b.global_position = muzzle.global_position
