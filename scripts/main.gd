extends SubViewportContainer
## Tela do jogo: a fase roda num SubViewport no tamanho do SNES (398×224) e é desenhada na janela com o
## filtro xBR (scripts/xbr.gdshader), que deixa os contornos lisos. F2 liga e desliga o filtro.


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_F2:
		material.set_shader_parameter(&"enabled", not material.get_shader_parameter(&"enabled"))
