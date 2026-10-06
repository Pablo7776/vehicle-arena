class_name DamageValidator
extends Node

@export var max_damage: float = 25.0
@export var min_interval_msec: int = 80

var _last_hit := {}   # id del que envió -> último golpe aceptado

# Devuelve el daño ya limitado, o -1.0 si el golpe se rechaza
func validate(sender_id: int, amount: float) -> float:
	var now := Time.get_ticks_msec()
	if now - _last_hit.get(sender_id, -min_interval_msec) < min_interval_msec:
		return -1.0
	_last_hit[sender_id] = now
	return clampf(amount, 0.0, max_damage)
