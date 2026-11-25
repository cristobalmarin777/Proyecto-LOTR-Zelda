extends SceneTree

# Ejecutar con --headless --script res://tests/saruman_duel.gd --quit-after 300.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var p: MiddleEarthPlayer = game.player
	var tower: Dictionary = game.world.poi_for_chunk(game.world.landmarks.isengard_center())
	var doorstep: Vector2 = tower.position + Vector2(0,88)
	game.saruman_defeated = false
	p.global_position = doorstep
	assert(not game.world.is_blocked(doorstep))
	game.interact()
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
	print("OK: acceso, fuego, esquiva, impacto, cambio de fase, espada, arco, derrota y victoria.")
	quit()
