class_name LandmarkRegions
extends RefCounted

## Los límites se alinean con las cartas de 9 x 9 chunks. Las posiciones son
## funciones puras de la semilla: cargar, guardar o volver no desplaza regiones.
const ATLAS := 9
const ISENGARD_SIZE := 9
const MORDOR_SIZE := 18

var isengard_start: Vector2i
var mordor_start: Vector2i

func _init(seed_value: int) -> void:
	# Ángulo sudeste: x crece hacia el este e y hacia el sur.
	var candidates_isengard: Array[Vector2i] = []
	var candidates_mordor: Array[Vector2i] = []
	for atlas_y in range(0, 14):
		for atlas_x in range(0, 14):
			var small_center := Vector2(atlas_x * ATLAS + 4.5, atlas_y * ATLAS + 4.5)
			var large_center := Vector2((atlas_x + 1) * ATLAS, (atlas_y + 1) * ATLAS)
			if small_center.length() >= 32.0 and small_center.length() <= 42.0 and in_southeast_sector(small_center):
				candidates_isengard.append(Vector2i(atlas_x * ATLAS, atlas_y * ATLAS))
			if large_center.length() >= 85.0 and large_center.length() <= 110.0 and in_southeast_sector(large_center):
				candidates_mordor.append(Vector2i(atlas_x * ATLAS, atlas_y * ATLAS))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	isengard_start = candidates_isengard[rng.randi_range(0, candidates_isengard.size() - 1)]
	mordor_start = candidates_mordor[rng.randi_range(0, candidates_mordor.size() - 1)]

func in_southeast_sector(center: Vector2) -> bool:
	var angle := rad_to_deg(atan2(center.y, center.x))
	return angle >= 25.0 and angle <= 55.0

func isengard_center() -> Vector2i:
	return isengard_start + Vector2i(4, 4)

func mordor_center() -> Vector2i:
	return mordor_start + Vector2i(9, 9)

func region_at_chunk(chunk: Vector2i) -> String:
	if chunk.x >= isengard_start.x and chunk.x < isengard_start.x + ISENGARD_SIZE and chunk.y >= isengard_start.y and chunk.y < isengard_start.y + ISENGARD_SIZE:
		return "ISENGARD"
	if chunk.x >= mordor_start.x and chunk.x < mordor_start.x + MORDOR_SIZE and chunk.y >= mordor_start.y and chunk.y < mordor_start.y + MORDOR_SIZE:
		var local := chunk - mordor_start
		if local.x < 9 and local.y < 9:
			return "MORDOR_UDUN"
		if local.x >= 9 and local.y < 9:
			return "MORDOR_GORGOROTH"
		if local.x < 9:
			return "MORDOR_NURN"
		return "MORDOR_SHADOW"
	return ""

func site_at_chunk(chunk: Vector2i) -> String:
	if chunk == isengard_center():
		return "ORTHANC"
	if chunk == mordor_center() + Vector2i(-2, -2):
		return "ORODRUIN"
	if chunk == mordor_center() + Vector2i(3, 2):
		return "BARAD_DUR"
	return ""
