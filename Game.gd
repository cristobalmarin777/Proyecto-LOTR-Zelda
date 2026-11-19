extends Node2D

const EnemyScript := preload("res://scripts/Enemy.gd")
const EnemyArrowScript := preload("res://scripts/EnemyArrow.gd")
const PlayerArrowScript := preload("res://scripts/PlayerArrow.gd")
const FriendlyScript := preload("res://scripts/FriendlyNPC.gd")
const ChestScript := preload("res://scripts/Chest.gd")
const SignScript := preload("res://scripts/Signpost.gd")
const DungeonScript := preload("res://scripts/DungeonMap.gd")
const PlayerScript := preload("res://scripts/Player.gd")
const WorldScript := preload("res://scripts/WorldGenerator.gd")
const OverlayScript := preload("res://scripts/DarknessOverlay.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const BuildingScript := preload("res://scripts/HobbitonBuilding.gd")

var world: MiddleEarthWorld
var active_world: MiddleEarthWorld
var y_sort_layer: Node2D
var player: MiddleEarthPlayer
var darkness: DarknessOverlay
var hud: MiddleEarthHUD
var primary_quest := "Habla con Gandalf en Bolsón Cerrado."
var secondary_quests: Array = [
	{"title": "Cartógrafo: encuentra una Carta Regional", "completed": false},
	{"title": "Bajo la piedra: explora una cueva o mina", "completed": false},
]
var dialog_title := ""
var dialog_pages: Array = []
var dialog_index := 0
var dialog_active := false
var loot_chest: TreasureChest
var interaction_hint := ""
var uruk_defeated := false
var dungeon: MiddleEarthDungeon
var in_dungeon := false
var overworld_return := Vector2.ZERO
var dungeon_nodes: Array = []
var hidden_overworld_nodes: Array = []

func _ready() -> void:
	world = WorldScript.new()
	world.z_index = 0
	add_child(world)
	active_world = world
	y_sort_layer = Node2D.new()
	y_sort_layer.z_index = 3
	y_sort_layer.y_sort_enabled = true
	add_child(y_sort_layer)
	player = PlayerScript.new()
	player.global_position = world.shire.spawn_position
	y_sort_layer.add_child(player)
	player.setup(active_world)
	active_world.bind_player(player)
	world.enemy_requested.connect(spawn_enemy)
	world.elf_requested.connect(spawn_elf)
	player.attack_started.connect(resolve_player_attack)
	player.defeated.connect(respawn_player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	darkness = OverlayScript.new()
	darkness.z_index = 5
	add_child(darkness)
	darkness.setup(player, active_world)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = HUDScript.new()
	hud.position = Vector2.ZERO
	hud.size = Vector2(960, 640)
	layer.add_child(hud)
	hud.setup(self)
	load_game()
	spawn_authored_shire()
	world.reveal_current_atlas()
	hud.notify("WASD: mover · ESPACIO: atacar · E: interactuar · M: mapa · H: debug alturas")

func _process(_delta: float) -> void:
	if player == null:
		return
	var nearby_orc := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: MiddleEarthEnemy = node as MiddleEarthEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not in_dungeon and enemy.global_position.distance_to(player.global_position) > 1850.0:
			enemy.queue_free()
			continue
		if enemy.enemy_type in ["orc", "uruk", "archer_orc"] and enemy.global_position.distance_to(player.global_position) < 240.0:
			nearby_orc = true
	player.orcs_nearby = nearby_orc
	interaction_hint = nearby_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if hud.loot_open:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			claim_loot()
		elif event.keycode == KEY_ESCAPE:
			hud.loot_open = false
			player.input_locked = false
		return
	if dialog_active:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			advance_dialog()
		return
	if hud.shop_open:
		if event.keycode in [KEY_E, KEY_ESCAPE]:
			hud.shop_open = false
			player.input_locked = false
			hud.notify("El vendedor guarda su mercancía.")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			buy_shop_offer(int(event.keycode - KEY_1))
		return
	if hud.inventory_open:
		if event.keycode in [KEY_I, KEY_ESCAPE]:
			hud.inventory_open = false
			player.input_locked = false
		elif event.keycode == KEY_1:
			player.active_item = "potion"
			hud.notify("Equipado: Frasco de Miruvor [Q].")
		elif event.keycode == KEY_2 and player.bow_unlocked:
			player.active_item = "bow"
			hud.notify("Equipado: Arco de la Comarca [Q].")
		return
	match event.keycode:
		KEY_F11:
			toggle_fullscreen()
		KEY_SPACE:
			player.request_attack()
		KEY_E:
			interact()
		KEY_I:
			hud.inventory_open = true
			player.input_locked = true
		KEY_M:
			hud.map_expanded = not hud.map_expanded
			player.input_locked = hud.map_expanded
		KEY_H:
			world.debug_elevation_mode = not world.debug_elevation_mode
			hud.notify("Debug Elevaciones [H]: %s" % ("ACTIVADO" if world.debug_elevation_mode else "DESACTIVADO"))
			world.queue_redraw()
		KEY_Q:
			use_active_item()
		KEY_1:
			player.active_item = "potion"
			hud.notify("Equipado: Frasco de Miruvor [Q].")
		KEY_2:
			if player.bow_unlocked:
				player.active_item = "bow"
				hud.notify("Equipado: Arco de la Comarca [Q].")
		KEY_F5:
			save_game()

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		hud.notify("Modo ventana: puedes redimensionar la ventana libremente.")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		hud.notify("Pantalla completa activada.")

func spawn_authored_shire() -> void:
	for b_data in world.shire.buildings_data:
		var building: HobbitonBuilding = BuildingScript.new()
		y_sort_layer.add_child(building)
		building.configure(b_data)
	for data in world.shire.npcs:
		var npc: FriendlyNPC = FriendlyScript.new()
		y_sort_layer.add_child(npc)
		npc.configure_authored(data)
	for data in world.shire.chests:
		var chest: TreasureChest = ChestScript.new()
		y_sort_layer.add_child(chest)
		chest.configure(data)
		chest.opened = world.opened_story_chests.has(chest.chest_id)
		chest.queue_redraw()
	for data in world.shire.signs:
		var sc := int(data.get("col", 0))
		var sr := int(data.get("row", 0))
		if world.shire.tile_at(sc, sr) == ShireMap.Tile.WATER:
			continue
		var sign: ShireSignpost = SignScript.new()
		y_sort_layer.add_child(sign)
		sign.configure(data)
	for data in world.shire.enemy_spawns:
		spawn_story_enemy(data)

func spawn_story_enemy(data: Dictionary) -> void:
	var position := Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
	var enemy: MiddleEarthEnemy = EnemyScript.new()
	enemy.z_index = 2
	add_child(enemy)
	enemy.configure(str(data.get("type", "orc")), position, player, world, 0, bool(data.get("mini_boss", false)))
	enemy.defeated.connect(handle_enemy_defeated)

func resolve_player_attack(origin: Vector2, facing: Vector2, damage: int) -> void:
	var hit_count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: MiddleEarthEnemy = node as MiddleEarthEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var displacement: Vector2 = enemy.global_position - origin
		if displacement.length() <= 49.0 and displacement.normalized().dot(facing) > -0.15:
			enemy.take_hit(damage, origin)
			hit_count += 1
	var cut_signs := 0
	for node in get_tree().get_nodes_in_group("signposts"):
		var sign: ShireSignpost = node as ShireSignpost
		if sign == null or not sign.visible or sign.is_cut:
			continue
		var disp: Vector2 = sign.global_position - origin
		if disp.length() <= 48.0 and disp.normalized().dot(facing) > -0.15:
			if sign.cut(facing):
				cut_signs += 1
	if hit_count > 0:
		hud.notify("Golpeas a %d enemigo%s." % [hit_count, "s" if hit_count != 1 else ""])
	elif cut_signs > 0:
		hud.notify("¡Has partido el cartel por la mitad!")

func spawn_enemy(kind: String, position: Vector2, threat: int) -> void:
	var enemy: MiddleEarthEnemy = EnemyScript.new()
	enemy.z_index = 2
	add_child(enemy)
	enemy.configure(kind, position, player, world, threat)
	enemy.defeated.connect(handle_enemy_defeated)

func spawn_enemy_arrow(origin: Vector2, destination: Vector2, damage: int) -> void:
	var arrow: EnemyArrow = EnemyArrowScript.new()
	arrow.z_index = 4
	add_child(arrow)
	arrow.setup(origin, destination, damage, player)

func spawn_player_arrow() -> void:
	if player.arrows <= 0:
		hud.notify("No te quedan flechas.")
		return
	player.arrows -= 1
	var dir := player.get_facing_vector()
	var arrow: PlayerArrow = PlayerArrowScript.new()
	arrow.z_index = 9
	add_child(arrow)
	arrow.setup(player.global_position + dir * 16.0, dir, 1, active_world)

func spawn_elf(role: String, position: Vector2) -> void:
	for node in get_tree().get_nodes_in_group("friendly_npcs"):
		var existing: FriendlyNPC = node as FriendlyNPC
		if existing != null and existing.role == role and existing.global_position.distance_to(position) < 20.0:
			return
	var elf: FriendlyNPC = FriendlyScript.new()
	elf.z_index = 3
	add_child(elf)
	elf.configure(role, position)

func handle_enemy_defeated(enemy: MiddleEarthEnemy) -> void:
	if enemy.is_mini_boss:
		uruk_defeated = true
		primary_quest = "¡Campamento liberado! Regresa con Gandalf en Bolsón Cerrado."
		if not "sting" in player.owned_weapons:
			player.owned_weapons.append("sting")
		hud.notify("¡Capitán Uruk-hai derrotado! Recuperas Dardo y el Mapa de Arnor.")
		return
	if enemy.enemy_type == "goblin":
		for quest in secondary_quests:
			if str(quest.title).begins_with("Limpia"):
				quest.completed = true

func interact() -> void:
	if in_dungeon and player.global_position.distance_to(dungeon.exit_position()) < 45.0:
		leave_dungeon()
		return
	var chest := nearby_story_chest()
	if chest != null:
		present_loot(chest)
		return
	var chest_message := "" if in_dungeon else world.open_nearby_map_chest(player.global_position)
	if not chest_message.is_empty():
		player.coins += 12
		start_dialog("Carta Regional Recuperada", [chest_message, "Pulsa M para consultar el territorio revelado. Los alrededores siguen ocultos hasta encontrar su carta."])
		return
	var npc := nearby_npc()
	if npc != null:
		interact_npc(npc)
		return
	var sign := nearby_sign()
	if sign != null:
		if sign.is_cut:
			start_dialog("Cartel Partido", ["El cartel fue partido por la mitad de un tajo limpio. Ya no se puede leer."])
		else:
			start_dialog("Cartel de La Comarca", [sign.text])
		return
	var building := nearby_building()
	if building != null:
		if building.heals_player:
			player.hp = player.max_hp
		start_dialog("%s · %s" % [building.building_title, building.resident], building.dialog_pages)
		return
	if not in_dungeon:
		var poi: Dictionary = nearby_poi()
		if not poi.is_empty():
			enter_dungeon(poi)
			return
	hud.notify("No hay nada con lo que interactuar cerca.")

func interact_npc(npc: FriendlyNPC) -> void:
	if npc.is_merchant:
		hud.shop_open = true
		player.input_locked = true
		hud.notify("Elige una oferta con [1]-[4].")
		return
	if npc.role == "lembas":
		if npc.used:
			start_dialog(npc.character_name, ["Que las estrellas guíen tus pasos. Ya he compartido mis provisiones contigo."])
		else:
			npc.used = true
			player.miruvor_charges += 1
			start_dialog(npc.character_name, ["Toma este pan de lembas. Añadí una ración a tus provisiones de Miruvor."])
		return
	if npc.role == "quest":
		start_elf_quest(npc)
		return
	if npc.role == "scout":
		start_dialog(npc.character_name, [scout_hint()])
		return
	if npc.npc_id == "gandalf":
		if uruk_defeated:
			start_dialog(npc.character_name, ["¡Extraordinario trabajo! El Capitán Uruk-hai ha caído y La Comarca está a salvo por ahora.", "La ruta hacia Bree y las ruinas de Arnor queda abierta para futuros capítulos."])
			return
		primary_quest = "Cruza el Río El Agua y derrota al Capitán Uruk-hai del campamento sureste."
	if npc.is_healer:
		player.hp = player.max_hp
	start_dialog(npc.character_name, npc.dialog_pages)

func directional_score(target_pos: Vector2, max_range: float) -> float:
	# Prioriza el objetivo que se encuentra frente a la dirección hacia la que mira el jugador
	var dist := player.global_position.distance_to(target_pos)
	if dist > max_range:
		return INF
	var to_target := (target_pos - player.global_position).normalized()
	var facing_dot := to_target.dot(player.get_facing_vector())
	# Bonificación clara si el objetivo está en el cono frontal del jugador
	return dist - facing_dot * 22.0

func nearby_npc() -> FriendlyNPC:
	var closest: FriendlyNPC
	var best_score := INF
	for node in get_tree().get_nodes_in_group("friendly_npcs"):
		var npc: FriendlyNPC = node as FriendlyNPC
		if npc == null or not npc.visible:
			continue
		var score := directional_score(npc.global_position, 56.0)
		if score < best_score:
			closest = npc
			best_score = score
	return closest

func nearby_story_chest() -> TreasureChest:
	var closest: TreasureChest
	var best_score := INF
	for node in get_tree().get_nodes_in_group("chests"):
		var chest: TreasureChest = node as TreasureChest
		if chest == null or not chest.visible or chest.opened:
			continue
		var score := directional_score(chest.global_position, 46.0)
		if score < best_score:
			closest = chest
			best_score = score
	return closest

func nearby_sign() -> ShireSignpost:
	var closest: ShireSignpost
	var best_score := INF
	for node in get_tree().get_nodes_in_group("signposts"):
		var sign: ShireSignpost = node as ShireSignpost
		if sign == null or not sign.visible or sign.is_cut:
			continue
		var score := directional_score(sign.global_position, 46.0)
		if score < best_score:
			closest = sign
			best_score = score
	return closest

func nearby_building() -> HobbitonBuilding:
	var closest: HobbitonBuilding
	var best_score := INF
	for node in get_tree().get_nodes_in_group("hobbiton_buildings"):
		var b: HobbitonBuilding = node as HobbitonBuilding
		if b == null or not b.visible or not b.has_door:
			continue
		var score := directional_score(b.world_door_position(), 44.0)
		if score < best_score:
			closest = b
			best_score = score
	return closest

func nearby_hint() -> String:
	if in_dungeon and player.global_position.distance_to(dungeon.exit_position()) < 45.0:
		return "[E] Regresar al exterior"
	var chest := nearby_story_chest()
	if chest != null:
		return "[E] Abrir %s" % chest.title
	var npc := nearby_npc()
	if npc != null:
		return "[E] Hablar con %s" % npc.character_name
	var sign := nearby_sign()
	if sign != null:
		return "[E] Leer cartel"
	var building := nearby_building()
	if building != null:
		return "[E] Inspeccionar %s" % building.building_title
	if not in_dungeon:
		var poi: Dictionary = nearby_poi()
		if not poi.is_empty():
			return "[E] Entrar a %s" % ("Mina Enana" if str(poi.get("kind", "")) != "cave" else "Cueva Profunda")
	return ""

func nearby_poi() -> Dictionary:
	var chunk: Vector2i = world.chunk_from_world(player.global_position)
	for y in range(chunk.y - 1, chunk.y + 2):
		for x in range(chunk.x - 1, chunk.x + 2):
			var poi: Dictionary = world.poi_for_chunk(Vector2i(x, y))
			if not poi.is_empty() and player.global_position.distance_to(poi.position) < 46.0:
				return poi
	return {}

func enter_dungeon(poi: Dictionary) -> void:
	overworld_return = player.global_position
	hide_overworld_gameplay(true)
	world.visible = false
	world.set_process(false)
	dungeon = DungeonScript.new()
	dungeon.z_index = 0
	add_child(dungeon)
	var kind := "mine" if str(poi.get("kind", "")) != "cave" else "cave"
	dungeon.configure(kind, floori(world.hash01(floori(poi.position.x), floori(poi.position.y), 1102) * 2147483647.0), str(poi.get("biome", "OLD_FOREST")))
	active_world = dungeon
	player.global_position = dungeon.exit_position() + Vector2(4.5 * 32.0, 0.0)
	player.setup(active_world)
	dungeon.bind_player(player)
	darkness.world = active_world
	in_dungeon = true
	for data in dungeon.chests:
		var chest: TreasureChest = ChestScript.new()
		chest.z_index = 3
		add_child(chest)
		chest.configure(data)
		dungeon_nodes.append(chest)
	for data in dungeon.enemy_spawns:
		var position := Vector2((int(data.get("col", 0)) + 0.5) * 32.0, (int(data.get("row", 0)) + 0.5) * 32.0)
		var enemy: MiddleEarthEnemy = EnemyScript.new()
		enemy.z_index = 2
		add_child(enemy)
		enemy.configure(str(data.get("type", "orc")), position, player, dungeon)
		enemy.defeated.connect(handle_enemy_defeated)
		dungeon_nodes.append(enemy)
	start_dialog("Mina Subterránea" if kind == "mine" else "Cueva Profunda", ["Las sombras se agitan bajo la piedra. Encuentra el cofre y regresa por la entrada cuando estés preparado."])

func leave_dungeon() -> void:
	for node in dungeon_nodes:
		if is_instance_valid(node):
			node.queue_free()
	dungeon_nodes.clear()
	if dungeon != null:
		dungeon.queue_free()
	dungeon = null
	in_dungeon = false
	world.visible = true
	world.set_process(true)
	hide_overworld_gameplay(false)
	active_world = world
	player.global_position = overworld_return
	player.setup(active_world)
	world.bind_player(player)
	darkness.world = active_world
	start_dialog("Exterior", ["El aire de la Tierra Media vuelve a rodearte."])

func hide_overworld_gameplay(hide: bool) -> void:
	if hide:
		hidden_overworld_nodes.clear()
		for group in ["friendly_npcs", "chests", "signposts", "enemies", "hobbiton_buildings"]:
			for node in get_tree().get_nodes_in_group(group):
				if node in dungeon_nodes:
					continue
				node.visible = false
				if node is MiddleEarthEnemy:
					node.set_physics_process(false)
				hidden_overworld_nodes.append(node)
	else:
		for node in hidden_overworld_nodes:
			if is_instance_valid(node):
				node.visible = true
				if node is MiddleEarthEnemy:
					node.set_physics_process(true)
		hidden_overworld_nodes.clear()

func present_loot(chest: TreasureChest) -> void:
	loot_chest = chest
	hud.loot_open = true
	hud.loot_title = chest.title
	hud.loot_description = chest.description
	player.input_locked = true

func claim_loot() -> void:
	if loot_chest == null:
		return
	var chest := loot_chest
	chest.open()
	world.opened_story_chests[chest.chest_id] = true
	match chest.reward:
		"bow_upgrade":
			player.bow_unlocked = true
			player.arrows += 15
			player.active_item = "bow"
			start_dialog(chest.title, ["Has obtenido el Arco de la Comarca y 15 flechas. Pulsa 2 para equiparlo y Q para disparar."])
		"potion_pack":
			player.miruvor_charges += 2
			player.coins += 25
			start_dialog(chest.title, ["Recibes 2 raciones de Miruvor y 25 monedas."])
		"heart_container":
			player.max_hp = mini(MiddleEarthPlayer.MAX_HEARTS, player.max_hp + 1)
			player.hp = player.max_hp
			start_dialog(chest.title, ["Tu salud máxima aumenta. El límite temporal es de seis corazones."])
		"sword_temper":
			if not "barrow_blade" in player.owned_weapons:
				player.owned_weapons.append("barrow_blade")
			start_dialog(chest.title, ["Has obtenido la Hoja de los Túmulos. Puedes equiparla al alcanzar el nivel requerido."])
		_:
			start_dialog(chest.title, [chest.description])
	loot_chest = null
	hud.loot_open = false

func start_dialog(title: String, pages: Array) -> void:
	if pages.is_empty():
		return
	dialog_title = title
	dialog_pages = pages
	dialog_index = 0
	dialog_active = true
	player.input_locked = true

func advance_dialog() -> void:
	dialog_index += 1
	if dialog_index >= dialog_pages.size():
		dialog_active = false
		player.input_locked = false

func scout_hint() -> String:
	var start: Vector2i = world.chunk_from_world(player.global_position)
	for radius in range(1, 8):
		for y in range(start.y - radius, start.y + radius + 1):
			for x in range(start.x - radius, start.x + radius + 1):
				var poi: Dictionary = world.poi_for_chunk(Vector2i(x, y))
				if not poi.is_empty() and str(poi.get("kind", "")) == "cave":
					return "He visto una cueva cerca del chunk [%d, %d]. Busca su entrada entre los árboles." % [x, y]
	return "Las cuevas se ocultan donde el bosque calla. Explora los claros al norte y al oeste."

func start_elf_quest(elf: FriendlyNPC) -> void:
	if elf.used:
		start_dialog(elf.character_name, ["La misión ya está anotada en tu tabla."])
		return
	elf.used = true
	secondary_quests.append({"title": "Limpia un campamento de duendes", "completed": false})
	start_dialog(elf.character_name, ["Los duendes profanan nuestros senderos. Limpia uno de sus campamentos y el bosque recordará tu valor."])

func shop_offers() -> Array:
	return [
		{"kind": "weapon", "id": "barrow_blade", "data": WeaponCatalog.weapon("barrow_blade")},
		{"kind": "weapon", "id": "sting", "data": WeaponCatalog.weapon("sting")},
		{"kind": "armor", "id": "shire_leather", "data": WeaponCatalog.armor("shire_leather")},
		{"kind": "armor", "id": "elven_cloak", "data": WeaponCatalog.armor("elven_cloak")},
	]

func buy_shop_offer(index: int) -> void:
	var offers: Array = shop_offers()
	if index < 0 or index >= offers.size():
		return
	var offer: Dictionary = offers[index]
	var result: String = player.buy_weapon(str(offer.get("id", ""))) if str(offer.get("kind", "")) == "weapon" else player.buy_armor(str(offer.get("id", "")))
	hud.notify(result)

func use_active_item() -> void:
	if player.active_item == "bow" and player.bow_unlocked:
		spawn_player_arrow()
		return
	if player.miruvor_charges <= 0:
		hud.notify("No te quedan raciones de Miruvor.")
		return
	if player.hp >= player.max_hp:
		hud.notify("Ya tienes la salud completa.")
		return
	player.miruvor_charges -= 1
	player.hp = mini(player.max_hp, player.hp + 3)
	hud.notify("El Miruvor recupera 3 corazones.")

func respawn_player() -> void:
	player.hp = player.max_hp
	player.coins = maxi(0, player.coins - 5)
	player.global_position = world.shire.spawn_position
	player.elevation = world.get_interpolated_elevation(player.global_position)
	player.input_locked = false
	hud.notify("Has caído. Despiertas en Bolsón Cerrado (Nivel 3) y pierdes 5 monedas.")

func save_game() -> void:
	if SaveGame.save_snapshot(player, world):
		hud.notify("Partida guardada en este dispositivo.")
	else:
		hud.notify("No se pudo guardar la partida.")

func load_game() -> void:
	var snapshot: Dictionary = SaveGame.load_snapshot()
	if snapshot.is_empty():
		return
	player.restore(snapshot)
	world.revealed_atlases = Dictionary(snapshot.get("revealed_atlases", {"0,0": true}))
	world.opened_chests = Dictionary(snapshot.get("opened_chests", {}))
	world.opened_story_chests = Dictionary(snapshot.get("opened_story_chests", {}))

