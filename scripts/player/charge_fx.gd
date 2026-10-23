extends Node2D
## Aura de carga original, capturada das ROMs no Mesen 2 (tools/cut_charge.py → assets/charge/<jogo>/):
## as faíscas de cada frame e o clarão da paleta do X (via modulate), na mesma linha do tempo do jogo original
## (frame N desde o aperto do tiro). Depois do último frame capturado repete o trecho da carga cheia.
## Personagens sem buster próprio usam a aura do X1. Sons: CHARGE / CHARGED_SHOT (32 kHz, ripados do X1)
## e o loop CHARGE_MAX_LONG do mmx8 (assets/sfx/, tools/install_sfx.sh).

const ROOT := "res://assets/charge/"
## Volume e tom por som, como nos tiros do mmx8 (Lemon, Medium Buster, Charged Buster .tscn).
## BUSTER_CHARGED é o CHARGED_SHOT tocado como o carregado do buster do mmx8 (grave); armas e
## armaduras seguem com o CHARGED_SHOT normal.
const VOLUME_DB := {"LEMON": -12.7, "MEDIUM_SHOT": -13.8, "BUSTER_CHARGED": -10.2}
const PITCH := {"BUSTER_CHARGED": 0.41}
const BUSTER_SOUNDS := ["LEMON", "MEDIUM_SHOT", "BUSTER_CHARGED"]

static var _cache := {}

var player: Player
var _sfx := {}
var _charge_player := AudioStreamPlayer.new()
var _shot_player := AudioStreamPlayer.new()
var _stage := 0               # 0 parado, 1 carregando, 2 cheio
var _texture: Texture2D
var _held := 0                # frames com tiro guardado (ciclo da piscada)


func _ready() -> void:
	player = get_parent()
	z_index = 2
	for name in ["CHARGE", "CHARGE_MAX_LONG", "CHARGED_SHOT", "MEDIUM_SHOT", "LEMON", "saber_1", "saber_2", "saber_3"]:
		_sfx[name] = _load_sound(name)
	_sfx["BUSTER_CHARGED"] = _sfx["CHARGED_SHOT"]
	add_child(_charge_player)
	add_child(_shot_player)


static func _load_sound(name: String) -> AudioStream:
	var dir := ProjectSettings.globalize_path("res://assets/sfx/")
	if FileAccess.file_exists(dir + name + ".wav"):
		return AudioStreamWAV.load_from_file(dir + name + ".wav")
	if FileAccess.file_exists(dir + name + ".ogg"):
		return AudioStreamOggVorbis.load_from_file(dir + name + ".ogg")
	return null


## Quadros e metadados de um jogo (vazio se não foi instalado).
static func _data(game: String) -> Dictionary:
	if _cache.has(game):
		return _cache[game]
	var dir := ProjectSettings.globalize_path(ROOT + game)
	var meta = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("charge.json")))
	var data := {}
	if meta != null:
		data = meta
		data.frames = {}
		for k in range(int(meta.first), int(meta.last) + 1):
			var img := Image.load_from_file(dir.path_join("sparks_%03d.png" % k))
			if img:
				data.frames[k] = ImageTexture.create_from_image(img)
	_cache[game] = data
	return data


func play(name: String) -> void:
	if _sfx.get(name):
		_shot_player.stream = _sfx[name]
		_shot_player.volume_db = VOLUME_DB.get(name, 0.0)
		_shot_player.pitch_scale = PITCH.get(name, 1.0)
		if name in BUSTER_SOUNDS:   # variação do WeaponShot.play_fire_sound do mmx8
			_shot_player.pitch_scale += randf_range(-0.05, 0.0)
		_shot_player.play()


func _physics_process(_delta: float) -> void:
	var levels := player.charge_levels()
	var stage := 0
	if player.charge >= levels[1] or (player.charge == 0 and player.has_stored_shot()):
		stage = 2   # cheio, ou tiro guardado: o som da carga cheia continua até disparar
	elif player.charge >= levels[0] * 0.5:
		stage = 1
	if stage != _stage:
		_charge_player.stop()
		var loop: AudioStream = _sfx.CHARGE if stage == 1 else (_sfx.CHARGE_MAX_LONG if stage == 2 else null)
		if loop:
			_charge_player.stream = loop
			_charge_player.play()
		_stage = stage

	var data := _data(player.buster() if player.buster() != "" else "x1")
	_texture = null
	var add := Vector3.ZERO
	if not data.is_empty() and player.charge > 0:
		var full := int(data.full)
		var last := int(data.last)
		var k: int = player.charge
		if k > last:
			k = full + (k - full) % (last - full + 1)
		_texture = data.frames.get(k)
		var f = data.flash.get(str(k))
		if f != null:
			add = Vector3(f[0], f[1], f[2])
	elif not data.is_empty() and player.has_stored_shot():
		# Tiro guardado (carga dupla, combo do Zero): continua piscando como na carga cheia, sem as
		# faíscas, até disparar — como no original.
		_held += 1
		var full := int(data.full)
		var f = data.flash.get(str(full + _held % (int(data.last) - full + 1)))
		if f != null:
			add = Vector3(f[0], f[1], f[2])
			if player.zsaber_ready or player.zero_combo in [-1, 2]:
				# Sabre guardado (X3 e Zero): a piscada fica verde, como no original.
				var g := (add.x + add.y + add.z) / 3.0
				add = Vector3(g * 0.2, g * 1.5, g * 0.2)
	# Clarão da paleta do original como brilho multiplicativo (o X clareia na cor da variação).
	if player.visual:
		player.visual.modulate = Color(1, 1, 1) + Color(add.x, add.y, add.z, 0) * 1.5
	queue_redraw()


func _draw() -> void:
	# Quadro 80×80 com os pés do X na linha 72 (charge.json "feet"); a origem do Player é o pé.
	if _texture:
		draw_texture(_texture, Vector2(-40, -72))
