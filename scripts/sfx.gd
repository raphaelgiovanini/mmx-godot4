class_name Sfx
## Sons curtos do mmx8 (assets/sfx/, tools/install_sfx.sh): um tocador por som, que some ao terminar.
## Sem o arquivo, fica em silêncio.


static func play(node: Node, name: String, volume_db := 0.0) -> void:
	var dir := "res://assets/sfx/"
	var stream := Assets.audio(dir + name + ".wav") if Assets.exists(dir + name + ".wav") else Assets.audio(dir + name + ".ogg")
	if stream == null or not node.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db - 4.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.finished.connect(p.queue_free)
	var tree := node.get_tree()
	(tree.current_scene if tree.current_scene else tree.root).add_child(p)
	p.play()
