class_name StatIcons
extends RefCounted

## Smooth procedural HUD / world icons (clock, coin). High-res with antialiased edges.

const SIZE := 128

static var _clock: ImageTexture
static var _coin: ImageTexture


static func clock_texture() -> Texture2D:
	if _clock == null:
		_clock = _from_image(_draw_clock())
	return _clock


static func coin_texture() -> Texture2D:
	if _coin == null:
		_coin = _from_image(_draw_coin())
	return _coin


static func _from_image(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _draw_clock() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2((SIZE - 1) * 0.5, (SIZE - 1) * 0.5)
	_fill_disk(img, c, 54.0, Color(0.16, 0.18, 0.21, 0.96))
	_stroke_ring(img, c, 50.0, 6.5, Color(0.93, 0.88, 0.70, 1.0))
	_stroke_line(img, c, c + Vector2(0.0, -28.0), 3.4, Color(0.96, 0.92, 0.78, 1.0))
	_stroke_line(img, c, c + Vector2(22.0, 10.0), 3.0, Color(0.95, 0.80, 0.38, 1.0))
	_fill_disk(img, c, 5.0, Color(1.0, 0.86, 0.40, 1.0))
	return img


static func _draw_coin() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2((SIZE - 1) * 0.5, (SIZE - 1) * 0.5)
	_fill_disk(img, c, 54.0, Color(0.78, 0.56, 0.14, 1.0))
	_fill_disk(img, c, 44.0, Color(0.92, 0.72, 0.22, 1.0))
	_stroke_ring(img, c, 50.0, 5.5, Color(1.0, 0.88, 0.42, 1.0))
	_stroke_line(img, c + Vector2(0.0, -16.0), c + Vector2(0.0, 16.0), 4.0, Color(1.0, 0.93, 0.55, 1.0))
	_stroke_line(img, c + Vector2(-11.0, -15.0), c + Vector2(11.0, -15.0), 3.2, Color(1.0, 0.93, 0.55, 1.0))
	_stroke_line(img, c + Vector2(-11.0, 15.0), c + Vector2(11.0, 15.0), 3.2, Color(1.0, 0.93, 0.55, 1.0))
	return img


static func _fill_disk(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 := radius + 1.6
	var min_x := maxi(int(center.x - r2), 0)
	var max_x := mini(int(center.x + r2) + 1, SIZE - 1)
	var min_y := maxi(int(center.y - r2), 0)
	var max_y := mini(int(center.y + r2) + 1, SIZE - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d := Vector2(float(x), float(y)).distance_to(center)
			_blend(img, x, y, color, _aa(radius - d))


static func _stroke_ring(img: Image, center: Vector2, radius: float, width: float, color: Color) -> void:
	var half := width * 0.5
	var r2 := radius + half + 1.6
	var min_x := maxi(int(center.x - r2), 0)
	var max_x := mini(int(center.x + r2) + 1, SIZE - 1)
	var min_y := maxi(int(center.y - r2), 0)
	var max_y := mini(int(center.y + r2) + 1, SIZE - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d := absf(Vector2(float(x), float(y)).distance_to(center) - radius)
			_blend(img, x, y, color, _aa(half - d))


static func _stroke_line(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var half := width * 0.5
	var pad := half + 1.6
	var min_x := maxi(int(minf(a.x, b.x) - pad), 0)
	var max_x := mini(int(maxf(a.x, b.x) + pad) + 1, SIZE - 1)
	var min_y := maxi(int(minf(a.y, b.y) - pad), 0)
	var max_y := mini(int(maxf(a.y, b.y) + pad) + 1, SIZE - 1)
	var ab := b - a
	var len_sq := ab.length_squared()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x), float(y))
			var t := 0.0 if len_sq < 0.0001 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			_blend(img, x, y, color, _aa(half - d))


static func _aa(signed_dist: float, softness: float = 1.35) -> float:
	return clampf(signed_dist / softness + 0.5, 0.0, 1.0)


static func _blend(img: Image, x: int, y: int, color: Color, a: float) -> void:
	if a <= 0.002:
		return
	var src_a := color.a * a
	var dst := img.get_pixel(x, y)
	var out_a := src_a + dst.a * (1.0 - src_a)
	if out_a <= 0.002:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (color.r * src_a + dst.r * dst.a * (1.0 - src_a)) / out_a
	var g := (color.g * src_a + dst.g * dst.a * (1.0 - src_a)) / out_a
	var b := (color.b * src_a + dst.b * dst.a * (1.0 - src_a)) / out_a
	img.set_pixel(x, y, Color(r, g, b, out_a))
