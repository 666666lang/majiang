shader_type canvas_item;
// 花牌贴图：按「圆角矩形」裁一刀。
//
// 半径和矩形都是牌面在绘制时算好传进来的，所以图片是 9:12 还是 9:14、
// 牌是大牌还是商店里的小牌，圆角都跟牌身自己的圆角一样大，看着才是一套。

// 贴图在牌面里的矩形（局部像素，x、y、宽、高）
uniform vec4 mask_rect = vec4(0.0, 0.0, 100.0, 140.0);
// 圆角半径（局部像素）
uniform float corner_radius = 8.0;

varying vec2 face_pos;


void vertex() {
	// VERTEX 是顶点在牌面局部坐标里的位置（像素）
	face_pos = VERTEX;
}


void fragment() {
	vec2 half_size = mask_rect.zw * 0.5;
	vec2 p = abs(face_pos - mask_rect.xy - half_size) - half_size + vec2(corner_radius);
	// 圆角矩形的有向距离：负数在圆角内，正数在圆角外
	float dist = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - corner_radius;
	// 用屏幕上的导数做一像素宽的羽化，缩到多小都不会有锯齿
	float edge = max(fwidth(dist), 0.5);
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.a *= clamp(0.5 - dist / edge, 0.0, 1.0);
	COLOR = col;
}
