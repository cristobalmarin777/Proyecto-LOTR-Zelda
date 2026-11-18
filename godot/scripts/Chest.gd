class_name TreasureChest
extends Node2D

var chest_id := ""
var reward := ""
var title := ""
var description := ""
var opened := false
var tint := Color("8c5319")

func configure(data: Dictionary) -> void:
	chest_id = str(data.get("id", ""))
	reward = str(data.get("reward", ""))
	title = str(data.get("title", "Cofre"))
	description = str(data.get("description", ""))
	global_position = Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
	add_to_group("chests")
	queue_redraw()

func open() -> void:
	opened = true
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-12, 10, 24, 5), Color(0.0, 0.0, 0.0, 0.35))
	var body := Color("4a3520") if opened else tint
	draw_rect(Rect2(-11, -6, 22, 18), body)
	draw_rect(Rect2(-11, 0, 22, 3), Color("d4af37"))
	if opened:
		draw_rect(Rect2(-11, -11, 22, 7), body.lightened(0.1))
	else:
		draw_rect(Rect2(-10, -9, 20, 5), body.lightened(0.18))
		draw_rect(Rect2(-2, -1, 4, 6), Color("ffe283"))

