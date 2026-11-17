class_name Weapon
extends Node

## Arma de un vehículo. Es la ÚNICA que crea balas: tanto el teclado (PC)
## como el joystick (Android) disparan llamando a shoot().
## También maneja la munición y la cadencia de disparo.

signal municion_cambiada(actual: int, maxima: int)

@export var muzzle: Node3D          # PuntoDisparo de ESTE vehículo
@export var bullet_scene: PackedScene
@export var damage: float = 10.0
@export var max_range: float = 100.0
@export var bullet_speed: float = 80.0
@export var fire_rate: float = 0.25   # segundos mínimos entre disparos
@export var municion_maxima: int = 100

var municion_actual: int
var _last_shot_time: float = -1000.0


func _ready() -> void:
	municion_actual = municion_maxima
	GDSync.expose_func(spawn_bullet_remote)   # cualquiera dispara: es solo la copia visual


## Dispara hacia `direction` (en el mundo). Devuelve true si salió una bala.
func shoot(direction: Vector3) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot_time < fire_rate:
		return false
	if municion_actual <= 0:
		return false
	direction.y = 0.0
	if direction.length() < 0.01:
		return false
	direction = direction.normalized()
	_last_shot_time = now

	municion_actual -= 1
	municion_cambiada.emit(municion_actual, municion_maxima)

	var pos := muzzle.global_position
	var shot_dir := -direction   # la bala avanza en sentido contrario a su `direction`
	var peer_id := GDSync.get_client_id()

	_spawn_bullet(pos, shot_dir, peer_id, true)
	GDSync.call_func(spawn_bullet_remote, [pos, shot_dir, peer_id])
	return true


## Para el ítem de munición, si algún día lo agregás.
func recargar(cantidad: int) -> void:
	municion_actual = mini(municion_actual + cantidad, municion_maxima)
	municion_cambiada.emit(municion_actual, municion_maxima)


# Los parámetros de call_func llegan empaquetados en un Array
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
