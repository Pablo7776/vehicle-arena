extends Hitbox

@export var speed: float = 200.0
@export var life_time: float = 3.0

var direction: Vector3
var deals_damage: bool = true

func _ready() -> void:
	print("[BULLET] pos: ", global_position, " | visible: ", visible, " | deals_damage: ", deals_damage)
	super._ready()
	if deals_damage:
		hit_landed.connect(func(_h): queue_free())
	else:
		set_deferred("monitoring", false)   # copia visual: no detecta golpes
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position -= direction * speed * delta
