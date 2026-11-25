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
var landmarks: LandmarkRegions = LandmarkRegions.new(world_seed)
var player: MiddleEarthPlayer
var shire: ShireMap = ShireMap.new()
var sprite_bank: TerrainSpriteBank = TerrainSpriteBank.new()
var debug_elevation_mode := false
var populated_chunks: Dictionary = {}
var opened_chests: Dictionary = {}
var opened_story_chests: Dictionary = {}
var revealed_atlases: Dictionary = {"0,0": true}

# Paleta base unificada (el mismo tono base #58ad34 para que superficie, bordes y esquinas
# coincidan al 100% sin parches cromáticos entre piezas)
const ELEVATION_GRASS_COLORS := [
	Color("58ad34"),
	Color("58ad34"),
	Color("58ad34"),
	Color("58ad34"),
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
	var landmark_biome := landmarks.region_at_chunk(Vector2i(floori(float(cell_x) / CHUNK_SIZE), floori(float(cell_y) / CHUNK_SIZE)))
	if not landmark_biome.is_empty():
		return landmark_biome
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
		"ISENGARD": return "ISENGARD"
		"MORDOR_UDUN": return "MORDOR · UDÛN"
		"MORDOR_GORGOROTH": return "MORDOR · GORGOROTH"
		"MORDOR_NURN": return "MORDOR · NÚRN"
		"MORDOR_SHADOW": return "MORDOR · TIERRAS DE SOMBRA"
		_: return "ERIADOR SALVAJE"

func darkness_at(world_position: Vector2) -> float:
	match biome_at_world(world_position):
		"OLD_FOREST": return 0.74
		"BARROW_DOWNS": return 0.34
		"ISENGARD": return 0.28
		"MORDOR_NURN": return 0.38
		"MORDOR_GORGOROTH": return 0.54
		"MORDOR_UDUN", "MORDOR_SHADOW": return 0.48
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
	if biome == "ISENGARD":
		# La muralla circular deja cuatro portales atravesables y Orthanc en el centro.
		var tower := Vector2(landmarks.isengard_center() * CHUNK_SIZE + Vector2i(16, 16))
		var distance_chunks := Vector2(cell_x, cell_y).distance_to(tower) / CHUNK_SIZE
		var gate := absf(float(cell_y) - tower.y) < 5.0 or absf(float(cell_x) - tower.x) < 5.0
		return (distance_chunks > 2.35 and distance_chunks < 2.48 and not gate) or distance_chunks < 0.045
	if biome.begins_with("MORDOR_"):
		# Ceniza transitables con escarpes dispersos; nunca sella el territorio.
		return hash01(cell_x, cell_y, 93) < 0.07
	if biome == "SHIRE":
		return false
	if biome == "OLD_FOREST":
		return hash01(cell_x, cell_y, 91) < 0.13
	if biome == "MISTY_FOOTHILLS":
		return hash01(cell_x, cell_y, 92) < 0.10
	return hash01(cell_x, cell_y, 93) < 0.025

func poi_for_chunk(chunk: Vector2i) -> Dictionary:
	var site := landmarks.site_at_chunk(chunk)
	if not site.is_empty():
		return {"kind": site, "position": Vector2((chunk.x * CHUNK_SIZE + 16) * TILE_SIZE, (chunk.y * CHUNK_SIZE + 16) * TILE_SIZE)}
	if not landmarks.region_at_chunk(chunk).is_empty():
		return {}
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
	if not landmarks.region_at_chunk(chunk).is_empty():
		return {}
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
	var count: int = int({"SHIRE": 1, "OLD_FOREST": 3, "BREE_LAND": 2, "BARROW_DOWNS": 3, "ERIADOR": 2, "MISTY_FOOTHILLS": 3, "ISENGARD": 3, "MORDOR_UDUN": 4, "MORDOR_GORGOROTH": 4, "MORDOR_NURN": 3, "MORDOR_SHADOW": 4}.get(biome, 2))
	if biome == "ISENGARD":
		threat = 3
	elif biome.begins_with("MORDOR_"):
		threat = 5
	for index in range(count):
		var roll := hash01(chunk.x, chunk.y, 900 + index)
		var kind := "orc"
		if biome == "OLD_FOREST":
			kind = "spider" if roll < 0.42 else ("orc" if roll < 0.72 else "archer_orc")
		elif biome == "MISTY_FOOTHILLS":
			kind = "uruk" if roll < 0.35 else "orc"
		elif biome == "ISENGARD":
			kind = "uruk" if roll < 0.7 else "archer_orc"
		elif biome.begins_with("MORDOR_"):
			kind = "uruk" if roll < 0.38 else ("archer_orc" if roll < 0.63 else "orc")
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
	var landmark_biome := landmarks.region_at_chunk(Vector2i(floori(float(cell_x) / CHUNK_SIZE), floori(float(cell_y) / CHUNK_SIZE)))
	if not landmark_biome.is_empty():
		draw_landmark_tile(cell_x, cell_y, landmark_biome)
		return
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

func draw_landmark_tile(cell_x: int, cell_y: int, biome: String) -> void:
	var origin := Vector2(cell_x, cell_y) * TILE_SIZE
	var rect := Rect2(origin, Vector2(TILE_SIZE + 1.0, TILE_SIZE + 1.0))
	var noise := hash01(cell_x, cell_y, 2610)
	if biome == "ISENGARD":
		var tower_cell := Vector2(landmarks.isengard_center() * CHUNK_SIZE + Vector2i(16, 16))
		var distance_chunks := Vector2(cell_x, cell_y).distance_to(tower_cell) / CHUNK_SIZE
		var wall := distance_chunks > 2.35 and distance_chunks < 2.48
		var road := absf(float(cell_y) - tower_cell.y) < 3.0 or absf(float(cell_x) - tower_cell.x) < 3.0
		draw_rect(rect, Color("54564a") if road else Color("4f6344"))
		if wall and not road:
			draw_rect(rect, Color("252a2b"))
			draw_rect(Rect2(origin + Vector2(2, 3), Vector2(28, 6)), Color("6d7470"))
		elif noise < 0.22 and not road:
			draw_rect(Rect2(origin + Vector2(9, 11), Vector2(14, 10)), Color("344338"))
		if distance_chunks < 0.06:
			draw_rect(rect, Color("181b22"))
			draw_rect(Rect2(origin + Vector2(8, 3), Vector2(16, 25)), Color("333a45"))
			draw_rect(Rect2(origin + Vector2(13, 5), Vector2(6, 16)), Color("8c9ca6"))
		return
	var ground := Color("4b4239")
	match biome:
		"MORDOR_UDUN": ground = Color("4a3b33")
		"MORDOR_GORGOROTH": ground = Color("3a3637")
		"MORDOR_NURN": ground = Color("625448")
		"MORDOR_SHADOW": ground = Color("292d35")
	draw_rect(rect, ground.lightened((noise - 0.5) * 0.10))
	if noise < 0.15:
		draw_rect(Rect2(origin + Vector2(5, 19), Vector2(15, 5)), ground.darkened(0.24))
	elif noise > 0.93 and biome != "MORDOR_NURN":
		draw_circle(origin + Vector2(17, 17), 4.0, Color("9b4931"))
	var volcano_cell := Vector2((landmarks.mordor_center() + Vector2i(-2, -2)) * CHUNK_SIZE + Vector2i(16, 16))
	var volcano_distance := Vector2(cell_x, cell_y).distance_to(volcano_cell)
	if volcano_distance < 96.0:
		if volcano_distance < 45.0:
			draw_rect(rect, Color("5a332d"))
		if hash01(cell_x, cell_y, 2611) > 0.76:
			draw_rect(Rect2(origin + Vector2(8, 11), Vector2(16, 4)), Color("d45626"))

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
			draw_water_alttp(cell_x, cell_y, origin, rect, grass_col)
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

func draw_water_alttp(cell_x: int, cell_y: int, origin: Vector2, rect: Rect2, grass_col: Color) -> void:
	draw_rect(rect, Color("235789"))
	var shift := int(Time.get_ticks_msec() / 450) % 2 * 4
	draw_rect(Rect2(origin + Vector2((4 + shift) % 28, 7), Vector2(10, 2)), Color("5698d4"))
	draw_rect(Rect2(origin + Vector2((16 - shift + 28) % 28, 17), Vector2(12, 2)), Color("7ab8eb"))
	draw_rect(Rect2(origin + Vector2((8 + shift) % 28, 26), Vector2(9, 2)), Color("5698d4"))

	# Orillas orgánicas redondeadas en pixel art donde el agua toca tierra/césped
	var n_land := shire.tile_at(cell_x, cell_y - 1) != ShireMap.Tile.WATER
	var s_land := shire.tile_at(cell_x, cell_y + 1) != ShireMap.Tile.WATER
	var w_land := shire.tile_at(cell_x - 1, cell_y) != ShireMap.Tile.WATER
	var e_land := shire.tile_at(cell_x + 1, cell_y) != ShireMap.Tile.WATER
	var bank_col := Color("b8965c")
	var foam_col := Color("a9def9")

	if n_land and shire.elevation.get_height_at_tile(cell_x, cell_y - 1) == 0:
		draw_rect(Rect2(origin, Vector2(32, 4)), bank_col)
		draw_rect(Rect2(origin + Vector2(0, 4), Vector2(32, 2)), foam_col)
	if s_land:
		draw_rect(Rect2(origin + Vector2(0, 28), Vector2(32, 4)), bank_col)
		draw_rect(Rect2(origin + Vector2(0, 26), Vector2(32, 2)), foam_col)
	if w_land:
		draw_rect(Rect2(origin, Vector2(4, 32)), bank_col)
		draw_rect(Rect2(origin + Vector2(4, 0), Vector2(2, 32)), foam_col)
	if e_land:
		draw_rect(Rect2(origin + Vector2(28, 0), Vector2(4, 32)), bank_col)
		draw_rect(Rect2(origin + Vector2(26, 0), Vector2(2, 32)), foam_col)

	if n_land and w_land:
		draw_pixel_corner_mask(origin, "NW", grass_col, bank_col)
	if n_land and e_land:
		draw_pixel_corner_mask(origin, "NE", grass_col, bank_col)
	if s_land and w_land:
		draw_pixel_corner_mask(origin, "SW", grass_col, bank_col)
	if s_land and e_land:
		draw_pixel_corner_mask(origin, "SE", grass_col, bank_col)

func draw_pixel_corner_mask(origin: Vector2, corner: String, outer_col: Color, rim_col: Color) -> void:
	# Suaviza esquinas de 90° mediante pasos pixelados de 2px (estética ALTTP 16-bit)
	var steps := [[10, 2], [8, 2], [6, 2], [4, 2], [2, 2]]
	for i in range(steps.size()):
		var w: float = float(steps[i][0])
		var h: float = float(steps[i][1])
		var y_off: float = float(i * 2)
		match corner:
			"NW":
				draw_rect(Rect2(origin + Vector2(0, y_off), Vector2(w, h)), outer_col)
				draw_rect(Rect2(origin + Vector2(w, y_off), Vector2(2, h)), rim_col)
			"NE":
				draw_rect(Rect2(origin + Vector2(32.0 - w, y_off), Vector2(w, h)), outer_col)
				draw_rect(Rect2(origin + Vector2(30.0 - w, y_off), Vector2(2, h)), rim_col)
			"SW":
				draw_rect(Rect2(origin + Vector2(0, 30.0 - y_off), Vector2(w, h)), outer_col)
				draw_rect(Rect2(origin + Vector2(w, 30.0 - y_off), Vector2(2, h)), rim_col)
			"SE":
				draw_rect(Rect2(origin + Vector2(32.0 - w, 30.0 - y_off), Vector2(w, h)), outer_col)
				draw_rect(Rect2(origin + Vector2(30.0 - w, 30.0 - y_off), Vector2(2, h)), rim_col)

func draw_grass_base(origin: Vector2, rect: Rect2, color: Color = Color("58ad34"), seed_val: float = 0.0) -> void:
	# Si el color es el césped base de Hobbiton y existe el sprite artístico, usarlo directamente
	if color == Color("58ad34"):
		var key := "grass_center"
		if seed_val < 0.16:
			key = "grass_sprout"
		elif seed_val > 0.90:
			key = "grass_stones"
		var tex := sprite_bank.get_sprite(key)
		if tex != null:
			draw_texture(tex, origin)
			return
	draw_rect(rect, color)
	var light := color.lightened(0.14)
	for blade in [Vector2(4, 6), Vector2(18, 4), Vector2(26, 12), Vector2(8, 22), Vector2(22, 26)]:
		draw_rect(Rect2(origin + blade, Vector2(2, 1)), light)

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
	# Autotiling orgánico de 8 vecinos para caminos de tierra:
	# bordes irregulares dentados, esquinas exteriores redondeadas y esquinas interiores suaves.
	var grass_like := [ShireMap.Tile.GRASS, ShireMap.Tile.TALL_GRASS, ShireMap.Tile.FLOWERS, ShireMap.Tile.TREE, ShireMap.Tile.FENCE, ShireMap.Tile.ROCK]
	var shadow := Color("295418")
	var n_g := shire.tile_at(cell_x, cell_y - 1) in grass_like
	var s_g := shire.tile_at(cell_x, cell_y + 1) in grass_like
	var w_g := shire.tile_at(cell_x - 1, cell_y) in grass_like
	var e_g := shire.tile_at(cell_x + 1, cell_y) in grass_like
	var nw_g := shire.tile_at(cell_x - 1, cell_y - 1) in grass_like
	var ne_g := shire.tile_at(cell_x + 1, cell_y - 1) in grass_like
	var sw_g := shire.tile_at(cell_x - 1, cell_y + 1) in grass_like
	var se_g := shire.tile_at(cell_x + 1, cell_y + 1) in grass_like
	var phase := absi(cell_x * 3 + cell_y * 5)

	if n_g:
		for i in range(8):
			var th := float(2 + ((i + phase) % 3) * 2)
			draw_rect(Rect2(origin + Vector2(i * 4, 0), Vector2(4, th)), grass_col)
			draw_rect(Rect2(origin + Vector2(i * 4, th), Vector2(4, 2)), shadow)
	if s_g:
		for i in range(8):
			var th := float(2 + ((i + phase + 1) % 3) * 2)
			draw_rect(Rect2(origin + Vector2(i * 4, 32.0 - th - 2.0), Vector2(4, 2)), shadow)
			draw_rect(Rect2(origin + Vector2(i * 4, 32.0 - th), Vector2(4, th)), grass_col)
	if w_g:
		for i in range(8):
			var tw := float(2 + ((i + phase) % 3) * 2)
			draw_rect(Rect2(origin + Vector2(0, i * 4), Vector2(tw, 4)), grass_col)
			draw_rect(Rect2(origin + Vector2(tw, i * 4), Vector2(2, 4)), shadow)
	if e_g:
		for i in range(8):
			var tw := float(2 + ((i + phase + 1) % 3) * 2)
			draw_rect(Rect2(origin + Vector2(32.0 - tw - 2.0, i * 4), Vector2(2, 4)), shadow)
			draw_rect(Rect2(origin + Vector2(32.0 - tw, i * 4), Vector2(tw, 4)), grass_col)

	# Esquinas exteriores redondeadas (cuando 2 bordes adyacentes tocan césped)
	if n_g and w_g:
		draw_pixel_corner_mask(origin, "NW", grass_col, shadow)
	if n_g and e_g:
		draw_pixel_corner_mask(origin, "NE", grass_col, shadow)
	if s_g and w_g:
		draw_pixel_corner_mask(origin, "SW", grass_col, shadow)
	if s_g and e_g:
		draw_pixel_corner_mask(origin, "SE", grass_col, shadow)

	# Esquinas interiores suaves (cuando el camino gira en L y solo la diagonal toca césped)
	if not n_g and not w_g and nw_g:
		draw_rect(Rect2(origin, Vector2(6, 4)), grass_col)
		draw_rect(Rect2(origin + Vector2(0, 4), Vector2(4, 2)), grass_col)
		draw_rect(Rect2(origin + Vector2(6, 0), Vector2(2, 4)), shadow)
		draw_rect(Rect2(origin + Vector2(4, 4), Vector2(2, 2)), shadow)
	if not n_g and not e_g and ne_g:
		draw_rect(Rect2(origin + Vector2(26, 0), Vector2(6, 4)), grass_col)
		draw_rect(Rect2(origin + Vector2(28, 4), Vector2(4, 2)), grass_col)
		draw_rect(Rect2(origin + Vector2(24, 0), Vector2(2, 4)), shadow)
		draw_rect(Rect2(origin + Vector2(26, 4), Vector2(2, 2)), shadow)
	if not s_g and not w_g and sw_g:
		draw_rect(Rect2(origin + Vector2(0, 28), Vector2(6, 4)), grass_col)
		draw_rect(Rect2(origin + Vector2(0, 26), Vector2(4, 2)), grass_col)
		draw_rect(Rect2(origin + Vector2(6, 28), Vector2(2, 4)), shadow)
		draw_rect(Rect2(origin + Vector2(4, 26), Vector2(2, 2)), shadow)
	if not s_g and not e_g and se_g:
		draw_rect(Rect2(origin + Vector2(26, 28), Vector2(6, 4)), grass_col)
		draw_rect(Rect2(origin + Vector2(28, 26), Vector2(4, 2)), grass_col)
		draw_rect(Rect2(origin + Vector2(24, 28), Vector2(2, 4)), shadow)
		draw_rect(Rect2(origin + Vector2(26, 26), Vector2(2, 2)), shadow)

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
	# Renderizado de elevaciones basado 100% en SPRITES ARTÍSTICOS MODULARES (res://assets/terrain/):
	#  - Superficie base inferior visible bajo transparencia de esquinas superiores.
	#  - Bordes rectos (edge_north, edge_south, edge_west, edge_east).
	#  - Esquinas exteriores dedicadas (corner_outer_nw, corner_outer_ne, corner_outer_sw, corner_outer_se).
	#  - Esquinas interiores dedicadas (corner_inner_nw, corner_inner_ne, corner_inner_sw, corner_inner_se).
	#  - Paredes verticales y terminaciones inferiores (wall_center, wall_end_left, wall_end_right, wall_end_both).
	var h_north := shire.elevation.get_height_at_tile(cell_x, cell_y - 1)
	var h_south := shire.elevation.get_height_at_tile(cell_x, cell_y + 1)
	var h_west := shire.elevation.get_height_at_tile(cell_x - 1, cell_y)
	var h_east := shire.elevation.get_height_at_tile(cell_x + 1, cell_y)
	var h_nw := shire.elevation.get_height_at_tile(cell_x - 1, cell_y - 1)
	var h_ne := shire.elevation.get_height_at_tile(cell_x + 1, cell_y - 1)
	var h_sw := shire.elevation.get_height_at_tile(cell_x - 1, cell_y + 1)
	var h_se := shire.elevation.get_height_at_tile(cell_x + 1, cell_y + 1)

	var north_drop := h_north > h and shire.elevation.get_connection_at_tile(cell_x, cell_y - 1).is_empty()
	var south_edge := h_south < h and shire.elevation.get_connection_at_tile(cell_x, cell_y + 1).is_empty()
	var west_edge := h_west < h and shire.elevation.get_connection_at_tile(cell_x - 1, cell_y).is_empty()
	var east_edge := h_east < h and shire.elevation.get_connection_at_tile(cell_x + 1, cell_y).is_empty()
	var north_edge := h_north < h and shire.elevation.get_connection_at_tile(cell_x, cell_y - 1).is_empty()

	# 1. PAREDES VERTICALES Y TERMINACIONES INFERIORES (en el tile del nivel inferior al sur del acantilado)
	if north_drop:
		var is_left_end := h_nw < h_north
		var is_right_end := h_ne < h_north
		var wall_key := "wall_center"
		if is_left_end and is_right_end:
			wall_key = "wall_end_both"
		elif is_left_end:
			wall_key = "wall_end_left"
		elif is_right_end:
			wall_key = "wall_end_right"
		var wall_tex := sprite_bank.get_sprite(wall_key)
		if wall_tex != null:
			draw_texture(wall_tex, origin)
		if shire.tile_at(cell_x, cell_y) == ShireMap.Tile.WATER:
			var foam_l := 4.0 if is_left_end else 0.0
			var foam_w := 32.0 - foam_l - (4.0 if is_right_end else 0.0)
			draw_rect(Rect2(origin + Vector2(foam_l, 22), Vector2(foam_w, 3)), Color("a9def9"))

	# 2. BORDES Y ESQUINAS EXTERIORES DE LA SUPERFICIE ELEVADA (usando sprites exactos, sin parches)
	# Si el tile es camino de tierra (DIRT_PATH), no sobrescribimos el camino con césped
	if shire.tile_at(cell_x, cell_y) == ShireMap.Tile.DIRT_PATH:
		return

	var corner_key := ""
	if north_edge and west_edge:
		corner_key = "corner_outer_nw"
	elif north_edge and east_edge:
		corner_key = "corner_outer_ne"
	elif south_edge and west_edge:
		corner_key = "corner_outer_sw"
	elif south_edge and east_edge:
		corner_key = "corner_outer_se"

	if not corner_key.is_empty():
		# Rellenar el fondo detrás de los píxeles transparentes del vértice con el terreno vecino real
		var bg_col := get_neighbor_surface_color(
			cell_x + (-1 if west_edge else 1),
			cell_y + (-1 if north_edge else 1),
			h_nw if corner_key == "corner_outer_nw" else (h_ne if corner_key == "corner_outer_ne" else (h_sw if corner_key == "corner_outer_sw" else h_se))
		)
		draw_rect(Rect2(origin, Vector2(32, 32)), bg_col)
		var c_tex := sprite_bank.get_sprite(corner_key)
		if c_tex != null:
			draw_texture(c_tex, origin)
		return

	# Bordes rectos (solo cuando no es esquina exterior)
	if south_edge:
		var t_s := sprite_bank.get_sprite("edge_south")
		if t_s != null:
			draw_texture(t_s, origin)
	elif north_edge:
		var t_n := sprite_bank.get_sprite("edge_north")
		if t_n != null:
			draw_texture(t_n, origin)

	if west_edge:
		var t_w := sprite_bank.get_sprite("edge_west")
		if t_w != null:
			draw_texture(t_w, origin)
	elif east_edge:
		var t_e := sprite_bank.get_sprite("edge_east")
		if t_e != null:
			draw_texture(t_e, origin)

	# 3. ESQUINAS INTERIORES (cóncavas) cuando la plataforma gira en L
	if not south_edge and not west_edge and h_sw < h:
		var t_isw := sprite_bank.get_sprite("corner_inner_sw")
		if t_isw != null:
			draw_texture(t_isw, origin)
	elif not south_edge and not east_edge and h_se < h:
		var t_ise := sprite_bank.get_sprite("corner_inner_se")
		if t_ise != null:
			draw_texture(t_ise, origin)
	elif not north_edge and not west_edge and h_nw < h:
		var t_inw := sprite_bank.get_sprite("corner_inner_nw")
		if t_inw != null:
			draw_texture(t_inw, origin)
	elif not north_edge and not east_edge and h_ne < h:
		var t_ine := sprite_bank.get_sprite("corner_inner_ne")
		if t_ine != null:
			draw_texture(t_ine, origin)

func get_neighbor_surface_color(nx: int, ny: int, _nh: int) -> Color:
	var t := shire.tile_at(nx, ny)
	if t == ShireMap.Tile.WATER:
		return Color("235789")
	if t == ShireMap.Tile.DIRT_PATH:
		return Color("e8b55a")
	if t == ShireMap.Tile.DARK_FOREST:
		return Color("2d5e29")
	return Color("58ad34")

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
	if poi.kind == "ORTHANC":
		draw_circle(position, 28.0, Color("171b21"))
		draw_rect(Rect2(position - Vector2(12, 25), Vector2(24, 46)), Color("202631"))
		draw_rect(Rect2(position - Vector2(4, 22), Vector2(8, 36)), Color("84929b"))
	elif poi.kind == "ORODRUIN":
		draw_circle(position, 40.0, Color("302e30"))
		draw_circle(position, 21.0, Color("6a3025"))
		draw_circle(position, 10.0, Color("dc6127"))
	elif poi.kind == "BARAD_DUR":
		draw_rect(Rect2(position - Vector2(21, 24), Vector2(42, 48)), Color("15171b"))
		draw_rect(Rect2(position - Vector2(8, 36), Vector2(16, 50)), Color("30313b"))
		draw_circle(position + Vector2(0, -28), 5.0, Color("f27b2b"))
	elif poi.kind == "cave":
		draw_circle(position, 25.0, Color("30332e"))
		draw_circle(position, 16.0, Color("0d1210"))
	else:
		draw_rect(Rect2(position - Vector2(26, 19), Vector2(52, 38)), Color("55504b"))
		draw_circle(position + Vector2(0, -4), 14.0, Color("171918"))
		if poi.kind == "mine_dwarven":
			draw_line(position + Vector2(-17, -17), position + Vector2(17, -17), Color("d6b76d"), 2.0)
