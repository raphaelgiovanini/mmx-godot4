extends CanvasLayer
## Menu de pausa "Hunter Terminal" (proposta aprovada): armadura peça por peça, armas dos três jogos,
## itens e o status ao vivo. Esc/Enter/Start abre e fecha. TAB/Q troca de painel, setas navegam,
## ←→ troca a peça ou o chip, D (atira) equipa a arma ou liga/usa o item.

const BG := Color("0b1020")
const PANEL := Color("121a30")
const LINE := Color("2a3a66")
const TEXT := Color("e6ecff")
const MUTED := Color("9aa8cf")
const ACCENT := Color("5ff0ff")
const GOLD := Color("f8c000")
const SEL := Color("1b2850")
const SET_COLOR := {"": Color("6b7799"), "light": Color("dce6ff"), "giga": Color("7c97ff"), "tri": Color("ff7a7a")}
const SLOT_NAME := {"head": "CAPACETE", "body": "CORPO", "arm": "BRAÇO", "legs": "PERNAS"}
const CHIPS := ["", "head", "body", "arm", "legs", "gold"]
const CHIP_NAME := {"": "NENHUM", "head": "CAPACETE", "body": "CORPO", "arm": "BRAÇO", "legs": "PERNAS", "gold": "GOLD"}
## Efeito de cada peça (docs/armaduras-e-energia.md). "*" = ainda não funciona no jogo.
const EFFECT := {
	"head": {"": "—", "light": "Quebra blocos *", "giga": "Item Tracer *", "tri": "[efeito do X3] *"},
	"body": {"": "—", "light": "Dano pela metade", "giga": "−1 de dano · Giga Crush", "tri": "Metade + escudo"},
	"arm": {"": "—", "light": "Espiral · carrega armas", "giga": "Carga dupla", "tri": "Cruz + Z-Saber"},
	"legs": {"": "—", "light": "Dash", "giga": "Dash no ar", "tri": "Dash no ar → ou ↑"},
}
const CHIP_EFFECT := {"head": "vida volta parado *", "body": "escudo −2", "arm": "Hyper Charge *", "legs": "2 dashes no ar"}
const PANELS := ["ARMADURA", "ARMAS", "ITENS"]
const ROWS_ARMOR := ["char", "full", "head", "body", "arm", "legs", "chip"]
const FULL_SETS := ["", "light", "giga", "tri", "gold"]
const FULL_NAME := {"": "NENHUMA", "light": "LIGHT (X1)", "giga": "GIGA (X2)", "tri": "TRI (X3)", "gold": "GOLD (X3)"}

@export var player_path: NodePath

var player: Player
var open := false
var panel := 0
var row := 0         # linha dentro do painel
var col := 0         # coluna (armas, itens)
var _draw_node := Control.new()
var _font: Font
var _tex := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_node(player_path)
	_font = ThemeDB.fallback_font
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	visible = false


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if not open and get_tree().paused:
			return   # menu de armas aberto
		open = not open
		visible = open
		get_tree().paused = open
	elif not open:
		return
	elif event.is_action_pressed(&"switch_next") or event.is_action_pressed(&"switch_prev"):
		panel = posmod(panel + (1 if event.is_action_pressed(&"switch_next") else -1), PANELS.size())
		row = 0
		col = 0
	elif event.is_action_pressed(&"up"):
		_move(0, -1)
	elif event.is_action_pressed(&"down"):
		_move(0, 1)
	elif event.is_action_pressed(&"left"):
		_move(-1, 0)
	elif event.is_action_pressed(&"right"):
		_move(1, 0)
	elif event.is_action_pressed(&"fire"):
		_confirm()
	else:
		return
	get_viewport().set_input_as_handled()
	_draw_node.queue_redraw()


func _move(dx: int, dy: int) -> void:
	match panel:
		0:
			if dy != 0:
				row = posmod(row + dy, ROWS_ARMOR.size())
			else:
				_cycle(ROWS_ARMOR[row], dx)
		1:
			row = posmod(row + dy, 4)
			col = 0 if row == 0 else posmod(col + dx, 8)
		2:
			row = posmod(row + dy, 2)
			col = posmod(col + dx, 8 if row == 0 else 4)


## ←→ na armadura: personagem, peça do encaixe ou chip.
func _cycle(what: String, dx: int) -> void:
	if what == "char":
		player.set_character(Characters.next(player.character_id, dx).id)
		return
	if player.character_id != "x":
		return
	if what == "full":
		player.set_armor(FULL_SETS[posmod(FULL_SETS.find(_full_set()) + dx, FULL_SETS.size())])
		return
	if what == "chip":
		player.chip = CHIPS[posmod(CHIPS.find(player.chip) + dx, CHIPS.size())]
		if player.chip == "gold":
			for k in Characters.SLOTS:
				player.parts[k] = "tri"
	else:
		var ids := [""] + Characters.ARMOR_SETS.keys()
		player.parts[what] = ids[posmod(ids.find(player.parts[what]) + dx, ids.size())]
		if player.chip == "gold" and player.parts[what] != "tri":
			player.chip = ""
	player.refresh_armor()


## Armadura inteira equipada ("mixed" quando as peças são de jogos diferentes).
func _full_set() -> String:
	var id: String = player.parts.head
	if not Characters.SLOTS.all(func(k): return player.parts[k] == id):
		return "mixed"
	return "gold" if id == "tri" and player.chip == "gold" else id


## Imagem da armadura montada: arte X DiVE da armadura inteira; Light por peças = sprite do X1 capturado
## com aquelas peças (assets/armor_parts/x1, máscara 1 capacete 2 braço 4 corpo 8 pernas); outras
## misturas = o X com a armadura do corpo.
func _armor_image() -> Texture2D:
	if player.character_id != "x":
		return _image("res://assets/art/zero.png", false)
	var full := _full_set()
	if full in ["light", "giga", "tri"]:
		return _image("res://assets/art/%s.png" % full, false)
	if full == "":
		return _image("res://assets/art/x_select.png", false)
	if full == "gold":
		return _image("res://assets/characters/x_gold/idle_0.png", true)
	if Characters.SLOTS.all(func(k): return player.parts[k] in ["", "light"]):
		var mask := 0
		for pair in [["head", 1], ["arm", 2], ["body", 4], ["legs", 8]]:
			if player.parts[pair[0]] == "light":
				mask |= pair[1]
		return _image("res://assets/armor_parts/x1/idle_%02d.png" % mask, true)
	var skin: String = player.armor().get("skin", "x")
	return _image("res://assets/characters/%s/idle_0.png" % skin, true)


func _confirm() -> void:
	match panel:
		1:
			player.set_weapon(_weapon_index(row, col))
		2:
			var id := player.health_id()
			if row == 0:
				# Heart Tank: liga até este; apertar o último ligado desliga. +2 de vida a cada um.
				var before := player.max_hp()
				player.hearts = col if player.hearts == col + 1 else col + 1
				player.hp[id] = clampi(player.hp.get(id, before) + player.max_hp() - before, 1, player.max_hp())
			elif player.sub_tanks[col] and player.hp.get(id, player.max_hp()) < player.max_hp():
				player.hp[id] = player.max_hp()   # usar: enche a vida e esvazia
				player.sub_tanks[col] = false
			else:
				player.sub_tanks[col] = not player.sub_tanks[col]


## Armas: linha 0 = X-Buster; linhas 1-3 = X1, X2, X3 (8 cada, na ordem de Weapons.LIST).
func _weapon_index(r: int, c: int) -> int:
	return 0 if r == 0 else 1 + (r - 1) * 8 + c


# ---------------------------------------------------------------- desenho (pixels do jogo, 398×224)

func _on_draw() -> void:
	var d := _draw_node
	var size := d.get_viewport_rect().size
	d.draw_rect(Rect2(Vector2.ZERO, size), BG)
	_header(d)
	# Abas: só a aba aberta ocupa a área; o status fica sempre ao lado.
	for i in PANELS.size():
		var tab := Rect2(6 + i * 64, 26, 62, 12)
		d.draw_rect(tab, PANEL if panel == i else BG)
		d.draw_rect(tab, ACCENT if panel == i else LINE, false, 1.0)
		_text(d, tab.position + Vector2(6, 9), PANELS[i], 7, ACCENT if panel == i else MUTED)
	var area := Rect2(6, 38, 288, 168)
	d.draw_rect(area, PANEL)
	d.draw_rect(area, ACCENT, false, 1.0)
	[_armor, _weapons, _items][panel].call(d, area)
	_status(d, Rect2(298, 26, 94, 180))
	_text(d, Vector2(6, 216), "TAB/Q troca de aba · setas navegam · ←→ troca peça · D equipa/usa · ESC volta", 6, MUTED)


func _header(d: Control) -> void:
	var c: Dictionary = player.character
	var icon := _image("res://assets/fx/emblem_%s.png" % c.get("icon", "x"), false)
	if icon:
		d.draw_texture_rect(icon, Rect2(6, 3, 14, 16), false)
	_text(d, Vector2(24, 11), "HUNTER TERMINAL", 9, TEXT)
	_text(d, Vector2(24, 19), "Pausa · %s" % c.name, 6, MUTED)
	_text(d, Vector2(318, 11), "VIDA MÁX", 6, MUTED)
	_text(d, Vector2(318, 20), str(player.max_hp()), 9, GOLD)
	_text(d, Vector2(352, 11), "VIDA", 6, MUTED)
	_text(d, Vector2(352, 20), str(player.hp.get(player.health_id(), player.max_hp())), 9, TEXT)
	d.draw_line(Vector2(6, 23), Vector2(392, 23), LINE)


func _armor(d: Control, r: Rect2) -> void:
	var is_x := player.character_id == "x"
	# Imagem da armadura montada, à esquerda das peças.
	var pic := Rect2(r.position.x + 4, r.position.y + 4, 84, r.size.y - 8)
	d.draw_rect(pic, BG)
	d.draw_rect(pic, LINE, false, 1.0)
	var tex := _armor_image()
	if tex:
		var k := minf((pic.size.x - 4) / tex.get_width(), (pic.size.y - 4) / tex.get_height())
		var sz := Vector2(tex.get_width(), tex.get_height()) * k
		d.draw_texture_rect(tex, Rect2(pic.get_center() - sz / 2, sz), false)
	var y := r.position.y + 4
	for i in ROWS_ARMOR.size():
		var what: String = ROWS_ARMOR[i]
		var x0 := pic.end.x + 4
		var box := Rect2(x0, y, r.end.x - 4 - x0, 16 if what in ["char", "full"] else 21)
		var focused := panel == 0 and row == i
		d.draw_rect(box, SEL if focused else BG)
		d.draw_rect(box, ACCENT if focused else LINE, false, 1.0)
		var at := box.position + Vector2(4, 8)
		if what == "char":
			_text(d, at + Vector2(0, 2), "PERSONAGEM", 6, MUTED)
			_text(d, at + Vector2(56, 2), "‹ %s ›" % player.character.name, 7, TEXT)
		elif what == "full":
			var full := _full_set()
			_text(d, at + Vector2(0, 2), "ARMADURA INTEIRA", 6, MUTED)
			_text(d, at + Vector2(76, 2), "—" if not is_x else ("‹ PEÇAS MISTAS ›" if full == "mixed" else "‹ %s ›" % FULL_NAME[full]), 6, GOLD if full == "gold" else TEXT)
		elif not is_x:
			_text(d, at, SLOT_NAME.get(what, "CHIP"), 6, MUTED)
			_text(d, at + Vector2(0, 8), "Só o X usa armadura", 6, MUTED)
		elif what == "chip":
			_text(d, at, "CHIP (X3, SÓ NA PEÇA TRI)", 6, MUTED)
			_text(d, at + Vector2(0, 8), "‹ %s ›" % CHIP_NAME[player.chip], 6, GOLD if player.chip == "gold" else Color("b06bff"))
		else:
			var id: String = player.parts[what]
			var set_name: String = "GOLD" if player.chip == "gold" and id == "tri" else (Characters.ARMOR_SETS[id].name if id != "" else "SEM PEÇA")
			_text(d, at, SLOT_NAME[what], 6, MUTED)
			_text(d, at + Vector2(52, 0), "‹ %s ›" % set_name, 6, SET_COLOR[id])
			var effect: String = EFFECT[what][id]
			if player.has_chip(what):
				effect += " · " + CHIP_EFFECT[what]
			_text(d, at + Vector2(0, 8), effect, 5, TEXT)
		y += box.size.y + 3


func _weapons(d: Control, r: Rect2) -> void:
	var cell := 22.0
	var x0 := r.position.x + 5
	var y := r.position.y + 6
	for rr in 4:
		var label: String = ["", "X1", "X2", "X3"][rr]
		if rr > 0:
			_text(d, Vector2(x0, y + 12), label, 7, MUTED)
		for c in (1 if rr == 0 else 8):
			var i := _weapon_index(rr, c)
			var w: Dictionary = Weapons.LIST[i]
			var box := Rect2(x0 + (14 if rr > 0 else 0) + c * cell, y, cell - 3, cell - 3)
			var focused := panel == 1 and row == rr and col == c
			d.draw_rect(box, SEL if focused or player.weapon_index == i else BG)
			d.draw_rect(box, ACCENT if focused else (w.color if player.weapon_index == i else LINE), false, 1.0)
			var icon := _image("res://assets/weapons/icons/%s_%s.png" % [w.game if w.game != "" else "x1", w.id], true)
			if icon:
				d.draw_texture_rect(icon, box.grow(-2), false)
			if rr == 0:
				_text(d, box.position + Vector2(cell + 2, 8), "X-BUSTER (sem gasto)", 6, MUTED)
			elif i > 0:
				var e: float = player.weapon_energy(w.id) / Weapons.MAX_ENERGY
				d.draw_rect(Rect2(box.position.x + 1, box.end.y - 2, (box.size.x - 2) * e, 1), w.color)
		y += cell + (6 if rr == 0 else 2)
	# Detalhe da arma em foco (ou da equipada fora do painel).
	var sel: Dictionary = Weapons.LIST[_weapon_index(row, col) if panel == 1 else player.weapon_index]
	var info := Rect2(r.position.x + 4, r.end.y - 52, r.size.x - 8, 48)
	d.draw_rect(info, BG)
	d.draw_rect(info, LINE, false, 1.0)
	_text(d, info.position + Vector2(4, 10), sel.name, 7, sel.color)
	if sel.id == "buster":
		_text(d, info.position + Vector2(4, 20), "Tiro padrão, energia infinita", 6, TEXT)
	else:
		var cost: Array = Weapons.COST.get(sel.id, Weapons.COST_DEFAULT)
		_text(d, info.position + Vector2(4, 20), "Forte contra %s" % sel.weak, 6, TEXT)
		_text(d, info.position + Vector2(4, 29), "Gasto: %s · carregado %s" % [_num(cost[0]), _num(cost[1])], 6, MUTED)
		_text(d, info.position + Vector2(4, 38), "Energia %s/28" % _num(player.weapon_energy(sel.id)), 6, MUTED)
	_text(d, info.position + Vector2(info.size.x - 42, 38), "EQUIPADA" if Weapons.LIST.find(sel) == player.weapon_index else "D: EQUIPAR", 6, GOLD)


func _items(d: Control, r: Rect2) -> void:
	var x := r.position.x + 8
	_text(d, Vector2(x, r.position.y + 14), "HEART TANKS  %d/8" % player.hearts, 7, TEXT)
	_text(d, Vector2(x, r.position.y + 23), "Cada um soma 2 à vida máxima (16 + 2 por tanque).", 6, MUTED)
	for i in 8:
		var box := Rect2(x + i * 26, r.position.y + 28, 22, 22)
		var on := i < player.hearts
		var focused := panel == 2 and row == 0 and col == i
		d.draw_rect(box, Color("ff4d6d") if on else BG)
		d.draw_rect(box, ACCENT if focused else (Color("ff4d6d") if on else LINE), false, 1.0 if not focused else 2.0)
	_text(d, Vector2(x, r.position.y + 72), "SUB-TANKS", 7, TEXT)
	_text(d, Vector2(x, r.position.y + 81), "D num tanque cheio enche a vida; num vazio, enche o tanque (teste).", 6, MUTED)
	for i in 4:
		var box := Rect2(x + i * 52, r.position.y + 86, 46, 30)
		var on: bool = player.sub_tanks[i]
		var focused := panel == 2 and row == 1 and col == i
		d.draw_rect(box, BG)
		if on:
			d.draw_rect(Rect2(box.position + Vector2(3, 3), box.size - Vector2(6, 6)), GOLD.darkened(0.55))
		d.draw_rect(box, ACCENT if focused else (GOLD if on else LINE), false, 1.0 if not focused else 2.0)
		_text(d, box.position + Vector2(5, 19), "CHEIO" if on else "VAZIO", 7, GOLD if on else MUTED)
	_text(d, Vector2(x, r.end.y - 8), "Itens das fases (pegar no mapa) ainda não existem: aqui eles ligam e desligam.", 6, MUTED)


func _status(d: Control, r: Rect2) -> void:
	d.draw_rect(r, PANEL)
	d.draw_rect(r, LINE, false, 1.0)
	_text(d, r.position + Vector2(5, 9), "STATUS AO VIVO", 7, ACCENT)
	var p := player
	var lines := []
	if p.character_id != "x":
		lines = [["Armadura", "não usa"], ["Especial", "sabre (F)"]]
	else:
		var dmg: String = {"": "inteiro", "light": "metade ↑", "giga": "−1 (−2 se 5+)", "tri": "metade ↓"}[p.part("body")]
		if p.part("body") == "tri":
			dmg += " · escudo −2" if p.has_chip("body") else " · escudo −1"
		var move: String = "sem dash" if not p.can_dash() else {"": "dash", "light": "dash", "giga": "dash no ar", "tri": "dash no ar ↑"}[p.part("legs")]
		if p.has_chip("legs"):
			move += " ×2"
		var charge: String = {"": "nível 2", "light": "espiral", "giga": "dois tiros", "tri": "cruz + sabre"}[p.part("arm")]
		var sp := "Giga Crush" if p.part("body") == "giga" else ("Hadouken" if p.full_set("light") else ("Shoryuken" if p.full_set("giga") else "nenhum"))
		lines = [["Dano recebido", dmg], ["Movimento", move], ["Carregado", charge], ["Especial (F)", sp],
			["Carrega arma", "sim" if p.can_charge_weapon() else "não (falta braço)"]]
	var y := r.position.y + 19
	for l in lines:
		_text(d, Vector2(r.position.x + 5, y), l[0], 6, MUTED)
		_text(d, Vector2(r.position.x + 5, y + 8), l[1], 6, TEXT)
		y += 18
	_text(d, Vector2(r.position.x + 5, r.end.y - 4), "* ainda não funciona", 5, MUTED)


# ---------------------------------------------------------------- utilidades

func _text(d: Control, at: Vector2, s: String, size: int, color: Color) -> void:
	d.draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _num(v: float) -> String:
	return str(v).replace(".", ",") if v != int(v) else str(int(v))


## Imagem de arquivo (fora do git); pixel art é ampliado 8× antes para não borrar com o filtro linear.
func _image(path: String, pixel: bool) -> Texture2D:
	if not _tex.has(path):
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if img and pixel:
			img.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
		if img:
			img.generate_mipmaps()
		_tex[path] = ImageTexture.create_from_image(img) if img else null
	return _tex[path]
