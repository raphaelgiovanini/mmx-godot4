extends SceneTree
# Exporta os personagens do mmx8-16bit (SpriteFrames do Godot 3) para PNG + JSON lidos pelo Godot 4.
# Roda NO GODOT 3, dentro do projeto mmx8:
#   OUT=<mmx-godot4>/assets/characters "/Applications/Godot 3.app/Contents/MacOS/Godot" \
#     --no-window --path <mmx8-16bit> -s <mmx-godot4>/tools/export_mmx8_skins.gd
# Saída: OUT/<skin>/<anim>_<i>.png e OUT/<skin>/frames.json {anim: {fps, loop, frames: [arquivo]}}.
# Os quadros já vêm alinhados pelo build_skin do mmx8: pés 20 px abaixo do centro do quadro.

const SKINS := {
	"x": "res://src/Actors/Player/x_sprites/x.res",
	"zero": "res://src/Actors/Player/skins/zero/zero.res",
	"zero_black": "res://src/Actors/Player/skins/zero_black/zero_black.res",
	"protoman": "res://src/Actors/Player/skins/protoman/protoman.res",
	"bass": "res://src/Actors/Player/skins/bass/bass.res",
	"bass_treble": "res://src/Actors/Player/skins/bass_treble/bass_treble.res",
	"megaman": "res://src/Actors/Player/skins/megaman_normal/megaman_normal.res",
	"megaman_rush": "res://src/Actors/Player/skins/megaman/megaman.res",
	"vile": "res://src/Actors/Player/skins/vile/vile.res",
	"x_ultimate": "res://src/Actors/Player/skins/x_ultimate/x_ultimate.res",
	# armaduras de corpo inteiro do X (Player.BODY_ARMORS no mmx8)
	"x_light": "res://src/Actors/Player/skins/x_light/x_light.res",
	"x_giga": "res://src/Actors/Player/skins/x_giga/x_giga.res",
	"x_tri": "res://src/Actors/Player/skins/x_tri/x_tri.res",
	"x_gold": "res://src/Actors/Player/skins/x_gold/x_gold.res",
	"x_fourth": "res://src/Actors/Player/skins/x_fourth/x_fourth.res",
}


func _init():
	var out: String = OS.get_environment("OUT")
	if out == "":
		printerr("defina OUT")
		quit(1)
		return
	var dir := Directory.new()
	for skin in SKINS:
		var frames: SpriteFrames = load(SKINS[skin])
		if frames == null:
			printerr("não carregou ", SKINS[skin])
			continue
		var base: String = out.plus_file(skin)
		dir.make_dir_recursive(base)
		var meta := {}
		var count := 0
		for anim in frames.get_animation_names():
			var files := []
			for i in frames.get_frame_count(anim):
				var img := _image(frames.get_frame(anim, i))
				if img == null:
					continue
				var name := "%s_%d.png" % [anim, i]
				img.save_png(base.plus_file(name))
				files.append(name)
				count += 1
			meta[anim] = {"fps": frames.get_animation_speed(anim), "loop": frames.get_animation_loop(anim), "frames": files}
		var f := File.new()
		f.open(base.plus_file("frames.json"), File.WRITE)
		f.store_string(to_json(meta))
		f.close()
		print("%s: %d animações, %d quadros" % [skin, meta.size(), count])
	# retratos da tela de armaduras (recortes de TheEvilMaverick, "Megaman X All X Armors"; creditar)
	var portraits: String = out.plus_file("portraits")
	dir.make_dir_recursive(portraits)
	for armor in ["light", "giga", "tri", "gold", "fourth", "ultimate"]:
		dir.copy("res://src/StageSelect/armor_setup/full/%s.png" % armor, portraits.plus_file(armor + ".png"))
	quit(0)


func _image(tex: Texture) -> Image:
	if tex == null:
		return null
	if tex is AtlasTexture:
		var atlas: Image = tex.atlas.get_data()
		var img: Image = atlas.get_rect(tex.region)
		if tex.margin.size != Vector2.ZERO:
			var full := Image.new()
			full.create(int(tex.region.size.x + tex.margin.size.x), int(tex.region.size.y + tex.margin.size.y), false, Image.FORMAT_RGBA8)
			full.blit_rect(img, Rect2(Vector2.ZERO, tex.region.size), tex.margin.position)
			return full
		return img
	return tex.get_data()
