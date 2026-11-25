class_name SaveGame
extends RefCounted

const PATH := "user://sombras_tierra_media.save"

static func save_snapshot(player: MiddleEarthPlayer, world: MiddleEarthWorld, save_position: Vector2, saruman_defeated: bool) -> bool:
	var payload := {
		"version": 1,
		"position": {"x": save_position.x, "y": save_position.y},
		"saruman_defeated": saruman_defeated,
		"hp": player.hp,
		"coins": player.coins,
		"xp": player.xp,
		"level": player.level,
		"equipped_weapon": player.equipped_weapon_id,
		"equipped_armor": player.equipped_armor_id,
		"owned_weapons": player.owned_weapons,
		"owned_armors": player.owned_armors,
		"active_item": player.active_item,
		"miruvor_charges": player.miruvor_charges,
		"bow_unlocked": player.bow_unlocked,
		"revealed_atlases": world.revealed_atlases,
		"opened_chests": world.opened_chests,
		"opened_story_chests": world.opened_story_chests,
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

