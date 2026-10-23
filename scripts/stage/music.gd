extends AudioStreamPlayer
## Música da fase: toca a introdução uma vez e depois o trecho em loop (arquivos fora do git, em
## assets/music; tirados do mmx8-16bit, src/Sounds/OST - *). Sem os arquivos, fica em silêncio.

@export var intro := "res://assets/music/boss_intro.ogg"
@export var loop := "res://assets/music/boss_loop.ogg"


func _ready() -> void:
	volume_db = -8.0
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua no menu de pausa, como nos originais
	var first := _load(intro)
	if first == null:
		_play_loop()
		return
	stream = first
	finished.connect(_play_loop, CONNECT_ONE_SHOT)
	play()


func _play_loop() -> void:
	var s := _load(loop)
	if s == null:
		return
	s.loop = true
	stream = s
	play()


func _load(path: String) -> AudioStreamOggVorbis:
	return AudioStreamOggVorbis.load_from_file(path) if FileAccess.file_exists(path) else null
