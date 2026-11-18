class_name FriendlyNPC
extends Node2D

var role := "scout"
var npc_id := ""
var character_name := "Elfo explorador"
var dialog_pages: Array = []
var is_merchant := false
var is_healer := false
var used := false
var hat_color := Color("8c5a2b")
var cloak_color := Color("3c9461")

func configure(npc_role: String, spawn_position: Vector2) -> void:
	role = npc_role
	npc_id = "elf_%s_%d_%d" % [role, roundi(spawn_position.x), roundi(spawn_position.y)]
	character_name = label()
	global_position = spawn_position
	cloak_color = Color("3c9461")
	hat_color = Color("d7f3e1")
	add_to_group("friendly_npcs")
	queue_redraw()

func configure_authored(data: Dictionary) -> void:
	npc_id = str(data.get("id", "npc"))
	role = "shire"
	character_name = str(data.get("name", "Habitante de La Comarca"))
	dialog_pages = Array(data.get("dialog", []))
	is_merchant = bool(data.get("merchant", false))
	is_healer = bool(data.get("healer", false))
	hat_color = data.get("hat_color", Color("8c5a2b")) as Color
	cloak_color = data.get("cloak_color", Color("4b7a34")) as Color
	global_position = Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
	add_to_group("friendly_npcs")
	queue_redraw()

func label() -> String:
	match role:
		"merchant": return "Vendedor de la Comarca"
		"lembas": return "Elfa portadora de lembas"
		"quest": return "Elfo guardabosques"
		_: return "Elfo explorador"

func _draw() -> void:
	draw_rect(Rect2(-9, 10, 18, 4), Color(0.0, 0.0, 0.0, 0.35))
	# Túnica y rostro en bloques para conservar la lectura pixel-art del prototipo.
	draw_rect(Rect2(-8, -3, 16, 16), cloak_color)
	draw_rect(Rect2(-6, -12, 12, 9), Color("f2c199"))
	if npc_id == "gandalf":
		draw_rect(Rect2(-5, -6, 10, 10), Color("e8eef2"))
		draw_rect(Rect2(-10, -14, 20, 3), hat_color)
		draw_rect(Rect2(-6, -19, 12, 5), hat_color)
		draw_rect(Rect2(-3, -23, 6, 4), hat_color)
		draw_line(Vector2(10, 9), Vector2(14, -15), Color("5c3a1e"), 2.0)
	else:
		draw_rect(Rect2(-7, -15, 14, 4), hat_color)
	if role != "shire":
		draw_line(Vector2(8, -3), Vector2(14, -12), Color("d8e8df"), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-28, -27), character_name.split(" ")[0], HORIZONTAL_ALIGNMENT_CENTER, 56, 8, Color("fff1c3"))

