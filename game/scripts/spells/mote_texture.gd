class_name MoteTexture
extends RefCounted
## A soft round glow sprite generated once at runtime (no external texture).

static var _tex: ImageTexture


static func get_texture() -> ImageTexture:
	if _tex:
		return _tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
