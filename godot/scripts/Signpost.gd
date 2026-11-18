class_name ShireSignpost
extends Node2D

var text := ""

func configure(data: Dictionary) -> void:
	text = str(data.get("text", ""))
	global_position = Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
	add_to_group("signposts")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-3, 0, 6, 15), Color("5c3a1e"))
	draw_rect(Rect2(-11, -9, 22, 12), Color("8c5c30"))
	draw_rect(Rect2(-8, -6, 16, 2), Color("d9c29c"))
	draw_rect(Rect2(-8, -2, 12, 2), Color("d9c29c"))

