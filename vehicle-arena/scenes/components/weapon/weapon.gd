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
# Balas de esta arma que siguen en el escenario (las que explotan con el botón).
# Cada disparo lleva un número, el mismo en todas las máquinas, para que
# cada jugador sepa cuál de sus copias corresponde a cuál bala real.
var _balas := {}          # número de bala -> la bala
var _siguiente_numero := 0


func _ready() -> void:
	municion_actual = municion_maxima
	GDSync.expose_func(spawn_bullet_remote)   # cualquiera dispara: es solo la copia visual
	GDSync.expose_func(_detonar_remoto)       # también visual: la copia explota donde explotó la real


## Dispara hacia `direction` (en el mundo). Devuelve true si salió una bala.
## `ignorar_cadencia`: para las balas de una ráfaga, que salen más seguido
## que la cadencia normal (fire_rate).
func shoot(direction: Vector3, ignorar_cadencia := false) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if not ignorar_cadencia and now - _last_shot_time < fire_rate:
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

	var numero := _siguiente_numero
	_siguiente_numero += 1

	_spawn_bullet(pos, shot_dir, peer_id, true, numero)
	GDSync.call_func(spawn_bullet_remote, [pos, shot_dir, peer_id, numero])
	return true


## Hace explotar ahora TODAS las balas de esta arma que siguen en el escenario
## (botón EXPLOTAR). Devuelve false si no había ninguna.
func detonar() -> bool:
	var detonadas := []   # [número, posición] de cada bala que explotó
	for numero in _balas.keys():
		var bala: Node3D = _balas[numero]
		if not is_instance_valid(bala) or bala._exploto:
			continue
		detonadas.append([numero, bala.global_position])
		bala.explotar(true)   # estas son las reales: sus explosiones hacen daño
	if detonadas.is_empty():
		return false
	# En las otras pantallas, cada copia explota en el mismo punto que su bala real
	GDSync.call_func(_detonar_remoto, [detonadas])
	return true


func _detonar_remoto(data) -> void:
	for par in data[0]:
		var bala: Node3D = _balas.get(int(par[0]))
		if not is_instance_valid(bala) or bala._exploto:
			continue
		bala.global_position = par[1]   # por si la copia iba un poco atrasada
		bala.explotar(false)            # copia: solo se ve


## Para el ítem de munición, si algún día lo agregás.
func recargar(cantidad: int) -> void:
	municion_actual = mini(municion_actual + cantidad, municion_maxima)
	municion_cambiada.emit(municion_actual, municion_maxima)


# Los parámetros de call_func llegan empaquetados en un Array
func spawn_bullet_remote(data) -> void:
	_spawn_bullet(data[0], data[1], data[2], false, int(data[3]))


func _spawn_bullet(pos: Vector3, dir: Vector3, peer_id: int, deals_damage: bool, numero: int) -> void:
	var b := bullet_scene.instantiate()
	b.direction = dir
	b.speed = bullet_speed
	b.life_time = max_range / bullet_speed
	b.damage = damage
	b.source_peer_id = peer_id
	b.deals_damage = deals_damage
	get_tree().current_scene.add_child(b)
	_balas[numero] = b
	b.tree_exiting.connect(func(): _balas.erase(numero))   # al desaparecer, sale de la lista
	b.global_position = pos
	b.reset_physics_interpolation()   # aparece ahí, no "viene volando" desde el origen
