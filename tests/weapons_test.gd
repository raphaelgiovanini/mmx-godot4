extends SceneTree
## Dispara cada arma (normal e carregado) e o tiro do braço de cada armadura, frame a frame:
## - durante a gravação, a caixa do tiro tem que bater com a do quadro gravado do original;
## - depois dela, a frente do tiro não pode voltar nem saltar mais que 2× a velocidade medida,
##   e o tiro tem que sair da tela ou parar numa parede.
## Rodar: godot --headless --path . -s res://tests/weapons_test.gd

const Room := preload("res://scenes/stages/test_room.tscn")
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := Room.instantiate()
	root.add_child(room)
	room.get_node("ChillPenguin").position.x = 5000
	var p: Player = room.get_node("Player")
	p.set_character("x")
	await _frames(20)
	var shots := []
	for i in range(1, Weapons.LIST.size()):
		shots.append([Weapons.LIST[i], false])
		shots.append([Weapons.LIST[i], true])
	for arm in ["arm_x1", "arm_x2", "arm_x3"]:
		shots.append([{"id": arm, "game": "x1", "name": arm}, true])
	for arm in ["arm_x2", "arm_x3"]:   # 2º tiro da carga dupla
		shots.append([{"id": arm, "game": "x1", "name": arm}, true, true])
	for s in shots:
		await _check(room, p, s[0], s[1], s.size() > 2)
	print("FALHAS: %d" % failures if failures else "OK: tiros contínuos")
	quit(1 if failures else 0)


func _check(room: Node, p: Player, w: Dictionary, charged: bool, second := false) -> void:
	var shot := preload("res://scripts/player/weapon_shot.gd").new()
	shot.weapon = w
	shot.charged = charged
	shot.second = second
	shot.dir = 1
	shot.position = Vector2(240, 192)
	room.add_child(shot)
	await _frames(1)
	var label := "%s %s" % [w.id, "segundo tiro" if second else ("carregado" if charged else "normal")]
	if not is_instance_valid(shot):
		print("  --  %s: sem gravação" % label)
		return
	var n: int = shot._end
	var speed: float = shot._speed
	var last := -INF
	var worst := 0.0
	var back := false
	var frames := 0
	while is_instance_valid(shot) and frames < 600:
		var r: Rect2i = shot._rects[shot._frame()]
		if r.size != Vector2i.ZERO:
			var front: float = r.end.x + shot._shift
			if last != -INF and shot._tick >= n:
				var d := front - last
				if d < -0.5:
					back = true
				worst = maxf(worst, d)
			last = front
		frames += 1
		await _frames(1)
	var ok := not back and (speed <= 0.0 or worst <= speed * 2.0 + 1.0) and frames < 600
	if not ok:
		failures += 1
	print(("  ok  " if ok else "  FALHOU  ") + "%s: %d quadros com o tiro visível, %.2f px/f no fim, %d frames na tela%s%s" % [
		label, n, speed, frames,
		" (voltou para trás)" if back else "", " (salto %.1f)" % worst if worst > 0 else ""])
	if is_instance_valid(shot):
		shot.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
