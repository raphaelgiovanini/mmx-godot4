extends SceneTree
## Fase 1 (highway): inimigos nascem e morrem com o buster, buraco volta ao checkpoint,
## a arena fecha, chama o chefe e vencê-lo dá STAGE CLEAR.
## Rodar: godot --headless --path . -s res://tests/stage_test.gd

const Stage := preload("res://scenes/stages/highway.tscn")
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := Stage.instantiate()
	root.add_child(s)
	var p: Player = s.get_node("Player")
	await _frames(10)
	var enemies := s.get_children().filter(func(n): return n is Enemy)
	_ok(enemies.size() == 14, "14 inimigos na fase (%d)" % enemies.size())
	var e: Enemy = enemies[0]
	for i in 10:
		e.hit(0, 1.0)
		e._invuln = 0
	await _frames(2)
	_ok(not is_instance_valid(e), "inimigo morre com o buster")
	p.global_position = Vector2(1500, 176)
	await _frames(2)
	p.global_position = Vector2(1460, 400)
	await _frames(2)
	_ok(p.global_position.distance_to(Vector2(1420, 176)) < 4, "buraco volta ao checkpoint")
	p.global_position = Vector2(3060, 176)
	await _frames(3)
	var boss: Boss = s.get_children().filter(func(n): return n is ChillPenguin).front()
	_ok(boss != null, "arena chama o chefe")
	_ok(s.get_node("Player/Camera").limit_left == 3000, "câmera presa na arena")
	var seen := {}
	for i in 1500:
		seen[boss._state] = true
		await physics_frame
	_ok(seen.size() >= 6, "chefe usa os golpes (%d estados)" % seen.size())
	_ok(boss.position.x >= boss.arena.x and boss.position.x <= boss.arena.y and boss.position.y <= 176.5, "chefe fica dentro da arena")
	boss.hit(-1, 99)
	await create_timer(4.0).timeout
	var clear := s.get_node("Stage").find_children("*", "Label", true, false).any(func(l): return l.text == "STAGE CLEAR")
	_ok(clear, "chefe vencido dá STAGE CLEAR")
	_ok(p.cutscene_pose == &"beam", "pose de vitória e teletransporte")
	print("FALHAS: %d" % failures if failures else "OK: fase 1")
	quit(1 if failures else 0)


func _ok(cond: bool, what: String) -> void:
	print(("  ok  " if cond else "  FALHA  ") + what)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
