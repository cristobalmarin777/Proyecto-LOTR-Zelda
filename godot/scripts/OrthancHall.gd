class_name OrthancHall
extends MiddleEarthDungeon

const FLOOR := Rect2(152, 132, 560, 342)
const WALKABLE := Rect2(163, 144, 538, 318)
const THRONE := Vector2(432, 218)
const DOOR := Vector2(432, 450)

func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = FLOOR.get_center()
	add_child(camera)
	camera.make_current()

func exit_position() -> Vector2:
	return DOOR

func biome_at_world(_point: Vector2) -> String:
	return "ORTHANC"

func biome_display_name(_biome: String) -> String:
	return "CÁMARA DE ORTHANC"

func darkness_at(_point: Vector2) -> float:
	return 0.0

func get_interpolated_elevation(_point: Vector2) -> float:
	return 0.0

func get_height_at_tile(_x: int, _y: int) -> int:
	return 0

func get_connection_at_pixel(_point: Vector2) -> Dictionary:
	return {}

func is_blocked(point: Vector2, _height: float = -999.0) -> bool:
	return not WALKABLE.has_point(point)

func _process(_delta: float) -> void:
	pass

func _draw() -> void:
	draw_rect(FLOOR.grow(500), Color("#10121b"))
	draw_rect(FLOOR.grow(18), Color("#141721"))
	draw_rect(FLOOR.grow(9), Color("#505567"))
	draw_rect(FLOOR, Color("#2d303f"))
	for y in range(142, 474, 24):
		draw_line(Vector2(152, y), Vector2(712, y), Color("#252935"), 2)
		var offset := 22 * ((y / 24) % 2)
		for x in range(160 + offset, 702, 44):
			draw_line(Vector2(x,y), Vector2(x,mini(y+24,474)), Color("#252935"), 2)
	draw_rect(Rect2(391,132,82,342), Color("#473947"))
	for x in [396, 468]:
		draw_line(Vector2(x,132), Vector2(x,474), Color("#a29274"), 2)
	draw_arc(THRONE, 39, 0, TAU, 48, Color("#a99a85"), 2)
	for x in [156, 706]:
		for y in [145, 228, 311, 394, 464]:
			draw_rect(Rect2(x-5,y-9,10,19), Color("#666376"))
			draw_circle(Vector2(x,y-6), 4, Color("#dfd2b4"))
	draw_rect(Rect2(DOOR.x-26, 468, 52, 10), Color("#c1aa80"))
