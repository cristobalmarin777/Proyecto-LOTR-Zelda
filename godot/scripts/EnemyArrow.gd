class_name EnemyArrow
extends Node2D

var direction := Vector2.RIGHT
var damage := 1
var target: MiddleEarthPlayer
var lifetime := 2.6

func setup(origin: Vector2, destination: Vector2, attack_damage: int, player_ref: MiddleEarthPlayer) -> void:
	global_position = origin
	direction = (destination - origin).normalized()
	damage = attack_damage
	target = player_ref
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	global_position += direction * 285.0 * delta
	if target != null and global_position.distance_to(target.global_position) < 14.0:
		target.take_damage(damage, global_position)
		queue_free()
	elif lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-7, 0), Vector2(8, 0), Color("dbc089"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(4, -3), Vector2(4, 3)]), Color("d7d7d7"))

