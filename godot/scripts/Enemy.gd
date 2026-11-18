class_name MiddleEarthEnemy
extends Node2D

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
var hurt_time := 0.0
var shoot_cooldown := 1.1
var flee_time := 0.0
var stolen_coins := 0
var patrol_direction := Vector2.RIGHT
var patrol_time := 1.5

func configure(kind: String, spawn_position: Vector2, player_ref: MiddleEarthPlayer, world_ref: MiddleEarthWorld, danger: int = 0) -> void:
	enemy_type = kind
	global_position = spawn_position
	target = player_ref
	world = world_ref
	threat = danger
	match enemy_type:
		"spider":
			display_name = "Araña del Bosque Viejo"
			max_hp = 2; damage = 1; speed = 112.0; detection_radius = 195.0; xp_reward = 18
		"uruk":
			display_name = "Capitán Uruk-hai"
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
		queue_free()
	else:
		queue_redraw()
	return true

func _draw() -> void:
	var body_color := Color("658c47")
	match enemy_type:
		"spider": body_color = Color("3b263d")
		"uruk": body_color = Color("4f3428")
		"goblin": body_color = Color("7e9b35")
		"archer_orc": body_color = Color("637b42")
	if hurt_time > 0.0:
		body_color = Color("fff0d0")
	if enemy_type == "spider":
		draw_circle(Vector2.ZERO, 10.0, body_color)
		for angle in [0.35, 0.9, 2.25, 2.8, 3.5, 4.05, 5.4, 5.95]:
			draw_line(Vector2.from_angle(angle) * 6.0, Vector2.from_angle(angle) * 16.0, body_color, 2.0)
	else:
		draw_circle(Vector2(0, -5), 6.0, Color("d3aa82"))
		draw_rect(Rect2(-9, 0, 18, 14), body_color)
		if enemy_type == "archer_orc":
			draw_line(Vector2(-13, -9), Vector2(13, 9), Color("d9b169"), 2.0)
	var ratio := float(maxi(hp, 0)) / float(max_hp)
	draw_rect(Rect2(-12, -19, 24, 3), Color("221717"))
	draw_rect(Rect2(-12, -19, 24.0 * ratio, 3), Color("d4524f"))

