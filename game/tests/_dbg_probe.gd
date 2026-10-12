extends Node
## Dev: prints terrain heights on a grid (to site a flat spot for the range).
##   godot --headless --path game -- --dbg --probe
func _ready() -> void:
	var main := get_parent()
	await get_tree().process_frame
	var t: MeadowTerrain = main.terrain
	var zs := range(-40, 51, 5)
	var line := "x\\z "
	for z in zs:
		line += "%6d" % z
	print(line)
	for x in range(-50, 51, 5):
		line = "%4d" % x
		for z in zs:
			line += "%6.1f" % t.height_at(x, z)
		print(line)
	get_tree().quit()
