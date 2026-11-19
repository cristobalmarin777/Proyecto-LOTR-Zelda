class_name HobbitonBuilding
extends Node2D

## Vivienda / Edificio modular de Hobbiton en Pixel Art 16-bit (Referencias A y B + Especiales)
## con soporte nativo para Y-Sorting en Godot 4, colisiones reales y puertas interactivas.

var catalog_id: String = "smial_green_classic"
var building_title: String = "Casa Hobbit"
var resident: String = "Hobbiton"
var dialog_pages: Array = []
var heals_player: bool = false
var sprite_size: Vector2 = Vector2(144, 104)
var sort_y_offset: float = 88.0
var local_collider: Rect2 = Rect2(18, 44, 108, 44)
var local_door: Vector2 = Vector2(72, 94)
var has_door: bool = true
var elevation: int = 0

func configure(data: Dictionary) -> void:
	catalog_id = str(data.get("catalog_id", "smial_green_classic"))
	building_title = str(data.get("title", "Vivienda de Hobbiton"))
	resident = str(data.get("resident", "La Comarca"))
	dialog_pages = Array(data.get("dialog", ["Una acogedora vivienda de Hobbiton."]))
	heals_player = bool(data.get("heals_player", false))
	elevation = int(data.get("elevation", 0))
	apply_catalog_metrics()
	# Posicionamos el nodo en su línea de base (sort_y) para que y_sort_enabled de Godot funcione perfecto
	global_position = Vector2(float(data.get("center_x", 0.0)), float(data.get("base_y", 0.0)))
	add_to_group("hobbiton_buildings")
	queue_redraw()

func apply_catalog_metrics() -> void:
	match catalog_id:
		"bag_end":
			sprite_size = Vector2(224, 160)
			sort_y_offset = 126.0
			local_collider = Rect2(24, 64, 176, 62)
			local_door = Vector2(112, 134)
		"green_dragon_inn":
			sprite_size = Vector2(220, 140)
			sort_y_offset = 110.0
			local_collider = Rect2(22, 58, 176, 52)
			local_door = Vector2(81, 116)
		"old_mill":
			sprite_size = Vector2(164, 136)
			sort_y_offset = 112.0
			local_collider = Rect2(24, 52, 118, 60)
			local_door = Vector2(74, 118)
		"party_tree":
			sprite_size = Vector2(180, 160)
			sort_y_offset = 130.0
			local_collider = Rect2(68, 98, 44, 34)
			has_door = false
		"party_tent":
			sprite_size = Vector2(112, 88)
			sort_y_offset = 72.0
			local_collider = Rect2(18, 44, 76, 28)
			local_door = Vector2(56, 78)
		"smial_sam":
			sprite_size = Vector2(136, 100)
			sort_y_offset = 84.0
			local_collider = Rect2(18, 42, 100, 42)
			local_door = Vector2(68, 90)
		"smial_wealthy_blue":
			sprite_size = Vector2(152, 106)
			sort_y_offset = 90.0
			local_collider = Rect2(20, 44, 112, 46)
			local_door = Vector2(76, 96)
		"smial_humble_red":
			sprite_size = Vector2(116, 92)
			sort_y_offset = 76.0
			local_collider = Rect2(16, 38, 84, 38)
			local_door = Vector2(58, 82)
		"smial_oak_brown":
			sprite_size = Vector2(132, 98)
			sort_y_offset = 82.0
			local_collider = Rect2(18, 40, 96, 42)
			local_door = Vector2(66, 88)
		"rural_l_house":
			sprite_size = Vector2(148, 118)
			sort_y_offset = 100.0
			local_collider = Rect2(18, 52, 112, 48)
			local_door = Vector2(49, 106)
		"rural_cottage":
			sprite_size = Vector2(116, 98)
			sort_y_offset = 84.0
			local_collider = Rect2(16, 46, 84, 38)
			local_door = Vector2(58, 90)
		"rural_stone_barn":
			sprite_size = Vector2(104, 86)
			sort_y_offset = 72.0
			local_collider = Rect2(14, 38, 76, 34)
			local_door = Vector2(52, 78)
		_:
			sprite_size = Vector2(144, 104)
			sort_y_offset = 88.0
			local_collider = Rect2(18, 44, 108, 44)
			local_door = Vector2(72, 94)

func top_left() -> Vector2:
	return global_position - Vector2(sprite_size.x * 0.5, sort_y_offset)

func world_collider() -> Rect2:
	var tl := top_left()
	return Rect2(tl + local_collider.position, local_collider.size)

func world_door_position() -> Vector2:
	return top_left() + local_door

func _draw() -> void:
	# Dibujamos relativo al origen local del nodo (0,0 = base_y central)
	var ox := -sprite_size.x * 0.5
	var oy := -sort_y_offset
	var o := Vector2(ox, oy)
	match catalog_id:
		"bag_end":
			draw_bag_end(o)
		"green_dragon_inn":
			draw_green_dragon(o)
		"old_mill":
			draw_old_mill(o)
		"party_tree":
			draw_party_tree(o)
		"party_tent":
			draw_party_tent(o)
		"smial_sam":
			draw_smial(o, Color("d9a426"), Color("9e7211"), 2, true, false, true)
		"smial_green_classic":
			draw_smial(o, Color("1b632d"), Color("10421d"), 2, true, true, true)
		"smial_wealthy_blue":
			draw_smial(o, Color("295f98"), Color("193e66"), 2, true, true, false)
		"smial_humble_red":
			draw_smial(o, Color("a8322d"), Color("731e1b"), 1, false, false, true)
		"smial_oak_brown":
			draw_smial(o, Color("8c5322"), Color("5e3513"), 2, true, false, false)
		"rural_l_house":
			draw_rural_l_house(o)
		"rural_cottage":
			draw_rural_cottage(o)
		"rural_stone_barn":
			draw_rural_barn(o)

func draw_turf_mound(o: Vector2, cx: float, cy: float, rx: float, ry: float) -> void:
	draw_rect(Rect2(o + Vector2(cx - rx - 2, cy + ry * 0.25), Vector2(rx * 2 + 4, ry * 0.5)), Color(0.04, 0.08, 0.03, 0.34))
	var step := 4
	for y_i in range(int(-ry), int(ry * 0.55), step):
		var norm_y := float(y_i) / ry
		var span_ratio := sqrt(maxf(0.0, 1.0 - norm_y * norm_y * 0.85))
		var half_w := rx * span_ratio
		var col := Color("4f773b")
		if float(y_i) < -ry * 0.35:
			col = Color("799e58")
		elif float(y_i) < 0.0:
			col = Color("588242")
		draw_rect(Rect2(o + Vector2(cx - half_w, cy + y_i), Vector2(half_w * 2, step)), col)
		draw_rect(Rect2(o + Vector2(cx - half_w, cy + y_i), Vector2(3, step)), Color("2a421e"))
		draw_rect(Rect2(o + Vector2(cx + half_w - 3, cy + y_i), Vector2(3, step)), Color("2a421e"))

func draw_round_door(o: Vector2, cx: float, cy: float, radius: float, col: Color, dark: Color) -> void:
	draw_circle(o + Vector2(cx, cy), radius + 4.0, Color("a86434"))
	draw_circle(o + Vector2(cx, cy), radius, col)
	for dx in range(int(-radius) + 3, int(radius), 4):
		draw_line(o + Vector2(cx + dx, cy - radius * 0.7), o + Vector2(cx + dx, cy + radius * 0.7), dark, 1.0)
	draw_circle(o + Vector2(cx, cy), 2.5, Color("f0c441"))

func draw_round_window(o: Vector2, cx: float, cy: float, radius: float) -> void:
	draw_circle(o + Vector2(cx, cy), radius + 3.0, Color("9e5b2c"))
	draw_circle(o + Vector2(cx, cy), radius, Color("6fa4b8"))
	draw_line(o + Vector2(cx - radius * 0.7, cy - radius * 0.7), o + Vector2(cx + radius * 0.7, cy + radius * 0.7), Color("e6f2f5"), 2.0)
	draw_line(o + Vector2(cx + radius * 0.7, cy - radius * 0.7), o + Vector2(cx - radius * 0.7, cy + radius * 0.7), Color("e6f2f5"), 2.0)

func draw_steps_and_garden(o: Vector2, door_x: float, bottom_y: float, count: int, has_pumpkin: bool) -> void:
	for i in range(count):
		var sy := bottom_y + i * 5.0
		var sw := 28.0 + i * 4.0
		var sx := door_x - sw * 0.5
		draw_rect(Rect2(o + Vector2(sx, sy), Vector2(sw, 4)), Color("7a8288"))
		draw_rect(Rect2(o + Vector2(sx + 1, sy), Vector2(sw - 2, 3)), Color("cfd6db"))
	# Macetas floridas (Referencia A)
	draw_rect(Rect2(o + Vector2(door_x - 22, bottom_y - 6), Vector2(8, 6)), Color("8f522c"))
	draw_rect(Rect2(o + Vector2(door_x - 24, bottom_y - 12), Vector2(12, 7)), Color("2f5922"))
	draw_rect(Rect2(o + Vector2(door_x - 21, bottom_y - 13), Vector2(4, 4)), Color("ffdf38"))
	draw_rect(Rect2(o + Vector2(door_x + 15, bottom_y - 5), Vector2(7, 5)), Color("8f522c"))
	draw_rect(Rect2(o + Vector2(door_x + 14, bottom_y - 10), Vector2(9, 5)), Color("e85d9c"))
	if has_pumpkin:
		draw_rect(Rect2(o + Vector2(door_x - 42, bottom_y - 4), Vector2(12, 8)), Color("d96b14"))
		draw_rect(Rect2(o + Vector2(door_x - 40, bottom_y - 4), Vector2(8, 7)), Color("f28729"))
		draw_rect(Rect2(o + Vector2(door_x - 37, bottom_y - 6), Vector2(2, 2)), Color("3d6e29"))

func draw_pixel_tree_canopy(o: Vector2, tx: float, ty: float, w: float, h: float) -> void:
	# Estética de árbol rectangular en 4 niveles (idéntica a la actualización)
	draw_rect(Rect2(o + Vector2(tx - 6, ty - 8), Vector2(12, 24)), Color("5c3a1e"))
	draw_rect(Rect2(o + Vector2(tx - w * 0.5, ty - h), Vector2(w, h)), Color("1e4d1b"))
	draw_rect(Rect2(o + Vector2(tx - w * 0.44, ty - h - 4), Vector2(w * 0.88, h * 0.9)), Color("2e6f28"))
	draw_rect(Rect2(o + Vector2(tx - w * 0.36, ty - h - 1), Vector2(w * 0.72, h * 0.65)), Color("44913b"))
	draw_rect(Rect2(o + Vector2(tx - w * 0.25, ty - h + 2), Vector2(w * 0.42, h * 0.35)), Color("62b356"))

func draw_smial(o: Vector2, door_col: Color, door_dark: Color, win_count: int, has_chimney: bool, has_tree: bool, has_pumpkin: bool) -> void:
	var cx := sprite_size.x * 0.5
	var mound_cy := sprite_size.y * 0.56
	var rx := sprite_size.x * 0.46
	var ry := sprite_size.y * 0.44
	draw_turf_mound(o, cx, mound_cy, rx, ry)
	if has_chimney:
		draw_rect(Rect2(o + Vector2(cx - rx * 0.35, mound_cy - ry + 4), Vector2(12, 16)), Color("8f5735"))
	if has_tree:
		draw_pixel_tree_canopy(o, cx + rx * 0.25, mound_cy - ry + 14, 44.0, 22.0)
	var fw := rx * 1.48
	var fh := 30.0
	var fx := cx - fw * 0.5
	var fy := mound_cy + 2.0
	draw_rect(Rect2(o + Vector2(fx - 2, fy - 4), Vector2(fw + 4, 6)), Color("362010"))
	draw_rect(Rect2(o + Vector2(fx, fy), Vector2(fw, fh)), Color("edd29f"))
	if win_count >= 1:
		draw_round_window(o, cx - 35.0, fy + 14.0, 7.0)
	if win_count >= 2:
		draw_round_window(o, cx + 35.0, fy + 14.0, 7.0)
	draw_round_door(o, cx, fy + 15.0, 13.0, door_col, door_dark)
	draw_steps_and_garden(o, cx, fy + fh - 2.0, 4, has_pumpkin)

func draw_bag_end(o: Vector2) -> void:
	var cx := sprite_size.x * 0.5
	draw_turf_mound(o, cx, 96.0, 104.0, 56.0)
	draw_pixel_tree_canopy(o, cx + 10.0, 46.0, 84.0, 38.0)
	draw_rect(Rect2(o + Vector2(cx - 52, 42), Vector2(12, 18)), Color("9c5b34"))
	draw_rect(Rect2(o + Vector2(cx + 48, 48), Vector2(10, 15)), Color("6e3f23"))
	var fx := cx - 82.0
	var fy := 94.0
	draw_rect(Rect2(o + Vector2(fx - 3, fy - 4), Vector2(170, 6)), Color("362010"))
	draw_rect(Rect2(o + Vector2(fx, fy), Vector2(164, 34)), Color("f0d7a8"))
	draw_round_window(o, cx - 70.0, fy + 16.0, 7.0)
	draw_round_window(o, cx - 38.0, fy + 15.0, 9.0)
	draw_round_window(o, cx + 38.0, fy + 15.0, 9.0)
	draw_round_window(o, cx + 70.0, fy + 16.0, 7.0)
	draw_round_door(o, cx, fy + 16.0, 15.0, Color("195e2c"), Color("10401d"))
	draw_steps_and_garden(o, cx, fy + 32.0, 5, true)

func draw_thatch_wing(o: Vector2, x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), Color("ebd04b"))
	draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h * 0.25)), Color("db9f27"))
	draw_rect(Rect2(o + Vector2(x, y + h - 5), Vector2(w, 5)), Color("d49422"))
	draw_rect(Rect2(o + Vector2(x + 2, y - 2), Vector2(w - 4, 6)), Color("bd7b19"))
	for rx in range(int(x) + 6, int(x + w) - 6, 11):
		draw_rect(Rect2(o + Vector2(rx, y - 3), Vector2(3, 12)), Color("8f5210"))

func draw_gable_thatch(o: Vector2, cx: float, top_y: float, half_w: float, height: float) -> void:
	for dy in range(0, int(height), 2):
		var ratio := float(dy) / height
		var span := 10.0 + (half_w - 10.0) * pow(ratio, 0.85)
		draw_rect(Rect2(o + Vector2(cx - span, top_y + dy), Vector2(span, 2)), Color("f5eb67"))
		draw_rect(Rect2(o + Vector2(cx, top_y + dy), Vector2(span, 2)), Color("d99824"))
		var chev := minf(span - 2.0, 10.0)
		draw_rect(Rect2(o + Vector2(cx - chev, top_y + dy), Vector2(chev * 2.0, 2)), Color("8f5112") if (dy / 4) % 2 == 0 else Color("d69324"))

func draw_rural_window(o: Vector2, x: float, y: float, w: float = 13.0, h: float = 13.0) -> void:
	draw_rect(Rect2(o + Vector2(x - 1, y - 1), Vector2(w + 2, h + 2)), Color("5c3818"))
	draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), Color("3d5894"))
	draw_rect(Rect2(o + Vector2(x + 1, y + 1), Vector2(w * 0.4, h * 0.4)), Color("142042"))
	draw_rect(Rect2(o + Vector2(x + w * 0.55, y + 1), Vector2(w * 0.4, h * 0.4)), Color("142042"))

func draw_rural_door(o: Vector2, x: float, y: float, w: float = 18.0, h: float = 24.0) -> void:
	draw_rect(Rect2(o + Vector2(x - 2, y - 2), Vector2(w + 4, h + 2)), Color("5e3914"))
	draw_rect(Rect2(o + Vector2(x, y), Vector2(w, h)), Color("c48335"))
	draw_rect(Rect2(o + Vector2(x + 4, y + 4), Vector2(w - 8, 5)), Color("1a120b"))
	draw_rect(Rect2(o + Vector2(x + w - 5, y + 10), Vector2(3, 2)), Color("e6e8ec"))

func draw_rural_l_house(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(42, 6), Vector2(24, 20)), Color("d9d4cc"))
	draw_rect(Rect2(o + Vector2(64, 58), Vector2(68, 30)), Color("e8dfd5"))
	draw_rect(Rect2(o + Vector2(64, 58), Vector2(68, 4)), Color("6e4318"))
	draw_rural_window(o, 70, 61)
	draw_rural_window(o, 108, 61)
	draw_thatch_wing(o, 56, 22, 80, 40)
	# Escalera apoyada (Referencia B)
	draw_rect(Rect2(o + Vector2(94, 54), Vector2(2, 38)), Color("7a4e21"))
	draw_rect(Rect2(o + Vector2(106, 54), Vector2(2, 38)), Color("7a4e21"))
	for ry in range(58, 90, 7):
		draw_rect(Rect2(o + Vector2(93, ry), Vector2(16, 2)), Color("ab7638"))
	draw_rect(Rect2(o + Vector2(16, 50), Vector2(54, 52)), Color("ede4da"))
	draw_rect(Rect2(o + Vector2(16, 50), Vector2(4, 52)), Color("6e4318"))
	draw_rect(Rect2(o + Vector2(66, 50), Vector2(4, 52)), Color("6e4318"))
	draw_rural_window(o, 22, 77)
	draw_rural_door(o, 40, 76, 18, 25)
	draw_gable_thatch(o, 43, 16, 32, 42)

func draw_rural_cottage(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(78, 6), Vector2(18, 16)), Color("d9d4cc"))
	draw_rect(Rect2(o + Vector2(16, 46), Vector2(84, 38)), Color("ebe2d8"))
	draw_rural_window(o, 24, 65)
	draw_rural_window(o, 79, 65)
	draw_rural_door(o, 50, 59, 17, 24)
	draw_thatch_wing(o, 10, 16, 96, 34)

func draw_rural_barn(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(14, 38), Vector2(76, 34)), Color("8c8274"))
	draw_rural_door(o, 43, 47, 18, 24)
	draw_thatch_wing(o, 8, 12, 88, 28)

func draw_green_dragon(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(48, 8), Vector2(24, 22)), Color("d9d4cc"))
	draw_rect(Rect2(o + Vector2(148, 12), Vector2(22, 20)), Color("d9d4cc"))
	draw_rect(Rect2(o + Vector2(22, 64), Vector2(176, 44)), Color("ebe2d6"))
	draw_rect(Rect2(o + Vector2(22, 98), Vector2(176, 10)), Color("7c756b"))
	draw_rural_window(o, 34, 69)
	draw_rural_window(o, 120, 69)
	draw_rural_window(o, 150, 69)
	draw_rural_window(o, 176, 69)
	draw_thatch_wing(o, 16, 26, 188, 42)
	draw_rect(Rect2(o + Vector2(52, 56), Vector2(58, 56)), Color("f0e7dc"))
	draw_rural_door(o, 72, 84, 20, 26)
	draw_gable_thatch(o, 81, 18, 34, 42)
	# Letrero verde del Dragón
	draw_rect(Rect2(o + Vector2(114, 83), Vector2(12, 11)), Color("1e4d26"))
	draw_rect(Rect2(o + Vector2(116, 85), Vector2(8, 7)), Color("58c468"))

func draw_old_mill(o: Vector2) -> void:
	# Rueda hidráulica derecha
	draw_rect(Rect2(o + Vector2(122, 62), Vector2(26, 48)), Color("3d2511"))
	draw_rect(Rect2(o + Vector2(125, 65), Vector2(20, 42)), Color("69411f"))
	draw_rect(Rect2(o + Vector2(120, 106), Vector2(30, 6)), Color("9ad1f5"))
	# Torreón de ladrillo y madera
	draw_rect(Rect2(o + Vector2(26, 46), Vector2(96, 68)), Color("9c6244"))
	draw_rect(Rect2(o + Vector2(26, 46), Vector2(96, 24)), Color("e6ddd1"))
	draw_rural_window(o, 40, 52)
	draw_rural_window(o, 94, 52)
	draw_rural_door(o, 64, 86, 20, 26)
	draw_thatch_wing(o, 20, 16, 108, 34)
	draw_gable_thatch(o, 74, 10, 36, 38)

func draw_party_tree(o: Vector2) -> void:
	var cx := sprite_size.x * 0.5
	draw_rect(Rect2(o + Vector2(cx - 26, 122), Vector2(52, 10)), Color("4a2e16"))
	draw_rect(Rect2(o + Vector2(cx - 18, 78), Vector2(36, 48)), Color("5c3a1d"))
	draw_rect(Rect2(o + Vector2(cx - 72, 22), Vector2(144, 64)), Color("1e4d1b"))
	draw_rect(Rect2(o + Vector2(cx - 64, 14), Vector2(128, 56)), Color("2e6f28"))
	draw_rect(Rect2(o + Vector2(cx - 52, 20), Vector2(104, 40)), Color("44913b"))
	draw_rect(Rect2(o + Vector2(cx - 36, 24), Vector2(62, 22)), Color("62b356"))
	for lantern in [[-48, 78, Color("ffdf4d")], [-26, 84, Color("ff758f")], [0, 86, Color("ffdf4d")], [28, 84, Color("72efdd")], [50, 78, Color("ffdf4d")]]:
		draw_rect(Rect2(o + Vector2(cx + lantern[0] - 2, lantern[1]), Vector2(6, 6)), lantern[2])

func draw_party_tent(o: Vector2) -> void:
	draw_rect(Rect2(o + Vector2(18, 42), Vector2(4, 34)), Color("6e451f"))
	draw_rect(Rect2(o + Vector2(90, 42), Vector2(4, 34)), Color("6e451f"))
	draw_rect(Rect2(o + Vector2(26, 58), Vector2(60, 12)), Color("8c5828"))
	draw_rect(Rect2(o + Vector2(28, 56), Vector2(56, 4)), Color("f5ebd6"))
	for x in range(12, 100, 8):
		var col := Color("f5ecd8") if ((x - 12) / 8) % 2 == 0 else Color("d94e34")
		draw_rect(Rect2(o + Vector2(x, 18), Vector2(8, 26)), col)
