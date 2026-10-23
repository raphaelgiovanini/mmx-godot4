extends "res://scripts/stage/block_room.gd"
## Fase 1: Central Highway (X1), refeita. Rodovia elevada à noite sobre a cidade, com buracos,
## carros batidos, vigas e inimigos; termina numa arena fechada com o Chill Penguin.
## Blocos com o fundo em DECK_BOTTOM são pista; os outros são carros e vigas.
## Sem tiles por enquanto: tudo desenhado em código, colisão pela lista `blocks` (block_room.gd).
## Com o mapa original instalado (tools/build_x1_intro.py → assets/stages/x1_intro, só local), a fase
## vira a do X1: camadas do mapa ampliadas e suavizadas, colisão tirada do próprio mapa.

const DECK_BOTTOM := 256.0
const MUSIC := "res://assets/music/"
const MAP := "res://assets/stages/x1_intro/"

var pit_y := 280.0             # abaixo disso: caiu no buraco
var checkpoint_x := 1420.0
var gate_x := 2984.0           # porta da arena
var arena := Vector2(3000, 3398)
var boss_at := Vector2(3300, 176)
## [tipo, x, y, patrulha]; tipo: Enemy.Kind (0 Metool, 1 Batton, 2 canhão, 3 Spiky)
var enemies := [
	[0, 380, 176, 60], [1, 560, 110, 0], [3, 820, 176, 90], [1, 980, 100, 0], [2, 1136, 136, 0],
	[0, 1260, 176, 40], [2, 1520, 176, 0], [1, 1700, 60, 0], [0, 2010, 176, 40], [1, 2200, 130, 0],
	[3, 2260, 208, 100], [2, 2520, 176, 0], [1, 2680, 110, 0], [3, 2800, 176, 120],
]
var _map := {}
@onready var player: Player = $"../Player"
@onready var camera: Camera2D = $"../Player/Camera"
@onready var music: AudioStreamPlayer = $"../Music"
var _checkpoint := false
var _arena := false
var _t := 0


func _ready() -> void:
	if Assets.exists(MAP + "fg_00.png"):
		_use_map()
	super()
	for e in enemies:
		var en := Enemy.new()
		en.kind = e[0]
		en.position = Vector2(e[1], e[2])
		en.patrol = e[3]
		get_parent().add_child.call_deferred(en)
	_build_background()
	_banner("READY", 1.6)


## Fase do mapa original: colisão do stage.json, inimigos no chão de cada ponto, chefe no trecho final.
func _use_map() -> void:
	_map = JSON.parse_string(FileAccess.get_file_as_string(MAP + "stage.json"))
	var w: float = _map.fg.size[0]
	blocks = [Rect2(-32, -300, 80, 800), Rect2(w - 9, -300, 40, 800)]
	for r in _map.solids:
		blocks.append(Rect2(r[0], r[1], r[2], r[3]))
	pit_y = _map.fg.size[1] + 40.0
	arena = Vector2(w - 9 - 398, w - 9)
	gate_x = arena.x - 16
	boss_at = Vector2(arena.y - 90, floor_at(arena.y - 90))
	checkpoint_x = 3900.0
	enemies = []
	var kinds := [0, 1, 3, 2, 1, 0, 3, 1, 2, 0, 1, 3, 2, 1, 0, 3, 1, 0]
	for i in kinds.size():
		var x := 420.0 + i * 370.0
		var y := floor_at(x)
		if y < INF and x < gate_x - 120:
			enemies.append([kinds[i], x, y - (60 if kinds[i] == 1 else 0), 50])
	player.global_position = Vector2(100, floor_at(100))
	camera.limit_left = 0
	camera.limit_right = int(w - 9)
	camera.limit_top = -40
	camera.limit_bottom = int(_map.fg.size[1])


## Topo do chão mais alto que cobre x (INF se é buraco).
func floor_at(x: float) -> float:
	var best := INF
	for r in blocks:
		if r.position.x <= x and x < r.end.x and r.position.y > -100:
			best = minf(best, r.position.y)
	return best


func _physics_process(_delta: float) -> void:
	_t += 1
	if player.global_position.y > pit_y:
		player.die()
	if not _checkpoint and player.global_position.x > checkpoint_x and player.is_on_floor():
		_checkpoint = true
		player.spawn_point = player.global_position
		_banner("CHECKPOINT", 1.0)
	if not _arena and player.global_position.x > arena.x + 24:
		_enter_arena()
	if _t % 4 == 0 and _map.is_empty():
		queue_redraw()   # luzes piscando


## Fecha a porta atrás do jogador, prende a câmera na arena e chama o chefe.
func _enter_arena() -> void:
	_arena = true
	var door := Rect2(gate_x, boss_at.y - 80, 16, 80)
	blocks.append(door)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = door.size
	shape.shape = box
	shape.position = door.get_center()
	body.add_child(shape)
	add_child(body)
	camera.limit_left = int(arena.x)
	camera.limit_right = int(arena.y)
	player.spawn_point = Vector2(arena.x + 40, boss_at.y)
	var boss := ChillPenguin.new()
	boss.respawn = false
	boss.arena = Vector2(arena.x + 24, arena.y - 22)
	boss.floor_y = boss_at.y
	boss.position = boss_at
	boss.defeated.connect(_stage_clear)
	get_parent().add_child(boss)
	music.play_track(MUSIC + "boss_intro.ogg", MUSIC + "boss_loop.ogg")
	_banner("WARNING", 1.6, Color8(248, 56, 48))


## Vitória como nos originais: espera pisar no chão, pose de vitória e teletransporte para cima.
func _stage_clear() -> void:
	music.stop()
	await get_tree().create_timer(1.2).timeout
	while not player.is_on_floor():
		await get_tree().physics_frame
	player.cutscene_pose = &"victory"
	music.play_track(MUSIC + "stage_clear.ogg", "")
	_banner("STAGE CLEAR", 0.0)
	await get_tree().create_timer(2.2).timeout
	player.cutscene_pose = &"beam"
	player.create_tween().tween_property(player, "global_position:y", player.global_position.y - 320, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.0).timeout
	var get_screen := preload("res://scripts/ui/weapon_get.gd").new()
	get_screen.weapon = Weapons.LIST.filter(func(w): return w.id == "shotgun_ice")[0]
	get_screen.character_id = player.character_id
	add_child(get_screen)
	music.play_track(MUSIC + "weapon_get.ogg", "")


## Texto grande no meio da tela; some depois de `secs` (0 = fica).
func _banner(text: String, secs: float, color := Color8(248, 248, 248)) -> void:
	var layer := CanvasLayer.new()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color8(16, 24, 64))
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(l)
	add_child(layer)
	var tw := l.create_tween().set_loops(int(secs / 0.4) if secs > 0 else 0)
	tw.tween_property(l, "modulate:a", 0.25, 0.2)
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	if secs > 0:
		get_tree().create_timer(secs).timeout.connect(layer.queue_free)


func _draw() -> void:
	if not _map.is_empty():
		if _arena:
			_barrier(blocks.back())   # porta da arena
		return
	var lamp_on := (_t / 20) % 2 == 0
	for r in blocks:
		if r.end.y >= DECK_BOTTOM:
			_deck(r, lamp_on)
		elif r.size.x <= 24 or r.size.y > r.size.x:
			_barrier(r)
		elif r.size.y >= 24:
			_car(r)
		else:
			_girder(r)


func _deck(r: Rect2, lamp_on: bool) -> void:
	# Pilares por baixo, até sumir no escuro.
	var px := ceilf(r.position.x / 160.0) * 160.0 + 40.0
	while px + 28 < r.end.x:
		draw_rect(Rect2(px, r.end.y - 40, 28, 220), Color8(44, 48, 68))
		draw_rect(Rect2(px + 3, r.end.y - 40, 6, 220), Color8(64, 70, 96))
		px += 160.0
	# Laje de concreto.
	draw_rect(Rect2(r.position.x, r.position.y + 10, r.size.x, r.size.y - 10), Color8(78, 84, 108))
	var panel := r.position.x
	while panel < r.end.x:
		draw_line(Vector2(panel, r.position.y + 12), Vector2(panel, r.end.y), Color8(58, 62, 84), 1)
		panel += 32.0
	draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Color8(50, 54, 74))
	# Asfalto com faixa amarela tracejada.
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 10), Color8(52, 52, 60))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color8(150, 150, 168))
	var dash := ceilf(r.position.x / 32.0) * 32.0
	while dash + 14 < r.end.x:
		draw_rect(Rect2(dash, r.position.y + 5, 14, 2), Color8(232, 200, 64))
		dash += 32.0
	# Postes de luz atrás da pista.
	var lx := ceilf(r.position.x / 192.0) * 192.0 + 96.0
	while lx < r.end.x - 8:
		var top := r.position.y - 70
		draw_rect(Rect2(lx, top, 3, 70), Color8(96, 104, 132))
		draw_rect(Rect2(lx - 10, top, 14, 3), Color8(96, 104, 132))
		draw_circle(Vector2(lx - 9, top + 4), 3, Color8(255, 236, 170))
		draw_circle(Vector2(lx - 9, top + 6), 12, Color(1, 0.9, 0.6, 0.12))
		lx += 192.0
	# Borda cortada nos buracos, com ferragem aparente.
	for edge in [r.position.x, r.end.x]:
		if edge > 0 and edge < arena.y:
			for i in 4:
				draw_line(Vector2(edge, r.position.y + 14 + i * 9), Vector2(edge + (5 if edge == r.end.x else -5), r.position.y + 18 + i * 9), Color8(150, 90, 60), 1)
	# Luz de alerta nas pontas dos buracos.
	if lamp_on:
		for edge in [r.position.x + 4, r.end.x - 4]:
			draw_circle(Vector2(edge, r.position.y - 3), 2, Color8(255, 80, 60))


func _car(r: Rect2) -> void:
	# Carro/caminhão batido: lataria, janela, rodas.
	draw_rect(r.grow(1), Color8(16, 16, 24))
	draw_rect(r, Color8(176, 52, 60))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4), Color8(222, 98, 96))
	draw_rect(Rect2(r.position.x + 6, r.position.y + 6, r.size.x * 0.4, 8), Color8(120, 170, 220))
	draw_line(r.position + Vector2(8, 7), r.position + Vector2(14, 13), Color8(220, 240, 255), 1)
	for wx in [r.position.x + 10, r.end.x - 10]:
		draw_circle(Vector2(wx, r.end.y - 1), 6, Color8(16, 16, 24))
		draw_circle(Vector2(wx, r.end.y - 1), 3, Color8(120, 120, 130))


func _girder(r: Rect2) -> void:
	# Viga de aço com treliça.
	draw_rect(r.grow(1), Color8(16, 16, 24))
	draw_rect(r, Color8(200, 120, 40))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color8(248, 176, 80))
	var x := r.position.x
	while x + 8 <= r.end.x:
		draw_line(Vector2(x, r.end.y - 1), Vector2(x + 8, r.position.y + 2), Color8(130, 70, 24), 1)
		x += 8.0


func _barrier(r: Rect2) -> void:
	# Barreira/porta: listras de alerta.
	draw_rect(r.grow(1), Color8(16, 16, 24))
	draw_rect(r, Color8(90, 96, 120))
	var y := r.position.y
	var i := 0
	while y < r.end.y:
		draw_rect(Rect2(r.position.x + 2, y, r.size.x - 4, 6), Color8(232, 200, 64) if i % 2 == 0 else Color8(24, 24, 32))
		y += 6.0
		i += 1


## Céu e cidade ao fundo em camadas de parallax (mais longe = anda mais devagar).
func _build_background() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -10
	var grad := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill_to = Vector2(0, 1)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color8(10, 12, 36))
	g.gradient.set_color(1, Color8(70, 40, 96))
	grad.texture = g
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.add_child(grad)
	get_parent().add_child.call_deferred(sky)
	if not _map.is_empty():
		g.gradient.set_color(0, Color8(40, 28, 52))
		g.gradient.set_color(1, Color8(82, 56, 74))
		# Fundo do mapa: 3545 px contra 7680 da frente, anda ~0,43 da câmera; embaixo alinhado com a tela.
		var far := Parallax2D.new()
		far.scroll_scale = Vector2(0.43, 0.5)
		far.z_index = -5
		far.add_child(_strips("bg", Vector2(0, 224 - float(_map.bg.size[1]) + 30)))
		get_parent().add_child.call_deferred(far)
		add_child(_strips("fg", Vector2.ZERO))
		return
	get_parent().add_child.call_deferred(_city(0.15, 1, Color8(34, 30, 70), 120.0, 3))
	get_parent().add_child.call_deferred(_city(0.4, 2, Color8(22, 24, 52), 80.0, 7))


## Faixas de 1024 px ampliadas 3x (Scale3x), desenhadas a 1/3 com filtro linear: contorno liso.
func _strips(layer: String, at: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = at
	for i in int(_map[layer].strips):
		var sp := Sprite2D.new()
		sp.texture = Assets.texture(MAP + "%s_%02d.png" % [layer, i])
		sp.centered = false
		sp.scale = Vector2.ONE / float(_map.scale)
		sp.position.x = i * float(_map.strip)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(sp)
	return root


func _city(scroll: float, seed_: int, color: Color, base_h: float, z: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, scroll * 0.3)
	p.z_index = -z
	var city := City.new()
	city.seed_ = seed_
	city.color = color
	city.base_h = base_h
	p.add_child(city)
	return p


class City extends Node2D:
	var seed_ := 0
	var color := Color.BLACK
	var base_h := 100.0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		var x := -200.0
		while x < 2400.0:
			var w := rng.randf_range(28, 64)
			var h := base_h + rng.randf_range(0, 90)
			var top := 230.0 - h
			draw_rect(Rect2(x, top, w - 4, 400), color)
			# Janelas acesas.
			var wy := top + 6
			while wy < 230:
				var wx := x + 4
				while wx < x + w - 10:
					if rng.randf() < 0.35:
						draw_rect(Rect2(wx, wy, 3, 4), Color(1, 0.85, 0.5, 0.55 if seed_ == 2 else 0.3))
					wx += 7
				wy += 9
			if rng.randf() < 0.3:
				draw_rect(Rect2(x + w / 2 - 3, top - 14, 2, 14), color)
				draw_circle(Vector2(x + w / 2 - 2, top - 15), 1.5, Color8(255, 60, 60))
			x += w
