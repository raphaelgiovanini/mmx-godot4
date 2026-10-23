class_name Assets
## Carrega imagens e sons de assets/ pelo importador do Godot, o único jeito que funciona no jogo
## exportado (lá dentro os PNG/OGG originais não existem, só as versões importadas).
## Arquivo novo gerado por tools/ só aparece depois de `godot --headless --path . --import`.


## Textura importada, ou null se o arquivo não existe (asset fora do git que não foi gerado).
static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## Pixels da imagem (para recortar, ampliar ou medir), ou null.
static func image(path: String) -> Image:
	var tex := texture(path)
	return tex.get_image() if tex else null


static func audio(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path)
