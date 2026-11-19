class_name MiddleEarthDungeon
extends MiddleEarthWorld

## Interior finito generado al entrar en una cueva o mina del mundo. Las cuevas
## usan varias pasadas de autómata celular; las minas enlazan salas rectangulares
## mediante galerías, como en el prototipo web.
const DUNGEON_COLS := 48
const DUNGEON_ROWS := 34

var dungeon_type := "cave"
var source_biome := "OLD_FOREST"
var grid: Array = []
var exit_cell := Vector2i(3, 17)
var enemy_spawns: Array = []
var chests: Array = []
var interior_darkness := 0.48

func configure(kind: String, seed_value: int, biome: String) -> void:
	dungeon_type = kind
	world_seed = seed_value
	source_biome = biome
	interior_darkness = 0.76 if biome == "OLD_FOREST" else (0.48 if kind == "cave" else 0.24)
	grid.clear()
	for row in range(DUNGEON_ROWS):
		var line: Array = []
		for column in range(DUNGEON_COLS):
			line.append(ShireMap.Tile.ROCK)
		grid.append(line)
	if dungeon_type == "cave":
		generate_cave()
	else:
		generate_mine()
	populate_contents()

func _process(_delta: float) -> void:
	queue_redraw()

func biome_at_world(_world_position: Vector2) -> String:
	return "CAVE" if dungeon_type == "cave" else "DWARVEN_MINE"

func biome_display_name(biome: String) -> String:
	if biome == "CAVE":
		return "CUEVA PROFUNDA"
	if biome == "DWARVEN_MINE":
		return "MINA SUBTERRÁNEA"
	return super.biome_display_name(biome)

func darkness_at(_world_position: Vector2) -> float:
	return interior_darkness

func is_blocked(world_position: Vector2, _current_height: float = -999.0) -> bool:
	var column := floori(world_position.x / TILE_SIZE)
	var row := floori(world_position.y / TILE_SIZE)
	return ShireMap.Tile.ROCK == tile_at(column, row)

func tile_at(column: int, row: int) -> int:
	if row < 0 or row >= DUNGEON_ROWS or column < 0 or column >= DUNGEON_COLS:
		return ShireMap.Tile.ROCK
	return int(grid[row][column])

func generate_cave() -> void:
	for row in range(1, DUNGEON_ROWS - 1):
		for column in range(1, DUNGEON_COLS - 1):
			grid[row][column] = ShireMap.Tile.DIRT_PATH if hash01(column, row, 10) > 0.47 else ShireMap.Tile.ROCK
	for generation in range(4):
		var next: Array = []
		for row in range(DUNGEON_ROWS):
			next.append(grid[row].duplicate())
		for row in range(1, DUNGEON_ROWS - 1):
			for column in range(1, DUNGEON_COLS - 1):
				var rocks := 0
				for y in range(-1, 2):
					for x in range(-1, 2):
						if x != 0 or y != 0:
							rocks += 1 if tile_at(column + x, row + y) == ShireMap.Tile.ROCK else 0
				next[row][column] = ShireMap.Tile.ROCK if rocks >= 5 else ShireMap.Tile.DIRT_PATH
		grid = next
	carve_room(1, exit_cell.y - 2, 9, exit_cell.y + 2)
	carve_room(19, 10, 31, 24)
	carve_corridor(7, exit_cell.y, 23, 17)

func generate_mine() -> void:
	var rooms: Array = [
		Rect2i(2, 13, 8, 8),
		Rect2i(14, 5 + floori(hash01(1, 1, 30) * 8.0), 10, 9),
		Rect2i(28, 16 + floori(hash01(2, 2, 31) * 6.0), 10, 8),
		Rect2i(38, 7 + floori(hash01(3, 3, 32) * 8.0), 7, 10),
	]
	for room in rooms:
		carve_room(room.position.x, room.position.y, room.end.x, room.end.y)
	for index in range(rooms.size() - 1):
		var a: Rect2i = rooms[index]
		var b: Rect2i = rooms[index + 1]
		carve_corridor(a.position.x + a.size.x / 2, a.position.y + a.size.y / 2, b.position.x + b.size.x / 2, b.position.y + b.size.y / 2)
	exit_cell = Vector2i(3, 17)
	carve_corridor(exit_cell.x, exit_cell.y, 6, 17)

func carve_room(x1: int, y1: int, x2: int, y2: int) -> void:
	for row in range(maxi(1, y1), mini(DUNGEON_ROWS - 1, y2)):
		for column in range(maxi(1, x1), mini(DUNGEON_COLS - 1, x2)):
			grid[row][column] = ShireMap.Tile.DIRT_PATH

func carve_corridor(x1: int, y1: int, x2: int, y2: int) -> void:
	var step_x := 1 if x1 <= x2 else -1
	for column in range(x1, x2 + step_x, step_x):
		carve_room(column, y1 - 1, column + 1, y1 + 2)
	var step_y := 1 if y1 <= y2 else -1
	for row in range(y1, y2 + step_y, step_y):
		carve_room(x2, row, x2 + 1, row + 1)

func populate_contents() -> void:
	grid[exit_cell.y][exit_cell.x] = ShireMap.Tile.COBBLESTONE
	var floors: Array[Vector2i] = []
	for row in range(2, DUNGEON_ROWS - 2):
		for column in range(4, DUNGEON_COLS - 2):
			if tile_at(column, row) == ShireMap.Tile.DIRT_PATH:
				floors.append(Vector2i(column, row))
	var enemy_count := 6 if dungeon_type == "cave" else 8
	enemy_spawns.clear()
	for index in range(enemy_count):
		var position: Vector2i = floor_choice(floors, index + 1)
		var roll := hash01(index, 1, 80)
		var kind := "uruk" if dungeon_type == "mine" and roll > 0.72 else ("orc" if roll > 0.52 else "spider")
		enemy_spawns.append({"type": kind, "col": position.x, "row": position.y})
	var reward_position: Vector2i = floor_choice(floors, 95)
	chests = [{
		"id": "dungeon_%d" % world_seed,
		"col": reward_position.x,
		"row": reward_position.y,
		"reward": "sword_temper" if dungeon_type == "mine" else "potion_pack",
		"title": "Herramientas de los Enanos" if dungeon_type == "mine" else "Alijo de la Cueva",
		"description": "Los útiles enanos han reforjado un filo antiguo." if dungeon_type == "mine" else "Un alijo olvidado restaura tus provisiones de Miruvor.",
	}]

func floor_choice(floors: Array[Vector2i], salt: int) -> Vector2i:
	if floors.is_empty():
		return Vector2i(7, exit_cell.y)
	return floors[floori(hash01(salt, salt * 2, 70) * floors.size())]

func exit_position() -> Vector2:
	return (Vector2(exit_cell) + Vector2(0.5, 0.5)) * TILE_SIZE

func _draw() -> void:
	if player == null:
		return
	var start_x := maxi(0, floori((player.global_position.x - 640.0) / TILE_SIZE))
	var end_x := mini(DUNGEON_COLS - 1, floori((player.global_position.x + 640.0) / TILE_SIZE))
	var start_y := maxi(0, floori((player.global_position.y - 460.0) / TILE_SIZE))
	var end_y := mini(DUNGEON_ROWS - 1, floori((player.global_position.y + 460.0) / TILE_SIZE))
	for row in range(start_y, end_y + 1):
		for column in range(start_x, end_x + 1):
			var origin := Vector2(column * TILE_SIZE, row * TILE_SIZE)
			var tile := tile_at(column, row)
			if tile == ShireMap.Tile.ROCK:
				draw_rect(Rect2(origin, Vector2(TILE_SIZE + 1, TILE_SIZE + 1)), Color("24262b"))
				draw_rect(Rect2(origin + Vector2(3, 4), Vector2(12, 8)), Color("3c4048"))
				draw_rect(Rect2(origin + Vector2(18, 15), Vector2(10, 9)), Color("343840"))
			else:
				draw_rect(Rect2(origin, Vector2(TILE_SIZE + 1, TILE_SIZE + 1)), Color("514536") if dungeon_type == "mine" else Color("3d362e"))
				if (column + row) % 3 == 0:
					draw_circle(origin + Vector2(10, 11), 1.5, Color("75634a"))
			if Vector2i(column, row) == exit_cell:
				draw_rect(Rect2(origin + Vector2(5, 6), Vector2(22, 21)), Color("a78342"))
				draw_rect(Rect2(origin + Vector2(10, 11), Vector2(12, 16)), Color("182026"))

