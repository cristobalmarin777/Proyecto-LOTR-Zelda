extends SceneTree

# Ejecutar con --headless --script res://tests/saruman_duel.gd --quit-after 300.
func _initialize() -> void:
	call_deferred("run")

func press_key(window: Window, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	window.push_input(event)
	event.pressed = false
	window.push_input(event)

func run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var p: MiddleEarthPlayer = game.player
	var tower: Dictionary = game.world.poi_for_chunk(game.world.landmarks.isengard_center())
	var doorstep: Vector2 = tower.position + Vector2(0,88)
	game.saruman_defeated = false
	var departure := p.global_position
	press_key(root, KEY_ESCAPE)
	assert(paused and game.pause_menu.visible)
	game.pause_menu.get_cancel_button().pressed.emit()
	await process_frame
	assert(not paused and p.global_position == departure)
	press_key(root, KEY_ESCAPE)
	game.pause_menu.get_ok_button().pressed.emit()
	await process_frame
	assert(not paused and not game.pause_menu.visible and p.global_position == doorstep)
	assert(not game.world.is_blocked(doorstep))
	press_key(root, KEY_E)
	var boss: SarumanBoss = game.saruman
	assert(boss != null and game.in_dungeon)
	game.advance_dialog()
	p.hp = 6
	p.invulnerability = 0
	p.equipped_armor_id = "traveler_cloak"
	boss.begin_spell()
	boss.release_spell()
	assert(boss.bolts.size() == 1)
	boss.bolts.clear()
	boss.begin_spell()
	assert(boss.spell == SarumanBoss.Spell.GRASP)
	p.global_position.x += 40
	boss.release_spell()
	assert(not p.spellbound and p.hp == 6)
	boss.sequence = 1
	boss.begin_spell()
	boss.release_spell()
	assert(p.spellbound and p.hp == 6)
	for i in 60:
		boss._physics_process(1.0/60)
		if not p.spellbound:
			break
	assert(not p.spellbound and p.hp == 4 and not game.dungeon.is_blocked(p.global_position))
	p.global_position = boss.global_position + Vector2(0,25)
	game.resolve_player_attack(p.global_position, Vector2.UP, 35)
	assert(boss.hp == 37 and boss.phase == 1)
	game.spawn_player_arrow()
	var arrow := game.get_child(-1) as PlayerArrow
	assert(arrow != null)
	arrow.global_position = boss.global_position + Vector2(0,5)
	arrow.direction = Vector2.UP
	arrow._physics_process(0.01)
	assert(boss.hp == 36 and boss.phase == 2)
	boss._physics_process(1.3)
	boss.release_spell()
	assert(boss.bolts.size() == 3)
	boss.bolts.clear()
	boss.begin_spell()
	assert(boss.spell == SarumanBoss.Spell.SIGILS)
	p.invulnerability = 0
	boss.release_spell()
	assert(p.hp == 2)
	p.invulnerability = 0
	p.take_damage(2, boss.global_position)
	assert(game.saruman == null and not game.in_dungeon and p.global_position == doorstep)
	game.interact()
	game.advance_dialog()
	boss = game.saruman
	assert(boss.hp == boss.max_hp and boss.phase == 1)
	boss.take_hit(36, p.global_position)
	boss._physics_process(1.3)
	boss.take_hit(36, p.global_position)
	assert(game.saruman == null and game.saruman_defeated and not game.in_dungeon)
	game.advance_dialog()
	game.interact()
	assert(game.saruman == null and game.dialog_active)
	game.advance_dialog()
	press_key(root, KEY_ESCAPE)
	game.pause_menu.get_ok_button().pressed.emit()
	await process_frame
	press_key(root, KEY_E)
	assert(game.saruman != null and game.saruman_defeated)
	game.advance_dialog()
	var previous_xp := p.xp
	var previous_level := p.level
	game.saruman.take_hit(36, p.global_position)
	game.saruman._physics_process(1.3)
	game.saruman.take_hit(36, p.global_position)
	assert(game.saruman == null and game.saruman_defeated and p.xp == previous_xp and p.level == previous_level)
	print("OK: pausa, viaje a Orthanc, duelo completo y revancha sin duplicar experiencia.")
	quit()
