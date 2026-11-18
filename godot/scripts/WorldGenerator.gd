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
var populated_chunks: Dictionary = {}
var opened_chests: Dictionary = {}
var opened_story_chests: Dictionary = {}
var revealed_atlases: Dictionary = {"0,0": true}

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

func is_blocked(world_position: Vector2) -> bool:
	var cell_x := floori(world_position.x / TILE_SIZE)
	var cell_y := floori(world_position.y / TILE_SIZE)
	if shire.has_inner_cell(cell_x, cell_y):
		return shire.tile_is_solid(shire.tile_at(cell_x, cell_y))
	var biome := biome_at_cell(cell_x, cell_y)
	if biome == "SHIRE":
		return false
	if biome == "OLD_FOREST":
		return hash01(cell_x, cell_y, 91) < 0.13
	if biome == "MISTY_FOOTHILLS":
		return hash01(cell_x, cell_y, 92) < 0.10
	return hash01(cell_x, cell_y, 93) < 0.025

func poi_for_chunk(chunk: Vector2i) -> Dictionary:
	if chunk.x >= 0 and chunk.x <= 1 and chunk.y >= 0 and chunk.y <= 1:
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
	if chunk.x >= 0 and chunk.x <= 1 and chunk.y >= 0 and chunk.y <= 1:
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
	# Versión nativa de los tiles pixel-art del prototipo. Se compone con formas
	# de 2 a 4 píxeles y no depende de una textura externa.
	var origin := Vector2(cell_x * TILE_SIZE, cell_y * TILE_SIZE)
	var rect := Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE))
	var seed_detail := hash01(cell_x, cell_y, 601)
	match tile:
		ShireMap.Tile.GRASS:
			draw_grass_base(origin, rect)
		ShireMap.Tile.TALL_GRASS:
			draw_grass_base(origin, rect)
			for y in range(4, 28, 8):
				for x in range(4, 28, 8):
					draw_rect(Rect2(origin + Vector2(x, y + 2), Vector2(6, 4)), Color("295b1a"))
					draw_rect(Rect2(origin + Vector2(x + 1, y), Vector2(2, 5)), Color("63b546"))
					draw_rect(Rect2(origin + Vector2(x + 4, y + 1), Vector2(2, 4)), Color("79c95b"))
		ShireMap.Tile.FLOWERS:
			draw_grass_base(origin, rect)
			for flower in [[Vector2(6, 7), Color("ffd84d")], [Vector2(20, 10), Color("ff7088")], [Vector2(11, 22), Color.WHITE], [Vector2(24, 24), Color("ffd84d")]]:
				draw_rect(Rect2(origin + flower[0], Vector2(4, 4)), flower[1])
				draw_rect(Rect2(origin + flower[0] + Vector2(1, 1), Vector2(2, 2)), Color("d97b16"))
		ShireMap.Tile.DIRT_PATH:
			draw_rect(rect, Color("b98f58"))
			for pebble in [Vector2(3, 5), Vector2(14, 8), Vector2(25, 4), Vector2(8, 19), Vector2(19, 23), Vector2(27, 17), Vector2(5, 27), Vector2(15, 15)]:
				draw_rect(Rect2(origin + pebble, Vector2(3, 2)), Color("9d7440") if seed_detail < 0.5 else Color("cfb576"))
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
			draw_grass_base(origin, rect)
			draw_rect(Rect2(origin + Vector2(4, 24), Vector2(24, 6)), Color(0, 0, 0, 0.28))
			draw_rect(Rect2(origin + Vector2(11, 18), Vector2(10, 11)), Color("5c3a1e"))
			draw_rect(Rect2(origin + Vector2(3, 4), Vector2(26, 18)), Color("1e4d1b"))
			draw_rect(Rect2(origin + Vector2(5, 2), Vector2(22, 16)), Color("2e6f28"))
			draw_rect(Rect2(origin + Vector2(7, 4), Vector2(18, 11)), Color("44913b"))
			draw_rect(Rect2(origin + Vector2(9, 5), Vector2(10, 6)), Color("62b356"))
		ShireMap.Tile.FENCE:
			draw_grass_base(origin, rect)
			draw_rect(Rect2(origin + Vector2(4, 8), Vector2(6, 20)), Color("5e3c1b"))
			draw_rect(Rect2(origin + Vector2(22, 8), Vector2(6, 20)), Color("5e3c1b"))
			draw_rect(Rect2(origin + Vector2(0, 12), Vector2(32, 4)), Color("7a4e26"))
			draw_rect(Rect2(origin + Vector2(0, 20), Vector2(32, 4)), Color("7a4e26"))
		ShireMap.Tile.ROCK:
			draw_grass_base(origin, rect)
			draw_rect(Rect2(origin + Vector2(4, 8), Vector2(24, 18)), Color("4a4e54"))
			draw_rect(Rect2(origin + Vector2(6, 6), Vector2(20, 16)), Color("6c727a"))
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(14, 10)), Color("8d949e"))
		ShireMap.Tile.HOBBIT_WALL:
			draw_rect(rect, Color("d9c29c"))
			draw_rect(Rect2(origin, Vector2(32, 12)), Color("3d782b"))
			draw_rect(Rect2(origin + Vector2(0, 10), Vector2(32, 4)), Color("5ba843"))
			draw_rect(Rect2(origin + Vector2(0, 14), Vector2(32, 3)), Color("5c3a1e"))
			draw_rect(Rect2(origin + Vector2(10, 17), Vector2(12, 11)), Color("4a2e16"))
			draw_rect(Rect2(origin + Vector2(12, 19), Vector2(8, 7)), Color("f5d469"))
		ShireMap.Tile.HOBBIT_DOOR:
			draw_rect(rect, Color("d9c29c"))
			draw_rect(Rect2(origin, Vector2(32, 10)), Color("3d782b"))
			draw_rect(Rect2(origin + Vector2(5, 8), Vector2(22, 24)), Color("4e2f16"))
			draw_rect(Rect2(origin + Vector2(7, 10), Vector2(18, 22)), Color("2d7a3e"))
			draw_rect(Rect2(origin + Vector2(9, 12), Vector2(14, 18)), Color("3a944e"))
			draw_circle(origin + Vector2(16, 20), 2.0, Color("ffd700"))
		ShireMap.Tile.CROP_FIELD:
			draw_rect(rect, Color("5c3d22"))
			for y in range(3, 30, 8):
				draw_rect(Rect2(origin + Vector2(2, y), Vector2(28, 4)), Color("472d17"))
			for plant in [Vector2(6, 6), Vector2(20, 18), Vector2(18, 6), Vector2(7, 19)]:
				draw_circle(origin + plant + Vector2(3, 3), 3.5, Color("e67e22") if int(plant.x) % 2 == 0 else Color("58b347"))
		ShireMap.Tile.DARK_FOREST:
			draw_grass_base(origin, rect, Color("2b5228"))
			if seed_detail < 0.48:
				draw_circle(origin + Vector2(16, 10), 13.0, Color("173a21"))
				draw_circle(origin + Vector2(9, 8), 8.0, Color("1f4a28"))
				draw_rect(Rect2(origin + Vector2(13, 17), Vector2(6, 14)), Color("3d2c1d"))
		ShireMap.Tile.MILL_BASE:
			draw_rect(rect, Color("6e655c"))
			for y in range(0, 32, 8):
				for x in range(0, 32, 16):
					draw_rect(Rect2(origin + Vector2(x + 1, y + 1), Vector2(14, 6)), Color("8c8275"))
		ShireMap.Tile.CAMPFIRE_ASH:
			draw_rect(rect, Color("3d332a"))
			draw_rect(Rect2(origin + Vector2(4, 4), Vector2(24, 24)), Color("2c241d"))
			draw_circle(origin + Vector2(16, 17), 8.0, Color("595959"))
			draw_circle(origin + Vector2(16, 17), 5.0, Color("d35400"))
			draw_circle(origin + Vector2(16, 17), 2.5, Color("f1c40f"))

func draw_grass_base(origin: Vector2, rect: Rect2, color: Color = Color("478932")) -> void:
	draw_rect(rect, color)
	for blade in [Vector2(4, 6), Vector2(18, 4), Vector2(26, 12), Vector2(8, 22), Vector2(22, 26), Vector2(14, 15)]:
		draw_rect(Rect2(origin + blade, Vector2(2, 2)), Color("529b3b"))
		draw_rect(Rect2(origin + blade + Vector2(2, 2), Vector2(2, 2)), Color("3a7527"))

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

