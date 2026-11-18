class_name DarknessOverlay
extends Node2D

## La capa oscurece únicamente el entorno. Se dibuja después del mundo y antes
## del jugador, que conserva su silueta luminosa al entrar al Bosque Viejo.
var player: MiddleEarthPlayer
var world: MiddleEarthWorld
var sprite: Sprite2D
var gradient: Gradient
var last_darkness := -1.0
var last_sting_state := false

func setup(player_ref: MiddleEarthPlayer, world_ref: MiddleEarthWorld) -> void:
	player = player_ref
	world = world_ref
	gradient = Gradient.new()
	var texture := GradientTexture2D.new()
	texture.width = 1400
	texture.height = 1400
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	sprite = Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)
	update_gradient(0.0, false)

func _process(_delta: float) -> void:
	if player == null or world == null:
		return
	global_position = player.global_position
	var darkness := world.darkness_at(player.global_position)
	var sting := player.sting_lit()
	if not is_equal_approx(darkness, last_darkness) or sting != last_sting_state:
		update_gradient(darkness, sting)

func update_gradient(darkness: float, sting: bool) -> void:
	last_darkness = darkness
	last_sting_state = sting
	var light_radius := 0.29 if sting else 0.16
	gradient.offsets = PackedFloat32Array([0.0, light_radius, minf(light_radius + 0.19, 0.75), 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, darkness * 0.82),
		Color(0.0, 0.0, 0.0, darkness),
	])

