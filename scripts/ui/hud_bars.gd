extends Control
## HUD no estilo do X1–X3 (folha "Lifebars"), desenhado em pixels do jogo (398×224):
##   vida       barra vertical à esquerda, 2 px por ponto, símbolo do personagem embaixo
##   arma       só com arma especial: barra ao lado, na cor da arma, ícone da arma embaixo
##   Giga Crush só com o corpo Giga: barra roxa ao lado; cheia pisca
##   F          aviso do especial (Hadouken/Shoryuken/Giga Crush) só quando dá para usar
## Modo chefe: a mesma barra à direita, com o emblema Maverick embaixo.

const BAR_DARK := Color8(24, 24, 24)
const BAR_WHITE := Color8(248, 248, 248)
const BAR_GREY := Color8(136, 136, 136)
const BAR_FILL := Color8(248, 192, 0)
const GIGA_FILL := Color("c04cff")
const TOP := 30.0   # topo das barras

var player: Player
@export var boss_mode := false
var boss: Boss

var _shown := 0.0     # chefe: enche ponto a ponto quando aparece
var _font: Font
var _tex := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Símbolos em alta resolução e pixel art ampliado 8×: linear para não serrilhar.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if boss_mode:
		if boss == null or not is_instance_valid(boss):
			boss = _find_boss()
		visible = boss != null
		if boss:
			_shown = minf(_shown + delta * 30.0, boss.hp) if _shown < boss.hp else float(boss.hp)
	queue_redraw()


## Primeiro chefe de verdade na cena (inimigos comuns também ficam no grupo "boss" para os tiros).
func _find_boss() -> Boss:
	for b in get_tree().get_nodes_in_group(&"boss"):
		if b.show_bar:
			return b
	return null


func _draw() -> void:
	if boss_mode:
		if boss:
			var skull := _image("res://assets/fx/lifebar/004.png", Rect2i(0, 42, 14, 16))
			_vbar(Vector2(get_viewport_rect().size.x - 24, TOP), boss.max_hp, int(_shown), BAR_FILL, skull)
		return
	if player == null:
		return
	var id := player.health_id()
	var hp: int = player.hp.get(id, player.max_hp())
	var x := 10.0
	var emblem := _image("res://assets/fx/emblem_%s.png" % player.character.get("icon", "x"), Rect2i())
	var bottom := _vbar(Vector2(x, TOP), player.max_hp(), hp, BAR_FILL, emblem)
	# Energia da arma: só com arma especial (o buster não gasta, como nos originais).
	if player.weapon_index > 0:
		x += 16
		var w: Dictionary = Weapons.LIST[player.weapon_index]
		var icon := _image("res://assets/weapons/icons/%s_%s.png" % [w.game, w.id], Rect2i())
		bottom = maxf(bottom, _vbar(Vector2(x, TOP), int(Weapons.MAX_ENERGY), ceili(player.weapon_energy(w.id)), w.color, icon))
	if player.part("body") == "giga":
		x += 16
		var full := player.giga >= player.GIGA_MAX
		var fill := BAR_WHITE if full and (Engine.get_frames_drawn() / 6) % 2 == 0 else GIGA_FILL
		bottom = maxf(bottom, _vbar(Vector2(x, TOP), int(player.GIGA_MAX), int(player.giga), fill, null))
	var move := player.x_special_name()
	if move != "":
		var at := Vector2(10, bottom + 10)
		draw_string_outline(_font, at, "F  " + move, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, BAR_DARK)
		draw_string(_font, at, "F  " + move, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, BAR_FILL)


## Barra vertical do X1 (14 px de largura): tampa, moldura escura/branca/cinza, um tracinho por ponto
## (cor com brilho branco no meio) e a placa do ícone embaixo. Devolve o y do fim da placa.
func _vbar(top: Vector2, units: int, filled: int, fill: Color, icon: Texture2D) -> float:
	var h := units * 2
	draw_rect(Rect2(top + Vector2(2, 0), Vector2(10, 1)), BAR_DARK)
	draw_rect(Rect2(top + Vector2(1, 1), Vector2(12, 1)), BAR_DARK)
	draw_rect(Rect2(top + Vector2(2, 1), Vector2(10, 1)), BAR_WHITE)
	draw_rect(Rect2(top + Vector2(0, 2), Vector2(14, 1)), BAR_DARK)
	draw_rect(Rect2(top + Vector2(1, 2), Vector2(12, 1)), BAR_WHITE)
	draw_rect(Rect2(top + Vector2(3, 2), Vector2(8, 1)), BAR_GREY)
	var body := Rect2(top + Vector2(0, 3), Vector2(14, h))
	draw_rect(body, BAR_DARK)
	draw_rect(Rect2(body.position + Vector2(1, 0), Vector2(12, h)), BAR_WHITE)
	draw_rect(Rect2(body.position + Vector2(2, 0), Vector2(10, h)), BAR_GREY)
	draw_rect(Rect2(body.position + Vector2(3, 0), Vector2(8, h)), BAR_DARK)
	for i in clampi(filled, 0, units):
		var y := body.end.y - 2 - i * 2
		draw_rect(Rect2(body.position.x + 4, y, 6, 1), fill)
		draw_rect(Rect2(body.position.x + 6, y, 2, 1), BAR_WHITE)
	var plate := Rect2(Vector2(top.x, body.end.y), Vector2(14, 16))
	if icon:
		draw_texture_rect(icon, plate, false)
	else:
		draw_rect(plate, BAR_DARK)
		draw_rect(plate.grow(-1), BAR_WHITE)
		draw_rect(plate.grow(-3), BAR_DARK)
	return plate.end.y


## Imagem de arquivo (fora do git), em cache. `region` recorta (pixel art: ampliado 8× antes de filtrar).
func _image(path: String, region: Rect2i) -> Texture2D:
	var key := path + str(region)
	if not _tex.has(key):
		var img := Assets.image(path)
		if img:
			if region.size != Vector2i.ZERO:
				img = img.get_region(region)
			if img.get_width() < 32:
				img.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
			img.generate_mipmaps()
		_tex[key] = ImageTexture.create_from_image(img) if img else null
	return _tex[key]
