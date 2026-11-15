class_name Hurtbox
extends Area3D

@export var health: HealthComponent
@export var damage_multiplier: float = 1.0

func receive_hit(hit: HitData) -> void:
	if health:
		health.apply_damage(hit.amount * damage_multiplier)	
