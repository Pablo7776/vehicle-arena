class_name Hitbox
extends Area3D

signal hit_landed(hurtbox: Hurtbox)

@export var damage: float = 10.0
var source_peer_id: int = 1   # quién disparó (lo asigna el arma al instanciar)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if not multiplayer.is_server():
		return
	if area is Hurtbox:
		var hit := HitData.new()
		hit.amount = damage
		hit.source_peer_id = source_peer_id
		hit.hit_position = global_position
		area.receive_hit(hit)
		hit_landed.emit(area)
