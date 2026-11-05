class_name Weapon
extends Node

@export var muzzle: Node3D          # PuntoDisparo de ESTE vehículo
@export var bullet_scene: PackedScene
@export var damage: float = 10.0
@export var max_range: float = 25.0
@export var bullet_speed: float = 40.0
@export var fire_rate: float = 0.25

var _last_shot_time: float = 0.0

func _ready() -> void:
	GDSync.expose_func(spawn_bullet_remote)

func shoot(direction: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot_time < fire_rate:
		return
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	_last_shot_time = now

	var pos := muzzle.global_position
	var shot_dir := -direction
	var peer_id := GDSync.get_client_id()

	_spawn_bullet(pos, shot_dir, peer_id, true)
	GDSync.call_func(spawn_bullet_remote, [pos, shot_dir, peer_id])

func spawn_bullet_remote(data) -> void:
	_spawn_bullet(data[0], data[1], data[2], false)

func _spawn_bullet(pos: Vector3, dir: Vector3, peer_id: int, deals_damage: bool) -> void:
	var b := bullet_scene.instantiate()
	b.direction = dir
	b.speed = bullet_speed
	b.life_time = max_range / bullet_speed
	b.damage = damage
	b.source_peer_id = peer_id
	b.deals_damage = deals_damage
	get_tree().current_scene.add_child(b)
	b.global_position = pos
