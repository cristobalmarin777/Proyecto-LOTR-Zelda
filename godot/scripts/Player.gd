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
var active_item := "potion"
var miruvor_charges := 2
var bow_unlocked := false
var input_locked := false
var armor_cooldown := 0.0
var invulnerability := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var is_moving := false
var orcs_nearby := false
var walk_time := 0.0

func setup(world_ref: MiddleEarthWorld) -> void:
	world = world_ref
	queue_redraw()

func _physics_process(delta: float) -> void:
	armor_cooldown = maxf(0.0, armor_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if input_locked:
		queue_redraw()
		return
	var input_direction := read_movement()
	is_moving = not input_direction.is_zero_approx()
	if is_moving:
		walk_time += delta * 12.0
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
	if input_locked or attack_cooldown > 0.0:
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
	active_item = str(snapshot.get("active_item", "potion"))
	miruvor_charges = int(snapshot.get("miruvor_charges", 2))
	bow_unlocked = bool(snapshot.get("bow_unlocked", false))

func _draw() -> void:
	# Sprite pixel-art nativo: el protagonista se dibuja por encima de la capa
	# ambiental, de modo que sigue siendo el punto más legible en zonas oscuras.
	var flicker := 0.35 if invulnerability > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0 else 1.0
	var bob := sin(walk_time) * 1.3 if is_moving else 0.0
	var alpha_color := Color(1.0, 1.0, 1.0, flicker)
	# Sombra y botas.
	draw_ground_shadow(Vector2(0, 14 + bob), Vector2(10, 3), Color(0.0, 0.0, 0.0, 0.38 * flicker))
	draw_rect(Rect2(-8, 8 + bob, 6, 6), Color("352821") * alpha_color)
	draw_rect(Rect2(2, 8 - bob, 6, 6), Color("352821") * alpha_color)
	# Capa azul del viajero, cinturón y túnica verde.
	draw_rect(Rect2(-10, -3 + bob, 20, 13), Color("142938") * alpha_color)
	draw_rect(Rect2(-8, -5 + bob, 16, 15), Color("315d4c") * alpha_color)
	draw_rect(Rect2(-9, 5 + bob, 18, 4), Color("1c3c34") * alpha_color)
	draw_rect(Rect2(-8, 2 + bob, 16, 2), Color("895d2c") * alpha_color)
	draw_rect(Rect2(-2, 2 + bob, 4, 3), Color("d9b650") * alpha_color)
	# Cabeza, cabello y capucha.
	draw_rect(Rect2(-6, -15 + bob, 12, 11), Color("f1c49d") * alpha_color)
	draw_rect(Rect2(-7, -18 + bob, 14, 5), Color("6b4026") * alpha_color)
	draw_rect(Rect2(-8, -14 + bob, 3, 8), Color("6b4026") * alpha_color)
	if facing.y > 0.1:
		draw_rect(Rect2(-4, -11 + bob, 2, 2), Color("38291f") * alpha_color)
		draw_rect(Rect2(2, -11 + bob, 2, 2), Color("38291f") * alpha_color)
	# Broche de la capa y brazo adelantado.
	draw_circle(Vector2(-7, -2 + bob), 2.0, Color("d5b95f") * alpha_color)
	draw_rect(Rect2(7, -1 + bob, 5, 9), Color("d7a97d") * alpha_color)
	# Escudo pequeño cuando hay defensa equipada.
	if armor_defense() > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -1 + bob), Vector2(-7, -4 + bob), Vector2(-4, -1 + bob), Vector2(-5, 7 + bob), Vector2(-9, 10 + bob), Vector2(-12, 6 + bob)]), Color("788b94") * alpha_color)
		draw_line(Vector2(-9, -2 + bob), Vector2(-9, 7 + bob), Color("c8d6d7") * alpha_color, 1.0)
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(10, 3 + bob), 7.0, -PI * 0.5, PI * 0.5, 8, Color("c98a4b") * alpha_color, 2.0)
	if attack_time > 0.0:
		draw_sword_swing(bob, flicker)
	else:
		# Hoja enfundada: se ve incluso antes de atacar y comunica el equipo.
		draw_line(Vector2(8, 3 + bob), Vector2(14, 11 + bob), Color("b8c6c9") * alpha_color, 2.0)
	if sting_lit():
		draw_arc(Vector2(0, bob), 21.0, 0.0, TAU, 24, Color("7cecff"), 1.5)

func draw_sword_swing(bob: float, flicker: float) -> void:
	var progress := 1.0 - attack_time / 0.20
	var start_angle := facing.angle() - 1.35
	var current_angle := lerpf(start_angle, facing.angle() + 1.35, progress)
	# Estela dorada detrás de la hoja: el arco permite leer el ataque, no solo
	# el instante de impacto.
	draw_arc(Vector2(0, bob), 28.0, start_angle, current_angle, 16, Color(1.0, 0.82, 0.28, 0.38 * flicker), 4.0)
	draw_set_transform(Vector2(0, bob), current_angle)
	draw_line(Vector2(3, 0), Vector2(12, 0), Color("70401f") * Color(1, 1, 1, flicker), 4.0)
	draw_line(Vector2(11, 0), Vector2(32, 0), Color("202c34") * Color(1, 1, 1, flicker), 5.0)
	draw_line(Vector2(11, 0), Vector2(32, 0), Color("e8f4f2") * Color(1, 1, 1, flicker), 2.0)
	draw_line(Vector2(6, -5), Vector2(6, 5), Color("d7a846") * Color(1, 1, 1, flicker), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0)

func draw_ground_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	# Un polígono mantiene la sombra estable con cualquier zoom de cámara.
	var points := PackedVector2Array()
	for index in range(16):
		points.append(center + Vector2.from_angle(TAU * float(index) / 16.0) * radius)
	draw_colored_polygon(points, color)
