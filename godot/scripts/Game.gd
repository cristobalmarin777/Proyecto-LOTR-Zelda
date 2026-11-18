extends Node2D

const EnemyScript := preload("res://scripts/Enemy.gd")
const ArrowScript := preload("res://scripts/EnemyArrow.gd")
const FriendlyScript := preload("res://scripts/FriendlyNPC.gd")
const PlayerScript := preload("res://scripts/Player.gd")
const WorldScript := preload("res://scripts/WorldGenerator.gd")
const OverlayScript := preload("res://scripts/DarknessOverlay.gd")
const HUDScript := preload("res://scripts/HUD.gd")

var world: MiddleEarthWorld
var player: MiddleEarthPlayer
var darkness: DarknessOverlay
var hud: MiddleEarthHUD
var primary_quest := "Habla con el guardián y cartografía los caminos más allá de La Comarca."
var secondary_quests: Array = []

func _ready() -> void:
	world = WorldScript.new()
	world.z_index = 0
	add_child(world)
	player = PlayerScript.new()
	player.z_index = 10
	player.global_position = Vector2(512, 352)
	add_child(player)
	player.setup(world)
	world.bind_player(player)
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
	darkness.setup(player, world)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = HUDScript.new()
	hud.position = Vector2.ZERO
	hud.size = Vector2(960, 640)
	layer.add_child(hud)
	hud.setup(self)
	load_game()
	spawn_merchant()
	world.reveal_current_atlas()
	hud.notify("WASD/Flechas: mover · ESPACIO: atacar · E: interactuar · M: mapa · F5: guardar")

func _process(_delta: float) -> void:
	if player == null:
		return
	var nearby_orc := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(player.global_position) > 1850.0:
			enemy.queue_free()
			continue
		if enemy.enemy_type in ["orc", "uruk", "archer_orc"] and enemy.global_position.distance_to(player.global_position) < 240.0:
			nearby_orc = true
	player.orcs_nearby = nearby_orc

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if hud.shop_open:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			hud.shop_open = false
			hud.notify("El vendedor guarda su mercancía.")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			buy_shop_offer(int(event.keycode - KEY_1))
		return
	match event.keycode:
		KEY_SPACE:
			player.request_attack()
		KEY_E:
			interact()
		KEY_M:
			hud.map_expanded = not hud.map_expanded
		KEY_Q:
			use_miruvor()
		KEY_F5:
			save_game()

func resolve_player_attack(origin: Vector2, facing: Vector2, damage: int) -> void:
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var displacement: Vector2 = enemy.global_position - origin
		if displacement.length() <= 49.0 and displacement.normalized().dot(facing) > -0.15:
			enemy.take_hit(damage, origin)
			hit_count += 1
	if hit_count > 0:
		hud.notify("Golpeas a %d enemigo%s." % [hit_count, "s" if hit_count != 1 else ""])

func spawn_enemy(kind: String, position: Vector2, threat: int) -> void:
	var enemy: MiddleEarthEnemy = EnemyScript.new()
	enemy.z_index = 2
	add_child(enemy)
	enemy.configure(kind, position, player, world, threat)

func spawn_enemy_arrow(origin: Vector2, destination: Vector2, damage: int) -> void:
	var arrow: EnemyArrow = ArrowScript.new()
	arrow.z_index = 4
	add_child(arrow)
	arrow.setup(origin, destination, damage, player)

func spawn_elf(role: String, position: Vector2) -> void:
	# Evita apilar el mismo encuentro al volver a cargar un borde de chunk.
	for npc in get_tree().get_nodes_in_group("friendly_npcs"):
		if npc.role == role and npc.global_position.distance_to(position) < 20.0:
			return
	var elf: FriendlyNPC = FriendlyScript.new()
	elf.z_index = 3
	add_child(elf)
	elf.configure(role, position)

func spawn_merchant() -> void:
	var merchant: FriendlyNPC = FriendlyScript.new()
	merchant.z_index = 3
	add_child(merchant)
	merchant.configure("merchant", Vector2(664, 392))

func interact() -> void:
	var chest_message := world.open_nearby_map_chest(player.global_position)
	if not chest_message.is_empty():
		player.coins += 12
		hud.notify("%s +12 monedas." % chest_message)
		return
	var closest: FriendlyNPC
	var closest_distance := 54.0
	for npc in get_tree().get_nodes_in_group("friendly_npcs"):
		var distance: float = npc.global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest = npc
			closest_distance = distance
	if closest == null:
		hud.notify("No hay nada con lo que interactuar cerca.")
		return
	match closest.role:
		"merchant":
			hud.shop_open = true
			hud.notify("Elige una oferta con [1]-[4].")
		"lembas":
			if closest.used:
				hud.notify("La elfa sonríe: guarda fuerzas para el camino.")
			else:
				closest.used = true
				player.hp = mini(player.max_hp, player.hp + 3)
				hud.notify("Recibes pan de lembas y recuperas 3 corazones.")
		"quest":
			start_elf_quest(closest)
		"scout":
			hud.notify(scout_hint())

func scout_hint() -> String:
	var start := world.chunk_from_world(player.global_position)
	for radius in range(1, 8):
		for y in range(start.y - radius, start.y + radius + 1):
			for x in range(start.x - radius, start.x + radius + 1):
				var poi := world.poi_for_chunk(Vector2i(x, y))
				if not poi.is_empty() and poi.kind == "cave":
					return "El explorador señala una cueva cerca del chunk [%d, %d]." % [x, y]
	return "El explorador no conoce ninguna cueva cercana; sigue hacia el oeste." 

func start_elf_quest(elf: FriendlyNPC) -> void:
	if elf.used:
		hud.notify("La misión ya está anotada en tu tabla.")
		return
	elf.used = true
	secondary_quests.append({"title": "Limpia un campamento de duendes", "completed": false})
	hud.notify("Misión secundaria: limpia un campamento de duendes del Bosque Viejo.")

func shop_offers() -> Array:
	return [
		{"kind": "weapon", "id": "barrow_blade", "data": WeaponCatalog.weapon("barrow_blade")},
		{"kind": "weapon", "id": "sting", "data": WeaponCatalog.weapon("sting")},
		{"kind": "armor", "id": "shire_leather", "data": WeaponCatalog.armor("shire_leather")},
		{"kind": "armor", "id": "elven_cloak", "data": WeaponCatalog.armor("elven_cloak")},
	]

func buy_shop_offer(index: int) -> void:
	var offers := shop_offers()
	if index < 0 or index >= offers.size():
		return
	var offer: Dictionary = offers[index]
	var result := player.buy_weapon(str(offer.id)) if offer.kind == "weapon" else player.buy_armor(str(offer.id))
	hud.notify(result)

func use_miruvor() -> void:
	if player.hp >= player.max_hp:
		hud.notify("Ya tienes la salud completa.")
		return
	player.hp = mini(player.max_hp, player.hp + 3)
	hud.notify("El Miruvor recupera 3 corazones.")

func respawn_player() -> void:
	player.hp = player.max_hp
	player.coins = maxi(0, player.coins - 5)
	player.global_position = Vector2(512, 352)
	hud.notify("Has caído. Despiertas en La Comarca y pierdes 5 monedas.")

func save_game() -> void:
	if SaveGame.save_snapshot(player, world):
		hud.notify("Partida guardada en este dispositivo.")
	else:
		hud.notify("No se pudo guardar la partida.")

func load_game() -> void:
	var snapshot := SaveGame.load_snapshot()
	if snapshot.is_empty():
		return
	player.restore(snapshot)
	world.revealed_atlases = Dictionary(snapshot.get("revealed_atlases", {"0,0": true}))
	world.opened_chests = Dictionary(snapshot.get("opened_chests", {}))

