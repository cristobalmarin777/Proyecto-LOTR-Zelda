class_name ShireMap
extends RefCounted

## Reconstrucción jugable de HOBBITON (Escala Cartográfica 1:5 — 80x56 tiles = 2560x1792 px)
## con Sistema Real de Elevaciones (Niveles 0, 1, 2, 3), Rampas de tierra, Escaleras de piedra,
## Puentes, Viviendas Hobbit/Rurales (Referencias A y B + Especiales) y Bosque Viejo.

const TILE_SIZE := 32
const COLS := 80
const ROWS := 56

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
var elevation: ElevationSystem
var buildings_data: Array = []
var building_colliders: Array = []
var npcs: Array = []
var chests: Array = []
var signs: Array = []
var enemy_spawns: Array = []
var spawn_position: Vector2 = Vector2(35.0 * 32.0, 9.0 * 32.0)

func _init() -> void:
	elevation = ElevationSystem.new(COLS, ROWS, float(TILE_SIZE))
	build_level()

func build_level() -> void:
	grid.clear()
	buildings_data.clear()
	building_colliders.clear()

	for _row in range(ROWS):
		var line: Array = []
		line.resize(COLS)
		line.fill(Tile.GRASS)
		grid.append(line)

	for column in range(COLS):
		grid[0][column] = Tile.TREE
		grid[ROWS - 1][column] = Tile.TREE
	for row in range(ROWS):
		grid[row][0] = Tile.TREE
		grid[row][COLS - 1] = Tile.TREE

	# 1. NIVELES DE ELEVACIÓN DE HOBBITON CON CONTORNOS ORGÁNICOS (esquinas achaflanadas + curvas naturales)
	# Nivel 1 Norte se extiende hasta la orilla del Lago El Agua (el agua en Nivel 0 actúa como límite natural)
	elevation.set_height_organic_plateau(3, 10, 32, 57, 1, 3)
	# Nivel 1 Sur (Meseta de Granjas Rurales) linda por el norte con la orilla sur del Lago El Agua
	elevation.set_height_organic_plateau(39, 26, 51, 53, 1, 2)
	# Nivel 2 (Ladera Media: Bagshot Row y Colina Oriental) con esquinas suavizadas
	elevation.set_height_organic_plateau(3, 15, 16, 56, 2, 2)
	# Nivel 3 (Cumbre de Bolsón Cerrado): mantiene cols 27..43 en la entrada de las rampas y suaviza las esquinas norte
	elevation.set_height_rect(2, 27, 10, 43, 3)
	elevation.height_grid[2][27] = 2
	elevation.height_grid[2][28] = 2
	elevation.height_grid[3][27] = 2
	elevation.height_grid[2][43] = 2
	elevation.height_grid[2][42] = 2
	elevation.height_grid[3][43] = 2

	# 2. RAMPAS Y PUENTES (Todas las conexiones entre niveles usan textura de camino y anchura exacta de 3 tiles para calzar con los caminos)
	elevation.add_connection({"id": "ramp_bag_end_west", "type": "ramp", "col": 27, "row": 10, "width_tiles": 3, "height_tiles": 2, "start_height": 2, "end_height": 3, "direction": "north"})
	elevation.add_connection({"id": "ramp_bag_end_east", "type": "ramp", "col": 40, "row": 10, "width_tiles": 3, "height_tiles": 2, "start_height": 2, "end_height": 3, "direction": "north"})
	elevation.add_connection({"id": "ramp_bagshot_south", "type": "ramp", "col": 23, "row": 16, "width_tiles": 3, "height_tiles": 2, "start_height": 1, "end_height": 2, "direction": "north"})
	elevation.add_connection({"id": "ramp_mid_hill", "type": "ramp", "col": 33, "row": 16, "width_tiles": 3, "height_tiles": 2, "start_height": 1, "end_height": 2, "direction": "north"})
	elevation.add_connection({"id": "ramp_east_hills", "type": "ramp", "col": 49, "row": 16, "width_tiles": 3, "height_tiles": 2, "start_height": 1, "end_height": 2, "direction": "north"})
	# Rampa del Molino y Puente (baja de Nivel 1 -> Nivel 0 hacia el Molino y Puente de Piedra)
	elevation.add_connection({"id": "ramp_to_mill", "type": "ramp", "col": 22, "row": 27, "width_tiles": 3, "height_tiles": 2, "start_height": 0, "end_height": 1, "direction": "north"})
	# Zona ribereña del Viejo Molino y acceso al Puente de Piedra en Nivel 0
	elevation.set_height_rect(28, 10, 34, 25, 0)
	# Rampa oriental hacia el Puente del Bosque Viejo (baja de Nivel 1 -> Nivel 0)
	elevation.add_connection({"id": "ramp_east_bridge", "type": "ramp", "col": 52, "row": 27, "width_tiles": 3, "height_tiles": 2, "start_height": 0, "end_height": 1, "direction": "north"})
	elevation.set_height_rect(28, 52, 34, 59, 0)
	elevation.add_connection({"id": "ramp_rural_west", "type": "ramp", "col": 25, "row": 42, "width_tiles": 2, "height_tiles": 3, "start_height": 0, "end_height": 1, "direction": "east"})
	elevation.add_connection({"id": "ramp_rural_south", "type": "ramp", "col": 35, "row": 51, "width_tiles": 3, "height_tiles": 2, "start_height": 0, "end_height": 1, "direction": "north"})
	elevation.add_connection({"id": "ramp_rural_east", "type": "ramp", "col": 53, "row": 42, "width_tiles": 2, "height_tiles": 3, "start_height": 0, "end_height": 1, "direction": "west"})
	elevation.add_connection({"id": "bridge_stone", "type": "bridge", "col": 22, "row": 32, "width_tiles": 3, "height_tiles": 7, "start_height": 0, "end_height": 0, "direction": "north"})
	elevation.add_connection({"id": "bridge_east", "type": "bridge", "col": 57, "row": 31, "width_tiles": 2, "height_tiles": 7, "start_height": 0, "end_height": 0, "direction": "north"})

	# 3. BOSQUE VIEJO AL ESTE Y LAGO "EL AGUA" (Siempre Nivel 0; recorta el borde de Nivel 1 y sirve de límite natural)
	for row in range(1, ROWS - 1):
		for col in range(63, COLS - 1):
			var jitter := roundi(sin(float(row) * 0.4) * 2.0)
			if col >= 64 + jitter:
				grid[row][col] = Tile.DARK_FOREST

	for col in range(1, 64):
		var center_row := roundi(35.0 + sin(float(col) * 0.11) * 2.2)
		var half_w := (3.5 + sin(float(col - 27) * 0.14) * 1.6) if (col >= 27 and col <= 49) else 1.8
		for row in range(maxi(2, floori(center_row - half_w)), mini(ROWS - 3, ceili(center_row + half_w)) + 1):
			grid[row][col] = Tile.WATER
			# El agua siempre permanece en Nivel 0, formando un acantilado ribereño contra las terrazas de Nivel 1
			elevation.height_grid[row][col] = 0

	# 4. CAMINOS PRINCIPALES (3 tiles de ancho, calzando exactamente con el ancho de cada rampa)
	paint_rect(8, 27, 10, 42, Tile.DIRT_PATH)
	paint_curved_path([[28, 12], [25, 13], [24, 16]], 2, Tile.DIRT_PATH)
	paint_curved_path([[28, 12], [34, 13], [34, 16]], 2, Tile.DIRT_PATH)
	paint_curved_path([[41, 12], [47, 13], [50, 16]], 2, Tile.DIRT_PATH)
	paint_curved_path([[24, 18], [27, 22], [34, 24], [34, 18]], 2, Tile.DIRT_PATH)
	paint_curved_path([[50, 18], [52, 23], [53, 27]], 2, Tile.DIRT_PATH)
	paint_curved_path([[34, 24], [24, 25], [23, 27]], 2, Tile.DIRT_PATH)
	paint_curved_path([[34, 24], [44, 25], [53, 26]], 2, Tile.DIRT_PATH)

	# Asegurar empalme exacto (3 tiles) en las entradas y salidas de todas las rampas verticales
	paint_rect(10, 27, 12, 29, Tile.DIRT_PATH)
	paint_rect(10, 40, 12, 42, Tile.DIRT_PATH)
	paint_rect(15, 23, 18, 25, Tile.DIRT_PATH)
	paint_rect(15, 33, 18, 35, Tile.DIRT_PATH)
	paint_rect(15, 49, 18, 51, Tile.DIRT_PATH)
	paint_rect(26, 22, 31, 24, Tile.DIRT_PATH)
	paint_rect(26, 52, 29, 54, Tile.DIRT_PATH)

	paint_rect(28, 22, 39, 24, Tile.DIRT_PATH)
	for r in range(32, 39):
		grid[r][22] = Tile.COBBLESTONE
		grid[r][23] = Tile.BRIDGE
		grid[r][24] = Tile.COBBLESTONE
	paint_curved_path([[23, 39], [18, 41], [13, 43], [6, 44], [1, 44]], 2, Tile.DIRT_PATH)
	paint_rect(39, 22, 44, 26, Tile.DIRT_PATH)

	# Meseta Sur (Nivel 1): camino principal de 3 tiles (filas 42..44) y bajada sur de 3 tiles (cols 35..37)
	paint_rect(42, 25, 44, 54, Tile.DIRT_PATH)
	paint_rect(44, 35, 54, 37, Tile.DIRT_PATH)

	for r in range(31, 38):
		grid[r][57] = Tile.BRIDGE
		grid[r][58] = Tile.BRIDGE
	paint_curved_path([[53, 29], [57, 30], [57, 38], [64, 39], [72, 41], [78, 41]], 2, Tile.DIRT_PATH)
	paint_curved_path([[54, 43], [58, 42], [58, 38]], 2, Tile.DIRT_PATH)

	# 4b. SENDEROS ANGOSTOS (1 tile de ancho) que acceden a todas las viviendas separadas del camino principal
	# Acceso a Bolsón Cerrado (Bag End) desde el camino de la cumbre
	paint_rect(6, 35, 8, 35, Tile.DIRT_PATH)
	# Acceso al Smial del Jardín Florido (Ref. A, col 18, fila 13) desde Bolsón de Tirada
	paint_rect(13, 18, 13, 24, Tile.DIRT_PATH)
	# Acceso al Smial de la Colina Oriental (col 47, fila 11-12)
	paint_rect(11, 47, 13, 47, Tile.DIRT_PATH)
	# Acceso al Smial del Sendero Oeste (col 14-15, fila 21) desde el camino del valle
	paint_rect(21, 14, 21, 25, Tile.DIRT_PATH)
	# Acceso al Smial del Robledal (col 45-46, fila 22) desde el camino del valle este
	paint_rect(22, 45, 25, 45, Tile.DIRT_PATH)
	# Acceso al Pabellón del Banquete (col 29, fila 24) y al Árbol de la Fiesta (col 34, fila 21)
	paint_rect(21, 34, 23, 34, Tile.DIRT_PATH)
	paint_rect(24, 29, 25, 29, Tile.DIRT_PATH)
	# Acceso al Viejo Molino de Arenas (col 19, fila 30) desde el camino del puente
	paint_rect(30, 19, 30, 22, Tile.DIRT_PATH)
	# Acceso a la Posada El Dragón Verde (col 12, fila 41) desde el camino de la ribera suroeste
	paint_rect(41, 12, 43, 12, Tile.DIRT_PATH)
	# Accesos individuales a las 3 Granjas Rurales de la Meseta Sur (Ref. B)
	paint_rect(43, 29, 44, 29, Tile.DIRT_PATH)
	paint_rect(43, 36, 44, 36, Tile.DIRT_PATH)
	paint_rect(43, 45, 44, 45, Tile.DIRT_PATH)

	# 5. HUERTOS, FLORES, HIERBA ALTA Y ÁRBOLES (ESTÉTICA DE LA ACTUALIZACIÓN)
	paint_rect(46, 27, 49, 33, Tile.CROP_FIELD)
	paint_rect(46, 42, 49, 49, Tile.CROP_FIELD)
	for c in range(27, 35):
		if c != 30:
			grid[45][c] = Tile.FENCE
	for c in range(41, 51):
		if c != 45:
			grid[45][c] = Tile.FENCE

	for tree in [
		[30, 5], [40, 5], [16, 8], [21, 8], [52, 8], [54, 12],
		[12, 18], [13, 24], [20, 23], [41, 20], [55, 22],
		[7, 39], [8, 45], [18, 45], [27, 49], [40, 48], [51, 48],
		[66, 8], [66, 9], [70, 14], [70, 15], [67, 22], [67, 23],
		[72, 29], [72, 30], [68, 48], [68, 49], [74, 20], [75, 21],
	]:
		grid[tree[1]][tree[0]] = Tile.TREE

	for rock in [[63, 12], [63, 13], [65, 25], [69, 34], [73, 45], [74, 45]]:
		grid[rock[1]][rock[0]] = Tile.ROCK

	for spot in [[32, 8], [38, 8], [22, 13], [27, 13], [44, 12], [31, 22], [37, 22], [18, 42], [29, 44], [41, 44], [51, 42]]:
		if grid[spot[1]][spot[0]] == Tile.GRASS:
			grid[spot[1]][spot[0]] = Tile.FLOWERS

	paint_rect(19, 17, 21, 20, Tile.TALL_GRASS)
	paint_rect(22, 48, 25, 51, Tile.TALL_GRASS)
	paint_rect(47, 16, 49, 20, Tile.TALL_GRASS)
	paint_rect(19, 60, 23, 62, Tile.TALL_GRASS)

	paint_rect(38, 67, 44, 75, Tile.DIRT_PATH)
	grid[41][71] = Tile.CAMPFIRE_ASH

	# 6. EDIFICIOS DE HOBBITON (REFERENCIAS A Y B + ESPECIALES)
	register_building("bag_end", 35.0 * 32.0, 6.4 * 32.0, "Bolsón Cerrado (Bag End)", "Nivel 3 · Cumbre de La Colina", ["«En un agujero en el suelo, vivía un hobbit...»", "Desde la cumbre (Nivel 3) puedes bajar por las escaleras oeste o la rampa este."])
	register_building("smial_sam", 24.5 * 32.0, 12.2 * 32.0, "Nº 3 de Bolsón de Tirada", "Nivel 2 · Sam Gamyi", ["Hogar de la familia Gamyi en la ladera media."])
	register_building("smial_green_classic", 18.2 * 32.0, 12.8 * 32.0, "Smial del Jardín Florido (Ref. A)", "Nivel 2 · Familia Cavada", ["Vivienda hobbit tradicional con puerta verde redonda, ventanas en X y escalones de piedra."])
	register_building("smial_wealthy_blue", 47.0 * 32.0, 11.2 * 32.0, "Smial de la Colina Oriental", "Nivel 2 · Familia Ceñidor", ["Vivienda amplia de puerta azul real con vistas al valle."])
	register_building("party_tree", 34.5 * 32.0, 20.5 * 32.0, "El Árbol de la Fiesta", "Nivel 1 · Valle Central", ["Bajo estas ramas se celebró el 111.º cumpleaños de Bilbo Bolsón."])
	register_building("party_tent", 29.0 * 32.0, 23.6 * 32.0, "Pabellón del Banquete", "Nivel 1 · Plaza de la Fiesta", ["Pasteles de miel y cerveza fresca restauran tus corazones al máximo."], true)
	register_building("smial_humble_red", 14.5 * 32.0, 20.5 * 32.0, "Smial del Sendero Oeste", "Nivel 1 · Pradera Oeste", ["Acogedor agujero hobbit de puerta carmesí."])
	register_building("smial_oak_brown", 45.5 * 32.0, 21.5 * 32.0, "Smial del Robledal", "Nivel 1 · Pradera Este", ["Taller del tonelero de Hobbiton con puerta de roble."])
	register_building("old_mill", 19.0 * 32.0, 29.8 * 32.0, "El Viejo Molino de Arenas", "Nivel 0 · Ribera Norte", ["La rueda hidráulica muele el grano junto al río El Agua."])
	register_building("green_dragon_inn", 12.8 * 32.0, 40.5 * 32.0, "Posada El Dragón Verde", "Nivel 0 · Ribera Suroeste", ["«¡No hallarás mejor cerveza que la de El Dragón Verde!»", "El calor de la chimenea restaura tu salud al completo."], true)
	register_building("rural_l_house", 36.5 * 32.0, 43.2 * 32.0, "Granja del Prado Sur (Ref. B)", "Nivel 1 · Familia Coto", ["Casa rural en L de piedra, entramado de madera y tejado de paja dorada."])
	register_building("rural_cottage", 29.0 * 32.0, 43.2 * 32.0, "Cabaña del Mirador Sur", "Nivel 1 · Meseta Sur", ["Cabaña campesina de piedra y techo de paja sobre la terraza sur."])
	register_building("rural_stone_barn", 45.5 * 32.0, 43.2 * 32.0, "Granero de Piedra y Paja", "Nivel 1 · Meseta Sur", ["Granero auxiliar donde se guardan las calabazas y el trigo."])

	build_story_content()

func register_building(catalog_id: String, center_x: float, base_y: float, title: String, resident: String, dialog: Array, heals: bool = false) -> void:
	var h := elevation.get_height_at_pixel(Vector2(center_x, base_y))
	var entry := {
		"catalog_id": catalog_id,
		"center_x": center_x,
		"base_y": base_y,
		"title": title,
		"resident": resident,
		"dialog": dialog,
		"heals_player": heals,
		"elevation": h,
	}
	buildings_data.append(entry)
	var probe := HobbitonBuilding.new()
	probe.catalog_id = catalog_id
	probe.apply_catalog_metrics()
	var tl := Vector2(center_x - probe.sprite_size.x * 0.5, base_y - probe.sort_y_offset)
	building_colliders.append(Rect2(tl + probe.local_collider.position, probe.local_collider.size))
	probe.free()

func build_story_content() -> void:
	npcs = [
		{
			"id": "gandalf", "name": "Gandalf el Gris", "col": 35, "row": 9,
			"hat_color": Color("52627a"), "cloak_color": Color("768496"),
			"dialog": [
				"¡Bienvenido a la cumbre de La Colina (Nivel 3), frente a Bolsón Cerrado!",
				"Usa las escaleras de piedra al oeste o la rampa al este para descender a Bolsón de Tirada (Nivel 2) y el Árbol de la Fiesta (Nivel 1).",
				"Pulsa [H] para activar el Modo de Depuración de Elevaciones y ver niveles, rampas y acantilados.",
				"MISIÓN PRINCIPAL: cruza el puente oriental hacia el Bosque Viejo y derrota al Capitán Uruk-hai.",
			],
		},
		{
			"id": "sam", "name": "Sam Gamyi", "col": 25, "row": 13,
			"hat_color": Color("8c5a2b"), "cloak_color": Color("4b7a34"),
			"dialog": ["¡Buenos días! Estás en Bolsón de Tirada (Nivel 2).", "Baja por la rampa hacia el Árbol de la Fiesta y el Viejo Molino (Nivel 0) para recoger el Arco de la Comarca."],
		},
		{
			"id": "shire_smith", "name": "Haldor el Armero", "col": 22, "row": 29,
			"hat_color": Color("667078"), "cloak_color": Color("704b2b"), "merchant": true, "dialog": [],
		},
		{
			"id": "rosie", "name": "Rosita Coto · El Dragón Verde", "col": 13, "row": 43,
			"hat_color": Color("d96b82"), "cloak_color": Color("b84058"), "healer": true,
			"dialog": ["¡Bienvenido a la Posada El Dragón Verde, a orillas del lago El Agua!", "Tus corazones de vida han sido restaurados al máximo."],
		},
		{
			"id": "farmer_maggot", "name": "Granjero Maggot", "col": 37, "row": 44,
			"hat_color": Color("a37b37"), "cloak_color": Color("6b4922"),
			"dialog": ["Nuestras Granjas Rurales se alzan sobre la meseta sur (Nivel 1).", "Baja por la rampa del este para llegar al Bosque Viejo o por la escalera del sur hacia Eriador."],
		},
	]
	chests = [
		{"id": "chest_mill", "col": 17, "row": 31, "reward": "bow_upgrade", "title": "Arco de la Comarca + 15 flechas", "description": "Puedes equipar el arco en el inventario y disparar con Q."},
		{"id": "chest_gardens", "col": 33, "row": 50, "reward": "potion_pack", "title": "Pan de lembas y Miruvor + 25 monedas", "description": "Recupera fuerzas durante el viaje."},
		{"id": "chest_forest_north", "col": 54, "row": 14, "reward": "heart_container", "title": "Contenedor de Corazón Dúnedain", "description": "Aumenta tu salud hasta el límite temporal de seis corazones."},
		{"id": "chest_orc_camp", "col": 74, "row": 41, "reward": "sword_temper", "title": "Hoja Élfica Templada", "description": "Una mejora de filo o una nueva hoja para tu viaje."},
	]
	signs = [
		{"col": 32, "row": 9, "text": "CUMBRE DE LA COLINA (Nivel 3) · Oeste: Rampa a Bolsón de Tirada (Niv. 2) · Este: Rampa · [H] Debug Alturas"},
		{"col": 25, "row": 29, "text": "Oeste: Viejo Molino y Forja de Haldor · Sur: Puente de Piedra -> Posada El Dragón Verde (Nivel 0)"},
		{"col": 35, "row": 44, "text": "MESETA DE GRANJAS RURALES (Nivel 1) · Sur: Rampa a Eriador · Este: Rampa al Bosque Viejo"},
		{"col": 60, "row": 39, "text": "PELIGRO: Frontera del Bosque Viejo. Más allá acechan los Orcos y el Capitán Uruk-hai."},
	]
	# Garantizar que ningún cartel se genere sobre agua ni sobre tiles sólidos
	var valid_signs: Array = []
	for s in signs:
		var sc := int(s.get("col", 0))
		var sr := int(s.get("row", 0))
		if tile_at(sc, sr) == Tile.WATER or tile_is_solid(tile_at(sc, sr)):
			var relocated := find_nearest_dry_tile(sc, sr)
			s["col"] = relocated.x
			s["row"] = relocated.y
		if tile_at(int(s["col"]), int(s["row"])) != Tile.WATER:
			valid_signs.append(s)
	signs = valid_signs
	enemy_spawns = [
		{"type": "spider", "col": 65, "row": 14}, {"type": "orc", "col": 68, "row": 19},
		{"type": "spider", "col": 64, "row": 27}, {"type": "orc", "col": 66, "row": 35},
		{"type": "spider", "col": 71, "row": 32}, {"type": "orc", "col": 67, "row": 42},
		{"type": "spider", "col": 64, "row": 47}, {"type": "uruk", "col": 71, "row": 41, "mini_boss": true},
	]

func paint_curved_path(waypoints: Array, radius_tiles: int, tile: int) -> void:
	for i in range(waypoints.size() - 1):
		var p1: Array = waypoints[i]
		var p2: Array = waypoints[i + 1]
		var steps := maxi(absi(int(p2[0]) - int(p1[0])), absi(int(p2[1]) - int(p1[1]))) * 2
		for s in range(steps + 1):
			var t := 0.0 if steps == 0 else float(s) / float(steps)
			var wave := sin(t * PI) * 0.45
			var cc := roundi(lerpf(float(p1[0]), float(p2[0]), t) + wave)
			var rr := roundi(lerpf(float(p1[1]), float(p2[1]), t))
			paint_rect(rr - radius_tiles + 1, cc - radius_tiles + 1, rr + radius_tiles - 1, cc + radius_tiles - 1, tile)

func paint_rect(row_start: int, col_start: int, row_end: int, col_end: int, tile: int) -> void:
	for row in range(row_start, row_end + 1):
		for column in range(col_start, col_end + 1):
			if row >= 0 and row < ROWS and column >= 0 and column < COLS:
				if grid[row][column] != Tile.WATER and grid[row][column] != Tile.BRIDGE:
					grid[row][column] = tile

func has_inner_cell(column: int, row: int) -> bool:
	return column > 0 and column < COLS - 1 and row > 0 and row < ROWS - 1

func tile_at(column: int, row: int) -> int:
	if column < 0 or column >= COLS or row < 0 or row >= ROWS:
		return Tile.GRASS
	return int(grid[row][column])

func find_nearest_dry_tile(col: int, row: int) -> Vector2i:
	for radius in range(1, 8):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				var nc := col + dc
				var nr := row + dr
				if has_inner_cell(nc, nr) and not tile_is_solid(tile_at(nc, nr)):
					return Vector2i(nc, nr)
	return Vector2i(col, row)

func tile_is_solid(tile: int) -> bool:
	return tile in [Tile.WATER, Tile.TREE, Tile.FENCE, Tile.ROCK, Tile.HOBBIT_WALL, Tile.MILL_BASE]

func is_building_blocked(pos: Vector2, half_w: float = 10.0, half_h: float = 10.0) -> bool:
	var p_rect := Rect2(pos - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0))
	for box in building_colliders:
		if p_rect.intersects(box):
			return true
	return false
