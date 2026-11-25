class_name MiddleEarthPlayer
extends CharacterBody2D

signal attack_started(origin: Vector2, facing: Vector2, damage: int)
signal defeated

const MAX_HEARTS := 6
const ARMOR_COOLDOWN_SECONDS := 3.0

var world: MiddleEarthWorld
var move_speed := 185.0
var facing := Vector2.DOWN
var facing_direction: String = "down" # "up"|"down"|"left"|"right"|"up_right"|"up_left"|"down_right"|"down_left"
var current_animation: String = "idle_down" # idle_* | walk_*
var anim_frame: int = 0
var anim_timer: float = 0.0
var idle_timer: float = 0.0
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
var spellbound := false
var armor_cooldown := 0.0
var invulnerability := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var is_moving := false
var orcs_nearby := false
var walk_time := 0.0
var elevation := 3.0

# Estados de salto desde acantilado (bajar sin rampa) + aterrizaje/estabilización (0.2s cooldown)
var is_ledge_jumping := false
var ledge_jump_start := Vector2.ZERO
var ledge_jump_end := Vector2.ZERO
var ledge_jump_elapsed := 0.0
var ledge_jump_duration := 0.34
var ledge_jump_height := 0.0
var ledge_target_elevation := 0.0
var land_recovery_timer := 0.0
const LAND_RECOVERY_DURATION := 0.20

func setup(world_ref: MiddleEarthWorld) -> void:
	world = world_ref
	if world != null and world.has_method("get_interpolated_elevation"):
		elevation = world.get_interpolated_elevation(global_position)
	queue_redraw()

func _physics_process(delta: float) -> void:
	armor_cooldown = maxf(0.0, armor_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	# 1. Animación activa de salto y caída desde un acantilado hacia un nivel inferior
	if is_ledge_jumping:
		ledge_jump_elapsed += delta
		var t := clampf(ledge_jump_elapsed / ledge_jump_duration, 0.0, 1.0)
		global_position = ledge_jump_start.lerp(ledge_jump_end, t)
		# Arco parabólico: impulso hacia arriba al saltar + caída progresiva
		ledge_jump_height = sin(t * PI) * 20.0
		elevation = lerpf(elevation, ledge_target_elevation, t)
		is_moving = false
		current_animation = "jump_" + facing_direction
		if t >= 1.0:
			is_ledge_jumping = false
			ledge_jump_height = 0.0
			global_position = ledge_jump_end
			elevation = ledge_target_elevation
			# Cooldown de estabilización al caer (0.2 segundos)
			land_recovery_timer = LAND_RECOVERY_DURATION
			current_animation = "land_" + facing_direction
		queue_redraw()
		return

	# 2. Fase de estabilización al aterrizar (cooldown de 0.2s antes de volver a moverse)
	if land_recovery_timer > 0.0:
		land_recovery_timer = maxf(0.0, land_recovery_timer - delta)
		is_moving = false
		current_animation = "land_" + facing_direction
		queue_redraw()
		return

	if input_locked or spellbound:
		is_moving = false
		idle_timer += delta
		current_animation = "idle_" + facing_direction
		queue_redraw()
		return

	var raw_axes := read_movement_axes()
	var input_direction := Vector2(float(raw_axes.x), float(raw_axes.y)).normalized()

	var prev_pos := global_position
	var moved_x := false
	var moved_y := false

	if not input_direction.is_zero_approx():
		# Resolución independiente por eje (permite deslizarse paralelamente a un acantilado)
		var step := input_direction * move_speed * delta
		if not is_zero_approx(step.x):
			var next_x := global_position + Vector2(step.x, 0.0)
			if world == null or not world.is_blocked(next_x, elevation):
				global_position = next_x
				moved_x = true
		if not is_zero_approx(step.y):
			var next_y := global_position + Vector2(0.0, step.y)
			if world == null or not world.is_blocked(next_y, elevation):
				global_position = next_y
				moved_y = true

		# Si el jugador empuja contra un borde que desciende a un nivel inferior transitable (sin agua ni muro), iniciar salto
		if not (moved_x and moved_y):
			if try_start_ledge_jump(input_direction):
				queue_redraw()
				return

		if world != null and world.has_method("get_interpolated_elevation"):
			elevation = world.get_interpolated_elevation(global_position)

	var displacement := global_position - prev_pos
	is_moving = displacement.length_squared() > 0.01

	# Actualizar orientación en 8 direcciones según el desplazamiento efectivo
	if is_moving:
		update_facing_direction(raw_axes, moved_x, moved_y)
		walk_time += delta * 12.0
		anim_timer += delta
		if anim_timer >= 0.13:
			anim_timer = 0.0
			anim_frame = (anim_frame + 1) % 4
		current_animation = "walk_" + facing_direction
		idle_timer = 0.0
	else:
		# Al detenerse conserva la última orientación (persistencia)
		anim_frame = 0
		anim_timer = 0.0
		idle_timer += delta
		current_animation = "idle_" + facing_direction

	queue_redraw()

func try_start_ledge_jump(input_dir: Vector2) -> bool:
	if world == null or not world.has_method("get_height_at_tile") or not world.has_method("is_solid_only"):
		return false
	# No saltar si ya estamos sobre una rampa o puente
	if world.has_method("get_connection_at_pixel") and not world.get_connection_at_pixel(global_position).is_empty():
		return false
	var current_h := roundi(elevation)
	if current_h <= 0:
		return false
	# Comprobar el tile justo delante (a 18 px) en la dirección en la que empuja el jugador
	var probe_edge := global_position + input_dir * 18.0
	var edge_col := floori(probe_edge.x / 32.0)
	var edge_row := floori(probe_edge.y / 32.0)
	var target_h: int = world.get_height_at_tile(edge_col, edge_row)
	# Solo se permite saltar hacia ABAJO (nunca subir un acantilado sin rampa)
	if target_h >= current_h:
		return false
	# Punto de aterrizaje seguro sobre el nivel inferior (a 36 px en dirección del salto)
	var landing := global_position + input_dir * 36.0
	var land_col := floori(landing.x / 32.0)
	var land_row := floori(landing.y / 32.0)
	var land_h: int = world.get_height_at_tile(land_col, land_row)
	if land_h >= current_h:
		return false
	# No saltar hacia agua, árboles, rocas ni edificios
	if world.is_solid_only(probe_edge) or world.is_solid_only(landing):
		return false

	# Orientar hacia la dirección del salto e iniciar animación parabólica
	var jump_axes := Vector2i(roundi(signf(input_dir.x)) if absf(input_dir.x) > 0.25 else 0, roundi(signf(input_dir.y)) if absf(input_dir.y) > 0.25 else 0)
	update_facing_direction(jump_axes, jump_axes.x != 0, jump_axes.y != 0)
	is_ledge_jumping = true
	ledge_jump_start = global_position
	ledge_jump_end = landing
	ledge_jump_elapsed = 0.0
	ledge_jump_height = 0.0
	ledge_target_elevation = float(land_h)
	return true

func read_movement_axes() -> Vector2i:
	var horizontal := (1 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0) - (1 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0)
	var vertical := (1 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0) - (1 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0)
	return Vector2i(horizontal, vertical)

func read_movement() -> Vector2:
	var axes := read_movement_axes()
	return Vector2(float(axes.x), float(axes.y)).normalized()

func update_facing_direction(raw_axes: Vector2i, moved_x: bool, moved_y: bool) -> void:
	var eff_x := raw_axes.x if moved_x else 0
	var eff_y := raw_axes.y if moved_y else 0
	if eff_x == 0 and eff_y == 0:
		return
	if eff_x > 0 and eff_y < 0:
		facing_direction = "up_right"
	elif eff_x < 0 and eff_y < 0:
		facing_direction = "up_left"
	elif eff_x > 0 and eff_y > 0:
		facing_direction = "down_right"
	elif eff_x < 0 and eff_y > 0:
		facing_direction = "down_left"
	elif eff_x > 0:
		facing_direction = "right"
	elif eff_x < 0:
		facing_direction = "left"
	elif eff_y < 0:
		facing_direction = "up"
	else:
		facing_direction = "down"
	facing = get_facing_vector()

func get_facing_vector() -> Vector2:
	match facing_direction:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up_right": return Vector2(1.0, -1.0).normalized()
		"up_left": return Vector2(-1.0, -1.0).normalized()
		"down_right": return Vector2(1.0, 1.0).normalized()
		"down_left": return Vector2(-1.0, 1.0).normalized()
		_: return Vector2.DOWN

func get_interaction_point(distance: float = 24.0) -> Vector2:
	return global_position + get_facing_vector() * distance

func request_attack() -> bool:
	if input_locked or spellbound or attack_cooldown > 0.0:
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
	var pushed := global_position + retreat * 12.0
	if world == null or not world.is_blocked(pushed, elevation):
		global_position = pushed
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
	# Sistema de 4 sprites direccionales reales estilo Zelda: A Link to the Past:
	#  - idle_down / walk_down (De frente: rostro, broche frontal, escudo a la izquierda, espada a la derecha)
	#  - idle_up   / walk_up   (De espaldas: capa cubriendo el torso, nuca/cabello completo sin ojos, carcaj/vaina)
	#  - idle_right / walk_right (Perfil derecho real)
	#  - idle_left  / walk_left  (Perfil izquierdo real espejado limpiamente)
	var flicker := 0.35 if invulnerability > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0 else 1.0
	var alpha := Color(1.0, 1.0, 1.0, flicker)

	# Rebote de caminar (walk_*), arco de salto/caída (jump_*), agachado de estabilización (land_*) o respiración (idle_*)
	var bob := 0.0
	var stride := 0.0
	if is_ledge_jumping:
		bob = -ledge_jump_height
		stride = 2.0
	elif land_recovery_timer > 0.0:
		# Compresión/estabilización al tocar tierra (0.2s)
		var land_t := land_recovery_timer / LAND_RECOVERY_DURATION
		bob = 3.2 * sin(land_t * PI)
		stride = 0.0
	elif is_moving:
		bob = -1.5 if (anim_frame == 1 or anim_frame == 3) else 0.0
		stride = 2.5 if anim_frame == 1 else (-2.5 if anim_frame == 3 else 0.0)
	else:
		bob = 0.5 if sin(idle_timer * 3.0) > 0.4 else 0.0

	# Sombra ovalada en el suelo (se achica ligeramente durante el salto y muestra polvo al aterrizar)
	var shadow_scale := 1.0 - (ledge_jump_height / 48.0) if is_ledge_jumping else 1.0
	draw_ground_shadow(Vector2(0, 14), Vector2(10.0 * shadow_scale, 3.2 * shadow_scale), Color(0.0, 0.0, 0.0, 0.38 * flicker))
	if land_recovery_timer > 0.0:
		# Pequeño anillo/nubecitas de polvo al aterrizar y estabilizarse
		var dust_spread := (1.0 - land_recovery_timer / LAND_RECOVERY_DURATION) * 8.0
		var dust_alpha := (land_recovery_timer / LAND_RECOVERY_DURATION) * 0.65
		draw_circle(Vector2(-7.0 - dust_spread, 13.0), 3.0, Color(0.92, 0.85, 0.68, dust_alpha))
		draw_circle(Vector2(7.0 + dust_spread, 13.0), 3.0, Color(0.92, 0.85, 0.68, dust_alpha))

	# Si ataca mirando arriba o en diagonal superior, el barrido de espada se dibuja detrás del cuerpo
	var is_upward := facing_direction in ["up", "up_left", "up_right"]
	if attack_time > 0.0 and is_upward:
		draw_sword_swing(bob, flicker)

	match facing_direction:
		"up":
			draw_sprite_up(bob, stride, alpha)
		"up_right":
			draw_sprite_diag_up(1.0, bob, stride, alpha)
		"up_left":
			draw_sprite_diag_up(-1.0, bob, stride, alpha)
		"left":
			draw_sprite_side(-1.0, bob, stride, alpha)
		"right":
			draw_sprite_side(1.0, bob, stride, alpha)
		"down_right":
			draw_sprite_diag_down(1.0, bob, stride, alpha)
		"down_left":
			draw_sprite_diag_down(-1.0, bob, stride, alpha)
		_:
			draw_sprite_down(bob, stride, alpha)

	# Barrido de espada delante del cuerpo en down / left / right / down_left / down_right
	if attack_time > 0.0 and not is_upward:
		draw_sword_swing(bob, flicker)

	if sting_lit():
		draw_arc(Vector2(0, bob), 21.0, 0.0, TAU, 24, Color("7cecff"), 1.5)

func draw_sprite_down(bob: float, stride: float, alpha: Color) -> void:
	# Botas alternando paso al caminar
	var left_foot_y := 8.0 + (1.5 if stride > 0.0 else (-1.0 if stride < 0.0 else 0.0))
	var right_foot_y := 8.0 + (1.5 if stride < 0.0 else (-1.0 if stride > 0.0 else 0.0))
	draw_rect(Rect2(-7, left_foot_y, 5, 6), Color("352821") * alpha)
	draw_rect(Rect2(2, right_foot_y, 5, 6), Color("352821") * alpha)

	# Capa por detrás del torso
	draw_rect(Rect2(-10, -2 + bob, 20, 12), Color("142938") * alpha)
	# Túnica verde frontal, faldón y cinturón con hebilla dorada
	draw_rect(Rect2(-8, -5 + bob, 16, 14), Color("315d4c") * alpha)
	draw_rect(Rect2(-9, 5 + bob, 18, 4), Color("1c3c34") * alpha)
	draw_rect(Rect2(-8, 2 + bob, 16, 2), Color("895d2c") * alpha)
	draw_rect(Rect2(-2, 2 + bob, 4, 3), Color("d9b650") * alpha)

	# Brazos frontales con balanceo
	draw_rect(Rect2(-10, -2 + bob - stride * 0.4, 3, 8), Color("d7a97d") * alpha)
	draw_rect(Rect2(7, -2 + bob + stride * 0.4, 3, 8), Color("d7a97d") * alpha)

	# Escudo a la izquierda si lleva armadura equipada
	if armor_defense() > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -1 + bob), Vector2(-7, -4 + bob), Vector2(-4, -1 + bob), Vector2(-5, 7 + bob), Vector2(-9, 10 + bob), Vector2(-12, 6 + bob)]), Color("788b94") * alpha)
		draw_line(Vector2(-9, -2 + bob), Vector2(-9, 7 + bob), Color("c8d6d7") * alpha, 1.0)

	# Cabeza y rostro frontal (ojos, flequillo y patillas)
	draw_rect(Rect2(-6, -15 + bob, 12, 11), Color("f1c49d") * alpha)
	draw_rect(Rect2(-7, -18 + bob, 14, 5), Color("6b4026") * alpha)
	draw_rect(Rect2(-7, -14 + bob, 2, 6), Color("6b4026") * alpha)
	draw_rect(Rect2(5, -14 + bob, 2, 6), Color("6b4026") * alpha)
	# Ojos frontales claros
	draw_rect(Rect2(-4, -11 + bob, 2, 3), Color("241a14") * alpha)
	draw_rect(Rect2(2, -11 + bob, 2, 3), Color("241a14") * alpha)

	# Broche de la capa en el hombro izquierdo
	draw_circle(Vector2(-6, -3 + bob), 1.8, Color("d5b95f") * alpha)
	# Arma / Arco
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(10, 3 + bob), 7.0, -PI * 0.5, PI * 0.5, 8, Color("c98a4b") * alpha, 2.0)
	elif attack_time <= 0.0:
		draw_line(Vector2(8, 3 + bob), Vector2(13, 11 + bob), Color("b8c6c9") * alpha, 2.0)

func draw_sprite_up(bob: float, stride: float, alpha: Color) -> void:
	# Botas vistas desde atrás alternando paso
	var left_foot_y := 8.0 + (1.5 if stride < 0.0 else (-1.0 if stride > 0.0 else 0.0))
	var right_foot_y := 8.0 + (1.5 if stride > 0.0 else (-1.0 if stride < 0.0 else 0.0))
	draw_rect(Rect2(-7, left_foot_y, 5, 6), Color("352821") * alpha)
	draw_rect(Rect2(2, right_foot_y, 5, 6), Color("352821") * alpha)

	# Brazos laterales vistos por detrás
	draw_rect(Rect2(-10, -2 + bob + stride * 0.4, 3, 8), Color("d7a97d") * alpha)
	draw_rect(Rect2(7, -2 + bob - stride * 0.4, 3, 8), Color("d7a97d") * alpha)

	# Espalda: túnica inferior y gran capa azul de montaraz cubriendo los hombros y espalda
	draw_rect(Rect2(-8, 4 + bob, 16, 6), Color("1c3c34") * alpha)
	draw_rect(Rect2(-10, -5 + bob, 20, 14), Color("142938") * alpha)
	draw_rect(Rect2(-8, -4 + bob, 16, 11), Color("1d3a4f") * alpha)
	# Correa diagonal del tahalí / carcaj en la espalda
	draw_line(Vector2(-6, -4 + bob), Vector2(6, 7 + bob), Color("895d2c") * alpha, 2.0)

	# Escudo a la espalda / costado derecho
	if armor_defense() > 0:
		draw_rect(Rect2(7, -2 + bob, 5, 10), Color("788b94") * alpha)
		draw_line(Vector2(9, -1 + bob), Vector2(9, 7 + bob), Color("c8d6d7") * alpha, 1.0)
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(-4, 1 + bob), 7.0, PI * 0.6, PI * 1.4, 8, Color("c98a4b") * alpha, 2.0)
	elif attack_time <= 0.0:
		# Empuñadura asomando sobre el hombro
		draw_line(Vector2(5, -6 + bob), Vector2(10, -11 + bob), Color("d7a846") * alpha, 2.0)

	# Cabeza vista de espaldas (cabello completo cubriendo nuca y orejas, sin rostro)
	draw_rect(Rect2(-7, -18 + bob, 14, 13), Color("6b4026") * alpha)
	draw_rect(Rect2(-6, -17 + bob, 12, 4), Color("825032") * alpha)
	draw_rect(Rect2(-5, -6 + bob, 10, 2), Color("52301b") * alpha)

func draw_sprite_side(dir_sign: float, bob: float, stride: float, alpha: Color) -> void:
	# Perfil real (dir_sign = +1.0 para derecha, -1.0 para izquierda)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir_sign, 1.0))

	# Pierna trasera y delantera con zancada real de perfil
	draw_rect(Rect2(-4 - stride, 8, 5, 6), Color("261c17") * alpha)
	draw_rect(Rect2(-1 + stride, 8, 6, 6), Color("3d2d24") * alpha)

	# Capa ondeando ligeramente hacia atrás (lado izquierdo del perfil local)
	draw_rect(Rect2(-9, -4 + bob, 10, 14), Color("142938") * alpha)
	draw_rect(Rect2(-11, 2 + bob, 4, 8), Color("1d3a4f") * alpha)

	# Torso de perfil (túnica verde y cinturón con hebilla hacia adelante)
	draw_rect(Rect2(-5, -5 + bob, 11, 14), Color("315d4c") * alpha)
	draw_rect(Rect2(-6, 5 + bob, 12, 4), Color("1c3c34") * alpha)
	draw_rect(Rect2(-5, 2 + bob, 11, 2), Color("895d2c") * alpha)
	draw_rect(Rect2(3, 2 + bob, 3, 3), Color("d9b650") * alpha)

	# Cabeza de perfil (rostro orientado hacia +X, cabello largo en la nuca -X)
	draw_rect(Rect2(-5, -15 + bob, 11, 11), Color("f1c49d") * alpha)
	# Nariz sutil de perfil
	draw_rect(Rect2(6, -10 + bob, 2, 2), Color("e0b088") * alpha)
	# Cabello superior y nuca
	draw_rect(Rect2(-7, -18 + bob, 13, 5), Color("6b4026") * alpha)
	draw_rect(Rect2(-7, -14 + bob, 6, 9), Color("6b4026") * alpha)
	# Un solo ojo mirando hacia adelante (+X)
	draw_rect(Rect2(2, -11 + bob, 2, 3), Color("241a14") * alpha)

	# Brazo en primer plano balanceándose al caminar
	draw_rect(Rect2(-1 - stride * 0.5, -1 + bob, 4, 8), Color("d7a97d") * alpha)

	# Escudo o arco/espada orientados hacia adelante
	if armor_defense() > 0:
		draw_rect(Rect2(3, -2 + bob, 5, 10), Color("788b94") * alpha)
		draw_line(Vector2(6, -1 + bob), Vector2(6, 7 + bob), Color("c8d6d7") * alpha, 1.0)
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(6, 2 + bob), 7.0, -PI * 0.45, PI * 0.45, 8, Color("c98a4b") * alpha, 2.0)
	elif attack_time <= 0.0:
		draw_line(Vector2(2, 5 + bob), Vector2(12, 8 + bob), Color("b8c6c9") * alpha, 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_sprite_diag_down(dir_sign: float, bob: float, stride: float, alpha: Color) -> void:
	# Vista 3/4 frontal-lateral (down_right con +1.0, down_left con -1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir_sign, 1.0))

	# Botas con zancada diagonal
	draw_rect(Rect2(-6 - stride * 0.6, 8 + (1.0 if stride > 0.0 else 0.0), 5, 6), Color("2b201a") * alpha)
	draw_rect(Rect2(1 + stride * 0.6, 8 + (1.0 if stride < 0.0 else 0.0), 5, 6), Color("3d2d24") * alpha)

	# Capa asomando más por el hombro trasero (-X)
	draw_rect(Rect2(-10, -3 + bob, 16, 13), Color("142938") * alpha)
	draw_rect(Rect2(-11, 2 + bob, 4, 8), Color("1d3a4f") * alpha)

	# Túnica verde y cinturón desplazado en 3/4 hacia +X
	draw_rect(Rect2(-7, -5 + bob, 14, 14), Color("315d4c") * alpha)
	draw_rect(Rect2(-8, 5 + bob, 16, 4), Color("1c3c34") * alpha)
	draw_rect(Rect2(-7, 2 + bob, 14, 2), Color("895d2c") * alpha)
	draw_rect(Rect2(0, 2 + bob, 4, 3), Color("d9b650") * alpha)

	# Cabeza en 3/4 frontal: dos ojos desplazados hacia adelante (+X) y melena en el lado trasero (-X)
	draw_rect(Rect2(-5, -15 + bob, 12, 11), Color("f1c49d") * alpha)
	draw_rect(Rect2(-7, -18 + bob, 14, 5), Color("6b4026") * alpha)
	draw_rect(Rect2(-7, -14 + bob, 4, 8), Color("6b4026") * alpha)
	draw_rect(Rect2(-1, -11 + bob, 2, 3), Color("241a14") * alpha)
	draw_rect(Rect2(4, -11 + bob, 2, 3), Color("241a14") * alpha)

	# Broche y brazo delantero
	draw_circle(Vector2(-4, -3 + bob), 1.8, Color("d5b95f") * alpha)
	draw_rect(Rect2(5, -2 + bob + stride * 0.4, 4, 8), Color("d7a97d") * alpha)

	if armor_defense() > 0:
		draw_rect(Rect2(-11, -1 + bob, 5, 10), Color("788b94") * alpha)
		draw_line(Vector2(-8, 0 + bob), Vector2(-8, 7 + bob), Color("c8d6d7") * alpha, 1.0)
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(8, 3 + bob), 7.0, -PI * 0.45, PI * 0.45, 8, Color("c98a4b") * alpha, 2.0)
	elif attack_time <= 0.0:
		draw_line(Vector2(6, 4 + bob), Vector2(13, 10 + bob), Color("b8c6c9") * alpha, 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_sprite_diag_up(dir_sign: float, bob: float, stride: float, alpha: Color) -> void:
	# Vista 3/4 dorsal-lateral (up_right con +1.0, up_left con -1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir_sign, 1.0))

	# Botas vistas desde atrás en ángulo 3/4
	draw_rect(Rect2(-6 + stride * 0.6, 8 + (1.0 if stride < 0.0 else 0.0), 5, 6), Color("2b201a") * alpha)
	draw_rect(Rect2(1 - stride * 0.6, 8 + (1.0 if stride > 0.0 else 0.0), 5, 6), Color("3d2d24") * alpha)

	# Brazo adelantado en el lateral (+X)
	draw_rect(Rect2(5, -2 + bob - stride * 0.4, 4, 8), Color("d7a97d") * alpha)

	# Espalda girada 3/4: capa cubriendo casi todo el torso y borde de túnica en +X
	draw_rect(Rect2(-7, 4 + bob, 14, 5), Color("1c3c34") * alpha)
	draw_rect(Rect2(-9, -5 + bob, 17, 14), Color("142938") * alpha)
	draw_rect(Rect2(-7, -4 + bob, 13, 11), Color("1d3a4f") * alpha)
	draw_line(Vector2(-5, -4 + bob), Vector2(5, 6 + bob), Color("895d2c") * alpha, 2.0)

	# Escudo / arma en el costado
	if armor_defense() > 0:
		draw_rect(Rect2(6, -2 + bob, 5, 10), Color("788b94") * alpha)
		draw_line(Vector2(8, -1 + bob), Vector2(8, 7 + bob), Color("c8d6d7") * alpha, 1.0)
	if active_item == "bow" and bow_unlocked:
		draw_arc(Vector2(6, 0 + bob), 7.0, -PI * 0.6, PI * 0.25, 8, Color("c98a4b") * alpha, 2.0)
	elif attack_time <= 0.0:
		draw_line(Vector2(4, -5 + bob), Vector2(11, -10 + bob), Color("d7a846") * alpha, 2.0)

	# Cabeza girada 3/4 dorsal: mayormente cabello y una pequeña franja de mejilla en el borde +X
	draw_rect(Rect2(-7, -18 + bob, 13, 13), Color("6b4026") * alpha)
	draw_rect(Rect2(-6, -17 + bob, 11, 4), Color("825032") * alpha)
	draw_rect(Rect2(4, -13 + bob, 3, 7), Color("f1c49d") * alpha)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
