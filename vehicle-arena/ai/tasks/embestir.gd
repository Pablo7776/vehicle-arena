extends BTAction

@export var preparacion: float = 0.6
@export var vel_carga: float = 25.0
@export var duracion_carga: float = 0.5
@export var fuerza_empuje: float = 30.0
@export var radio_golpe: float = 4.0

var _obj: Node3D
var _fase: int = 0
var _t: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _golpeo: bool = false

func _enter() -> void:
	print("EMBESTIR: enter")
	_obj = null
	var mejor: float = INF
	for v: Node3D in agent.get_tree().get_nodes_in_group("vehiculos"):
		var d: float = agent.global_position.distance_to(v.global_position)
		if d < mejor:
			mejor = d
			_obj = v
	_fase = 0
	_t = 0.0
	_golpeo = false
	agent.stop()
	agent.set_estado("Preparando embestida...")

func _tick(delta: float) -> Status:
	if _obj == null or not is_instance_valid(_obj):
		return FAILURE
	_t += delta
	if _fase == 0:
		agent.mirar_a(_obj.global_position)
		if _t >= preparacion:
			_dir = _obj.global_position - agent.global_position
			_dir.y = 0.0
			_dir = _dir.normalized()
			agent.dash(_dir, vel_carga, duracion_carga)
			agent.set_estado("¡Embistiendo!")
			_fase = 1
			_t = 0.0
	else:
		if not _golpeo and agent.global_position.distance_to(_obj.global_position) < radio_golpe:
			_empujar(_obj)
			_golpeo = true
		if _t >= duracion_carga:
			return SUCCESS
	return RUNNING

func _empujar(obj: Node3D) -> void:
	if obj.has_method("recibir_empujon"):
		# Un kart: su posición la manda su DUEÑO, así que el empujón lo tiene que
		# aplicar él (clase 10: "el servidor decide, el dueño ejecuta")
		obj.recibir_empujon(_dir * fuerza_empuje * obj.mass)
	elif obj is RigidBody3D:
		obj.apply_central_impulse(_dir * fuerza_empuje * obj.mass)
	elif obj is CharacterBody3D:
		obj.velocity += _dir * fuerza_empuje
