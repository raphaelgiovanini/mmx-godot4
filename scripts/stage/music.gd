extends AudioStreamPlayer
## Música da fase: toca a introdução uma vez e depois o trecho em loop (arquivos fora do git, em
## assets/music; tirados do mmx8-16bit, src/Sounds/OST - *). Sem os arquivos, fica em silêncio.

@export var intro := "res://assets/music/boss_intro.ogg"
@export var loop := "res://assets/music/boss_loop.ogg"


func _ready() -> void:
	volume_db = -8.0
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua no menu de pausa, como nos originais
	play_track(intro, loop)


## Troca a música: toca `intro_path` uma vez e depois `loop_path` em loop (vazio = só a intro).
func play_track(intro_path: String, loop_path: String) -> void:
	intro = intro_path
	loop = loop_path
	if finished.is_connected(_play_loop):
		finished.disconnect(_play_loop)
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
	return Assets.audio(path)
