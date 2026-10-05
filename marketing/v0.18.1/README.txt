SomeSide — itch.io 宣传素材 / Press images
2026-10-05 · 游戏版本 v0.18.1

双击 index.html 可查看完整素材；每张图片均可点击打开原图。

封面
covers/SomeSide-cover-630x500.png：推荐上传 itch 的 Cover image。
covers/SomeSide-cover-315x250.png：最小尺寸预览。
covers/SomeSide-cover-master.png：高清封面。

封面使用当前版本的游戏资产单独搭建宣传场景，包含当前角色、
平滑武器、雨林地形材质及怪物。封面场景经过摄影布局，属于宣传
构图，不表示游戏中存在这一块完全相同的平台布局。
二次加工使用内置 imagegen 加入标题和轻微明暗整理。
原生底图、完整提示词和捕获记录保存在 source/，便于复核。

三张宣传截图（1920×1080 PNG）
screenshots/01-forest-coop.png：雨林中的双人合作。
screenshots/02-canyon-action.png：折光断崖的平台动作。
screenshots/03-ruins-boss.png：双环遗迹首领战与高阶装备。

截图使用实际关卡地形、游戏模拟、最新平滑武器/图标及真实HUD。
为拍摄预先安排位置、合法装备与敌群，随后运行游戏输入选择时刻。
摄影镜头使用1.15–1.25倍近景，HUD保持原有大小，以便看清动作。
截图没有AI重绘、后加弹幕或合成界面。双人合作画面对应Windows版；
Web版为单人模式。截图均直接复制Godot原始PNG。

复现
tools/capture-cover-v0181.gd：封面场景底图。
tools/capture-promo-v0181.gd：三种游戏战斗场景。
tools/package-promo.ps1：封面技术尺寸导出和最终发布包。
files.json：每个最终图片的尺寸、大小和SHA-256。
source/capture-selection.json：截图选择及原图对应关系。

发布ZIP只包含封面、三张截图、预览页和说明。source/为制作留档，
不需要上传itch。根目录原有cover.png与旧版宣传素材保留。
本次没有改变游戏玩法、玩家存档或已发布的itch文件。
