class_name SideUITheme
extends RefCounted

## The same machined, cut-corner surface underlies menus and compact HUDs.
## StyleBoxFlat keeps native button/focus behavior and adds no redraw loop.
static func panel(fill: Color, edge: Color, cut: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1 if edge.a > 0.0 else 0)
	style.set_corner_radius_all(cut)
	style.corner_detail = 1
	style.anti_aliasing = false
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 11.0
	style.content_margin_bottom = 11.0
	if edge.a > 0.0 and cut >= 4:
		style.shadow_color = Color(0.005, 0.015, 0.02, 0.30)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
	return style

static func button(fill: Color, edge: Color, primary: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel(fill, edge, 7)
	style.corner_radius_top_left = 1
	style.corner_radius_bottom_right = 1
	style.border_width_bottom = 2
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	if primary: style.border_width_left = 3
	return style

static func slider_grip(color: Color) -> Texture2D:
	var image := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 1, 10, 20), Color("07171f"))
	image.fill_rect(Rect2i(3, 2, 8, 17), color)
	image.fill_rect(Rect2i(5, 7, 1, 7), Color("355452"))
	image.fill_rect(Rect2i(8, 7, 1, 7), Color("355452"))
	return ImageTexture.create_from_image(image)
