# SomeSide v0.20.1 构建记录

日期：2026-10-06。引擎：Godot 4.7.2，GDScript，Compatibility 渲染。

## 本次变化

- 直接移除敌方预警中的瞄准线、胶囊边框、范围圆框、冲锋通道边线、扑击轨迹、闪现与治疗虚线，以及敌方弹丸的两条辅助翼线。预警改由透明多帧材质承担：激光前方为电离烟流，冲锋为贴地扬尘，范围攻击为尘雾或孢雾，闪现为两端裂隙，治疗为弯曲飘动的能量碎片。
- 敌方开火、爆发与闪现事件从旧通用几何特效中分流，防止攻击释放时重新出现冲击圆环或速度线。玩家原有技能、武器、护盾和拾取反馈保持原样。
- `natural_threats.gd` 与 `enemy_attack_visual.gd` 仅消费快照。危险位置、射程、半径和计时继续取自主机，低特效与减少动态选项保留主要预警材质；没有修改 `simulation.gd` 或 `content.gd`。
- 新增电离烟流与尘雾两组八帧源图。活动特效图集共8张、64帧，导入上限1024²，共32 MiB（本版增加8 MiB，未提高原硬预算）。源文件、固定裁剪/锚点与内置 imagegen 完整提示词见 [素材记录](../assets/fx/v0201/ART_PROMPTS.md)。运行时使用缓存纹理，不生成新图片。

## 原生画面与攻击验证

- `tools/capture-natural-warnings-v0201.gd` 由真实AI准备和释放15种攻击，使用正式世界渲染；每种保留普通特效/最低特效与减少动态的准备、释放画面，每格960×540、1倍游戏尺寸。截图和逐tick轨迹在 `tools/results/natural-warnings-v0201/`，`report.json` 全部通过。
- 四段正常倍率实机片段覆盖激光、地刺、闪现、治疗，每段180个60Hz模拟步，输出1280×720/30fps；合并12秒 `natural-warnings-preview.webm`。没有直接制造伤害或替换预警形状来拍摄。
- `tools/capture-enemy-fx-v0201.gd` 保留64帧图册、预警阶段图、正常倍率激光和冲锋截图、交叉光束及60fps短片，位于 `tools/results/enemy-attacks-v0201/`。原生合成未出现源图透明预览的红色边缘。
- 新增自然预警验收91项，验证真实AI时序、预警期无提前伤害、锁定后可以躲避、低特效可见性、3个治疗目标的总治疗预算、敌方事件不产生旧圆环，以及渲染与未渲染模拟连续210tick结果一致。另有57项敌方动作/材质与44项图集检查，包括左向冲锋尘雾保持直立。

## 完成验证

- 完整回归50套、2747项通过，0失败、0运行错误、0警告。日志 `tools/results/tests-v0201.log`，汇总 `tests-v0201-summary.json`。
- Windows和Web独立导出成功，导出日志无运行错误或警告。独立Windows程序实跑480tick、34事件、1击杀，正常截图并以0退出；8张特效纹理全部从发布资源加载。`tools/results/export-v0201-report.json`，实机截图 `export-v0201-game.png`。
- 导出程序四人合作、三关跨场景、房主英文/客户端中文通过。同机真实ENet连接，覆盖全部9种普通敌人、3种首领、16种起手与两种危险区形状；客户端收到846/915/948次快照。所有进程正常退出、零运行错误、均加载8张特效。`tools/results/network-export-biomes-bilingual-20261006-190440/summary.json`。本轮未重跑丢包网络模拟。
- Chrome154 Web验收15/15通过：跨源iframe、960×540与1920×1080适配、全屏、真实Web Audio输出、语言/FPS偏好持久化、全部新贴图加载；模拟推进541tick，浏览器/网络/Godot错误为0。测试iframe存在浏览器提示 `allow` 优先于 `allowfullscreen`，不影响功能。`tools/results/web-v0201-chrome/report.json`。
- 性能观察：Windows/RTX5070Ti末次读数59FPS；Chrome/AMD610M/ANGLE末次33FPS，冷启动5.50秒。这是自动验收的单次读数，本版未做持续帧率或前后性能基准，不作为帧率保证。
- Web ZIP审计通过，根入口与11个资源/许可文件齐全，无缺失引用。`tools/results/web-v0201-artifacts.json`。本机用户profile前后SHA-256相同：`37209484288A6F10833133BA615EDCAFB817B0F7128A9C9F77280EA971754E16`。

## 本地发布文件

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/SomeSide-v0.20.1-windows-x64.zip` | 69176653 | `E691D6236B7EBDD8A1AA2200C7C1C219A73021BB9F779868188EEC0B49571ABA` |
| `dist/v0.20.1/SomeSide.exe` | 139222840 | `527827F5499904CBDB1667B01A5786534ABB2D7A05BBA0FB74B8B864115391F1` |
| `dist/SomeSide-v0.20.1-web.zip` | 40329511 | `3852F6251831DCBE2AEE1A7F30E326545A4964E9F5DF06DF7B4D52BA89EA9D50` |

清单：`tools/results/package-v0201-windows.json`、`package-v0201-web.json`。Windows版支持2–4人合作，Web版仍为单人。旧版本与宣传素材保留；本轮只生成本地包，未替换itch线上文件。

测试、截图、视频和发布包按既有规则留在本机忽略目录中。上版构建记录：[v0.20.0](BUILD_REPORT_v0.20.0.md)。
