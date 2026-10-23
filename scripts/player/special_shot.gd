extends Area2D
## Hadouken (X1) e Shoryuken (X2): quadros da folha (assets/fx/<name>), coluna 4 da tabela de dano
## do X1 (32 no Chill Penguin = mata com um golpe). O Shoryuken segue o X enquanto ele sobe.

var frames_name := "hadouken"
var dir := 1
var speed := 0.0      # px/frame
var follow: Node2D = null
var offset := Vector2.ZERO
var life := 120
var _tex: Array[Texture2D] = []
var _t := 0
var _hit := {}


func _ready() -> void:
	var path := "res://assets/fx/%s/%03d.png"
	while Assets.exists(path % [frames_name, _tex.size()]):
		_tex.append(Assets.texture(path % [frames_name, _tex.size()]))
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 30)
	shape.shape = box
	add_child(shape)
	scale.x = dir
	body_entered.connect(_on_body)


func _physics_process(_delta: float) -> void:
	_t += 1
	if follow:
		global_position = follow.global_position + Vector2(offset.x * dir, offset.y)
	else:
		position.x += speed * dir
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _tex.is_empty():
		return
	# Shoryuken: as 2 chamas em loop (o 3º quadro é a fagulha do fim).
	var n := _tex.size() - 1 if follow and _tex.size() > 2 else _tex.size()
	var tex := _tex[(_t / 4) % n]
	draw_texture(tex, -tex.get_size() / 2.0)


func _on_body(b: Node) -> void:
	if b is Boss and not _hit.has(b):
		_hit[b] = true
		b.hit(4, 1.0)
