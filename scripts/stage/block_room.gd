extends Node2D
## Sala de teste: blocos sólidos definidos em uma lista de retângulos (x, y, largura, altura em px).
## Provisório até as fases reais (TileMapLayer). Desenha e colide com a mesma lista.

@export var blocks: Array[Rect2] = []
@export var color := Color("3b4252")


func _ready() -> void:
	for rect in blocks:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
		add_child(body)


func _draw() -> void:
	for rect in blocks:
		draw_rect(rect, color)
		draw_rect(rect, color.lightened(0.25), false, 1.0)
