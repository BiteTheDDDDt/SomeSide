SomeSide — itch.io 宣传素材 / Press images
2026-10-05 · 游戏版本 v0.17.0

双击 index.html 可在浏览器中查看整组素材，点击图片打开原图。

封面
covers/SomeSide-cover-630x500.png：推荐上传到 itch 的 Cover image。
covers/SomeSide-cover-315x250.png：最小尺寸预览，检查缩略图阅读效果。
covers/SomeSide-cover-master.png：高清加工原图。

这张封面以真实游戏的森林双人交战截图为底图，使用内置 imagegen
移除小型名字/伤害标记、排入 SomeSide 标题，并轻微加强明暗与已有电弧。
原始截图保留在 source/forest-coop-cover-base.png；完整提示词在
source/cover-prompt.txt。根目录以前的 cover.png 保持原样。

宣传截图
screenshots/ 中的图片为1920×1080 PNG，可直接上传 itch 截图栏。
它们来自游戏原生渲染和真实HUD：预先布置位置、合法装备与敌群，
随后执行真实移动/攻击/技能输入并挑选画面。截图没有AI重绘、调色、
后加弹幕或界面合成。双人合作画面对应Windows合作模式。

建议先放遗迹首领战，再放森林合作与峡谷跑跳，最后补充近战、架盾和金币反馈。

生成与核对
拍摄工具：tools/capture-promo-v017.gd（Godot 4.7.2原生渲染）。
封面尺寸导出及打包：tools/package-promo.ps1。
files.json 列出每张最终图片的尺寸、文件大小与SHA-256。
source/capture-selection.json 保留截图选择及原图对应关系。
source/ 子目录为制作留档，不需要上传itch；发布ZIP只包含最终封面、截图和说明。
marketing/.gdignore 将宣传素材与游戏资源导出隔离。

No game code was changed for these images. The user's saved profile is preserved.
The cover is a retouched screenshot; promotional screenshots are unretouched,
directed in-game captures using the production simulation, renderer and HUD.
