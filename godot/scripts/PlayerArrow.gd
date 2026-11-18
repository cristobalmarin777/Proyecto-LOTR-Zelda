class_name PlayerArrow
extends Node2D

var direction := Vector2.RIGHT
var damage := 1
var lifetime := 1.2
var world: MiddleEarthWorld

func setup(origin: Vector2, aim: Vector2, attack_damage: int, world_ref: MiddleEarthWorld) -> void:
	global_position = origin
	direction = aim.normalized()
	damage = attack_damage
	world = world_ref
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	global_position += direction * 340.0 * delta
	if lifetime <= 0.0 or (world != null and world.is_blocked(global_position)):
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 15.0:
			enemy.take_hit(damage, global_position)
			queue_free()
			return

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color("d9a05b"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(4, -3), Vector2(4, 3)]), Color("e0e6ed"))
	draw_set_transform(Vector2.ZERO, 0.0)

