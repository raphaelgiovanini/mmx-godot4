class_name DeathFX
## Morte dos inimigos como no mmx8 (src/Actors/Enemies/Shared/QuickEnemyDeath.tscn): estouro de 16
## quadros, pedaços do inimigo voando e o som "Enemy Death". Chefe: vários estouros grandes em sequência.

const DIR := "res://assets/enemies/"

static var _small: SpriteFrames
static var _big: SpriteFrames


## Inimigo comum: `remains` é a folha de pedaços (6×3 de 32 px) da cor dele.
static func small(parent: Node, at: Vector2, remains := "remains") -> void:
	if _small == null:
		_small = grid(DIR + "explosion.png", 4, 4, 30.0)
	var boom := _sprite(_small, at)
	parent.add_child(boom)
	var tex := Assets.texture(DIR + remains + ".png")
	for i in 5:
		var bit := Debris.new()
		bit.position = at + Vector2(randf_range(-6, 6), randf_range(-12, 0))
		bit.velocity = Vector2(randf_range(-1.8, 1.8), randf_range(-3.2, -1.2))
		if tex:
			var at_tex := AtlasTexture.new()
			at_tex.atlas = tex
			at_tex.region = Rect2((randi() % 6) * 32, (randi() % 3) * 32, 32, 32)
			bit.texture = at_tex
		parent.add_child(bit)
	_sound(parent, at)


## Chefe: oito estouros grandes espalhados pelo corpo, um a cada 0,12 s.
static func big(parent: Node, at: Vector2) -> void:
	if _big == null:
		_big = Enemy.sheet("big_explosion")
	for i in 8:
		parent.get_tree().create_timer(i * 0.12).timeout.connect(func():
			if not is_instance_valid(parent):
				return
			var boom := _sprite(_big, at + Vector2(randf_range(-24, 24), randf_range(-48, 0)), &"oneshot")
			parent.add_child(boom)
			if i % 3 == 0:
				_sound(parent, at))


## Folha em grade (colunas × linhas de quadros iguais) como animação "default" de uma vez só.
static func grid(path: String, cols: int, rows: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_loop(&"default", false)
	sf.set_animation_speed(&"default", fps)
	var tex := Assets.texture(path)
	if tex == null:
		return sf
	var size := tex.get_size() / Vector2(cols, rows)
	for k in cols * rows:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(k % cols, k / cols) * size, size)
		sf.add_frame(&"default", at)
	return sf


## Morte do X: duas rodas de 8 bolhas de energia (death.png do mmx8) saindo do corpo.
static func x_death(parent: Node, at: Vector2) -> void:
	var frames := grid("res://assets/fx_mmx8/death.png", 3, 2, 15.0)
	frames.set_animation_loop(&"default", true)
	for ring in [1.3, 2.4]:
		for k in 8:
			var orb := Orb.new()
			orb.sprite_frames = frames
			orb.position = at
			orb.velocity = Vector2.RIGHT.rotated(k * TAU / 8 + (0.0 if ring < 2 else TAU / 16)) * ring
			orb.z_index = 5
			parent.add_child(orb)
			orb.play()


static func _sprite(frames: SpriteFrames, at: Vector2, anim := &"default") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.position = at
	s.z_index = 5
	if frames.has_animation(anim):
		frames.set_animation_loop(anim, false)
		s.play(anim)
	s.animation_finished.connect(s.queue_free)
	return s


static func _sound(parent: Node, at: Vector2) -> void:
	var snd := Assets.audio(DIR + "enemy_death.wav")
	if snd == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = snd
	p.position = at
	p.volume_db = -6.0
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.play()


## Bolha da morte do X: anda reto e some depois de 1,5 s.
class Orb extends AnimatedSprite2D:
	var velocity := Vector2.ZERO
	var _t := 0

	func _physics_process(_delta: float) -> void:
		_t += 1
		position += velocity
		if _t > 90:
			queue_free()


## Pedaço que voa, gira, cai e some.
class Debris extends Sprite2D:
	var velocity := Vector2.ZERO
	var _t := 0

	func _physics_process(_delta: float) -> void:
		_t += 1
		velocity.y += 0.15
		position += velocity
		rotation += velocity.x * 0.08
		modulate.a = clampf(1.5 - _t / 50.0, 0.0, 1.0)
		if _t > 75:
			queue_free()
