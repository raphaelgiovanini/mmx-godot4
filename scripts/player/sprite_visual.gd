class_name SpriteVisual
extends AnimatedSprite2D
## Visual com os sprites exportados do mmx8 (assets/characters/<id>/frames.json + PNGs).
## Mesmo contrato do placeholder: show_state(pose, facing). Trocar por um visual 2.5D depois.
## Quadros vêm alinhados com os pés 20 px abaixo do centro, por isso position.y = -20.

const ROOT := "res://assets/characters/"
const SWAP_SHADER := preload("res://scripts/player/palette_swap.gdshader")
## Cores da armadura por sprite (quadro parado), do escuro para o claro.
const ARMOR := {
	"zero": [Color8(96, 32, 0), Color8(160, 32, 0), Color8(224, 32, 0)],
	"zero_black": [Color8(96, 32, 0), Color8(160, 32, 0), Color8(224, 32, 0)],
	"megaman": [Color8(0, 48, 96), Color8(24, 144, 168), Color8(0, 64, 208), Color8(48, 192, 216), Color8(0, 136, 240), Color8(144, 216, 248)],
	"protoman": [Color8(104, 48, 16), Color8(168, 48, 8), Color8(240, 80, 8)],
	"bass": [Color8(48, 48, 64), Color8(80, 80, 104), Color8(144, 144, 160)],
	"vile": [Color8(56, 88, 0), Color8(88, 128, 0), Color8(128, 176, 16)],
	# Gold: os azuis do X viraram dourado (escuro → claro); são eles que pegam a cor da arma.
	"x_gold": [Color8(229, 69, 5), Color8(247, 101, 11), Color8(229, 117, 25), Color8(247, 220, 46), Color8(247, 229, 142)],
}
## Armaduras que mantêm os azuis do X: a troca é cor a cor, como no X (as peças da armadura ficam).
const X_BLUES := ["x", "x_light", "x_tri"]

static var _cache := {}
static var _palettes = null
static var _hues := {}    # personagem -> matiz principal (0–1)

var _pose: StringName = &""
var _id := ""
var _palette := ""


func set_character(id: String) -> void:
	_id = id
	_apply()


## Cores da arma (assets/weapons/palettes.json), aplicadas pelo shader palette_swap (sem custo na troca).
## "" = cores normais. O par de paletas é do X (cor a cor). Nos outros, só a armadura muda (rosto, mãos,
## cabelo e olhos ficam): as cores de ARMOR viram a cor da arma de brilho mais próximo. Sem lista, a cor
## principal do sprite (matiz saturado mais comum, fora tons de pele) faz esse papel no shader.
func set_palette(weapon_id: String) -> void:
	_palette = weapon_id
	_apply()


func _apply() -> void:
	var anim := animation
	var frame_i := frame
	sprite_frames = _load(_id)
	if sprite_frames and sprite_frames.has_animation(anim):
		play(anim)
		frame = frame_i
	else:
		_pose = &""
	_apply_palette()


func _apply_palette() -> void:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SWAP_SHADER
	var m := material as ShaderMaterial
	if _palettes == null:
		_palettes = JSON.parse_string(FileAccess.get_file_as_string(
			ProjectSettings.globalize_path("res://assets/weapons/palettes.json")))
		if _palettes == null:
			_palettes = {}
	var pair = _palettes.get(_palette) if _palette != "" else null
	if pair == null or sprite_frames == null:
		m.set_shader_parameter("mode", 0)
		return
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	var ramp: Array = []    # [brilho no X, cor da arma] das cores azuis do X
	for i in mini(pair[0].size(), 12):
		var a := Color8(pair[0][i][0], pair[0][i][1], pair[0][i][2])
		var b := Color8(pair[1][i][0], pair[1][i][1], pair[1][i][2])
		from.append(Vector3(a.r, a.g, a.b))
		to.append(Vector3(b.r, b.g, b.b))
		if a.s > 0.3 and a.h > 0.5 and a.h < 0.72 and ramp.size() < 8:
			ramp.append([a.v, Vector3(b.r, b.g, b.b)])
	from.resize(12)
	to.resize(12)
	var rv := PackedFloat32Array()
	var rc := PackedVector3Array()
	for r in ramp:
		rv.append(r[0])
		rc.append(r[1])
	rv.resize(8)
	rc.resize(8)
	var count := mini(pair[0].size(), 12)
	if ARMOR.has(_id) and not ramp.is_empty():
		# Armadura listada (escuro → claro) na rampa da arma em ordem de brilho: a sombra mais escura
		# vira a cor mais escura da arma e a luz, a mais clara, mantendo o degradê da armadura.
		var sorted_ramp := ramp.duplicate()
		sorted_ramp.sort_custom(func(a, b): return a[0] < b[0])
		var colors: Array = ARMOR[_id]
		count = colors.size()
		for i in count:
			var c: Color = colors[i]
			var k := roundi(float(i) * (sorted_ramp.size() - 1) / maxf(count - 1, 1))
			from[i] = Vector3(c.r, c.g, c.b)
			to[i] = sorted_ramp[k][1]
	m.set_shader_parameter("mode", 1 if _id in X_BLUES or ARMOR.has(_id) else 2)
	m.set_shader_parameter("count", count)
	m.set_shader_parameter("from_c", from)
	m.set_shader_parameter("to_c", to)
	m.set_shader_parameter("ramp_n", ramp.size())
	m.set_shader_parameter("ramp_v", rv)
	m.set_shader_parameter("ramp_c", rc)
	if _id != "x" and not ARMOR.has(_id):
		if not _hues.has(_id):
			_hues[_id] = _main_hue(sprite_frames)
		m.set_shader_parameter("hue", _hues[_id])


## Tom de pele (rosto, mãos): fica fora da troca. Mesmo teste do shader palette_swap.
static func _skin(c: Color) -> bool:
	return c.h >= 0.02 and c.h <= 0.11 and c.s <= 0.66 and c.v >= 0.7


## Matiz mais comum entre os pixels saturados do primeiro quadro (0–1), fora tons de pele.
static func _main_hue(base: SpriteFrames) -> float:
	var bins := PackedInt32Array()
	bins.resize(36)
	var anim: StringName = &"idle" if base.has_animation(&"idle") else base.get_animation_names()[0]
	var img := base.get_frame_texture(anim, 0).get_image()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.s > 0.35 and c.v > 0.2 and not _skin(c):
				bins[int(c.h * 36.0) % 36] += 1
	var best := 0
	for i in 36:
		if bins[i] > bins[best]:
			best = i
	return (best + 0.5) / 36.0


func show_state(pose: StringName, facing: int) -> void:
	flip_h = facing < 0
	if pose == _pose or sprite_frames == null or not sprite_frames.has_animation(pose):
		return
	_pose = pose
	play(pose)


## Monta o SpriteFrames uma vez por personagem. Lê os PNGs direto do disco: são gerados fora do
## editor (tools/export_mmx8_skins.gd) e não precisam passar pelo importador.
static func _load(id: String) -> SpriteFrames:
	if _cache.has(id):
		return _cache[id]
	var dir := ProjectSettings.globalize_path(ROOT + id)
	var text := FileAccess.get_file_as_string(dir.path_join("frames.json"))
	var meta = JSON.parse_string(text)
	if meta == null:
		push_error("sem sprites para '%s': rode tools/export_mmx8_skins.gd" % id)
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in meta:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, meta[anim].fps)
		frames.set_animation_loop(anim, meta[anim].loop)
		for file: String in meta[anim].frames:
			var img := Image.load_from_file(dir.path_join(file))
			if img:
				frames.add_frame(anim, ImageTexture.create_from_image(img))
	_cache[id] = frames
	return frames
