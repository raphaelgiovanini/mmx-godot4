extends CanvasLayer
## Tela de "WEAPON GET" depois do chefe (estilo X8: linhas de velocidade na cor da arma).
## O X grande da tela do mmx8 (assets/fx_mmx8/weapon_get_x.png, montado das peças de lá) aparece, um
## clarão pinta a armadura na cor da arma (weapon_color.gdshader) e ele atira a arma nova.
## Depois de alguns segundos, qualquer botão recomeça a fase.

const SIZE := Vector2(398, 224)

var weapon: Dictionary
var character_id := "x"
## Arte grande de quem venceu (escolhida pela fase); null = sprite do jogo ampliado.
var art: Texture2D
## Pinta a armadura na cor da arma: matiz, largura e saturação mínima da cor que troca (X azul, Zero
## vermelho). Vazio = não pinta.
var tint := {"hue": 0.64, "width": 0.14, "sat": 0.25}

var _t := 0.0
var _hero: CanvasItem
var _tint := ShaderMaterial.new()
var _flash := ColorRect.new()
var _name := Label.new()
var _done := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color8(8, 10, 30)
	bg.size = SIZE
	add_child(bg)
	var lines := Lines.new()
	lines.color = weapon.color
	add_child(lines)
	var band := ColorRect.new()
	band.color = Color(weapon.color, 0.18)
	band.position = Vector2(0, 112)
	band.size = Vector2(SIZE.x, 72)
	add_child(band)

	if art:
		# Cabe numa caixa de 200×216 com os pés no chão da tela; arte grande (ilustração) com filtro
		# linear, pixel art sem filtro.
		var big := Sprite2D.new()
		big.texture = art
		var k := minf(216.0 / art.get_height(), 200.0 / art.get_width())
		big.scale = Vector2(k, k)
		big.position = Vector2(100, 224 - art.get_height() * k / 2.0)
		big.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if k < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
		if not tint.is_empty():
			_tint.shader = preload("res://scripts/ui/weapon_color.gdshader")
			_tint.set_shader_parameter(&"target", weapon.color)
			_tint.set_shader_parameter(&"source_hue", tint.hue)
			_tint.set_shader_parameter(&"hue_width", tint.width)
			_tint.set_shader_parameter(&"min_sat", tint.sat)
			_two_tone()
			big.material = _tint
		_hero = big
	else:
		var small := SpriteVisual.new()
		small.position = Vector2(110, 150)
		small.scale = Vector2(3, 3)
		small.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		small.set_character(character_id)
		small.show_state(&"victory", 1)
		_hero = small
	add_child(_hero)

	var title := _label("WEAPON GET", 26, Color8(248, 248, 248))
	title.position = Vector2(SIZE.x, 18)
	add_child(title)
	title.create_tween().tween_property(title, "position:x", 214.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_name = _label(weapon.name, 18, weapon.color)
	_name.position = Vector2(216, 56)
	_name.visible_characters = 0
	add_child(_name)

	_flash.color = Color(1, 1, 1, 0)
	_flash.size = SIZE
	add_child(_flash)


## X: as duas cores da paleta da arma (a mesma do sprite do jogo), lidas de palettes.json pelas cores
## de origem do X: azul escuro/azul da armadura e azul-claro/azul-pálido.
func _two_tone() -> void:
	if character_id != "x":
		return
	var pals = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/palettes.json"))
	if pals == null or not pals.has(weapon.id):
		return
	var map := {}
	for i in pals[weapon.id][0].size():
		var s: Array = pals[weapon.id][0][i]
		var t: Array = pals[weapon.id][1][i]
		map[Color8(s[0], s[1], s[2])] = Color8(t[0], t[1], t[2])
	var pick := func(r, g, b): return map.get(Color8(r, g, b), Color8(r, g, b))
	_tint.set_shader_parameter(&"two_tone", true)
	_tint.set_shader_parameter(&"main_dark", pick.call(32, 48, 128))
	_tint.set_shader_parameter(&"main_light", pick.call(0, 128, 248))
	_tint.set_shader_parameter(&"light_dark", pick.call(80, 160, 240))
	_tint.set_shader_parameter(&"light_light", pick.call(120, 216, 240))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color8(8, 10, 30))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	_name.visible_characters = int(clampf((_t - 0.6) * 18.0, 0, 99))
	if before < 1.4 and _t >= 1.4:
		# Clarão: as cores da arma entram no personagem.
		_flash.color.a = 1.0
		_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
		if _hero is SpriteVisual:
			_hero.set_palette(weapon.id)
		else:
			_tint.set_shader_parameter(&"amount", 1.0)

	for at in [2.1, 2.5, 2.9]:
		if before < at and _t >= at:
			var s := Shard.new()
			s.color = weapon.color
			s.position = Vector2(196, 70)
			add_child(s)
			# Coice do canhão.
			var home: Vector2 = _hero.position
			var kick := _hero.create_tween()
			kick.tween_property(_hero, "position", home - Vector2(4, 0), 0.04)
			kick.tween_property(_hero, "position", home, 0.12)
	if before < 3.4 and _t >= 3.4:
		var info := _label("Arma do %s\nFraco contra ela: %s" % [weapon.boss, weapon.weak], 10, Color8(200, 208, 232))
		info.position = Vector2(216, 84)
		add_child(info)
	if before < 5.5 and _t >= 5.5:
		_done = true
		var end := _label("Obrigado por jogar a demo!\nAperte qualquer botão para jogar de novo", 11, Color8(248, 248, 248))
		end.position = Vector2(0, 192)
		end.size.x = SIZE.x
		end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(end)
		var tw := end.create_tween().set_loops()
		tw.tween_property(end, "modulate:a", 0.3, 0.5)
		tw.tween_property(end, "modulate:a", 1.0, 0.5)


func _input(event: InputEvent) -> void:
	if _done and event.is_pressed() and not event.is_echo():
		get_tree().paused = false
		get_tree().reload_current_scene()


## Linhas de velocidade passando da direita para a esquerda.
class Lines extends Node2D:
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 40:
			var y := rng.randf_range(0, 224)
			var speed := rng.randf_range(300, 700)
			var length := rng.randf_range(30, 120)
			var x := fposmod(rng.randf_range(0, 600) - _t * speed, 600.0) - 100.0
			draw_line(Vector2(x, y), Vector2(x + length, y), Color(color, rng.randf_range(0.15, 0.5)), rng.randf_range(1, 2.5))


## Tiro de demonstração da arma nova: cristal que atravessa a tela.
class Shard extends Node2D:
	var color := Color.WHITE

	func _process(delta: float) -> void:
		position.x += 360 * delta
		rotation += 10 * delta
		if position.x > 420:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)])
		draw_circle(Vector2.ZERO, 12, Color(color, 0.25))
		draw_colored_polygon(pts, color.lightened(0.4))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
