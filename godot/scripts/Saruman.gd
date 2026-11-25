class_name SarumanBoss
extends MiddleEarthEnemy

enum State { RECOVER, AIM, FLING, TRANSFORM, FINISHED }
enum Spell { FIRE, GRASP, SIGILS }

const HEALTH := 72
const WHITE_PATTERN := [Spell.FIRE, Spell.GRASP]
const PRISM_PATTERN := [Spell.FIRE, Spell.SIGILS, Spell.GRASP, Spell.SIGILS]
const EMBER := Color("#ff9851")
const VIOLET := Color("#c3a1e6")
const TEAL := Color("#69ebdb")
const RUNE_RADIUS := 40.0

var phase := 1
var state := State.RECOVER
var spell := Spell.FIRE
var sequence := 0
var timer := 1.5
var aim_time := 0.0
var marked := Vector2.ZERO
var aim := Vector2.DOWN
var runes := PackedVector2Array()
var bolts: Array[Dictionary] = []
var impact := Vector2.ZERO
var flash := 0.0
var sigil_burst := 0.0

func prepare(player_ref: MiddleEarthPlayer, hall: OrthancHall) -> void:
	target = player_ref
	world = hall
	enemy_type = "saruman"
	is_mini_boss = true
	max_hp = HEALTH
	hp = HEALTH
	global_position = OrthancHall.THRONE
	add_to_group("enemies")

func take_hit(amount: int, _origin: Vector2) -> bool:
	if state == State.FINISHED or state == State.TRANSFORM or target.input_locked:
		return false
	hp = maxi(0, hp - amount)
	flash = 0.12
	if phase == 1 and hp <= HEALTH / 2:
		hp = HEALTH / 2
		phase = 2
		sequence = 0
		cancel_spells()
		state = State.TRANSFORM
		timer = 1.2
	elif hp == 0:
		finish()
		defeated.emit(self)
	queue_redraw()
	return true

func cancel_spells() -> void:
	target.spellbound = false
	bolts.clear()
	sigil_burst = 0.0

func finish() -> void:
	cancel_spells()
	state = State.FINISHED
	set_physics_process(false)
	hide()

func _physics_process(delta: float) -> void:
	if state == State.FINISHED or target.input_locked:
		return
	animation_time += delta
	flash = maxf(0, flash - delta)
	sigil_burst = maxf(0, sigil_burst - delta)
	advance_bolts(delta)
	if state == State.FINISHED:
		return
	timer -= delta
	match state:
		State.FLING:
			target.global_position = target.global_position.move_toward(impact, 850 * delta)
			if target.global_position == impact:
				target.spellbound = false
				recover()
				# El retroceso del daño apunta hacia dentro de la sala.
				target.take_damage(2, impact + aim * 16)
		State.RECOVER:
			if timer <= 0:
				begin_spell()
		State.AIM:
			if timer <= 0:
				release_spell()
		State.TRANSFORM:
			if timer <= 0:
				begin_spell()
	queue_redraw()

func recover() -> void:
	state = State.RECOVER
	timer = 1.25 if phase == 1 else 1.05

func begin_spell() -> void:
	var pattern := WHITE_PATTERN if phase == 1 else PRISM_PATTERN
	spell = pattern[sequence % pattern.size()]
	sequence += 1
	marked = target.global_position
	aim = global_position.direction_to(marked)
	if aim.is_zero_approx():
		aim = Vector2.DOWN
	state = State.AIM
	aim_time = 0.78
	if spell == Spell.GRASP:
		aim_time = 0.68
	elif spell == Spell.SIGILS:
		aim_time = 1.0
		var across := aim.orthogonal() * 94
		runes = PackedVector2Array([marked, marked + across, marked - across])
	timer = aim_time

func release_spell() -> void:
	recover()
	match spell:
		Spell.FIRE:
			var angles := [0] if phase == 1 else [-19, 0, 19]
			for angle in angles:
				var dir := aim.rotated(deg_to_rad(angle))
				bolts.append({"pos": global_position + dir * 15, "dir": dir})
		Spell.GRASP:
			if target.global_position.distance_to(marked) <= 26:
				var room := OrthancHall.WALKABLE.grow(-2)
				var corner := Vector2(room.end.x if aim.x >= 0 else room.position.x,
					room.end.y if aim.y >= 0 else room.position.y)
				var gap := corner - target.global_position
				var dx := gap.x / aim.x if absf(aim.x) > 0.0001 else INF
				var dy := gap.y / aim.y if absf(aim.y) > 0.0001 else INF
				impact = (target.global_position + aim * maxf(0, minf(dx,dy))).clamp(room.position, room.end)
				target.spellbound = true
				state = State.FLING
		Spell.SIGILS:
			sigil_burst = 0.26
			for rune in runes:
				if rune.distance_to(target.global_position) <= RUNE_RADIUS:
					target.take_damage(2, rune)
					break

func advance_bolts(delta: float) -> void:
	for i in range(bolts.size()-1, -1, -1):
		var bolt := bolts[i]
		var from: Vector2 = bolt.pos
		var to: Vector2 = from + bolt.dir * 205.0 * delta
		if Geometry2D.get_closest_point_to_segment(target.global_position, from, to).distance_to(target.global_position) < 13:
			bolts.remove_at(i)
			target.take_damage(1, from)
			if state == State.FINISHED:
				return
		elif not OrthancHall.WALKABLE.has_point(to):
			bolts.remove_at(i)
		else:
			bolt.pos = to

func _draw() -> void:
	var accent := EMBER
	if spell == Spell.GRASP:
		accent = VIOLET
	elif spell == Spell.SIGILS:
		accent = TEAL
	if state == State.AIM:
		var charge := clampf(1.0 - timer / aim_time, 0, 1)
		match spell:
			Spell.FIRE:
				draw_line(aim * 18, aim * (40 + 24 * charge), EMBER, 2)
			Spell.GRASP:
				var p := marked - global_position
				draw_arc(p, 26, 0, TAU, 32, Color(VIOLET, 0.55), 1.5)
				draw_arc(p, 8 + 16 * charge, -PI * 0.8, PI * 0.35, 18, VIOLET, 2)
			Spell.SIGILS:
				for rune in runes:
					var p := rune - global_position
					draw_arc(p, RUNE_RADIUS, 0, TAU, 32, TEAL, 2)
					draw_arc(p, 3 + 36 * charge, 0, TAU, 4, Color(TEAL,0.75), 2)
	if sigil_burst > 0:
		for rune in runes:
			draw_circle(rune-global_position, RUNE_RADIUS, Color(TEAL, sigil_burst * 2))
	if state == State.FLING:
		draw_arc(target.global_position-global_position, 14, 0, TAU, 20, VIOLET, 2)
	for bolt in bolts:
		var p: Vector2 = bolt.pos - global_position
		draw_line(p - bolt.dir * 12, p, EMBER, 4)
		draw_circle(p, 6, Color("#e55f2b"))
		draw_circle(p, 3, Color("#fff4be"))
	# La túnica se abre en pliegues iridiscentes al revelar la segunda fase.
	draw_rect(Rect2(-13, 11, 27, 4), Color("#222432"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-9),Vector2(7,-9),Vector2(13,13),Vector2(-13,13)]), Color("#bfc1c8"))
	for i in range(5):
		var tint := Color.from_hsv(fposmod(animation_time * 0.20 + i * 0.17,1),0.57,1) if phase == 2 else Color("#f1ecdc")
		draw_line(Vector2(i * 2 - 4, -7), Vector2(i * 5 - 10, 11), Color.WHITE if flash > 0 else tint, 3)
	draw_rect(Rect2(-7,-23,14,13), Color("#eee8d6"))
	draw_rect(Rect2(-5,-20,10,7), Color("#c49879"))
	draw_rect(Rect2(-4,-18,3,2), Color("#34323d"))
	draw_rect(Rect2(2,-18,3,2), Color("#34323d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-14),Vector2(5,-14),Vector2(1,1),Vector2(-4,-7)]), Color("#fffbed"))
	draw_line(Vector2(12,12),Vector2(15,-23),Color("#c6bdab"),3)
	draw_circle(Vector2(15,-25), 5 if state == State.AIM else 3, accent if state == State.AIM else Color.WHITE)
	if state == State.TRANSFORM:
		draw_arc(Vector2.ZERO, 19 + (1.2-timer)*42, 0, TAU, 48, Color.from_hsv(fposmod(animation_time,1),0.6,1),3)
