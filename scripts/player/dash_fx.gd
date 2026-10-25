extends Node2D
## Efeitos de movimento, separados da física: rastro de imagens (estilo X4–X8), faísca e fumaça do dash,
## fumaça de deslizar e faísca do pulo na parede (sprites dos originais, tools/cut_ref_sheets.py; sem eles,
## os do mmx8 em assets/fx_mmx8) e câmera adiantada na direção do movimento. Lê o estado do Player pai.

const GHOST_EVERY := 2      # frames entre imagens do rastro
const GHOST_LIFE := 12      # frames até a imagem sumir
const DUST_EVERY := 6
const LOOKAHEAD := 48.0     # px que a câmera adianta durante o dash
const LOOKAHEAD_EASE := 0.12
## Efeito -> [folha do mmx8, colunas, linhas]
const MMX8 := {&"dash_spark": ["dash", 3, 2], &"dash_smoke": ["smoke", 3, 3], &"wall_slide": ["smoke", 3, 3],
	&"wall_kick": ["wall_kick", 3, 1]}

@export var camera_path: NodePath

var _tick := 0
var _slide_tick := 0
var _prev_state := -1
var _prev_kick := 0
var _fx := {}
## Silhueta sólida: a cor vem do modulate, a forma vem do alfa do quadro.
var _silhouette := ShaderMaterial.new()

@onready var player: Player = get_parent()
@onready var camera: Camera2D = get_node_or_null(camera_path)


func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvarying vec4 tint;\nvoid vertex() { tint = COLOR; }\nvoid fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }"
	_silhouette.shader = shader


func _physics_process(_delta: float) -> void:
	var fast := player.state == Player.State.DASH or player.airdash_timer > 0 \
		or (player.dash_momentum and player.state == Player.State.AIR)
	_tick = _tick + 1 if fast else 0
	if fast and _tick % GHOST_EVERY == 1:
		_ghost()
	if player.state == Player.State.DASH:
		if _prev_state != Player.State.DASH:
			_spawn(&"dash_spark", Vector2(-player.facing * 12, -8), player.facing)
		elif _tick % DUST_EVERY == 1:
			_spawn(&"dash_smoke", Vector2(-player.facing * 8, -6), player.facing)
	# Deslizando, a parede fica atrás do X (facing aponta para fora dela).
	_slide_tick = _slide_tick + 1 if player.state == Player.State.WALL_SLIDE else 0
	if _slide_tick % DUST_EVERY == 1:
		_spawn(&"wall_slide", Vector2(-player.facing * 8, -4), player.facing)
	# Pulo na parede: kick_timer recomeça; a parede fica do lado oposto ao do chute.
	if player.kick_timer > _prev_kick:
		_spawn(&"wall_kick", Vector2(-player.kick_dir * 10, -10), player.kick_dir)
	_prev_kick = player.kick_timer
	_prev_state = player.state
	if camera:
		var target := player.facing * LOOKAHEAD if fast else 0.0
		camera.offset.x = lerpf(camera.offset.x, target, LOOKAHEAD_EASE)


## Copia o quadro atual do sprite e deixa no lugar, na cor do personagem, sumindo.
func _ghost() -> void:
	var sprite := player.visual as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.global_position = sprite.global_position
	ghost.material = _silhouette
	var tint: Color = player.character.get("color", Color.WHITE).lightened(0.35)
	ghost.modulate = Color(tint.r, tint.g, tint.b, 0.55)
	# Logo antes do jogador na árvore: desenha atrás dele, mas na frente do cenário.
	player.add_sibling(ghost)
	player.get_parent().move_child(ghost, player.get_index())
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_LIFE / 60.0)
	tween.tween_callback(ghost.queue_free)


## Toca uma vez a animação de assets/fx/<name> na posição relativa aos pés e some.
## Os quadros da folha estão virados para a direita; side < 0 espelha.
func _spawn(fx_name: StringName, offset: Vector2, side: int) -> void:
	if not _fx.has(fx_name):
		var frames := SpriteFrames.new()
		frames.set_animation_loop(&"default", false)
		frames.set_animation_speed(&"default", 20.0)
		var k := 0
		var path := "res://assets/fx/%s/%03d.png"
		while Assets.exists(path % [fx_name, k]):
			frames.add_frame(&"default", Assets.texture(path % [fx_name, k]))
			k += 1
		if k == 0 and MMX8.has(fx_name):
			var m: Array = MMX8[fx_name]
			frames = DeathFX.grid("res://assets/fx_mmx8/%s.png" % m[0], m[1], m[2], 20.0)
			k = frames.get_frame_count(&"default")
		_fx[fx_name] = frames if k > 0 else null
	if _fx[fx_name] == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _fx[fx_name]
	fx.flip_h = side < 0
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.global_position = player.global_position + offset
	player.get_parent().add_child(fx)
	fx.play(&"default")
	fx.animation_finished.connect(fx.queue_free)
