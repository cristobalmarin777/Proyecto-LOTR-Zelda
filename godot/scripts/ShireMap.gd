class_name ShireMap
extends RefCounted

## Traducción directa de la zona inicial diseñada para el prototipo web.
## Las coordenadas son tiles de 32 px; el generador la incrusta en el mundo
## infinito sin imponer un borde artificial al explorador.
const TILE_SIZE := 32
const COLS := 48
const ROWS := 34

enum Tile {
	GRASS,
	TALL_GRASS,
	FLOWERS,
	DIRT_PATH,
	COBBLESTONE,
	WATER,
	BRIDGE,
	TREE,
	FENCE,
	ROCK,
	HOBBIT_WALL,
	HOBBIT_DOOR,
	CROP_FIELD,
	DARK_FOREST,
	MILL_BASE,
	CAMPFIRE_ASH,
}

var grid: Array = []
var npcs: Array = []
var chests: Array = []
var signs: Array = []
var enemy_spawns: Array = []

func _init() -> void:
	build_level()

func build_level() -> void:
	grid.clear()
	for row in range(ROWS):
		var line: Array = []
		for column in range(COLS):
			line.append(Tile.GRASS)
		grid.append(line)
	# Borde frondoso; WorldGenerator permite salir por él usando su terreno
	# procedimental en la comprobación de colisión exterior.
	for column in range(COLS):
		grid[0][column] = Tile.TREE
		grid[ROWS - 1][column] = Tile.TREE
	for row in range(ROWS):
		grid[row][0] = Tile.TREE
		grid[row][COLS - 1] = Tile.TREE
	# Bosque Viejo, Río El Agua, caminos y puentes.
	for row in range(1, ROWS - 1):
		for column in range(31, COLS - 1):
			grid[row][column] = Tile.DARK_FOREST
		var river_column := 25 + roundi(sin(float(row) * 0.25) * 1.2)
		grid[row][river_column] = Tile.WATER
		grid[row][river_column + 1] = Tile.WATER
	paint_rect(8, 2, 9, 24, Tile.DIRT_PATH)
	paint_rect(8, 12, 24, 13, Tile.DIRT_PATH)
	paint_rect(16, 4, 17, 45, Tile.DIRT_PATH)
	paint_rect(24, 8, 25, 22, Tile.DIRT_PATH)
	paint_rect(9, 28, 28, 29, Tile.DIRT_PATH)
	paint_rect(8, 23, 9, 28, Tile.BRIDGE)
	paint_rect(16, 23, 17, 28, Tile.BRIDGE)
	# Bolsón Cerrado y casas hobbit.
	paint_rect(3, 3, 5, 10, Tile.HOBBIT_WALL)
	grid[5][6] = Tile.HOBBIT_DOOR
	paint_rect(6, 6, 8, 7, Tile.COBBLESTONE)
	for column in range(2, 12):
		if column != 6 and column != 7:
			grid[7][column] = Tile.FENCE
	grid[4][2] = Tile.FLOWERS
	grid[6][4] = Tile.FLOWERS
	grid[6][9] = Tile.FLOWERS
	paint_rect(12, 3, 13, 8, Tile.HOBBIT_WALL)
	grid[13][5] = Tile.HOBBIT_DOOR
	paint_rect(14, 5, 16, 6, Tile.DIRT_PATH)
	# Delagua, Dragón Verde y Viejo Molino.
	paint_rect(11, 15, 13, 21, Tile.HOBBIT_WALL)
	grid[13][18] = Tile.HOBBIT_DOOR
	paint_rect(14, 17, 15, 19, Tile.COBBLESTONE)
	paint_rect(3, 20, 5, 23, Tile.MILL_BASE)
	grid[5][21] = Tile.HOBBIT_DOOR
	# Huertos de Maggot.
	paint_rect(20, 4, 23, 10, Tile.CROP_FIELD)
	paint_rect(20, 15, 23, 21, Tile.CROP_FIELD)
	for column in range(3, 12):
		if column != 7:
			grid[19][column] = Tile.FENCE
	for spot in [[3, 13], [4, 14], [10, 4], [10, 9], [18, 14], [26, 6], [27, 18], [15, 22]]:
		grid[spot[0]][spot[1]] = Tile.FLOWERS
	for patch in [[9, 15, 10, 19], [26, 8, 29, 16], [4, 29, 7, 33], [19, 29, 23, 33]]:
		paint_rect(patch[0], patch[1], patch[2], patch[3], Tile.TALL_GRASS)
	for tree in [[2, 16], [2, 17], [6, 15], [10, 22], [19, 12], [27, 4], [28, 5], [29, 21], [3, 35], [4, 35], [5, 35], [6, 35], [11, 32], [12, 32], [13, 32], [12, 38], [13, 38], [14, 38], [19, 34], [20, 34], [21, 34], [23, 39], [24, 39], [25, 39], [7, 42], [8, 42], [9, 42], [28, 33], [29, 33], [30, 33]]:
		grid[tree[0]][tree[1]] = Tile.TREE
	for rock in [[3, 28], [4, 28], [14, 31], [18, 31], [22, 27], [26, 36], [27, 36], [10, 40], [11, 40], [20, 43], [21, 43]]:
		grid[rock[0]][rock[1]] = Tile.ROCK
	paint_rect(25, 38, 29, 44, Tile.DIRT_PATH)
	grid[27][41] = Tile.CAMPFIRE_ASH
	build_story_content()

func build_story_content() -> void:
	npcs = [
		{
			"id": "gandalf", "name": "Gandalf el Gris", "col": 8, "row": 7,
			"hat_color": Color("52627a"), "cloak_color": Color("768496"),
			"dialog": [
				"¡Ah, joven montaraz! Menos mal que estás despierto en Bolsón Cerrado.",
				"Exploradores orcos y arañas del Bosque Viejo han cruzado el Río El Agua hacia el este.",
				"MISIÓN PRINCIPAL: cruza el puente, derrota al Capitán Uruk-hai del campamento sureste y recupera el Mapa de Arnor.",
				"Pulsa ESPACIO para atacar, Q para el objeto activo e I para abrir el inventario.",
			],
		},
		{
			"id": "sam", "name": "Sam Gamyi", "col": 6, "row": 14,
			"hat_color": Color("8c5a2b"), "cloak_color": Color("4b7a34"),
			"dialog": ["¡Buenos días, señor! He visto criaturas feas rondando cerca del Viejo Molino.", "Guardé un cofre con un Arco de la Comarca junto al molino. Ábrelo con E."],
		},
		{
			"id": "rosie", "name": "Rosita Coto · El Dragón Verde", "col": 18, "row": 14,
			"hat_color": Color("d96b82"), "cloak_color": Color("b84058"), "healer": true,
			"dialog": ["¡Bienvenido a la Posada El Dragón Verde de Delagua!", "He vendado tus heridas y servido una pinta fresca: tus corazones se han restaurado."],
		},
		{
			"id": "farmer_maggot", "name": "Granjero Maggot", "col": 11, "row": 21,
			"hat_color": Color("a37b37"), "cloak_color": Color("6b4922"),
			"dialog": ["¡Esos malditos trasgos han pisoteado mis calabazas premiadas!", "Al otro lado del puente empieza el Bosque Viejo. No entres sin provisiones y el arco."],
		},
		{
			"id": "shire_smith", "name": "Haldor el Armero", "col": 15, "row": 10,
			"hat_color": Color("667078"), "cloak_color": Color("704b2b"), "merchant": true, "dialog": [],
		},
	]
	chests = [
		{"id": "chest_mill", "col": 21, "row": 6, "reward": "bow_upgrade", "title": "Arco de la Comarca + 15 flechas", "description": "Puedes equipar el arco en el inventario y disparar con Q."},
		{"id": "chest_gardens", "col": 4, "row": 25, "reward": "potion_pack", "title": "Pan de lembas y Miruvor + 25 monedas", "description": "Recupera fuerzas durante el viaje."},
		{"id": "chest_forest_north", "col": 39, "row": 4, "reward": "heart_container", "title": "Contenedor de Corazón Dúnedain", "description": "Aumenta tu salud hasta el límite temporal de seis corazones."},
		{"id": "chest_orc_camp", "col": 44, "row": 27, "reward": "sword_temper", "title": "Hoja Élfica Templada", "description": "Una mejora de filo o una nueva hoja para tu viaje."},
	]
	signs = [
		{"col": 13, "row": 9, "text": "Oeste: Bolsón Cerrado · Sur: Delagua y el Dragón Verde · Este: Puente del Agua"},
		{"col": 29, "row": 15, "text": "PELIGRO: Frontera del Bosque Viejo. Arañas gigantes y exploradores orcos al este."},
		{"col": 45, "row": 16, "text": "Gran Camino del Este hacia Bree y Arnor. Se abre tras derrotar al Capitán Uruk-hai."},
	]
	enemy_spawns = [
		{"type": "orc", "col": 19, "row": 9}, {"type": "spider", "col": 17, "row": 26}, {"type": "orc", "col": 22, "row": 28},
		{"type": "spider", "col": 32, "row": 6}, {"type": "spider", "col": 36, "row": 8}, {"type": "orc", "col": 41, "row": 6},
		{"type": "orc", "col": 33, "row": 16}, {"type": "spider", "col": 37, "row": 19}, {"type": "orc", "col": 42, "row": 15},
		{"type": "orc", "col": 36, "row": 26}, {"type": "spider", "col": 35, "row": 30}, {"type": "uruk", "col": 41, "row": 27, "mini_boss": true},
	]

func paint_rect(row_start: int, col_start: int, row_end: int, col_end: int, tile: int) -> void:
	for row in range(row_start, row_end + 1):
		for column in range(col_start, col_end + 1):
			if row >= 0 and row < ROWS and column >= 0 and column < COLS:
				grid[row][column] = tile

func has_inner_cell(column: int, row: int) -> bool:
	return column > 0 and column < COLS - 1 and row > 0 and row < ROWS - 1

func tile_at(column: int, row: int) -> int:
	if column < 0 or column >= COLS or row < 0 or row >= ROWS:
		return Tile.GRASS
	return int(grid[row][column])

func tile_is_solid(tile: int) -> bool:
	return tile in [Tile.WATER, Tile.TREE, Tile.FENCE, Tile.ROCK, Tile.HOBBIT_WALL, Tile.MILL_BASE]

