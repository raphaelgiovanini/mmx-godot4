class_name Characters
## Personagens jogáveis, portados de Player.SKINS do mmx8-16bit (ordem = ordem da troca).
## stats multiplicam a física base do X: speed (andar), dash, jump, damage (tiro), max_shots.
## "hidden" = fora da seleção (por ora, os personagens fora do foco X e Zero).
## "buster" = sprites originais do tiro (x1/x2/x3, capturados das ROMs); "select" = o jogador escolhe (tecla B).
## "emblem" = letra do símbolo na barra de energia.
## stats.airdash = quantos dash no ar por pulo (0 no X sem armadura, como no X1 original).

const LIST := [
	{"id": "x", "icon": "x", "emblem": "X", "name": "MEGA MAN X", "color": Color("3d8bff"), "buster": "select", "stats": {}},
	{"id": "zero", "icon": "zero", "emblem": "Z", "name": "ZERO", "color": Color("ff2d6e"), "buster": "x3", "melee": "saber", "muzzle_y": -23.0,
		"stats": {"airdash": 1}},   # X3: mesma física do X; dash no ar a pedido (o X3 original não tem)
	{"id": "protoman", "emblem": "P", "name": "PROTO MAN", "color": Color("ff3b47"), "hidden": true,
		"stats": {"speed": 1.05, "jump": 1.05}},
	{"id": "bass", "emblem": "B", "name": "BASS", "color": Color("b06bff"), "hidden": true,
		"stats": {"damage": 0.6, "max_shots": 5, "air_jumps": 1, "airdash": 1}},
	{"id": "megaman", "emblem": "M", "name": "MEGA MAN", "color": Color("ffd23d"), "hidden": true, "stats": {}},
	{"id": "vile", "emblem": "V", "name": "VILE", "color": Color("8a5cd6"), "hidden": true,
		"stats": {"damage": 1.4, "speed": 0.9, "jump": 0.95, "airdash": 1}},
]


## Peças de armadura do X (docs/armaduras-e-energia.md), uma por encaixe: capacete, corpo, braço, pernas.
## Cada peça liga o efeito do jogo dela, e peças de jogos diferentes se combinam (o original não deixa).
## "skin" = visual quando é a peça do corpo; "buster" = tiro do braço; "arm" = carregado do braço gravado
## do original (assets/weapons/x1/<arm>): espiral do X1, carregado + 2º tiro do X2, cruz do X3.
const ARMOR_SETS := {
	"light": {"name": "LIGHT", "game": "X1", "skin": "x_light", "buster": "x1", "arm": "arm_x1"},
	"giga": {"name": "GIGA", "game": "X2", "skin": "x_giga", "buster": "x2", "arm": "arm_x2"},
	"tri": {"name": "TRI", "game": "X3", "skin": "x_tri", "buster": "x3", "arm": "arm_x3"},
}
const SLOTS := ["head", "body", "arm", "legs"]


static func by_id(id: String) -> Dictionary:
	for c in LIST:
		if c.id == id:
			return c
	return LIST[0]


## Próximo personagem selecionável.
static func next(id: String, step: int) -> Dictionary:
	var playable := LIST.filter(func(c): return not c.get("hidden", false))
	var i := playable.find(by_id(id))
	return playable[posmod(i + step, playable.size())]
