extends CanvasLayer
## HUD: barras (Health, BossBar) e o menu de armas (W). Os controles ficam no rodapé do menu de pausa.

@export var player_path: NodePath


func _ready() -> void:
	var player: Player = get_node(player_path)
	$Health.player = player
	var boss := get_tree().get_first_node_in_group(&"boss")
	$BossBar.boss = boss
	var menu := preload("res://scripts/ui/weapon_menu.gd").new()
	menu.player = player
	add_child(menu)

