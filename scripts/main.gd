extends SubViewportContainer
## Tela do jogo: a fase roda num SubViewport no tamanho do SNES (398×224) e é desenhada na janela com o
## filtro xBR (scripts/xbr.gdshader), que deixa os contornos lisos. F2 liga e desliga o filtro.
## Interface (HUD, menus, avisos: CanvasLayer com layer >= 0) é desenhada direto na janela, fora do
## filtro e na resolução dela; o céu (layer negativo) fica no SubViewport, atrás da fase.


func _ready() -> void:
	# A interface ainda pertence ao SubViewport, que gera as letras na escala dele (1×) e elas saem
	# borradas na janela: gera na escala da janela.
	$View.oversampling = true
	get_viewport().size_changed.connect(_fit_text)
	_fit_text()
	get_tree().node_added.connect(_on_node_added)
	for n in find_children("*", "CanvasLayer", true, false):
		_on_node_added(n)


func _fit_text() -> void:
	$View.oversampling_override = get_viewport().get_final_transform().get_scale().x


func _on_node_added(n: Node) -> void:
	if n is CanvasLayer and n.layer >= 0 and is_ancestor_of(n):
		n.custom_viewport = get_viewport()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F2:
		material.set_shader_parameter(&"enabled", not material.get_shader_parameter(&"enabled"))
