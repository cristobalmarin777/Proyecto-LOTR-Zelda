class_name MiddleEarthEnemy
extends Node2D

signal defeated(enemy: MiddleEarthEnemy)

var world: MiddleEarthWorld
var target: MiddleEarthPlayer
var enemy_type := "orc"
var display_name := "Orco Explorador"
var max_hp := 3
var hp := 3
var damage := 1
var speed := 76.0
var detection_radius := 175.0
var xp_reward := 20
var threat := 0
var is_mini_boss := false
var hurt_time := 0.0
var shoot_cooldown := 1.1
var flee_time := 0.0
var stolen_coins := 0
var patrol_direction := Vector2.RIGHT
var patrol_time := 1.5
var animation_time := 0.0

func configure(kind: String, spawn_position: Vector2, player_ref: MiddleEarthPlayer, world_ref: MiddleEarthWorld, danger: int = 0, mini_boss: bool = false) -> void:
	enemy_type = kind
	global_position = spawn_position
	target = player_ref
	world = world_ref
	threat = danger
	is_mini_boss = mini_boss
	match enemy_type:
		"spider":
			display_name = "Araña del Bosque Viejo"
			max_hp = 2; damage = 1; speed = 112.0; detection_radius = 195.0; xp_reward = 18
		"uruk":
			display_name = "Capitán Uruk-hai" if is_mini_boss else "Uruk-hai"
			max_hp = 9; damage = 2; speed = 92.0; detection_radius = 230.0; xp_reward = 80
		"goblin":
			display_name = "Duende Saqueador"
			max_hp = 1; damage = 1; speed = 122.0; detection_radius = 165.0; xp_reward = 8
		"archer_orc":
			display_name = "Orco Arquero"
			max_hp = 2; damage = 1; speed = 58.0; detection_radius = 245.0; xp_reward = 28
		_:
			display_name = "Orco Explorador"
			max_hp = 3; damage = 1; speed = 76.0; detection_radius = 175.0; xp_reward = 20
	if threat > 0:
		max_hp += threat * (3 if enemy_type == "uruk" else 2)
		damage += floori(float(threat + 1) / 2.0)
		xp_reward += threat * 12
		display_name += " · Amenaza %d" % threat
	hp = max_hp
	patrol_direction = Vector2.from_angle(world.hash01(floori(spawn_position.x), floori(spawn_position.y), 77) * TAU)
	add_to_group("enemies")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if target == null or world == null:
		return
	hurt_time = maxf(0.0, hurt_time - delta)
	animation_time += delta * (7.0 if enemy_type != "spider" else 10.0)
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	var offset := target.global_position - global_position
	var distance := offset.length()
	if enemy_type == "goblin" and flee_time > 0.0:
		flee_time -= delta
		move((global_position - target.global_position).normalized() * 250.0 * delta)
		if flee_time <= 0.0:
			queue_free()
		return
	if enemy_type == "archer_orc" and distance <= detection_radius:
		if distance < 125.0:
			move(-offset.normalized() * speed * delta)
		if shoot_cooldown <= 0.0:
			shoot_cooldown = 1.65
			var scene := get_tree().current_scene
			if scene.has_method("spawn_enemy_arrow"):
				scene.spawn_enemy_arrow(global_position, target.global_position, damage)
		queue_redraw()
		return
	if distance <= detection_radius:
		var current_speed := speed
		if enemy_type == "spider" and fmod(Time.get_ticks_msec() * 0.001, 1.6) < 0.35:
			current_speed *= 1.45
		elif enemy_type == "uruk" and hp <= max_hp / 2:
			current_speed *= 1.25
		move(offset.normalized() * current_speed * delta)
		if distance < 24.0:
			if target.take_damage(damage, global_position) and enemy_type == "goblin" and flee_time <= 0.0:
				stolen_coins = mini(target.coins, 3 + floori(world.hash01(floori(global_position.x), floori(global_position.y), 123) * 5.0))
				target.coins -= stolen_coins
				flee_time = 1.8
	else:
		patrol_time -= delta
		if patrol_time <= 0.0:
			patrol_time = 1.8 + world.hash01(floori(global_position.x), floori(global_position.y), 44) * 2.0
			patrol_direction = patrol_direction.rotated(PI * 0.75)
		move(patrol_direction * speed * 0.35 * delta)
	queue_redraw()

func move(step: Vector2) -> void:
	var desired := global_position + step
	if not world.is_blocked(desired):
		global_position = desired
	else:
		patrol_direction = -patrol_direction

func take_hit(amount: int, source_position: Vector2) -> bool:
	hp -= amount
	hurt_time = 0.14
	var knockback := (global_position - source_position).normalized() * (16.0 if enemy_type == "uruk" else 25.0)
	move(knockback)
	if hp <= 0:
		if target != null:
			target.add_xp(xp_reward)
		defeated.emit(self)
		queue_free()
	else:
		queue_redraw()
	return true

func _draw() -> void:
	var bob := sin(animation_time) * 1.0
	var flash := hurt_time > 0.0
	draw_shadow(Vector2(0, 13 + bob), Vector2(11, 3))
	match enemy_type:
		"spider": draw_spider(bob, flash)
		"uruk": draw_uruk(bob, flash)
		"goblin": draw_goblin(bob, flash)
		"archer_orc": draw_orc_archer(bob, flash)
		_: draw_orc(bob, flash)
	var ratio := float(maxi(hp, 0)) / float(max_hp)
	var bar_y := -25.0 if enemy_type == "uruk" else -21.0
	draw_rect(Rect2(-13, bar_y, 26, 4), Color("211518"))
	draw_rect(Rect2(-12, bar_y + 1, 24.0 * ratio, 2), Color("d4524f"))

func draw_shadow(center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for index in range(14):
		points.append(center + Vector2.from_angle(TAU * float(index) / 14.0) * radius)
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.38))

func hurt_color(base: Color, flash: bool) -> Color:
	return Color("fff1d0") if flash else base

func draw_orc(bob: float, flash: bool) -> void:
	var skin := hurt_color(Color("73934f"), flash)
	# Botas, túnica de cuero y hombreras.
	draw_rect(Rect2(-8, 8 + bob, 6, 5), Color("35261d"))
	draw_rect(Rect2(2, 8 - bob, 6, 5), Color("35261d"))
	draw_rect(Rect2(-10, -3 + bob, 20, 13), Color("39442b"))
	draw_rect(Rect2(-8, -6 + bob, 16, 14), Color("63723a"))
	draw_rect(Rect2(-9, 2 + bob, 18, 3), Color("51351f"))
	draw_circle(Vector2(0, -12 + bob), 7.0, skin)
	# Orejas, casco y ojos amenazantes.
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -13 + bob), Vector2(-12, -15 + bob), Vector2(-7, -9 + bob)]), skin)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -13 + bob), Vector2(12, -15 + bob), Vector2(7, -9 + bob)]), skin)
	draw_rect(Rect2(-8, -19 + bob, 16, 5), Color("3a3c37"))
	draw_rect(Rect2(-5, -22 + bob, 10, 4), Color("51544d"))
	draw_rect(Rect2(-5, -12 + bob, 3, 2), Color("ffcf47"))
	draw_rect(Rect2(2, -12 + bob, 3, 2), Color("ffcf47"))
	# Cimitarra y escudo de tablones.
	draw_line(Vector2(10, 1 + bob), Vector2(15, -13 + bob), Color("292e30"), 4.0)
	draw_line(Vector2(10, 1 + bob), Vector2(15, -13 + bob), Color("c5d0cc"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -3 + bob), Vector2(-7, -6 + bob), Vector2(-5, 7 + bob), Vector2(-11, 9 + bob)]), Color("5d3b28"))

func draw_orc_archer(bob: float, flash: bool) -> void:
	draw_orc(bob, flash)
	# El arco se ve claramente separado de la cimitarra del explorador.
	draw_arc(Vector2(13, -4 + bob), 10.0, -PI * 0.55, PI * 0.55, 10, Color("d7a360"), 2.0)
	draw_line(Vector2(14, -13 + bob), Vector2(14, 5 + bob), Color("eee1bd"), 1.0)
	draw_line(Vector2(-6, 8 + bob), Vector2(-12, 13 + bob), Color("9b6b3a"), 2.0)

func draw_uruk(bob: float, flash: bool) -> void:
	var armor := hurt_color(Color("44362f"), flash)
	draw_rect(Rect2(-11, 8 + bob, 8, 6), Color("261c18"))
	draw_rect(Rect2(3, 8 - bob, 8, 6), Color("261c18"))
	draw_rect(Rect2(-13, -5 + bob, 26, 15), Color("2c2926"))
	draw_rect(Rect2(-10, -7 + bob, 20, 17), armor)
	draw_rect(Rect2(-12, -5 + bob, 5, 6), Color("68635b"))
	draw_rect(Rect2(7, -5 + bob, 5, 6), Color("68635b"))
	draw_circle(Vector2(0, -14 + bob), 8.0, Color("7f5d46") if not flash else Color("fff1d0"))
	draw_rect(Rect2(-9, -22 + bob, 18, 7), Color("272827"))
	draw_rect(Rect2(-5, -25 + bob, 10, 4), Color("3f4141"))
	draw_rect(Rect2(-6, -14 + bob, 4, 2), Color("ff642f"))
	draw_rect(Rect2(2, -14 + bob, 4, 2), Color("ff642f"))
	# Gran espada Uruk y marca blanca de la Mano.
	draw_line(Vector2(11, 4 + bob), Vector2(19, -17 + bob), Color("20262a"), 6.0)
	draw_line(Vector2(11, 4 + bob), Vector2(19, -17 + bob), Color("d2d7d2"), 3.0)
	draw_rect(Rect2(-2, -2 + bob, 4, 8), Color("f2f0dc"))
	draw_rect(Rect2(-5, 1 + bob, 10, 2), Color("f2f0dc"))

func draw_goblin(bob: float, flash: bool) -> void:
	var skin := hurt_color(Color("94a944"), flash)
	draw_rect(Rect2(-6, 6 + bob, 5, 6), Color("34291e"))
	draw_rect(Rect2(1, 6 - bob, 5, 6), Color("34291e"))
	draw_rect(Rect2(-7, -2 + bob, 14, 10), Color("6b7130"))
	draw_circle(Vector2(0, -9 + bob), 6.0, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10 + bob), Vector2(-12, -13 + bob), Vector2(-6, -6 + bob)]), skin)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -10 + bob), Vector2(12, -13 + bob), Vector2(6, -6 + bob)]), skin)
	draw_rect(Rect2(-4, -11 + bob, 2, 2), Color("ffde54"))
	draw_rect(Rect2(2, -11 + bob, 2, 2), Color("ffde54"))
	draw_line(Vector2(7, 2 + bob), Vector2(13, -4 + bob), Color("b9b0a2"), 2.0)
	# Saco de monedas: diferencia inmediata respecto a los orcos.
	draw_circle(Vector2(-9, 5 + bob), 5.0, Color("86613a"))
	draw_line(Vector2(-12, 1 + bob), Vector2(-6, 1 + bob), Color("d8af52"), 1.0)

func draw_spider(bob: float, flash: bool) -> void:
	var shell := hurt_color(Color("3c2944"), flash)
	var leg_color := Color("23182a") if not flash else Color("fff1d0")
	# Ocho patas articuladas; sus posiciones alternan para una vibración orgánica.
	for side in [-1.0, 1.0]:
		for index in range(4):
			var y := -6.0 + float(index) * 4.0
			var wiggle := sin(animation_time + float(index)) * 2.0
			var hip := Vector2(side * 7.0, y + bob)
			var knee := Vector2(side * (14.0 + float(index) * 1.5), y + wiggle + bob)
			var foot := Vector2(side * (20.0 - float(index)), y + 8.0 + bob)
			draw_line(hip, knee, leg_color, 3.0)
			draw_line(knee, foot, leg_color, 2.0)
	draw_circle(Vector2(4, 0 + bob), 11.0, shell)
	draw_circle(Vector2(-7, -2 + bob), 8.0, Color("56355a") if not flash else Color("fff1d0"))
	draw_circle(Vector2(7, -3 + bob), 4.0, Color("69406d") if not flash else Color("fff1d0"))
	for eye in [Vector2(-10, -5 + bob), Vector2(-5, -6 + bob), Vector2(-9, -1 + bob), Vector2(-4, -2 + bob)]:
		draw_circle(eye, 1.5, Color("ef4d48"))

