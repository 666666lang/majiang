extends SceneTree
## 检查 assets/tiles/flowers/ 里的花牌图有没有「真透明通道」。
##
## 用法（无窗口跑一遍）：
##   godot --headless --path . --script res://tools/检查花牌透明通道.gd
##
## 为什么需要它：有些 AI 出图工具导出 PNG 时，会把「棋盘格」当成图案画进图片里，
## 而不是写入 alpha 通道——看起来像是透明底，实际每个像素都是不透明的，
## 贴到牌面上就会带一层白框。这个脚本直接看像素的 alpha，一眼分辨。

const DIR := "res://assets/tiles/flowers/"


func _initialize() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		print("打不开目录：", DIR)
		quit(1)
		return
	print("花牌图检查（看「透明像素占比」）：")
	var bad: Array[String] = []
	for file in dir.get_files():
		var ext := file.get_extension().to_lower()
		if ext != "png" and ext != "webp":
			continue
		var texture: Texture2D = load(DIR + file)
		if texture == null:
			print("  ", file, "  ：读不到")
			continue
		var image := texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var w := image.get_width()
		var h := image.get_height()
		var total := 0
		var clear := 0
		# 隔点采样就够了，快很多
		for y in range(0, h, 4):
			for x in range(0, w, 4):
				total += 1
				if image.get_pixel(x, y).a < 0.5:
					clear += 1
		var ratio := 100.0 * float(clear) / float(maxi(total, 1))
		var verdict := "✅ 真透明底" if ratio >= 5.0 else "❌ 没有透明通道（背景是画上去的）"
		print("  %-14s %dx%d   透明像素 %5.1f%%   %s" % [file, w, h, ratio, verdict])
		if ratio < 5.0:
			bad.append(file)
	print("")
	if bad.is_empty():
		print("全部合格 ✓")
	else:
		print("需要重做的：", ", ".join(bad))
		print("要求出图工具「保留 Alpha 通道」导出，别用棋盘格表示透明。")
	quit()
