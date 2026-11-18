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
var populated_chunks: Dictionary = {}
var opened_chests: Dictionary = {}
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

