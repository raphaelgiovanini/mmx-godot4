extends Area2D
## Espinhos: tiram vida de quem encostar (só para testar a barra enquanto não há inimigos).

@export var rect := Rect2(0, 0, 32, 8)
@export var damage := 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			body.take_damage(damage)


func _draw() -> void:
	var n := int(rect.size.x / 8)
	for i in n:
		var x := rect.position.x + i * 8
		draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 4, rect.position.y), Vector2(x + 8, rect.end.y)]), Color("c84a4a"))
