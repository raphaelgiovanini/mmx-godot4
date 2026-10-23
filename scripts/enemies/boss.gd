class_name Boss
extends StaticBody2D
## Chefe parado ("saco de pancadas") para testar o impacto de cada arma.
## Vida, dano por arma e sprites vêm do jogo original (docs/chefes.md). Não se move nem ataca.
## Ao ser atingido: clarão branco, número do dano subindo e invencibilidade curta.
## Ao zerar: explosão e volta com a vida cheia depois de um tempo.

signal hp_changed(hp: int, max_hp: int)
signal defeated

const ROOT := "res://assets/bosses/"
const RESPAWN_S := 2.5

@export var boss_id := "chill_penguin"
@export var boss_name := "CHILL PENGUIN"
@export var emblem := "C"
@export var color := Color("7fd0ff")
@export var max_hp := 32
@export var invuln_frames := 30   # placeholder; o X1 controla isso em bossHitDetectLoop (84:9B58)
## Sala de teste: volta com a vida cheia. Na fase: morre de vez e emite defeated.
@export var respawn := true
## Aparece na barra de chefe do HUD (inimigos comuns e estátuas de gelo não).
@export var show_bar := true
## Dano por arma: linha do chefe na tabela 86:EF37 do X1 (colunas ausentes = 1). Ver Projectile.weapon_col
## e Weapons.LIST "col". Chill Penguin: Fire Wave (0A) 3, carregado (13) 4; Chameleon Sting carregado (11) 0.
@export var damage := {0: 1, 1: 2, 2: 3, 3: 3, 4: 32, 5: 2, 6: 2, 10: 3, 16: 2, 17: 0, 18: 2, 19: 4, 20: 2, 21: 2, 22: 2, 23: 2}

var hp := 0
var _invuln := 0
var _sprite := AnimatedSprite2D.new()


func _ready() -> void:
	add_to_group(&"boss")
	hp = max_hp
	_sprite.sprite_frames = _frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if _sprite.sprite_frames:
		var tex := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
		_sprite.position.y = -tex.get_height() / 2.0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(tex.get_width() * 0.7, tex.get_height() * 0.9)
		shape.shape = box
		shape.position.y = -box.size.y / 2
		add_child(shape)
	_sprite.play(&"idle")
	hp_changed.emit(hp, max_hp)


func _physics_process(_delta: float) -> void:
	_invuln = maxi(_invuln - 1, 0)
	# Clarão branco nos primeiros frames do acerto (modulate acima de 1 clareia o sprite).
	_sprite.modulate = Color(4, 4, 4) if _invuln > invuln_frames - 4 else Color.WHITE
	_sprite.visible = hp > 0 and (_invuln == 0 or (_invuln / 2) % 2 == 0 or _invuln > invuln_frames - 4)


## Chamado pelo tiro. Devolve true se o tiro deve sumir (acertou).
func hit(weapon_col: int, multiplier: float) -> bool:
	if hp <= 0:
		return false
	if _invuln > 0:
		return true
	var dmg := maxi(0, roundi(damage.get(weapon_col, 1) * multiplier))
	hp = maxi(hp - dmg, 0)
	_invuln = invuln_frames
	_popup(str(dmg), Color(1, 0.95, 0.5) if dmg >= 3 else Color.WHITE)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		_explode()
	return true


func _popup(text: String, c: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = global_position + Vector2(randf_range(-10, 6), -48)
	l.z_index = 10
	get_parent().add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 22, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func _explode() -> void:
	for i in 10:
		var burst := CPUParticles2D.new()
		burst.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-36, 0))
		burst.one_shot = true
		burst.emitting = false   # liga no timer abaixo; ligado já no início ele terminava e se apagava antes
		burst.amount = 12
		burst.lifetime = 0.5
		burst.explosiveness = 1.0
		burst.spread = 180.0
		burst.initial_velocity_min = 30.0
		burst.initial_velocity_max = 90.0
		burst.gravity = Vector2.ZERO
		burst.scale_amount_min = 2.0
		burst.scale_amount_max = 4.0
		burst.color = Color(1.0, 0.8, 0.4) if i % 2 else color
		get_parent().add_child(burst)
		get_tree().create_timer(i * 0.08).timeout.connect(func(): burst.emitting = true)
		burst.finished.connect(burst.queue_free)
	if not respawn:
		defeated.emit()
		return
	get_tree().create_timer(RESPAWN_S).timeout.connect(func():
		hp = max_hp
		hp_changed.emit(hp, max_hp))


func _frames() -> SpriteFrames:
	var dir := ProjectSettings.globalize_path(ROOT + boss_id)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 4)
	for i in 8:
		var img := Image.load_from_file(dir.path_join("idle_%d.png" % i)) if FileAccess.file_exists(dir.path_join("idle_%d.png" % i)) else null
		if img == null:
			break
		frames.add_frame(&"idle", ImageTexture.create_from_image(img))
	if frames.get_frame_count(&"idle") == 0:
		push_error("sem sprites de %s: veja docs/chefes.md" % boss_id)
		return null
	return frames
