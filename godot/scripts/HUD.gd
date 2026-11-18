class_name MiddleEarthHUD
extends Control

var game: Node
var map_expanded := false
var shop_open := false
var notification := ""
var notification_time := 0.0

func setup(game_ref: Node) -> void:
	game = game_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func notify(message: String) -> void:
	notification = message
	notification_time = 4.0

func _process(delta: float) -> void:
	notification_time = maxf(0.0, notification_time - delta)
	queue_redraw()

func _draw() -> void:
	if game == null or game.player == null:
		return
	var player: MiddleEarthPlayer = game.player
	var font := ThemeDB.fallback_font
	# Banda superior y estadísticas.
	draw_rect(Rect2(0, 0, 960, 54), Color(0.04, 0.055, 0.045, 0.90))
	draw_line(Vector2(0, 53), Vector2(960, 53), Color("b89446"), 2.0)
	draw_string(font, Vector2(18, 16), "VIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8d8a8"))
	for heart in range(player.max_hp):
		draw_heart(Vector2(20 + heart * 21, 26), heart < player.hp)
	var weapon: Dictionary = player.weapon_data()
	draw_panel(Rect2(205, 7, 152, 40), "[ESPACIO] ARMA", "%s (%d)" % [weapon.name, player.weapon_damage()])
	draw_string(font, Vector2(376, 22), "MONEDAS %d" % player.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd75c"))
	draw_string(font, Vector2(376, 42), "FLECHAS %d" % player.arrows, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a8e090"))
	draw_string(font, Vector2(505, 22), "NV. %d" % player.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8ad8ff"))
	draw_string(font, Vector2(505, 42), "XP %d/%d" % [player.xp, player.next_level_xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cfcfcf"))
	draw_string(font, Vector2(620, 22), "DEF %d" % player.armor_defense(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d7f3e1"))
	draw_armor_gauge(Vector2(699, 27), player.armor_progress(), player.armor_defense() > 0)
	var region: String = str(game.world.biome_display_name(game.world.biome_at_world(player.global_position)))
	draw_string(font, Vector2(944, 20), "REGION: %s" % region, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color("ffd866"))
	draw_quest_panel(font)
	draw_minimap(font)
	if notification_time > 0.0:
		draw_notification(font)
	if shop_open:
		draw_shop(font)
	if map_expanded:
		draw_full_map(font)

func draw_heart(at: Vector2, filled: bool) -> void:
	var color := Color("ef233c") if filled else Color("4a252a")
	draw_circle(at + Vector2(4, 1), 4.0, color)
	draw_circle(at + Vector2(10, 1), 4.0, color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, 3), at + Vector2(14, 3), at + Vector2(7, 13)]), color)

func draw_panel(rect: Rect2, title: String, value: String) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(rect, Color("18140e"))
	draw_rect(rect, Color("8c6d3b"), false, 2.0)
	draw_string(font, rect.position + Vector2(6, 13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("b8a47e"))
	draw_string(font, rect.position + Vector2(6, 31), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 11, Color("fff3d1"))

func draw_armor_gauge(center: Vector2, progress: float, active: bool) -> void:
	draw_arc(center, 11.0, 0.0, TAU, 24, Color("293840"), 3.0)
	if active and progress > 0.0:
		draw_arc(center, 11.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color("8ce9ff") if progress >= 0.99 else Color("6e9fb1"), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-8, 3), "DEF", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("d7f3e1"))

func draw_quest_panel(font: Font) -> void:
	var rect := Rect2(704, 64, 242, 138)
	draw_rect(rect, Color(0.04, 0.06, 0.05, 0.88))
	draw_rect(rect, Color("8c6d3b"), false, 2.0)
	draw_string(font, rect.position + Vector2(10, 18), "MISIONES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd866"))
	draw_string(font, rect.position + Vector2(10, 38), "PRINCIPAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe394"))
	draw_string(font, rect.position + Vector2(10, 55), str(game.primary_quest), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 10, Color("f2ebd9"))
	draw_string(font, rect.position + Vector2(10, 86), "SECUNDARIAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9ad972"))
	var line := 104.0
	for quest in game.secondary_quests.slice(0, 2):
		var prefix := "[x] " if quest.completed else "[ ] "
		draw_string(font, Vector2(rect.position.x + 10, rect.position.y + line), prefix + str(quest.title), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 10, Color("7dff8b") if quest.completed else Color("c8d9b8"))
		line += 17.0

func draw_minimap(font: Font) -> void:
	var rect := Rect2(802, 525, 144, 101)
	draw_map_grid(rect, false)
	draw_string(font, rect.position + Vector2(7, 14), "[M] MAPA ZONAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("ead9a9"))

func draw_full_map(font: Font) -> void:
	var rect := Rect2(180, 92, 600, 456)
	draw_rect(Rect2(156, 68, 648, 504), Color(0.015, 0.02, 0.018, 0.94))
	draw_rect(Rect2(156, 68, 648, 504), Color("c19b54"), false, 2.0)
	draw_string(font, Vector2(180, 88), "CARTA REGIONAL — [M] CERRAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe49a"))
	draw_map_grid(rect, true)

func draw_map_grid(rect: Rect2, expanded: bool) -> void:
	var player: MiddleEarthPlayer = game.player
	var chunk: Vector2i = game.world.chunk_from_world(player.global_position)
	var atlas: Vector2i = game.world.atlas_from_chunk(chunk)
	var known: bool = game.world.revealed_atlases.has(game.world.atlas_key(atlas))
	var cell_size := rect.size / float(MiddleEarthWorld.ATLAS_CHUNKS)
	for y in range(MiddleEarthWorld.ATLAS_CHUNKS):
		for x in range(MiddleEarthWorld.ATLAS_CHUNKS):
			var cell_rect := Rect2(rect.position + Vector2(x, y) * cell_size, cell_size)
			var color := Color("142019") if not known else map_color_for_chunk(Vector2i(atlas.x * MiddleEarthWorld.ATLAS_CHUNKS + x, atlas.y * MiddleEarthWorld.ATLAS_CHUNKS + y))
			draw_rect(cell_rect, color)
			draw_rect(cell_rect, Color(0.0, 0.0, 0.0, 0.28), false, 1.0)
	if known:
		var local_chunk := Vector2i(posmod(chunk.x, MiddleEarthWorld.ATLAS_CHUNKS), posmod(chunk.y, MiddleEarthWorld.ATLAS_CHUNKS))
		var dot := rect.position + (Vector2(local_chunk) + Vector2(0.5, 0.5)) * cell_size
		draw_circle(dot, 3.0 if expanded else 2.0, Color("fff2a8"))
	else:
		# Fuera de una carta conocida, el explorador es la única luz en la niebla.
		draw_circle(rect.get_center(), 5.0 if expanded else 3.0, Color(1.0, 0.92, 0.55, 0.75))
		if expanded:
			draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-125, 42), "Territorio sin cartografiar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("bdb59f"))

func map_color_for_chunk(chunk: Vector2i) -> Color:
	var biome: String = str(game.world.biome_at_cell(chunk.x * MiddleEarthWorld.CHUNK_SIZE + 16, chunk.y * MiddleEarthWorld.CHUNK_SIZE + 16))
	match biome:
		"OLD_FOREST": return Color("28513a")
		"BARROW_DOWNS": return Color("6e7145")
		"MISTY_FOOTHILLS": return Color("6a6a6d")
		"ERIADOR": return Color("72815d")
		"BREE_LAND": return Color("76945d")
		_: return Color("639b51")

func draw_notification(font: Font) -> void:
	var width := minf(620.0, 30.0 + notification.length() * 7.2)
	var rect := Rect2(480.0 - width * 0.5, 560, width, 33)
	draw_rect(rect, Color(0.04, 0.05, 0.04, 0.92))
	draw_rect(rect, Color("c29e55"), false, 1.0)
	draw_string(font, rect.position + Vector2(12, 21), notification, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 12, Color("fff1ce"))

func draw_shop(font: Font) -> void:
	var rect := Rect2(200, 160, 560, 300)
	draw_rect(rect, Color(0.05, 0.035, 0.02, 0.96))
	draw_rect(rect, Color("d0a84e"), false, 3.0)
	draw_string(font, rect.position + Vector2(18, 28), "ARSENAL DE LA COMARCA — [E] CERRAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe294"))
	var offers: Array = game.shop_offers()
	var y := 64.0
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var requirement := "Nv. %d" % int(offer.data.required_level)
		draw_string(font, rect.position + Vector2(22, y), "[%d] %s — %d monedas (%s)" % [index + 1, offer.data.name, int(offer.data.price), requirement], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e9e2ce"))
		y += 43.0
	draw_string(font, rect.position + Vector2(22, 273), "Tu dinero: %d · Comprar equipa el objeto si cumples el nivel." % game.player.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9dbc0"))

