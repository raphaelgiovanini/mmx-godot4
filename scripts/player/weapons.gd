class_name Weapons
## Armas dos chefes do X1, X2 e X3 (índice 0 = buster). Gravações do original no Mesen, fora do git:
##   X1: tools/mesen/weapons.lua + tools/cut_weapons_x1.py → assets/weapons/x1/<id>/
##   X2/X3: idem com os inimigos desligados + tools/cut_weapons_x23.py → assets/weapons/x2|x3/<id>/
## Carregado do X1: precisa do braço e do nível "super" da carga ($5B=1 → $59=4, 81:94AF),
## por isso a captura segura 230 frames com 7E:1F99=0F desde o boot.
## "boss" = de quem a arma vem; "weak" = chefe fraco a ela (ciclo de fraquezas de cada jogo).
## "col" = coluna na tabela de dano do X1 (86:EF37): 07–0E normal, +9 carregado. Sem "col" (X2/X3),
## o dano é o provisório de DAMAGE até a tabela daqueles jogos entrar.

const LIST := [
	{"id": "buster", "name": "X-BUSTER", "game": "", "color": Color("3d8bff")},
	{"id": "homing_torpedo", "name": "HOMING TORPEDO", "game": "x1", "color": Color("9aa3b5"), "boss": "Launch Octopus", "weak": "Boomer Kuwanger", "col": 7},
	{"id": "chameleon_sting", "name": "CHAMELEON STING", "game": "x1", "color": Color("8fe060"), "boss": "Sting Chameleon", "weak": "Storm Eagle", "col": 8},
	{"id": "rolling_shield", "name": "ROLLING SHIELD", "game": "x1", "color": Color("ff6e8a"), "boss": "Armored Armadillo", "weak": "Launch Octopus", "col": 9},
	{"id": "fire_wave", "name": "FIRE WAVE", "game": "x1", "color": Color("ff8a2d"), "boss": "Flame Mammoth", "weak": "Chill Penguin", "col": 10},
	{"id": "storm_tornado", "name": "STORM TORNADO", "game": "x1", "color": Color("e58cff"), "boss": "Storm Eagle", "weak": "Flame Mammoth", "col": 11},
	{"id": "electric_spark", "name": "ELECTRIC SPARK", "game": "x1", "color": Color("ffd23d"), "boss": "Spark Mandrill", "weak": "Armored Armadillo", "col": 12},
	{"id": "boomerang_cutter", "name": "BOOMERANG CUTTER", "game": "x1", "color": Color("c8c8d8"), "boss": "Boomer Kuwanger", "weak": "Sting Chameleon", "col": 13},
	{"id": "shotgun_ice", "name": "SHOTGUN ICE", "game": "x1", "color": Color("7fd0ff"), "boss": "Chill Penguin", "weak": "Spark Mandrill", "col": 14},
	{"id": "crystal_hunter", "name": "CRYSTAL HUNTER", "game": "x2", "color": Color("8a7bff"), "boss": "Crystal Snail", "weak": "Overdrive Ostrich"},
	{"id": "bubble_splash", "name": "BUBBLE SPLASH", "game": "x2", "color": Color("6ee0c0"), "boss": "Bubble Crab", "weak": "Flame Stag"},
	{"id": "silk_shot", "name": "SILK SHOT", "game": "x2", "color": Color("c89a5a"), "boss": "Morph Moth", "weak": "Magna Centipede"},
	{"id": "spin_wheel", "name": "SPIN WHEEL", "game": "x2", "color": Color("e0e0e0"), "boss": "Wheel Gator", "weak": "Bubble Crab"},
	{"id": "sonic_slicer", "name": "SONIC SLICER", "game": "x2", "color": Color("9ab0ff"), "boss": "Overdrive Ostrich", "weak": "Wire Sponge"},
	{"id": "strike_chain", "name": "STRIKE CHAIN", "game": "x2", "color": Color("b07cff"), "boss": "Wire Sponge", "weak": "Wheel Gator"},
	{"id": "magnet_mine", "name": "MAGNET MINE", "game": "x2", "color": Color("c060ff"), "boss": "Magna Centipede", "weak": "Crystal Snail"},
	{"id": "speed_burner", "name": "SPEED BURNER", "game": "x2", "color": Color("ff6a2a"), "boss": "Flame Stag", "weak": "Morph Moth"},
	{"id": "acid_burst", "name": "ACID BURST", "game": "x3", "color": Color("6ee040"), "boss": "Toxic Seahorse", "weak": "Tunnel Rhino"},
	{"id": "parasitic_bomb", "name": "PARASITIC BOMB", "game": "x3", "color": Color("8a8aa0"), "boss": "Blast Hornet", "weak": "Blizzard Buffalo"},
	{"id": "triad_thunder", "name": "TRIAD THUNDER", "game": "x3", "color": Color("ffe060"), "boss": "Volt Catfish", "weak": "Crush Crawfish"},
	{"id": "spinning_blade", "name": "SPINNING BLADE", "game": "x3", "color": Color("d0d8e8"), "boss": "Crush Crawfish", "weak": "Neon Tiger"},
	{"id": "ray_splasher", "name": "RAY SPLASHER", "game": "x3", "color": Color("ff5050"), "boss": "Neon Tiger", "weak": "Gravity Beetle"},
	{"id": "gravity_well", "name": "GRAVITY WELL", "game": "x3", "color": Color("6a6aff"), "boss": "Gravity Beetle", "weak": "Blast Hornet"},
	{"id": "frost_shield", "name": "FROST SHIELD", "game": "x3", "color": Color("80c0ff"), "boss": "Blizzard Buffalo", "weak": "Toxic Seahorse"},
	{"id": "tornado_fang", "name": "TORNADO FANG", "game": "x3", "color": Color("b0b0c8"), "boss": "Tunnel Rhino", "weak": "Volt Catfish"},
]
const DAMAGE := [2, 4]   # normal, carregado (provisório)
## Energia: barra de 28 unidades (8.8 em 7E1F88+). Custo [normal, carregado] por disparo.
## X1 medido no Mesen (energia antes/depois de cada tiro, tools/mesen/weapons.lua LOGE). O Fire Wave
## gasta 1/16 por frame segurado; aqui um disparo = um toque de 2 frames, e o carregado inteiro 8,625.
## X2/X3: MmxWeaponsSpend do recomp (mmx_weapon_combat.c e mmx_weapon_*.inc).
const MAX_ENERGY := 28.0
const COST := {
	"homing_torpedo": [0.5, 3.5], "chameleon_sting": [0.5, 4.5], "rolling_shield": [1.0, 3.0],
	"fire_wave": [0.0625, 8.625], "storm_tornado": [1.0, 2.0], "electric_spark": [1.0, 3.0],
	"boomerang_cutter": [1.0, 1.0], "shotgun_ice": [1.0, 2.5],
	"crystal_hunter": [1.0, 2.0], "spin_wheel": [1.0, 3.0], "sonic_slicer": [0.5, 2.0],
	"magnet_mine": [1.0, 3.0], "speed_burner": [1.0, 3.0],
	"acid_burst": [1.0, 2.0], "parasitic_bomb": [1.0, 1.0], "spinning_blade": [1.0, 3.0],
	"ray_splasher": [1.0, 2.5], "gravity_well": [1.0, 1.0], "frost_shield": [1.0, 3.0], "tornado_fang": [1.0, 3.0],
}
## ponytail: Bubble Splash, Silk Shot, Strike Chain e Triad Thunder gastam por frame/peça no original;
## aqui 1 e 2 por disparo até esses tiros serem objetos de verdade.
const COST_DEFAULT := [1.0, 2.0]
const ROOT := "res://assets/weapons/"

static var _cache := {}


## Gravação de uma arma: {"normal": [Texture2D], "charged": [...], "second": [...], "rects": [[Rect2i] × 3], "edge": x}.
## "second" = segundo tiro da carga dupla (X2: tools/split_second_shot.py; X3: gravação com o 2º aperto),
## disparado no novo aperto. "replaces" (meta second_replaces, X3): o aperto transforma o primeiro tiro,
## então o segundo é a gravação inteira a partir do aperto e o primeiro some.
## second_start (meta, X3): quadros do começo do segundo tiro que ficam de fora. Soltar já dispara a cruz
## (escolha do dono), então as 3 bolinhas e o tiro rosa do 1º disparo saem; a gravação começa na bola.
## edge = borda direita da tela do SNES na janela (meta.json): ali o tiro começa a ser cortado.
## Cada quadro é a janela 272×160 presa aos pés do X no disparo (âncora 48, 120), um a cada 2 frames.
static func frames(w: Dictionary) -> Dictionary:
	if _cache.has(w.id):
		return _cache[w.id]
	var data := {"normal": [], "charged": [], "second": [], "rects": [[], [], []], "edge": 9999, "replaces": false, "lob": {}}
	var dir := ProjectSettings.globalize_path(ROOT).path_join(w.game + "/" + w.id)
	var meta = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json")))
	var skip := 0
	if meta != null:
		data.edge = int(meta.edge)
		skip = int(meta.get("second_start", 0))
		data.lob = meta.get("lob", {})
		data.replaces = meta.get("second_replaces", false)
	for i in 3:
		var kind: String = ["shot", "charged", "second"][i]
		var k := skip if kind == "second" else 0
		while FileAccess.file_exists(dir.path_join("%s_%03d.png" % [kind, k])):
			var img := Image.load_from_file(dir.path_join("%s_%03d.png" % [kind, k]))
			data[["normal", "charged", "second"][i]].append(ImageTexture.create_from_image(img))
			data.rects[i].append(img.get_used_rect())
			k += 1
	_cache[w.id] = data
	return data
