extends SceneTree

func _initialize() -> void:
	for seed_value in [1, 19771029, 98421, 1000001]:
		var regions := LandmarkRegions.new(seed_value)
		var copy := LandmarkRegions.new(seed_value)
		assert(regions.isengard_start == copy.isengard_start)
		assert(regions.mordor_start == copy.mordor_start)
		var isengard_distance := (Vector2(regions.isengard_start) + Vector2(4.5, 4.5)).length()
		var mordor_distance := Vector2(regions.mordor_center()).length()
		assert(isengard_distance >= 32.0 and isengard_distance <= 42.0)
		assert(mordor_distance >= 85.0 and mordor_distance <= 110.0)
		var isengard_count := 0
		for y in range(regions.isengard_start.y - 1, regions.isengard_start.y + 10):
			for x in range(regions.isengard_start.x - 1, regions.isengard_start.x + 10):
				if regions.region_at_chunk(Vector2i(x, y)) == "ISENGARD":
					isengard_count += 1
		assert(isengard_count == 81)
		var mordor_count := 0
		for y in range(regions.mordor_start.y - 1, regions.mordor_start.y + 19):
			for x in range(regions.mordor_start.x - 1, regions.mordor_start.x + 19):
				if regions.region_at_chunk(Vector2i(x, y)).begins_with("MORDOR_"):
					mordor_count += 1
		assert(mordor_count == 324)
		assert(regions.site_at_chunk(regions.isengard_center()) == "ORTHANC")
		assert(regions.site_at_chunk(regions.mordor_center() + Vector2i(-2, -2)) == "ORODRUIN")
		assert(regions.site_at_chunk(regions.mordor_center() + Vector2i(3, 2)) == "BARAD_DUR")
	print("Regiones: posiciones, radios, tamaños y puntos de interés correctos")
	quit()
