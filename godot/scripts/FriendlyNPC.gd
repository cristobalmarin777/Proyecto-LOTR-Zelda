class_name FriendlyNPC
extends Node2D

var role := "scout"
var used := false

func configure(npc_role: String, spawn_position: Vector2) -> void:
	role = npc_role
	global_position = spawn_position
	add_to_group("friendly_npcs")
	queue_redraw()

func label() -> String:
	match role:
		"merchant": return "Vendedor de la Comarca"
		"lembas": return "Elfa portadora de lembas"
		"quest": return "Elfo guardabosques"
		_: return "Elfo explorador"

func _draw() -> void:
	var clothes := Color("6cc392") if role != "merchant" else Color("9f6d3f")
	draw_circle(Vector2(0, -7), 6.0, Color("f0cfaa"))
	draw_rect(Rect2(-8, 0, 16, 16), clothes)
	if role != "merchant":
		draw_line(Vector2(8, -3), Vector2(14, -12), Color("d8e8df"), 2.0)

