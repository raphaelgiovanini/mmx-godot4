extends SceneTree
## Teste sem janela: confere que o X anda, dá dash, pula e desliza com os números da ROM.
## godot --headless --path . -s res://tests/physics_test.gd

const Room := preload("res://scenes/stages/test_room.tscn")

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := Room.instantiate()
	root.add_child(room)
	var p: Player = room.get_node("Player")
	p.pace = 1.0  # o teste confere os números do SNES, sem o ajuste de ritmo
	await _frames(20)  # assenta no chão
	check("parado no chão", p.state == Player.State.IDLE, p.state)

	Input.action_press(&"right")
	await _frames(3)
	var x0 := p.global_position.x
	await _frames(10)
	check("andar = 1,469 px/frame", is_equal_approx((p.global_position.x - x0) / 10.0, Player.WALK), (p.global_position.x - x0) / 10.0)
	Input.action_release(&"right")
	await _frames(2)

	# X do X1 sem armadura não tem dash (só com as pernas).
	Input.action_press(&"dash")
	await _frames(2)
	check("X1 sem pernas não dá dash", p.state != Player.State.DASH, p.state)
	Input.action_release(&"dash")
	p.set_armor("light")
	await _frames(2)

	Input.action_press(&"dash")
	await _frames(2)
	x0 = p.global_position.x
	await _frames(10)
	check("dash = 3,457 px/frame", is_equal_approx((p.global_position.x - x0) / 10.0, Player.DASH), (p.global_position.x - x0) / 10.0)
	Input.action_release(&"dash")
	p.set_armor("")
	await _frames(40)

	var y0 := p.global_position.y
	Input.action_press(&"jump")
	var top := y0
	var peak_vy := 0.0
	for i in 45:
		await _frames(1)
		top = minf(top, p.global_position.y)
		peak_vy = maxf(peak_vy, p.vy)
	check("pulo começa com 5,324 px/frame", is_equal_approx(peak_vy, Player.JUMP), peak_vy)
	# Altura esperada: soma de vy por frame, a partir de JUMP, enquanto sobe.
	var expected := 0.0
	var v := Player.JUMP
	while v > 0.0:
		expected += v
		v -= Player.GRAVITY
	check("altura do pulo ≈ %.1f px" % expected, absf((y0 - top) - expected) < 1.5, y0 - top)
	Input.action_release(&"jump")
	await _frames(40)

	# Parede da direita da sala (x=480): andar até ela, pular e segurar para a parede.
	p.global_position = Vector2(440, 192)
	await _frames(5)
	Input.action_press(&"right")
	Input.action_press(&"jump")
	await _frames(45)
	check("desliza na parede a 2 px/frame", p.state == Player.State.WALL_SLIDE and is_equal_approx(p.vy, -Player.WALL_SLIDE), "%s vy=%s" % [Player.State.find_key(p.state), p.vy])
	Input.action_release(&"jump")
	await _frames(1)
	Input.action_press(&"jump")
	await _frames(2)
	check("wall jump afasta da parede", p.vx < 0.0 and p.vy > 0.0, "vx=%s vy=%s" % [p.vx, p.vy])
	Input.action_release(&"jump")
	Input.action_release(&"right")

	# Zero (X3) tem a mesma física do X.
	p.set_character("zero")
	p.global_position = Vector2(48, 192)
	await _frames(20)
	Input.action_press(&"right")
	await _frames(3)
	x0 = p.global_position.x
	await _frames(10)
	Input.action_release(&"right")
	check("Zero anda 1,469", is_equal_approx((p.global_position.x - x0) / 10.0, Player.WALK), (p.global_position.x - x0) / 10.0)

	# Vida separada por personagem.
	p.set_character("x")
	p.invuln = 0
	p.take_damage(4)
	var x_hp: int = p.hp["x"]
	p.set_character("zero")
	check("Zero começa cheio", p.hp["zero"] == p.max_hp(), p.hp)
	p.set_character("x")
	check("X mantém a vida perdida", p.hp["x"] == x_hp and x_hp == p.max_hp() - 4, p.hp)
	# Corpo da armadura: metade do dano, arredondando para cima (X1 84:9D41).
	p.set_armor("light")
	p.invuln = 0
	p.take_damage(3)
	check("corpo: 3 de dano vira 2", p.hp["x"] == x_hp - 2, p.hp)
	p.set_armor("")
	p.set_character("x")

	# Zero: combo de sabre acerta o chefe; ↑+F = Ryuenjin sobe; carregado + F = golpe final.
	var boss: Boss = room.get_node("ChillPenguin")
	p.set_character("zero")
	p.global_position = boss.global_position + Vector2(-40, -4)
	p.facing = 1
	await _frames(20)
	var hp0 := boss.hp
	for i in 3:
		Input.action_press(&"saber")
		await _frames(1)
		Input.action_release(&"saber")
		await _frames(13)
	check("combo do sabre chega ao 3º golpe", p.saber.current == "saber_c", p.saber.current)
	await _frames(60)
	check("sabre tira vida do chefe", boss.hp < hp0, [hp0, boss.hp])
	check("combo termina", not p.saber.busy(), p.saber.current)
	var ry := p.global_position.y
	Input.action_press(&"up")
	Input.action_press(&"saber")
	await _frames(1)
	Input.action_release(&"saber")
	await _frames(10)
	Input.action_release(&"up")
	check("Ryuenjin sobe", p.global_position.y < ry - 20, ry - p.global_position.y)
	await _frames(80)
	Input.action_press(&"fire")
	await _frames(Player.CHARGE_LEVELS[1] + 2)
	Input.action_release(&"fire")
	await _frames(2)
	Input.action_press(&"saber")
	await _frames(1)
	Input.action_release(&"saber")
	await _frames(1)  # physics_frame chega antes do Player processar o frame
	check("carregado + F = golpe final", p.saber.current == "finisher", p.saber.current)
	await _frames(60)

	# Tri-Armor: o carregado é o tiro do braço do X3 gravado do original.
	p.set_character("x")
	p.set_armor("tri")
	p.global_position = boss.global_position + Vector2(-300, -4)
	await _frames(20)
	Input.action_press(&"fire")
	await _frames(Player.CHARGE_LEVELS[1] + 2)
	Input.action_release(&"fire")
	await _frames(2)
	var arm := root.find_children("*", "Area2D", true, false).filter(func(n): return n.get("weapon") != null and n.weapon.id == "arm_x3")
	check("Tri-Armor solta o tiro do braço do X3", arm.size() == 1, arm.size())
	p.set_armor("")

	print("FALHAS: %d" % failures if failures else "OK: física confere")
	quit(1 if failures else 0)


func check(label: String, ok: bool, got: Variant) -> void:
	print(("  ok  " if ok else "  FALHOU  ") + label + ("" if ok else "  (obtido: %s)" % str(got)))
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
