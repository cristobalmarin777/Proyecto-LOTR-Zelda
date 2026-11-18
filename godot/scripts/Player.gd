class_name MiddleEarthPlayer
extends CharacterBody2D

signal attack_started(origin: Vector2, facing: Vector2, damage: int)
signal defeated

const MAX_HEARTS := 6
const ARMOR_COOLDOWN_SECONDS := 3.0

var world: MiddleEarthWorld
var move_speed := 185.0
var facing := Vector2.DOWN
var hp := MAX_HEARTS
var max_hp := MAX_HEARTS
var coins := 15
var arrows := 8
var level := 1
var xp := 0
var next_level_xp := 60
var equipped_weapon_id := "traveler_dagger"
var equipped_armor_id := "traveler_cloak"
var owned_weapons: Array = ["traveler_dagger"]
var owned_armors: Array = ["traveler_cloak"]
var armor_cooldown := 0.0
var invulnerability := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var is_moving := false
var orcs_nearby := false

func setup(world_ref: MiddleEarthWorld) -> void:
	world = world_ref
	queue_redraw()

func _physics_process(delta: float) -> void:
	armor_cooldown = maxf(0.0, armor_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var input_direction := read_movement()
	is_moving = not input_direction.is_zero_approx()
	if is_moving:
		facing = input_direction
		var desired := global_position + input_direction * move_speed * delta
		if world == null or not world.is_blocked(desired):
			global_position = desired
	queue_redraw()

func read_movement() -> Vector2:
	var horizontal := (1.0 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0.0)
	var vertical := (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
	return Vector2(horizontal, vertical).normalized()

func request_attack() -> bool:
	if attack_cooldown > 0.0:
		return false
	attack_time = 0.20
	attack_cooldown = 0.24
	attack_started.emit(global_position, facing, weapon_damage())
	queue_redraw()
	return true

func take_damage(raw_damage: int, source_position: Vector2) -> bool:
	if invulnerability > 0.0:
		return false
	var dealt := raw_damage
	if armor_defense() > 0 and armor_cooldown <= 0.0:
		dealt = maxi(0, raw_damage - armor_defense())
		armor_cooldown = ARMOR_COOLDOWN_SECONDS
	hp = maxi(0, hp - dealt)
	invulnerability = 0.55
	var retreat := (global_position - source_position).normalized()
	global_position += retreat * 12.0
	queue_redraw()
	if hp <= 0:
		defeated.emit()
	return true

func add_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= next_level_xp:
		xp -= next_level_xp
		level += 1
		next_level_xp = floori(next_level_xp * 1.28)
		# El límite de seis corazones es intencional en esta etapa.
		hp = min(max_hp, hp + 2)
		leveled = true
	return leveled

func weapon_data() -> Dictionary:
	return WeaponCatalog.weapon(equipped_weapon_id)

func armor_data() -> Dictionary:
	return WeaponCatalog.armor(equipped_armor_id)

func weapon_damage() -> int:
	return int(weapon_data().get("damage", 1))

func armor_defense() -> int:
	return int(armor_data().get("defense", 0))

func armor_progress() -> float:
	if armor_defense() <= 0:
		return 0.0
	return 1.0 - armor_cooldown / ARMOR_COOLDOWN_SECONDS

func sting_lit() -> bool:
	return equipped_weapon_id == "sting" and orcs_nearby

func can_equip_weapon(id: String) -> bool:
	return id in owned_weapons and level >= int(WeaponCatalog.weapon(id).get("required_level", 1))

func can_equip_armor(id: String) -> bool:
	return id in owned_armors and level >= int(WeaponCatalog.armor(id).get("required_level", 1))

func equip_weapon(id: String) -> bool:
	if not can_equip_weapon(id):
		return false
	equipped_weapon_id = id
	queue_redraw()
	return true

func equip_armor(id: String) -> bool:
	if not can_equip_armor(id):
		return false
	equipped_armor_id = id
	return true

func buy_weapon(id: String) -> String:
	var item := WeaponCatalog.weapon(id)
	if id in owned_weapons:
		return "Ya posees %s." % item.name
	if level < int(item.required_level):
		return "Requiere nivel %d." % int(item.required_level)
	if coins < int(item.price):
		return "No tienes suficientes monedas."
	coins -= int(item.price)
	owned_weapons.append(id)
	equipped_weapon_id = id
	return "Has comprado y equipado %s." % item.name

func buy_armor(id: String) -> String:
	var item := WeaponCatalog.armor(id)
	if id in owned_armors:
		return "Ya posees %s." % item.name
	if level < int(item.required_level):
		return "Requiere nivel %d." % int(item.required_level)
	if coins < int(item.price):
		return "No tienes suficientes monedas."
	coins -= int(item.price)
	owned_armors.append(id)
	equipped_armor_id = id
	return "Has comprado y equipado %s." % item.name

func restore(snapshot: Dictionary) -> void:
	if snapshot.has("position"):
		var stored_position: Dictionary = snapshot.position
		global_position = Vector2(float(stored_position.get("x", 512.0)), float(stored_position.get("y", 352.0)))
	hp = clampi(int(snapshot.get("hp", MAX_HEARTS)), 1, MAX_HEARTS)
	coins = int(snapshot.get("coins", 15))
	xp = int(snapshot.get("xp", 0))
	level = maxi(1, int(snapshot.get("level", 1)))
	next_level_xp = maxi(60, floori(60.0 * pow(1.28, level - 1)))
	equipped_weapon_id = str(snapshot.get("equipped_weapon", "traveler_dagger"))
	equipped_armor_id = str(snapshot.get("equipped_armor", "traveler_cloak"))
	owned_weapons = Array(snapshot.get("owned_weapons", ["traveler_dagger"]))
	owned_armors = Array(snapshot.get("owned_armors", ["traveler_cloak"]))

func _draw() -> void:
	# El protagonista siempre se vuelve a dibujar luminoso; la oscuridad se
	# aplica como capa ambiental por encima del mundo, no sobre el personaje.
	var flicker := 0.35 if invulnerability > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0 else 1.0
	draw_circle(Vector2.ZERO, 12.0, Color(0.93, 0.84, 0.58, flicker))
	draw_circle(Vector2(0, -5), 6.0, Color(1.0, 0.90, 0.70, flicker))
	draw_rect(Rect2(-8, 2, 16, 11), Color(0.22, 0.36, 0.50, flicker))
	if attack_time > 0.0:
		draw_line(Vector2(0, -2), facing * 31.0, Color("fff4c6"), 4.0)
	if sting_lit():
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color("7cecff"), 1.5)

