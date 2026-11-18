class_name SaveGame
extends RefCounted

const PATH := "user://sombras_tierra_media.save"

static func save_snapshot(player: MiddleEarthPlayer, world: MiddleEarthWorld) -> bool:
	var payload := {
		"version": 1,
		"position": {"x": player.global_position.x, "y": player.global_position.y},
		"hp": player.hp,
		"coins": player.coins,
		"xp": player.xp,
		"level": player.level,
		"equipped_weapon": player.equipped_weapon_id,
		"equipped_armor": player.equipped_armor_id,
		"owned_weapons": player.owned_weapons,
		"owned_armors": player.owned_armors,
		"revealed_atlases": world.revealed_atlases,
		"opened_chests": world.opened_chests,
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true

static func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}

