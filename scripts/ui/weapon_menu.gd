extends Control
## Menu de armas (W / L3): grade com o buster e as 24 armas de chefe do X1–X3, com o ícone tirado do
## sprite original. Setas escolhem, W/Enter/Esc fecham. O jogo pausa enquanto está aberto.
## TAB/Q alterna para o mapa de fraquezas: para cada chefe do X1–X3, a arma que mais machuca.

const COLS := 5
const CELL := Vector2(74, 30)
## Dano da fraqueza no X1 (tabela 86:EF37), normal / carregado; o buster simples dá 1.
## Chameleon Sting carregado é a invencibilidade: não machuca.
const X1_WEAK_DMG := {"chameleon_sting": [3, 0], "electric_spark": [3, 6]}

var player: Player
var index := 0
var _font: Font
var _icons := {}
var _map := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"weapon_menu") or (visible and event.is_action_pressed(&"pause")):
		if not visible and (get_tree().paused):
			return
		visible = not visible
		get_tree().paused = visible
		index = player.weapon_index
	elif not visible:
		return
	elif event.is_action_pressed(&"switch_next") or event.is_action_pressed(&"switch_prev"):
		_map = not _map
	elif event.is_action_pressed(&"left"):
		index -= 1
	elif event.is_action_pressed(&"right"):
		index += 1
	elif event.is_action_pressed(&"up"):
		index -= COLS
	elif event.is_action_pressed(&"down"):
		index += COLS
	else:
		return
	index = posmod(index, Weapons.LIST.size())
	if visible:
		player.set_weapon(index)
	get_viewport().set_input_as_handled()
	queue_redraw()


func _icon(w: Dictionary) -> Texture2D:
	if not _icons.has(w.id):
		var tex: Texture2D = null
		# Ícone original do menu de cada jogo (tools/cut_ref_sheets.py); o buster usa o do X1.
		var icon := Image.load_from_file("res://assets/weapons/icons/%s_%s.png" % [w.game if w.game != "" else "x1", w.id])
		var f := {"normal": []} if icon else Weapons.frames(w)
		if icon:
			tex = ImageTexture.create_from_image(icon)
		elif not f.normal.is_empty():
			# Quadro do começo da gravação, recortado no que está desenhado.
			var img: Image = (f.normal[mini(6, f.normal.size() - 1)] as Texture2D).get_image()
			var r := img.get_used_rect()
			tex = ImageTexture.create_from_image(img.get_region(r)) if r.size != Vector2i.ZERO else null
		_icons[w.id] = tex
	return _icons[w.id]


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.08, 0.86))
	if _map:
		_draw_map(size)
		return
	draw_string(_font, Vector2(16, 20), "ARMAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9fd8ff"))
	var origin := Vector2((size.x - COLS * CELL.x) / 2.0, 30)
	for i in Weapons.LIST.size():
		var w: Dictionary = Weapons.LIST[i]
		var at := origin + Vector2(i % COLS, i / COLS) * CELL
		var box := Rect2(at, CELL - Vector2(4, 4))
		var on := i == index
		draw_rect(box, w.color.darkened(0.6) if on else Color(0.1, 0.12, 0.2))
		draw_rect(box, w.color if on else Color(0.3, 0.35, 0.5), false, 1.0)
		var tex := _icon(w)
		if tex:
			var s := minf(1.0, 22.0 / maxf(tex.get_width(), tex.get_height()))
			var ts := tex.get_size() * s
			draw_texture_rect(tex, Rect2(at + Vector2(14, 13) - ts / 2.0, ts), false)
		var tag: String = w.game.to_upper() if w.game != "" else ""
		draw_string(_font, at + Vector2(28, 11), w.name, HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 32, 6, Color.WHITE)
		draw_string(_font, at + Vector2(28, 21), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, w.color)
	var sel: Dictionary = Weapons.LIST[index]
	var info: String = ("FORTE CONTRA " + sel.weak.to_upper()) if sel.has("weak") else "ARMA PADRÃO"
	draw_string(_font, Vector2(16, size.y - 18), "%s · %s" % [sel.name, info], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, sel.color)
	draw_string(_font, Vector2(16, size.y - 7), "←→↑↓ escolhe · TAB/Q mapa de fraquezas · W fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("9fd8ff"))


## Mapa de fraquezas: uma coluna por jogo, um chefe por linha, com a arma a usar nele.
## A arma escolhida na grade fica destacada.
func _draw_map(size: Vector2) -> void:
	draw_string(_font, Vector2(16, 20), "QUAL ARMA USAR EM CADA CHEFE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9fd8ff"))
	var col_w := (size.x - 24) / 3.0
	var sel: Dictionary = Weapons.LIST[index]
	for g in 3:
		var game: String = ["x1", "x2", "x3"][g]
		var x := 12 + g * col_w
		draw_string(_font, Vector2(x, 36), "MEGA MAN " + game.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		var row := 0
		for w in Weapons.LIST:
			if w.game != game:
				continue
			var at := Vector2(x, 42 + row * 20)
			var box := Rect2(at, Vector2(col_w - 6, 18))
			if w.id == sel.id:
				draw_rect(box, w.color.darkened(0.6))
				draw_rect(box, w.color, false, 1.0)
			draw_string(_font, at + Vector2(3, 8), w.weak.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, col_w - 10, 7, Color.WHITE)
			var tag: String = "usar " + w.name
			if game == "x1":
				var d: Array = X1_WEAK_DMG.get(w.id, [3, 4])
				tag += "  dano %d%s" % [d[0], (" · carr. %d" % d[1]) if d[1] > 0 else ""]
			draw_string(_font, at + Vector2(3, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, col_w - 10, 6, w.color)
			row += 1
	draw_string(_font, Vector2(16, size.y - 7), "X1: dano da ROM (buster simples = 1) · TAB/Q volta às armas · W fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("9fd8ff"))
