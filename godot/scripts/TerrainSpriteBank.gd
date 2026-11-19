class_name TerrainSpriteBank
extends RefCounted

## Banco de Sprites y TileSet modular de elevaciones para Hobbiton (Godot 4).
## Carga los sprites pixel art .png desde res://assets/terrain/ y construye un TileSet
## nativo (TileSetAtlasSource) listo para usarse tanto en TileMapLayer como en renderizado
## directo mediante draw_texture(), garantizando:
##  - 100% continuidad de color en césped, bordes y esquinas (sin cambios dinámicos de tono).
##  - Piezas dedicadas para esquinas superiores (NW/NE), esquinas inferiores (SW/SE),
##    esquinas interiores y terminaciones de pared izquierda/derecha sin huecos transparentes.

var textures: Dictionary = {}
var tileset: TileSet

const SPRITE_PATHS := {
	"grass_center": "res://assets/terrain/grass/grass_center.png",
	"grass_sprout": "res://assets/terrain/grass/grass_sprout.png",
	"grass_stones": "res://assets/terrain/grass/grass_stones.png",
	"grass_flowers": "res://assets/terrain/grass/grass_flowers.png",
	"edge_north": "res://assets/terrain/grass_edges/edge_north.png",
	"edge_south": "res://assets/terrain/grass_edges/edge_south.png",
	"edge_west": "res://assets/terrain/grass_edges/edge_west.png",
	"edge_east": "res://assets/terrain/grass_edges/edge_east.png",
	"corner_outer_nw": "res://assets/terrain/grass_corners/corner_outer_nw.png",
	"corner_outer_ne": "res://assets/terrain/grass_corners/corner_outer_ne.png",
	"corner_outer_sw": "res://assets/terrain/grass_corners/corner_outer_sw.png",
	"corner_outer_se": "res://assets/terrain/grass_corners/corner_outer_se.png",
	"corner_inner_nw": "res://assets/terrain/grass_corners/corner_inner_nw.png",
	"corner_inner_ne": "res://assets/terrain/grass_corners/corner_inner_ne.png",
	"corner_inner_sw": "res://assets/terrain/grass_corners/corner_inner_sw.png",
	"corner_inner_se": "res://assets/terrain/grass_corners/corner_inner_se.png",
	"wall_center": "res://assets/terrain/elevation_walls/wall_center.png",
	"wall_end_left": "res://assets/terrain/elevation_terminations/wall_end_left.png",
	"wall_end_right": "res://assets/terrain/elevation_terminations/wall_end_right.png",
	"wall_end_both": "res://assets/terrain/elevation_terminations/wall_end_both.png",
	"ramp_vertical": "res://assets/terrain/ramps/ramp_vertical.png",
	"atlas": "res://assets/tilesets/hobbiton_terrain/hobbiton_elevation_atlas.png",
}

func _init() -> void:
	load_all_sprites()
	build_native_tileset()

func load_all_sprites() -> void:
	for key: String in SPRITE_PATHS.keys():
		var path: String = str(SPRITE_PATHS[key])
		var tex: Texture2D = load(path) as Texture2D
		if tex == null and FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null:
				tex = ImageTexture.create_from_image(img)
		if tex != null:
			textures[key] = tex

func get_sprite(key: String) -> Texture2D:
	return textures.get(key, null) as Texture2D

func build_native_tileset() -> void:
	# Construye un TileSet nativo de Godot 4 (32x32) con el atlas combinado para compatibilidad TileMapLayer
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var atlas_tex := get_sprite("atlas")
	if atlas_tex == null:
		return
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(32, 32)
	for row in range(3):
		for col in range(8):
			if row * 8 + col < 21:
				source.create_tile(Vector2i(col, row))
	tileset.add_source(source, 0)
