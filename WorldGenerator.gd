class_name MiddleEarthWorld
extends Node2D

## Mundo infinito determinista: no se almacena una cuadrícula global. Cada
## coordenada se deriva de la semilla, por lo que volver al mismo chunk siempre
## recrea su terreno, campamento, cofre y encuentros de la misma manera.
signal enemy_requested(kind: String, world_position: Vector2, threat: int)
signal elf_requested(role: String, world_position: Vector2)

const TILE_SIZE := 32.0
const CHUNK_SIZE := 32
const ATLAS_CHUNKS := 9
const ACTIVE_CHUNK_RADIUS := 2

var world_seed := 19771029
var player: MiddleEarthPlayer
var shire: ShireMap = ShireMap.new()
var debug_elevation_mode := false
var populated_chunks: Dictionary = {}
var opened_chests: Dictionary = {}
var opened_story_chests: Dictionary = {}
var revealed_atlases: Dictionary = {"0,0": true}

const ELEVATION_GRASS_COLORS := [
	Color("4ea02f"),
	Color("58ad34"),
	Color("65b83b"),
	Color("72c244"),
]

func bind_player(value: MiddleEarthPlayer) -> void:
	player = value
	queue_redraw()

func _process(_delta: float) -> void:
	if player == null:
		return
	refresh_population()
	queue_redraw()

func hash01(cell_x: int, cell_y: int, salt: int = 0) -> float:
	# Una función pura, no un RNG mutable: la base de la generación infinita.
	var value := sin(float(cell_x) * 12.9898 + float(cell_y) * 78.233 + float(world_seed + salt) * 0.0001) * 43758.5453
	return value - floor(value)

func chunk_from_world(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / (TILE_SIZE * CHUNK_SIZE)),
		floori(world_position.y / (TILE_SIZE * CHUNK_SIZE))
	)

func atlas_from_chunk(chunk: Vector2i) -> Vector2i:
	return Vector2i(floori(float(chunk.x) / ATLAS_CHUNKS), floori(float(chunk.y) / ATLAS_CHUNKS))

func atlas_key(atlas: Vector2i) -> String:
	return "%d,%d" % [atlas.x, atlas.y]

func biome_at_world(world_position: Vector2) -> String:
	return biome_at_cell(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))

func biome_at_cell(cell_x: int, cell_y: int) -> String:
	# La Comarca artesanal se reserva en el centro; las demás regiones forman
	# franjas amplias y predecibles, con ruido para que sus fronteras no sean rectas.
	var wobble := floori((hash01(floori(cell_x / 12.0), floori(cell_y / 12.0), 17) - 0.5) * 22.0)
	if shire.has_inner_cell(cell_x, cell_y):
		return "OLD_FOREST" if shire.tile_at(cell_x, cell_y) == ShireMap.Tile.DARK_FOREST else "SHIRE"
	if cell_x >= -10 and cell_x <= 70 and cell_y >= -8 and cell_y <= 58:
		return "SHIRE"
	if cell_x + wobble < -46:
		return "OLD_FOREST"
	if cell_y > 96:
		return "BARROW_DOWNS"
	if cell_x > 160:
		return "MISTY_FOOTHILLS"
	if cell_x > 72:
		return "ERIADOR"
	return "BREE_LAND"

func biome_display_name(biome: String) -> String:
	match biome:
		"SHIRE": return "LA COMARCA"
		"OLD_FOREST": return "BOSQUE VIEJO"
		"BREE_LAND": return "TIERRAS DE BREE"
		"BARROW_DOWNS": return "QUEBRADAS DE LOS TÚMULOS"
		"MISTY_FOOTHILLS": return "ESTRIBACIONES NUBLADAS"
		_: return "ERIADOR SALVAJE"

func darkness_at(world_position: Vector2) -> float:
	match biome_at_world(world_position):
		"OLD_FOREST": return 0.74
		"BARROW_DOWNS": return 0.34
		_: return 0.0

func get_height_at_tile(cell_x: int, cell_y: int) -> int:
	if shire.has_inner_cell(cell_x, cell_y):
		return shire.elevation.get_height_at_tile(cell_x, cell_y)
	return 0

func get_connection_at_pixel(world_position: Vector2) -> Dictionary:
	var cell_x := floori(world_position.x / TILE_SIZE)
	var cell_y := floori(world_position.y / TILE_SIZE)
	if shire.has_inner_cell(cell_x, cell_y):
		return shire.elevation.get_connection_at_tile(cell_x, cell_y)
	return {}

func is_signpost_blocked(world_position: Vector2) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("signposts"):
		var sign: ShireSignpost = node as ShireSignpost
		if sign != null and sign.blocks_position(world_position):
			return true
	return false

func is_solid_only(world_position: Vector2) -> bool:
	# Comprueba si un destino tiene agua, árbol, roca, edificio o cartel intacto (ignorando diferencia de altura)
	if is_signpost_blocked(world_position):
		return true
	var cell_x := floori(world_position.x / TILE_SIZE)
	var cell_y := floori(world_position.y / TILE_SIZE)
	if shire.has_inner_cell(cell_x, cell_y):
		if shire.tile_is_solid(shire.tile_at(cell_x, cell_y)):
			return true
		if shire.is_building_blocked(world_position, 10.0, 10.0):
			return true
		return false
	return is_blocked(world_position)

func get_interpolated_elevation(world_position: Vector2) -> float:
	var cell_x := floori(world_position.x / TILE_SIZE)
	var cell_y := floori(world_position.y / TILE_SIZE)
	if shire.has_inner_cell(cell_x, cell_y):
		return shire.elevation.get_interpolated_elevation(world_position)
	return 0.0

func is_blocked(world_position: Vector2, current_height: float = -999.0) -> bool:
	if is_signpost_blocked(world_position):
		return true
	var cell_x := floori(world_position.x / TILE_SIZE)
	var cell_y := floori(world_position.y / TILE_SIZE)
	if shire.has_inner_cell(cell_x, cell_y):
		if shire.tile_is_solid(shire.tile_at(cell_x, cell_y)):
			return true
		if shire.is_building_blocked(world_position, 10.0, 10.0):
			return true
		if current_height > -100.0 and shire.elevation.is_elevation_blocked(world_position, 9.0, 9.0, current_height):
			return true
		return false
	var biome := biome_at_cell(cell_x, cell_y)
	if biome == "SHIRE":
		return false
	if biome == "OLD_FOREST":
		return hash01(cell_x, cell_y, 91) < 0.13
	if biome == "MISTY_FOOTHILLS":
		return hash01(cell_x, cell_y, 92) < 0.10
	return hash01(cell_x, cell_y, 93) < 0.025

func poi_for_chunk(chunk: Vector2i) -> Dictionary:
	if chunk.x >= 0 and chunk.x <= 2 and chunk.y >= 0 and chunk.y <= 1:
		return {}
	var biome := biome_at_cell(chunk.x * CHUNK_SIZE + 16, chunk.y * CHUNK_SIZE + 16)
	var roll := hash01(chunk.x, chunk.y, 1100)
	var kind := ""
	if biome == "MISTY_FOOTHILLS" and roll < 0.22:
		kind = "mine_dwarven" if hash01(chunk.x, chunk.y, 1101) < 0.48 else "mine_abandoned"
	elif (biome == "OLD_FOREST" or biome == "BARROW_DOWNS") and roll < 0.12:
		kind = "cave"
	elif biome == "ERIADOR" and roll < 0.055:
		kind = "cave"
	if kind.is_empty():
		return {}
	return {"kind": kind, "position": Vector2((chunk.x * CHUNK_SIZE + 16) * TILE_SIZE, (chunk.y * CHUNK_SIZE + 16) * TILE_SIZE)}

func camp_for_chunk(chunk: Vector2i) -> Dictionary:
	var biome := biome_at_cell(chunk.x * CHUNK_SIZE + 16, chunk.y * CHUNK_SIZE + 16)
	if biome not in ["OLD_FOREST", "ERIADOR", "BARROW_DOWNS"] or hash01(chunk.x, chunk.y, 1500) > 0.115:
		return {}
	return {"position": Vector2((chunk.x * CHUNK_SIZE + 16) * TILE_SIZE, (chunk.y * CHUNK_SIZE + 16) * TILE_SIZE)}

func chest_for_atlas(atlas: Vector2i) -> Dictionary:
	var key := atlas_key(atlas)
	var local_x := 1 + floori(hash01(atlas.x, atlas.y, 321) * float(ATLAS_CHUNKS - 2))
	var local_y := 1 + floori(hash01(atlas.x, atlas.y, 322) * float(ATLAS_CHUNKS - 2))
	var chunk := Vector2i(atlas.x * ATLAS_CHUNKS + local_x, atlas.y * ATLAS_CHUNKS + local_y)
	return {
		"key": key,
		"position": Vector2((chunk.x * CHUNK_SIZE + 16) * TILE_SIZE, (chunk.y * CHUNK_SIZE + 16) * TILE_SIZE),
		"opened": opened_chests.has(key),
	}

func reveal_current_atlas() -> void:
	if player != null:
		revealed_atlases[atlas_key(atlas_from_chunk(chunk_from_world(player.global_position)))] = true

func open_nearby_map_chest(world_position: Vector2) -> String:
	var atlas := atlas_from_chunk(chunk_from_world(world_position))
	for y in range(atlas.y - 1, atlas.y + 2):
		for x in range(atlas.x - 1, atlas.x + 2):
			var chest := chest_for_atlas(Vector2i(x, y))
			if not chest.opened and world_position.distance_to(chest.position) < 44.0:
				opened_chests[chest.key] = true
				revealed_atlases[chest.key] = true
				return "Has encontrado la carta regional %s." % chest.key
	return ""

func refresh_population() -> void:
	var center := chunk_from_world(player.global_position)
	for y in range(center.y - ACTIVE_CHUNK_RADIUS, center.y + ACTIVE_CHUNK_RADIUS + 1):
		for x in range(center.x - ACTIVE_CHUNK_RADIUS, center.x + ACTIVE_CHUNK_RADIUS + 1):
			var chunk := Vector2i(x, y)
			var key := "%d,%d" % [x, y]
			if populated_chunks.has(key):
				continue
			populated_chunks[key] = true
			spawn_chunk_population(chunk)

func spawn_chunk_population(chunk: Vector2i) -> void:
	if chunk.x >= 0 and chunk.x <= 2 and chunk.y >= 0 and chunk.y <= 1:
		return
	var biome := biome_at_cell(chunk.x * CHUNK_SIZE + 16, chunk.y * CHUNK_SIZE + 16)
	var threat := mini(floori(Vector2(chunk).length() / 6.0) + (2 if biome == "MISTY_FOOTHILLS" else 0), 5)
	var count: int = int({"SHIRE": 1, "OLD_FOREST": 3, "BREE_LAND": 2, "BARROW_DOWNS": 3, "ERIADOR": 2, "MISTY_FOOTHILLS": 3}.get(biome, 2))
	for index in range(count):
		var roll := hash01(chunk.x, chunk.y, 900 + index)
		var kind := "orc"
		if biome == "OLD_FOREST":
			kind = "spider" if roll < 0.42 else ("orc" if roll < 0.72 else "archer_orc")
		elif biome == "MISTY_FOOTHILLS":
			kind = "uruk" if roll < 0.35 else "orc"
		elif biome == "BARROW_DOWNS":
			kind = "spider" if roll < 0.52 else "orc"
		elif roll < 0.28:
			kind = "spider"
		var spot := spawn_point(chunk, 500 + index)
		if not is_blocked(spot):
			enemy_requested.emit(kind, spot, threat)
	var camp := camp_for_chunk(chunk)
	if not camp.is_empty():
		var goblins := 5 + floori(hash01(chunk.x, chunk.y, 1501) * 4.0)
		for index in range(goblins):
			var angle := hash01(chunk.x, chunk.y, 1510 + index) * TAU
			var radius := 60.0 + hash01(chunk.x, chunk.y, 1530 + index) * 120.0
			enemy_requested.emit("goblin", camp.position + Vector2(cos(angle), sin(angle)) * radius, 0)
	if biome == "OLD_FOREST" and hash01(chunk.x, chunk.y, 1400) < 0.26:
		var roles := ["scout", "lembas", "quest"]
		var role: String = str(roles[floori(hash01(chunk.x, chunk.y, 1403) * roles.size())])
		elf_requested.emit(role, spawn_point(chunk, 1401))

func spawn_point(chunk: Vector2i, salt: int) -> Vector2:
	var cell_x := chunk.x * CHUNK_SIZE + 4 + floori(hash01(chunk.x, chunk.y, salt) * 24.0)
	var cell_y := chunk.y * CHUNK_SIZE + 4 + floori(hash01(chunk.x, chunk.y, salt + 100) * 24.0)
	return Vector2(cell_x * TILE_SIZE + TILE_SIZE * 0.5, cell_y * TILE_SIZE + TILE_SIZE * 0.5)

func _draw() -> void:
	if player == null:
		return
	var start_x := floori((player.global_position.x - 640.0) / TILE_SIZE)
	var end_x := floori((player.global_position.x + 640.0) / TILE_SIZE)
	var start_y := floori((player.global_position.y - 460.0) / TILE_SIZE)
	var end_y := floori((player.global_position.y + 460.0) / TILE_SIZE)
	for cell_y in range(start_y, end_y + 1):
		for cell_x in range(start_x, end_x + 1):
			draw_terrain_cell(cell_x, cell_y)
	draw_points_of_interest(start_x, end_x, start_y, end_y)
	if debug_elevation_mode:
		draw_elevation_debug(start_x, end_x, start_y, end_y)

func draw_terrain_cell(cell_x: int, cell_y: int) -> void:
	if shire.has_inner_cell(cell_x, cell_y):
		draw_shire_tile(cell_x, cell_y, shire.tile_at(cell_x, cell_y))
		return
	var biome := biome_at_cell(cell_x, cell_y)
	var rect := Rect2(cell_x * TILE_SIZE, cell_y * TILE_SIZE, TILE_SIZE + 1.0, TILE_SIZE + 1.0)
	var base := Color("5d9b4d")
	match biome:
		"OLD_FOREST": base = Color("1c422d")
		"BREE_LAND": base = Color("729c58")
		"BARROW_DOWNS": base = Color("6f7748")
		"ERIADOR": base = Color("71845b")
		"MISTY_FOOTHILLS": base = Color("6f6f68")
	draw_rect(rect, base)
	var visual_roll := hash01(cell_x, cell_y, 300)
	var center := rect.get_center()
	if biome == "OLD_FOREST" and visual_roll < 0.35:
		draw_circle(center + Vector2(0, 2), 13.0, Color("102718"))
		draw_circle(center + Vector2(-6, -7), 9.0, Color("173a21"))
		draw_circle(center + Vector2(7, -8), 10.0, Color("1e4a29"))
	elif biome == "MISTY_FOOTHILLS" and visual_roll < 0.18:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 14), center + Vector2(0, -14), center + Vector2(14, 14)]), Color("50565b"))
	elif biome != "OLD_FOREST" and visual_roll < 0.07:
		draw_circle(center, 4.0, Color("38713a"))
	if (cell_x + cell_y) % 9 == 0:
		draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), Color(0.0, 0.0, 0.0, 0.035), 1.0)

func draw_shire_tile(cell_x: int, cell_y: int, tile: int) -> void:
	# Texturas pixel art 16-bit renovadas estilo Zelda: A Link to the Past + elevaciones,
	# bordes dentados de césped sobre caminos dorados, hierba en abanico, acantilados, rampas y escaleras.
	var origin := Vector2(cell_x * TILE_SIZE, cell_y * TILE_SIZE)
	var rect := Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE))
	var seed_detail := hash01(cell_x, cell_y, 601)
	var h := shire.elevation.get_height_at_tile(cell_x, cell_y)
	var grass_col: Color = ELEVATION_GRASS_COLORS[clampi(h, 0, 3)]
	var conn := shire.elevation.get_connection_at_tile(cell_x, cell_y)

	if not conn.is_empty() and str(conn.type) in ["ramp", "stairs"]:
		draw_dirt_alttp(origin, rect, seed_detail)
		draw_dirt_toothed_edges(cell_x, cell_y, origin, grass_col)
		draw_ramp_overlay(cell_x, cell_y, origin, conn)
		return

	match tile:
		ShireMap.Tile.GRASS:
			draw_grass_base(origin, rect, grass_col, seed_detail)
		ShireMap.Tile.TALL_GRASS:
			draw_grass_base(origin, rect, grass_col, seed_detail)
			draw_lush_tall_grass(origin)
		ShireMap.Tile.FLOWERS:
			draw_grass_base(origin, rect, grass_col, seed_detail)
			draw_alttp_flowers(origin, cell_x, cell_y)
		ShireMap.Tile.DIRT_PATH:
			draw_dirt_alttp(origin, rect, seed_detail)
			draw_dirt_toothed_edges(cell_x, cell_y, origin, grass_col)
		ShireMap.Tile.COBBLESTONE:
			draw_rect(rect, Color("5a5f66"))
			for stone in [Rect2(1, 1, 14, 14), Rect2(17, 1, 14, 14), Rect2(1, 17, 9, 14), Rect2(12, 17, 19, 14)]:
				draw_rect(Rect2(origin + stone.position, stone.size), Color("878d96"))
				draw_rect(Rect2(origin + stone.position + Vector2(1, 1), stone.size - Vector2(3, 3)), Color("9da4ad"))
		ShireMap.Tile.WATER:
			draw_rect(rect, Color("235789"))
			var shift := int(Time.get_ticks_msec() / 450) % 2 * 4
			draw_rect(Rect2(origin + Vector2((4 + shift) % 28, 7), Vector2(10, 2)), Color("5698d4"))
			draw_rect(Rect2(origin + Vector2((16 - shift + 28) % 28, 17), Vector2(12, 2)), Color("7ab8eb"))
			draw_rect(Rect2(origin + Vector2((8 + shift) % 28, 26), Vector2(9, 2)), Color("5698d4"))
		ShireMap.Tile.BRIDGE:
			draw_rect(rect, Color("694221"))
			for x in range(0, 32, 8):
				draw_rect(Rect2(origin + Vector2(x, 0), Vector2(7, 32)), Color("9c6836"))
			draw_rect(Rect2(origin, Vector2(32, 4)), Color("4d2e14"))
			draw_rect(Rect2(origin + Vector2(0, 28), Vector2(32, 4)), Color("4d2e14"))
		ShireMap.Tile.TREE:
			draw_grass_base(origin, rect, grass_col, seed_detail)
			draw_rect(Rect2(origin + Vector2(4, 24), Vector2(24, 6)), Color(0, 0, 0, 0.28))
			draw_rect(Rect2(origin + Vector2(11, 18), Vector2(10, 11)), Color("5c3a1e"))
			draw_rect(Rect2(origin + Vector2(3, 4), Vector2(26, 18)), Color("1e4d1b"))
			draw_rect(Rect2(origin + Vector2(5, 2), Vector2(22, 16)), Color("2e6f28"))
			draw_rect(Rect2(origin + Vector2(7, 4), Vector2(18, 11)), Color("44913b"))
			draw_rect(Rect2(origin + Vector2(9, 5), Vector2(10, 6)), Color("62b356"))
		ShireMap.Tile.FENCE:
			draw_grass_base(origin, rect, grass_col, seed_detail)
			draw_rect(Rect2(origin + Vector2(4, 8), Vector2(6, 20)), Color("5e3c1b"))
			draw_rect(Rect2(origin + Vector2(22, 8), Vector2(6, 20)), Color("5e3c1b"))
			draw_rect(Rect2(origin + Vector2(0, 12), Vector2(32, 4)), Color("7a4e26"))
			draw_rect(Rect2(origin + Vector2(0, 20), Vector2(32, 4)), Color("7a4e26"))
		ShireMap.Tile.ROCK:
			draw_grass_base(origin, rect, grass_col, seed_detail)
			draw_rect(Rect2(origin + Vector2(4, 8), Vector2(24, 18)), Color("4a4e54"))
			draw_rect(Rect2(origin + Vector2(6, 6), Vector2(20, 16)), Color("6c727a"))
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(14, 10)), Color("8d949e"))
		ShireMap.Tile.CROP_FIELD:
			draw_rect(rect, Color("5c3d22"))
			for y in range(3, 30, 8):
				draw_rect(Rect2(origin + Vector2(2, y), Vector2(28, 4)), Color("472d17"))
			for plant in [Vector2(6, 6), Vector2(20, 18), Vector2(18, 6), Vector2(7, 19)]:
				draw_circle(origin + plant + Vector2(3, 3), 3.5, Color("e67e22") if int(plant.x) % 2 == 0 else Color("58b347"))
		ShireMap.Tile.DARK_FOREST:
			draw_grass_base(origin, rect, Color("2d5e29"), seed_detail)
		ShireMap.Tile.CAMPFIRE_ASH:
			draw_rect(rect, Color("3d332a"))
			draw_rect(Rect2(origin + Vector2(4, 4), Vector2(24, 24)), Color("2c241d"))
			draw_circle(origin + Vector2(16, 17), 8.0, Color("595959"))
			draw_circle(origin + Vector2(16, 17), 5.0, Color("d35400"))
			draw_circle(origin + Vector2(16, 17), 2.5, Color("f1c40f"))
		_:
			draw_grass_base(origin, rect, grass_col, seed_detail)

	# Dibujar paredes verticales de acantilado y bordes de plataforma elevada
	draw_cliff_edges(cell_x, cell_y, origin, h)

func draw_grass_base(origin: Vector2, rect: Rect2, color: Color = Color("58ad34"), seed_val: float = 0.0) -> void:
	draw_rect(rect, color)
	var light := color.lightened(0.14)
	for blade in [Vector2(4, 6), Vector2(18, 4), Vector2(26, 12), Vector2(8, 22), Vector2(22, 26)]:
		draw_rect(Rect2(origin + blade, Vector2(2, 1)), light)
	if seed_val < 0.16:
		# Pequeño brote de 3 briznas (Referencia ALTTP)
		var b := origin + Vector2(12, 16)
		draw_rect(Rect2(b + Vector2(1, 5), Vector2(6, 2)), Color("2a6624"))
		draw_rect(Rect2(b + Vector2(0, 2), Vector2(2, 3)), Color("2f7532"))
		draw_rect(Rect2(b + Vector2(3, 0), Vector2(2, 5)), Color("6fd160"))
		draw_rect(Rect2(b + Vector2(6, 2), Vector2(2, 3)), Color("2f7532"))
	elif seed_val > 0.90:
		# Pequeñas piedras en el césped
		draw_rect(Rect2(origin + Vector2(9, 14), Vector2(5, 3)), Color("7d838a"))
		draw_rect(Rect2(origin + Vector2(10, 14), Vector2(3, 2)), Color("aeb5bd"))

func draw_lush_tall_grass(origin: Vector2) -> void:
	for clump: Vector2 in [Vector2(8, 13), Vector2(24, 14), Vector2(16, 27)]:
		var c: Vector2 = origin + clump
		draw_rect(Rect2(c + Vector2(-7, -2), Vector2(14, 3)), Color("1d4d1a"))
		draw_rect(Rect2(c + Vector2(-7, -8), Vector2(3, 6)), Color("2b7333"))
		draw_rect(Rect2(c + Vector2(-9, -11), Vector2(3, 4)), Color("469c4b"))
		draw_rect(Rect2(c + Vector2(-4, -10), Vector2(3, 8)), Color("2b7333"))
		draw_rect(Rect2(c + Vector2(-5, -14), Vector2(3, 5)), Color("78cf72"))
		draw_rect(Rect2(c + Vector2(0, -11), Vector2(3, 9)), Color("25662d"))
		draw_rect(Rect2(c + Vector2(1, -15), Vector2(3, 5)), Color("92e88a"))
		draw_rect(Rect2(c + Vector2(4, -8), Vector2(3, 6)), Color("25662d"))
		draw_rect(Rect2(c + Vector2(6, -11), Vector2(3, 4)), Color("469c4b"))

func draw_alttp_flowers(origin: Vector2, cell_x: int, cell_y: int) -> void:
	var variant := absi(cell_x * 7 + cell_y * 13) % 3
	if variant == 0:
		# Margaritas blancas con centro dorado
		for pos: Vector2 in [Vector2(9, 12), Vector2(22, 24)]:
			var p: Vector2 = origin + pos
			draw_rect(Rect2(p + Vector2(-3, 2), Vector2(7, 3)), Color("28662b"))
			draw_rect(Rect2(p + Vector2(-2, -3), Vector2(5, 5)), Color.WHITE)
			draw_rect(Rect2(p + Vector2(-1, -2), Vector2(3, 3)), Color("f5a623"))
	elif variant == 1:
		# Espigas rosadas/lavanda
		var p := origin + Vector2(15, 21)
		draw_rect(Rect2(p + Vector2(-6, -3), Vector2(13, 4)), Color("235c26"))
		for dx in [-4, 0, 4]:
			draw_rect(Rect2(p + Vector2(dx, -10), Vector2(2, 8)), Color("2d6e31"))
			draw_rect(Rect2(p + Vector2(dx - 1, -11), Vector2(4, 3)), Color("eb6ca8"))
			draw_rect(Rect2(p + Vector2(dx, -12), Vector2(2, 2)), Color("ff9ed0"))
	else:
		# Ramillete naranja y flor azul celeste
		var p := origin + Vector2(11, 18)
		draw_rect(Rect2(p + Vector2(-1, -9), Vector2(2, 8)), Color("388036"))
		draw_rect(Rect2(p + Vector2(-4, -10), Vector2(3, 3)), Color("eb5628"))
		draw_rect(Rect2(p + Vector2(2, -11), Vector2(3, 3)), Color("ff9c40"))
		draw_rect(Rect2(origin + Vector2(21, 16), Vector2(5, 4)), Color("4589e6"))

func draw_dirt_alttp(origin: Vector2, rect: Rect2, seed_val: float) -> void:
	draw_rect(rect, Color("e8b55a"))
	var light := Color("f2c36b")
	var dark := Color("dba346")
	for pebble in [Vector2(4, 6), Vector2(18, 4), Vector2(26, 14), Vector2(8, 20), Vector2(20, 24), Vector2(12, 13)]:
		draw_rect(Rect2(origin + pebble, Vector2(3, 2)), light if seed_val > 0.5 else dark)

func draw_dirt_toothed_edges(cell_x: int, cell_y: int, origin: Vector2, grass_col: Color) -> void:
	var grass_like := [ShireMap.Tile.GRASS, ShireMap.Tile.TALL_GRASS, ShireMap.Tile.FLOWERS, ShireMap.Tile.TREE, ShireMap.Tile.FENCE, ShireMap.Tile.ROCK]
	var shadow := Color("295418")
	if shire.tile_at(cell_x, cell_y - 1) in grass_like:
		for i in range(8):
			var th := 4.0 if i % 2 == 0 else 2.0
			draw_rect(Rect2(origin + Vector2(i * 4, 0), Vector2(4, th)), grass_col)
			draw_rect(Rect2(origin + Vector2(i * 4, th), Vector2(4, 2)), shadow)
	if shire.tile_at(cell_x, cell_y + 1) in grass_like:
		for i in range(8):
			var th := 4.0 if i % 2 == 1 else 2.0
			draw_rect(Rect2(origin + Vector2(i * 4, 32 - th - 2), Vector2(4, 2)), shadow)
			draw_rect(Rect2(origin + Vector2(i * 4, 32 - th), Vector2(4, th)), grass_col)
	if shire.tile_at(cell_x - 1, cell_y) in grass_like:
		for i in range(8):
			var tw := 4.0 if i % 2 == 0 else 2.0
			draw_rect(Rect2(origin + Vector2(0, i * 4), Vector2(tw, 4)), grass_col)
			draw_rect(Rect2(origin + Vector2(tw, i * 4), Vector2(2, 4)), shadow)
	if shire.tile_at(cell_x + 1, cell_y) in grass_like:
		for i in range(8):
			var tw := 4.0 if i % 2 == 1 else 2.0
			draw_rect(Rect2(origin + Vector2(32 - tw - 2, i * 4), Vector2(2, 4)), shadow)
			draw_rect(Rect2(origin + Vector2(32 - tw, i * 4), Vector2(tw, 4)), grass_col)

func draw_stone_stairs(origin: Vector2, direction: String) -> void:
	draw_rect(Rect2(origin, Vector2(32, 32)), Color("7d838a"))
	if direction == "north" or direction == "south":
		draw_rect(Rect2(origin, Vector2(3, 32)), Color("52575e"))
		draw_rect(Rect2(origin + Vector2(29, 0), Vector2(3, 32)), Color("52575e"))
		for y in range(0, 32, 8):
			draw_rect(Rect2(origin + Vector2(3, y), Vector2(26, 6)), Color("cfd5dc"))
			draw_rect(Rect2(origin + Vector2(3, y + 6), Vector2(26, 2)), Color("595f66"))
	else:
		draw_rect(Rect2(origin, Vector2(32, 3)), Color("52575e"))
		draw_rect(Rect2(origin + Vector2(0, 29), Vector2(32, 3)), Color("52575e"))
		for x in range(0, 32, 8):
			draw_rect(Rect2(origin + Vector2(x, 3), Vector2(6, 26)), Color("cfd5dc"))
			draw_rect(Rect2(origin + Vector2(x + 6, 3), Vector2(2, 26)), Color("595f66"))

func draw_ramp_overlay(cell_x: int, cell_y: int, origin: Vector2, conn: Dictionary) -> void:
	# Mantiene la textura del camino de tierra y dibuja los bordes laterales únicamente
	# en los flancos exteriores de la rampa (respetando la anchura total de 3 tiles).
	var dir := str(conn.direction)
	var c0 := int(conn.col)
	var r0 := int(conn.row)
	var w_t := int(conn.width_tiles)
	var h_t := int(conn.height_tiles)
	var edge_dark := Color(0.36, 0.23, 0.09, 0.55)
	var step_mark := Color(0.55, 0.36, 0.14, 0.30)

	if dir == "north" or dir == "south":
		if cell_x == c0:
			draw_rect(Rect2(origin, Vector2(3, 32)), edge_dark)
		if cell_x == c0 + w_t - 1:
			draw_rect(Rect2(origin + Vector2(29, 0), Vector2(3, 32)), edge_dark)
		# Sutiles marcas de pendiente sobre la arena del camino
		for y in [7, 17, 27]:
			draw_rect(Rect2(origin + Vector2(4, y), Vector2(24, 2)), step_mark)
	else:
		if cell_y == r0:
			draw_rect(Rect2(origin, Vector2(32, 3)), edge_dark)
		if cell_y == r0 + h_t - 1:
			draw_rect(Rect2(origin + Vector2(0, 29), Vector2(32, 3)), edge_dark)
		for x in [7, 17, 27]:
			draw_rect(Rect2(origin + Vector2(x, 4), Vector2(2, 24)), step_mark)

func draw_cliff_edges(cell_x: int, cell_y: int, origin: Vector2, h: int) -> void:
	var h_north := shire.elevation.get_height_at_tile(cell_x, cell_y - 1)
	var h_south := shire.elevation.get_height_at_tile(cell_x, cell_y + 1)
	var h_west := shire.elevation.get_height_at_tile(cell_x - 1, cell_y)
	var h_east := shire.elevation.get_height_at_tile(cell_x + 1, cell_y)
	if h_north > h and shire.elevation.get_connection_at_tile(cell_x, cell_y - 1).is_empty():
		var wall_h := minf(26.0, float(h_north - h) * 14.0)
		draw_rect(Rect2(origin, Vector2(32, 3)), Color("2a591c"))
		draw_rect(Rect2(origin + Vector2(0, 3), Vector2(32, wall_h - 3)), Color("8c693e"))
		for x in range(2, 30, 10):
			draw_rect(Rect2(origin + Vector2(x, 5), Vector2(7, wall_h - 7)), Color("a67f4d"))
		if shire.tile_at(cell_x, cell_y) == ShireMap.Tile.WATER:
			# Espuma de agua y sombra ribereña en la base del acantilado que cae al lago
			draw_rect(Rect2(origin + Vector2(0, wall_h), Vector2(32, 3)), Color("a9def9"))
			draw_rect(Rect2(origin + Vector2(0, wall_h + 3), Vector2(32, 4)), Color(0.05, 0.14, 0.25, 0.40))
		else:
			draw_rect(Rect2(origin + Vector2(0, wall_h), Vector2(32, 5)), Color(0.05, 0.09, 0.04, 0.28))
	if h_south < h and shire.elevation.get_connection_at_tile(cell_x, cell_y + 1).is_empty():
		draw_rect(Rect2(origin + Vector2(0, 27), Vector2(32, 2)), Color("9be060"))
		draw_rect(Rect2(origin + Vector2(0, 29), Vector2(32, 3)), Color("2d5c1e"))
	if h_west < h and shire.elevation.get_connection_at_tile(cell_x - 1, cell_y).is_empty():
		draw_rect(Rect2(origin, Vector2(4, 32)), Color("6b4e2b"))
		draw_rect(Rect2(origin + Vector2(4, 0), Vector2(2, 32)), Color("9be060"))
	if h_east < h and shire.elevation.get_connection_at_tile(cell_x + 1, cell_y).is_empty():
		draw_rect(Rect2(origin + Vector2(28, 0), Vector2(4, 32)), Color("6b4e2b"))
		draw_rect(Rect2(origin + Vector2(26, 0), Vector2(2, 32)), Color("3c6e26"))

func draw_elevation_debug(start_x: int, end_x: int, start_y: int, end_y: int) -> void:
	var colors := [
		Color(0.18, 0.52, 0.87, 0.26),
		Color(0.18, 0.80, 0.44, 0.28),
		Color(0.95, 0.77, 0.06, 0.32),
		Color(0.91, 0.30, 0.24, 0.34),
	]
	var font := ThemeDB.fallback_font
	for cy in range(start_y, end_y + 1):
		for cx in range(start_x, end_x + 1):
			if not shire.has_inner_cell(cx, cy):
				continue
			var o := Vector2(cx * TILE_SIZE, cy * TILE_SIZE)
			var h := shire.elevation.get_height_at_tile(cx, cy)
			draw_rect(Rect2(o, Vector2(32, 32)), colors[clampi(h, 0, 3)])
			draw_string(font, o + Vector2(8, 20), "H%d" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
	for conn in shire.elevation.connections:
		var r: Rect2 = conn.rect
		var c := Color(0, 1, 1, 0.42) if str(conn.type) == "stairs" else (Color(0.6, 0.35, 0.7, 0.45) if str(conn.type) == "bridge" else Color(1, 0.65, 0, 0.45))
		draw_rect(r, c)
		draw_rect(r, Color.WHITE, false, 2.0)
	for box in shire.building_colliders:
		draw_rect(box, Color(1, 0, 1, 0.85), false, 2.0)

func draw_points_of_interest(start_x: int, end_x: int, start_y: int, end_y: int) -> void:
	var from_chunk := Vector2i(floori(float(start_x) / CHUNK_SIZE), floori(float(start_y) / CHUNK_SIZE))
	var to_chunk := Vector2i(floori(float(end_x) / CHUNK_SIZE), floori(float(end_y) / CHUNK_SIZE))
	for y in range(from_chunk.y, to_chunk.y + 1):
		for x in range(from_chunk.x, to_chunk.x + 1):
			var poi := poi_for_chunk(Vector2i(x, y))
			if not poi.is_empty():
				draw_poi(poi)
			var camp := camp_for_chunk(Vector2i(x, y))
			if not camp.is_empty():
				draw_circle(camp.position, 18.0, Color("392315"))
				draw_circle(camp.position, 7.0, Color("f2a449"))
				draw_circle(camp.position, 3.0, Color("fff0a6"))
	var atlas := atlas_from_chunk(chunk_from_world(player.global_position))
	for y in range(atlas.y - 1, atlas.y + 2):
		for x in range(atlas.x - 1, atlas.x + 2):
			var chest := chest_for_atlas(Vector2i(x, y))
			if not chest.opened and chest.position.x >= start_x * TILE_SIZE and chest.position.x <= end_x * TILE_SIZE and chest.position.y >= start_y * TILE_SIZE and chest.position.y <= end_y * TILE_SIZE:
				draw_rect(Rect2(chest.position - Vector2(10, 7), Vector2(20, 14)), Color("8f562b"))
				draw_line(chest.position - Vector2(10, 1), chest.position + Vector2(10, -1), Color("ffd36b"), 2.0)

func draw_poi(poi: Dictionary) -> void:
	var position: Vector2 = poi.position
	if poi.kind == "cave":
		draw_circle(position, 25.0, Color("30332e"))
		draw_circle(position, 16.0, Color("0d1210"))
	else:
		draw_rect(Rect2(position - Vector2(26, 19), Vector2(52, 38)), Color("55504b"))
		draw_circle(position + Vector2(0, -4), 14.0, Color("171918"))
		if poi.kind == "mine_dwarven":
			draw_line(position + Vector2(-17, -17), position + Vector2(17, -17), Color("d6b76d"), 2.0)

