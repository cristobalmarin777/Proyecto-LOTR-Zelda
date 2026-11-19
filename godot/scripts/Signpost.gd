class_name ShireSignpost
extends Node2D

## Cartel de madera estilo Zelda: A Link to the Past.
## Mientras está intacto bloquea el paso (colisión activa) y se puede leer con [E].
## Al recibir un espadazo se parte a la mitad con animación de la tabla superior cayendo
## y elimina su colisión, permitiendo caminar libremente sobre el tocón.

var text := ""
var is_cut := false
var cut_anim_time := 0.0
var cut_dir := Vector2.RIGHT
var collision_radius := 11.0

func configure(data: Dictionary) -> void:
	text = str(data.get("text", ""))
	is_cut = false
	cut_anim_time = 0.0
	global_position = Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
	add_to_group("signposts")
	queue_redraw()

func cut(attack_dir: Vector2) -> bool:
	if is_cut:
		return false
	is_cut = true
	cut_anim_time = 0.0
	cut_dir = attack_dir.normalized() if not attack_dir.is_zero_approx() else Vector2.RIGHT
	queue_redraw()
	return true

func blocks_position(world_pos: Vector2) -> bool:
	if is_cut or not visible:
		return false
	return global_position.distance_to(world_pos) < collision_radius + 8.0

func _process(delta: float) -> void:
	if is_cut and cut_anim_time < 0.45:
		cut_anim_time = minf(0.45, cut_anim_time + delta)
		queue_redraw()

func _draw() -> void:
	if not is_cut:
		# Sombra + cartel intacto
		draw_rect(Rect2(-9, 11, 18, 4), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(-3, 0, 6, 15), Color("5c3a1e"))
		draw_rect(Rect2(-11, -9, 22, 12), Color("8c5c30"))
		draw_rect(Rect2(-10, -8, 20, 10), Color("a16b38"))
		draw_rect(Rect2(-8, -6, 16, 2), Color("d9c29c"))
		draw_rect(Rect2(-8, -2, 12, 2), Color("d9c29c"))
	else:
		# Mitad inferior / tocón cortado (ya sin colisión)
		draw_rect(Rect2(-6, 11, 12, 3), Color(0, 0, 0, 0.20))
		draw_rect(Rect2(-3, 5, 6, 10), Color("5c3a1e"))
		# Corte limpio de madera clara en diagonal
		draw_rect(Rect2(-3, 4, 6, 2), Color("e6c89c"))
		draw_rect(Rect2(-2, 3, 3, 2), Color("d4b07f"))

		# Mitad superior cayendo y desvaneciéndose al ser cortada
		if cut_anim_time < 0.45:
			var t := cut_anim_time / 0.45
			var fly_offset := cut_dir * (t * 22.0) + Vector2(0.0, -sin(t * PI) * 14.0 + t * 10.0)
			var alpha := Color(1.0, 1.0, 1.0, 1.0 - t)
			draw_set_transform(fly_offset, t * 1.4 * (1.0 if cut_dir.x >= 0.0 else -1.0))
			draw_rect(Rect2(-11, -9, 22, 11), Color("8c5c30") * alpha)
			draw_rect(Rect2(-8, -6, 16, 2), Color("d9c29c") * alpha)
			draw_rect(Rect2(-8, -2, 12, 2), Color("d9c29c") * alpha)
			draw_set_transform(Vector2.ZERO, 0.0)
