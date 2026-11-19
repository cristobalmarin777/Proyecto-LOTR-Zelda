class_name ElevationSystem
extends RefCounted

## Sistema real de elevaciones discretas (Niveles 0, 1, 2, 3), rampas de tierra,
## escaleras de piedra, puentes y colisiones verticales entre plataformas para Godot 4.

const ELEVATION_PIXEL_STEP := 14.0

var cols: int
var rows: int
var tile_size: float
var height_grid: Array = []
var connections: Array = []
var connection_map: Dictionary = {}

func _init(p_cols: int, p_rows: int, p_tile_size: float = 32.0) -> void:
	cols = p_cols
	rows = p_rows
	tile_size = p_tile_size
	for _r in range(rows):
		var line: Array = []
		line.resize(cols)
		line.fill(0)
		height_grid.append(line)

func set_height_rect(r1: int, c1: int, r2: int, c2: int, h: int) -> void:
	var clamped := clampi(h, 0, 3)
	for r in range(maxi(0, r1), mini(rows - 1, r2) + 1):
		for c in range(maxi(0, c1), mini(cols - 1, c2) + 1):
			height_grid[r][c] = clamped

func add_connection(conn: Dictionary) -> Dictionary:
	var col := int(conn.get("col", 0))
	var row := int(conn.get("row", 0))
	var w_tiles := int(conn.get("width_tiles", 2))
	var h_tiles := int(conn.get("height_tiles", 2))
	var record := {
		"id": str(conn.get("id", "conn_%d" % connections.size())),
		"type": str(conn.get("type", "ramp")),
		"col": col,
		"row": row,
		"width_tiles": w_tiles,
		"height_tiles": h_tiles,
		"start_height": int(conn.get("start_height", 0)),
		"end_height": int(conn.get("end_height", 1)),
		"direction": str(conn.get("direction", "north")),
		"rect": Rect2(col * tile_size, row * tile_size, w_tiles * tile_size, h_tiles * tile_size),
	}
	connections.append(record)
	for r in range(row, row + h_tiles):
		for c in range(col, col + w_tiles):
			if r >= 0 and r < rows and c >= 0 and c < cols:
				connection_map[Vector2i(c, r)] = record
	return record

func get_height_at_tile(col: int, row: int) -> int:
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return 0
	return int(height_grid[row][col])

func get_height_at_pixel(pos: Vector2) -> int:
	return get_height_at_tile(floori(pos.x / tile_size), floori(pos.y / tile_size))

func get_connection_at_tile(col: int, row: int) -> Dictionary:
	return connection_map.get(Vector2i(col, row), {})

func get_connection_at_pixel(pos: Vector2) -> Dictionary:
	return get_connection_at_tile(floori(pos.x / tile_size), floori(pos.y / tile_size))

func get_interpolated_elevation(pos: Vector2) -> float:
	var conn := get_connection_at_pixel(pos)
	if conn.is_empty():
		return float(get_height_at_pixel(pos))
	if str(conn.type) == "bridge":
		return float(conn.start_height)
	var rect: Rect2 = conn.rect
	var t := 0.0
	match str(conn.direction):
		"north":
			t = 1.0 - (pos.y - rect.position.y) / rect.size.y
		"south":
			t = (pos.y - rect.position.y) / rect.size.y
		"west":
			t = 1.0 - (pos.x - rect.position.x) / rect.size.x
		"east":
			t = (pos.x - rect.position.x) / rect.size.x
	t = clampf(t, 0.0, 1.0)
	return lerpf(float(conn.start_height), float(conn.end_height), t)

func is_elevation_blocked(pos: Vector2, half_w: float, half_h: float, current_height: float) -> bool:
	var center_conn := get_connection_at_pixel(pos)
	var corners := [
		pos + Vector2(-half_w, -half_h),
		pos + Vector2(half_w, -half_h),
		pos + Vector2(-half_w, half_h),
		pos + Vector2(half_w, half_h),
	]
	for corner in corners:
		var col := floori(corner.x / tile_size)
		var row := floori(corner.y / tile_size)
		var tile_h := get_height_at_tile(col, row)
		var tile_conn := get_connection_at_tile(col, row)
		if not tile_conn.is_empty():
			var min_h := float(mini(int(tile_conn.start_height), int(tile_conn.end_height)))
			var max_h := float(maxi(int(tile_conn.start_height), int(tile_conn.end_height)))
			if current_height < min_h - 0.35 or current_height > max_h + 0.35:
				return true
			continue
		if not center_conn.is_empty():
			var min_c := mini(int(center_conn.start_height), int(center_conn.end_height))
			var max_c := maxi(int(center_conn.start_height), int(center_conn.end_height))
			if tile_h >= min_c and tile_h <= max_c:
				continue
			return true
		if abs(tile_h - roundi(current_height)) > 0:
			return true
	return false
